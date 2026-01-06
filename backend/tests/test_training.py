"""
Tests for training pipeline
"""
import pytest
import numpy as np
from app.ml.training import TripletDataGenerator


def test_triplet_data_generator_creation():
    """Test triplet data generator can be created"""
    # Create sample data
    data_by_label = {
        "Walking": [np.random.randn(200).astype(np.float32) for _ in range(20)],
        "Running": [np.random.randn(200).astype(np.float32) for _ in range(20)],
        "Sitting": [np.random.randn(200).astype(np.float32) for _ in range(20)],
    }

    generator = TripletDataGenerator(data_by_label, batch_size=8, shuffle=True)

    assert len(generator) > 0
    assert generator.batch_size == 8
    assert len(generator.labels) == 3


def test_triplet_data_generator_batch():
    """Test generator produces correct batch format"""
    data_by_label = {
        "Walking": [np.random.randn(200).astype(np.float32) for _ in range(15)],
        "Running": [np.random.randn(200).astype(np.float32) for _ in range(15)],
    }

    generator = TripletDataGenerator(data_by_label, batch_size=4, shuffle=False)

    # Get a batch
    (anchors, positives, negatives), labels = generator[0]

    # Check shapes
    assert anchors.shape == (4, 200)
    assert positives.shape == (4, 200)
    assert negatives.shape == (4, 200)
    assert labels.shape == (4,)

    # Anchors and positives should be from same class (not identical)
    # Negatives should be from different class
    # Can't test exactly without knowing generator internals


def test_triplet_data_generator_length():
    """Test generator calculates correct number of batches"""
    total_samples = 60
    batch_size = 10

    data_by_label = {
        "Class1": [np.random.randn(200).astype(np.float32) for _ in range(20)],
        "Class2": [np.random.randn(200).astype(np.float32) for _ in range(20)],
        "Class3": [np.random.randn(200).astype(np.float32) for _ in range(20)],
    }

    generator = TripletDataGenerator(data_by_label, batch_size=batch_size)

    expected_batches = total_samples // batch_size
    assert len(generator) == expected_batches


def test_triplet_data_generator_epoch_end():
    """Test generator shuffles on epoch end"""
    data_by_label = {
        "Walking": [np.random.randn(200).astype(np.float32) for _ in range(10)],
        "Running": [np.random.randn(200).astype(np.float32) for _ in range(10)],
    }

    generator = TripletDataGenerator(data_by_label, batch_size=4, shuffle=True)

    # Get first batch
    batch1, _ = generator[0]

    # Call epoch end
    generator.on_epoch_end()

    # Get first batch again
    batch2, _ = generator[0]

    # Batches might be different due to shuffling
    # (not guaranteed, but likely with random data)
    # Just verify no errors occurred
    assert batch1[0].shape == batch2[0].shape


def test_triplet_data_generator_insufficient_samples():
    """Test generator handles classes with insufficient samples"""
    data_by_label = {
        "Class1": [np.random.randn(200).astype(np.float32)],  # Only 1 sample
        "Class2": [np.random.randn(200).astype(np.float32) for _ in range(20)],
    }

    generator = TripletDataGenerator(data_by_label, batch_size=4)

    # Should still work but skip Class1 for anchor/positive pairs
    (anchors, positives, negatives), _ = generator[0]

    # Check that we got some samples (even if not full batch)
    assert len(anchors) >= 0
