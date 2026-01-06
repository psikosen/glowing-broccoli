"""
Tests for ML model architecture and components
"""
import pytest
import numpy as np
import tensorflow as tf
from app.ml.model import FeatureExtractorModel, TripletLossModel


def test_feature_extractor_model_build():
    """Test feature extractor model can be built"""
    model = FeatureExtractorModel(input_dim=200, embedding_dim=64)
    keras_model = model.build_model()

    assert keras_model is not None
    assert keras_model.input_shape == (None, 200)
    assert keras_model.output_shape == (None, 64)
    assert keras_model.name == "cortex"


def test_feature_extractor_inference():
    """Test feature extractor produces normalized embeddings"""
    model = FeatureExtractorModel(input_dim=200, embedding_dim=64)
    keras_model = model.build_model()

    # Create random input
    test_input = np.random.randn(10, 200).astype(np.float32)

    # Get embeddings
    embeddings = keras_model.predict(test_input, verbose=0)

    assert embeddings.shape == (10, 64)

    # Check L2 normalization (magnitude should be ~1.0)
    magnitudes = np.linalg.norm(embeddings, axis=1)
    assert np.allclose(magnitudes, 1.0, atol=1e-5)


def test_triplet_loss_function():
    """Test triplet loss calculation"""
    base_model = FeatureExtractorModel(input_dim=200, embedding_dim=64)
    base_model.build_model()

    triplet_model = TripletLossModel(base_model.model, margin=0.5)

    # Create dummy embeddings
    anchor = np.random.randn(5, 64).astype(np.float32)
    positive = anchor + np.random.randn(5, 64) * 0.1  # Similar to anchor
    negative = np.random.randn(5, 64).astype(np.float32)  # Different

    # Normalize
    anchor = anchor / np.linalg.norm(anchor, axis=1, keepdims=True)
    positive = positive / np.linalg.norm(positive, axis=1, keepdims=True)
    negative = negative / np.linalg.norm(negative, axis=1, keepdims=True)

    # Concatenate as expected by loss function
    y_pred = np.concatenate([anchor, positive, negative], axis=1)
    y_true = np.zeros(5)  # Dummy labels

    # Calculate loss
    loss = triplet_model.triplet_loss(y_true, y_pred)

    assert loss.numpy() >= 0.0  # Loss should be non-negative
    assert not np.isnan(loss.numpy())


def test_triplet_model_build():
    """Test triplet training model can be built"""
    base_model = FeatureExtractorModel(input_dim=200, embedding_dim=64)
    base_model.build_model()

    triplet_trainer = TripletLossModel(base_model.model, margin=0.5)
    training_model = triplet_trainer.build_triplet_model()

    assert training_model is not None
    assert len(training_model.inputs) == 3  # Anchor, positive, negative
    assert training_model.output_shape == (None, 192)  # 64*3


def test_model_weight_sharing():
    """Test that triplet model shares weights across branches"""
    base_model = FeatureExtractorModel(input_dim=200, embedding_dim=64)
    base_model.build_model()

    triplet_trainer = TripletLossModel(base_model.model, margin=0.5)
    training_model = triplet_trainer.build_triplet_model()

    # Create test inputs
    test_input = np.random.randn(2, 200).astype(np.float32)

    # Get embeddings from base model
    base_embedding = base_model.model.predict(test_input, verbose=0)

    # Get embeddings from triplet model (anchor branch)
    triplet_output = training_model.predict(
        [test_input, test_input, test_input],
        verbose=0
    )
    anchor_embedding = triplet_output[:, :64]

    # Should be identical (weights are shared)
    assert np.allclose(base_embedding, anchor_embedding, atol=1e-5)


def test_embedding_dimension_configuration():
    """Test that embedding dimension can be configured"""
    for embedding_dim in [32, 64, 128]:
        model = FeatureExtractorModel(input_dim=200, embedding_dim=embedding_dim)
        keras_model = model.build_model()

        test_input = np.random.randn(1, 200).astype(np.float32)
        output = keras_model.predict(test_input, verbose=0)

        assert output.shape == (1, embedding_dim)
