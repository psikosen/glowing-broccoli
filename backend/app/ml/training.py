import numpy as np
import tensorflow as tf
from tensorflow import keras
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from typing import List, Tuple
import random
from collections import defaultdict

from app.ml.model import FeatureExtractorModel, TripletLossModel, convert_to_tflite
from app.db.models import TrainingData, ModelVersion
from app.core.config import settings
import os


class TripletDataGenerator(keras.utils.Sequence):
    """
    Data generator for triplet loss training
    Generates batches of (anchor, positive, negative) triplets
    """

    def __init__(self, data_by_label, batch_size=32, shuffle=True):
        """
        Args:
            data_by_label: dict mapping labels to list of vectors
            batch_size: number of triplets per batch
        """
        self.data_by_label = data_by_label
        self.labels = list(data_by_label.keys())
        self.batch_size = batch_size
        self.shuffle = shuffle

        # Calculate total samples
        self.total_samples = sum(len(vectors) for vectors in data_by_label.values())
        self.on_epoch_end()

    def __len__(self):
        """Number of batches per epoch"""
        return int(np.floor(self.total_samples / self.batch_size))

    def __getitem__(self, index):
        """Generate one batch of triplets"""
        anchors = []
        positives = []
        negatives = []

        for _ in range(self.batch_size):
            # Select random anchor class
            anchor_label = random.choice(self.labels)

            # Select anchor and positive from same class
            if len(self.data_by_label[anchor_label]) < 2:
                continue

            anchor, positive = random.sample(self.data_by_label[anchor_label], 2)

            # Select negative from different class
            negative_label = random.choice([l for l in self.labels if l != anchor_label])
            negative = random.choice(self.data_by_label[negative_label])

            anchors.append(anchor)
            positives.append(positive)
            negatives.append(negative)

        # Convert to numpy arrays
        anchors = np.array(anchors, dtype=np.float32)
        positives = np.array(positives, dtype=np.float32)
        negatives = np.array(negatives, dtype=np.float32)

        # Dummy labels (not used by triplet loss)
        dummy_labels = np.zeros(len(anchors))

        return [anchors, positives, negatives], dummy_labels

    def on_epoch_end(self):
        """Shuffle data after each epoch"""
        if self.shuffle:
            for label in self.labels:
                random.shuffle(self.data_by_label[label])


async def load_training_data(db: AsyncSession) -> dict:
    """
    Load training data from database
    Returns dict mapping labels to list of vectors
    """
    query = select(TrainingData).where(TrainingData.label.isnot(None))
    result = await db.execute(query)
    training_samples = result.scalars().all()

    # Group by label
    data_by_label = defaultdict(list)

    for sample in training_samples:
        # Convert bytes to numpy array
        vector = np.frombuffer(sample.vector, dtype=np.float32)

        # Ensure correct shape
        if vector.shape[0] == settings.EMBEDDING_DIM:
            # This is already an embedding, skip
            continue

        if vector.shape[0] != settings.INPUT_DIM:
            print(f"Warning: Unexpected vector shape {vector.shape}, expected {settings.INPUT_DIM}")
            continue

        data_by_label[sample.label].append(vector)

    # Filter out classes with too few samples
    data_by_label = {
        label: vectors
        for label, vectors in data_by_label.items()
        if len(vectors) >= settings.MIN_SAMPLES_PER_CLASS
    }

    print(f"Loaded {len(data_by_label)} classes")
    for label, vectors in data_by_label.items():
        print(f"  {label}: {len(vectors)} samples")

    return data_by_label


async def train_model(db: AsyncSession, epochs: int = None):
    """
    Train the feature extractor model using triplet loss
    """
    if epochs is None:
        epochs = settings.EPOCHS

    print("Loading training data...")
    data_by_label = await load_training_data(db)

    if len(data_by_label) < 2:
        raise ValueError("Need at least 2 classes with sufficient samples for training")

    print(f"\nBuilding model...")
    # Build base feature extractor
    feature_extractor = FeatureExtractorModel(
        input_dim=settings.INPUT_DIM,
        embedding_dim=settings.EMBEDDING_DIM
    )
    base_model = feature_extractor.build_model()

    # Build triplet training model
    triplet_trainer = TripletLossModel(
        base_model=base_model,
        margin=settings.TRIPLET_MARGIN
    )
    training_model = triplet_trainer.build_triplet_model()

    # Compile model
    training_model.compile(
        optimizer=keras.optimizers.Adam(learning_rate=settings.LEARNING_RATE),
        loss=triplet_trainer.triplet_loss
    )

    print(f"\nModel architecture:")
    base_model.summary()

    # Create data generator
    train_generator = TripletDataGenerator(
        data_by_label=data_by_label,
        batch_size=settings.BATCH_SIZE,
        shuffle=True
    )

    # Callbacks
    callbacks = [
        keras.callbacks.EarlyStopping(
            monitor='loss',
            patience=5,
            restore_best_weights=True
        ),
        keras.callbacks.ReduceLROnPlateau(
            monitor='loss',
            factor=0.5,
            patience=3,
            min_lr=1e-6
        ),
        keras.callbacks.ModelCheckpoint(
            filepath=os.path.join(settings.MODEL_STORAGE_PATH, 'cortex_checkpoint.h5'),
            save_best_only=True,
            monitor='loss'
        )
    ]

    print(f"\nTraining for {epochs} epochs...")
    history = training_model.fit(
        train_generator,
        epochs=epochs,
        callbacks=callbacks,
        verbose=1
    )

    print("\nTraining completed!")

    # Save the base model (feature extractor)
    model_version = await _get_next_version(db)
    model_path = os.path.join(settings.MODEL_STORAGE_PATH, f'cortex_v{model_version}.h5')
    tflite_path = os.path.join(settings.MODEL_STORAGE_PATH, f'cortex_v{model_version}.tflite')

    # Ensure directory exists
    os.makedirs(settings.MODEL_STORAGE_PATH, exist_ok=True)

    # Save Keras model
    base_model.save(model_path)
    print(f"Saved Keras model to {model_path}")

    # Convert to TFLite
    convert_to_tflite(base_model, tflite_path)

    # Save model version to database
    model_record = ModelVersion(
        version=model_version,
        model_path=model_path,
        tflite_path=tflite_path,
        metrics=f"Final loss: {history.history['loss'][-1]:.4f}",
        is_active=True
    )

    # Deactivate previous versions
    query = select(ModelVersion).where(ModelVersion.is_active == True)
    result = await db.execute(query)
    old_models = result.scalars().all()
    for old_model in old_models:
        old_model.is_active = False

    db.add(model_record)
    await db.commit()

    print(f"\nModel v{model_version} saved and activated")

    return {
        'version': model_version,
        'model_path': model_path,
        'tflite_path': tflite_path,
        'final_loss': history.history['loss'][-1]
    }


async def _get_next_version(db: AsyncSession) -> int:
    """Get next model version number"""
    query = select(ModelVersion).order_by(ModelVersion.version.desc())
    result = await db.execute(query)
    latest = result.scalars().first()

    if latest:
        return latest.version + 1
    return 1
