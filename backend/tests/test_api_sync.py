"""
Tests for sync API endpoints
"""
import pytest
import base64
import json
import numpy as np
from datetime import datetime


@pytest.mark.asyncio
async def test_sync_dream_cycle_success(client, db_session):
    """Test successful dream cycle sync"""
    # Prepare test data
    vectors = []
    for i in range(3):
        vector = np.random.randn(64).astype(np.float32)
        vectors.append({
            "vector": base64.b64encode(vector.tobytes()).decode(),
            "label": f"Activity_{i}",
            "novelty_score": 0.5 + i * 0.1,
            "timestamp": int(datetime.now().timestamp() * 1000)
        })

    # Encode as JSON then base64 (simplified encryption for testing)
    payload = json.dumps(vectors).encode()
    encrypted_data = base64.b64encode(payload).decode()

    request_data = {
        "device_id": "test_device_456",
        "encrypted_data": encrypted_data,
        "version": 1
    }

    response = await client.post("/sync/v1/dream", json=request_data)

    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "success"
    assert data["synced_count"] == 3
    assert "message" in data


@pytest.mark.asyncio
async def test_sync_dream_cycle_empty_data(client):
    """Test sync with empty data"""
    request_data = {
        "device_id": "test_device_empty",
        "encrypted_data": base64.b64encode(b"[]").decode(),
        "version": 1
    }

    response = await client.post("/sync/v1/dream", json=request_data)

    assert response.status_code == 200
    data = response.json()
    assert data["synced_count"] == 0


@pytest.mark.asyncio
async def test_sync_stats(client, sample_sync_data, sample_training_data):
    """Test sync statistics endpoint"""
    response = await client.get("/sync/v1/stats")

    assert response.status_code == 200
    data = response.json()

    assert "total_devices" in data
    assert "total_synced_vectors" in data
    assert "training_vectors" in data
    assert "timestamp" in data

    assert data["total_devices"] >= 1
    assert data["total_synced_vectors"] >= 1
    assert data["training_vectors"] >= 15  # 3 labels * 5 samples


@pytest.mark.asyncio
async def test_sync_creates_device(client, db_session):
    """Test that sync creates device record if not exists"""
    from sqlalchemy import select
    from app.db.models import Device

    vector = np.random.randn(64).astype(np.float32)
    vectors = [{
        "vector": base64.b64encode(vector.tobytes()).decode(),
        "label": "Testing",
        "novelty_score": 0.7,
        "timestamp": int(datetime.now().timestamp() * 1000)
    }]

    payload = json.dumps(vectors).encode()
    encrypted_data = base64.b64encode(payload).decode()

    new_device_id = "brand_new_device_789"
    request_data = {
        "device_id": new_device_id,
        "encrypted_data": encrypted_data,
        "version": 1
    }

    response = await client.post("/sync/v1/dream", json=request_data)
    assert response.status_code == 200

    # Check device was created
    result = await db_session.execute(
        select(Device).where(Device.device_id == new_device_id)
    )
    device = result.scalar_one_or_none()
    assert device is not None
    assert device.device_id == new_device_id
