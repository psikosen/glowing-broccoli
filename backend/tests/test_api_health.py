"""
Tests for health check endpoints
"""
import pytest


@pytest.mark.asyncio
async def test_health_check(client):
    """Test basic health check endpoint"""
    response = await client.get("/health/")

    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"
    assert data["service"] == "Dear More API"
    assert "timestamp" in data


@pytest.mark.asyncio
async def test_database_health_check(client):
    """Test database health check endpoint"""
    response = await client.get("/health/db")

    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"
    assert data["database"] == "connected"
    assert "timestamp" in data


@pytest.mark.asyncio
async def test_root_endpoint(client):
    """Test root endpoint"""
    response = await client.get("/")

    assert response.status_code == 200
    data = response.json()
    assert data["service"] == "Dear More API"
    assert data["version"] == "1.0.0"
    assert data["status"] == "operational"
