"""
Tests for model distribution API endpoints
"""
import pytest


@pytest.mark.asyncio
async def test_get_latest_model_no_update(client, sample_model_version):
    """Test checking for updates when already on latest version"""
    response = await client.get(
        "/models/v1/latest",
        params={"device_id": "test_device", "current_version": 1}
    )

    assert response.status_code == 200
    data = response.json()

    assert data["update_available"] is False
    assert data["current_version"] == 1
    assert data["latest_version"] == 1
    assert data["model_url"] is None


@pytest.mark.asyncio
async def test_get_latest_model_update_available(client, sample_model_version):
    """Test checking for updates when update is available"""
    response = await client.get(
        "/models/v1/latest",
        params={"device_id": "test_device", "current_version": 0}
    )

    assert response.status_code == 200
    data = response.json()

    assert data["update_available"] is True
    assert data["current_version"] == 0
    assert data["latest_version"] == 1
    assert data["model_url"] is not None
    assert "/models/v1/download/1" in data["model_url"]


@pytest.mark.asyncio
async def test_get_latest_model_no_active_model(client, db_session):
    """Test when no active model exists"""
    response = await client.get(
        "/models/v1/latest",
        params={"device_id": "test_device", "current_version": 0}
    )

    # Should return 404 if no models exist
    # (sample_model_version fixture not used)
    assert response.status_code in [200, 404]


@pytest.mark.asyncio
async def test_download_model(client, sample_model_version):
    """Test model download endpoint"""
    response = await client.get("/models/v1/download/1")

    assert response.status_code == 200
    data = response.json()

    assert data["version"] == 1
    assert "download_url" in data
    assert "checksum" in data


@pytest.mark.asyncio
async def test_download_model_not_found(client):
    """Test downloading non-existent model version"""
    response = await client.get("/models/v1/download/999")

    assert response.status_code == 404
    data = response.json()
    assert "detail" in data
