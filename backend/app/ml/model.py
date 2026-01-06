import tensorflow as tf
from tensorflow import keras
from tensorflow.keras import layers
import numpy as np
from app.core.config import settings

class FeatureExtractorModel:
    """
    Base model for feature extraction (The Cortex)
    Uses MobileNetV3-inspired architecture with 1D convolutions
    """

    def __init__(self, input_dim=200, embedding_dim=64):
        self.input_dim = input_dim
        self.embedding_dim = embedding_dim
        self.model = None

    def build_model(self):
        """Build the feature extractor model"""
        inputs = layers.Input(shape=(self.input_dim,), name='sensor_input')

        # Reshape for 1D convolutions
        x = layers.Reshape((self.input_dim, 1))(inputs)

        # Initial convolution block
        x = self._conv_block(x, 32, 3)
        x = layers.MaxPooling1D(2)(x)

        # Depthwise separable convolutions (MobileNet-style)
        x = self._depthwise_separable_block(x, 64, 3)
        x = layers.MaxPooling1D(2)(x)

        x = self._depthwise_separable_block(x, 128, 3)
        x = layers.MaxPooling1D(2)(x)

        x = self._depthwise_separable_block(x, 256, 3)

        # Global average pooling
        x = layers.GlobalAveragePooling1D()(x)

        # Dense layers
        x = layers.Dense(128, activation='relu')(x)
        x = layers.Dropout(0.3)(x)

        # Embedding layer (no activation - raw embedding)
        embeddings = layers.Dense(self.embedding_dim, name='embeddings')(x)

        # L2 normalization for unit vectors
        normalized_embeddings = layers.Lambda(
            lambda x: tf.nn.l2_normalize(x, axis=1),
            name='normalized_embeddings'
        )(embeddings)

        self.model = keras.Model(inputs=inputs, outputs=normalized_embeddings, name='cortex')
        return self.model

    def _conv_block(self, x, filters, kernel_size):
        """Standard convolution block"""
        x = layers.Conv1D(filters, kernel_size, padding='same')(x)
        x = layers.BatchNormalization()(x)
        x = layers.ReLU()(x)
        return x

    def _depthwise_separable_block(self, x, filters, kernel_size):
        """Depthwise separable convolution block (efficient)"""
        x = layers.SeparableConv1D(filters, kernel_size, padding='same')(x)
        x = layers.BatchNormalization()(x)
        x = layers.ReLU()(x)
        return x

    def get_model(self):
        """Get the built model"""
        if self.model is None:
            self.build_model()
        return self.model


class TripletLossModel:
    """
    Wrapper for training with triplet loss
    Implements the contrastive learning objective
    """

    def __init__(self, base_model, margin=0.5):
        self.base_model = base_model
        self.margin = margin

    def triplet_loss(self, y_true, y_pred):
        """
        Triplet loss function
        L = max(||f(a) - f(p)||² - ||f(a) - f(n)||² + margin, 0)

        Where:
        - f(a) = anchor embedding
        - f(p) = positive embedding (same class)
        - f(n) = negative embedding (different class)
        """
        # y_pred contains [anchor, positive, negative] embeddings concatenated
        anchor = y_pred[:, :settings.EMBEDDING_DIM]
        positive = y_pred[:, settings.EMBEDDING_DIM:2*settings.EMBEDDING_DIM]
        negative = y_pred[:, 2*settings.EMBEDDING_DIM:]

        # Compute distances
        pos_dist = tf.reduce_sum(tf.square(anchor - positive), axis=1)
        neg_dist = tf.reduce_sum(tf.square(anchor - negative), axis=1)

        # Triplet loss
        loss = tf.maximum(pos_dist - neg_dist + self.margin, 0.0)

        return tf.reduce_mean(loss)

    def build_triplet_model(self):
        """Build model for triplet training"""
        # Three inputs: anchor, positive, negative
        anchor_input = layers.Input(shape=(settings.INPUT_DIM,), name='anchor')
        positive_input = layers.Input(shape=(settings.INPUT_DIM,), name='positive')
        negative_input = layers.Input(shape=(settings.INPUT_DIM,), name='negative')

        # Share weights across all three branches
        anchor_embedding = self.base_model(anchor_input)
        positive_embedding = self.base_model(positive_input)
        negative_embedding = self.base_model(negative_input)

        # Concatenate embeddings
        embeddings = layers.Concatenate()([
            anchor_embedding,
            positive_embedding,
            negative_embedding
        ])

        triplet_model = keras.Model(
            inputs=[anchor_input, positive_input, negative_input],
            outputs=embeddings,
            name='triplet_training_model'
        )

        return triplet_model


def convert_to_tflite(model, output_path):
    """
    Convert Keras model to TFLite format for mobile deployment
    Apply optimizations for edge devices
    """
    converter = tf.lite.TFLiteConverter.from_keras_model(model)

    # Optimizations
    converter.optimizations = [tf.lite.Optimize.DEFAULT]

    # For better performance on mobile
    converter.target_spec.supported_types = [tf.float16]

    # Convert
    tflite_model = converter.convert()

    # Save
    with open(output_path, 'wb') as f:
        f.write(tflite_model)

    print(f"TFLite model saved to {output_path}")
    print(f"Model size: {len(tflite_model) / 1024:.2f} KB")

    return output_path
