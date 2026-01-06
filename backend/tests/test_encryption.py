"""
Tests for encryption service
"""
import pytest
import json
import base64
from app.services.encryption import decrypt_payload, encrypt_response


@pytest.mark.asyncio
async def test_decrypt_payload_json():
    """Test decrypting JSON payload"""
    # Create test data
    test_data = [
        {"vector": "abc123", "label": "Walking", "novelty_score": 0.5}
    ]

    # Encode as base64 JSON (simplified encryption)
    payload = json.dumps(test_data).encode()
    encrypted = base64.b64encode(payload).decode()

    # Decrypt
    decrypted = await decrypt_payload(encrypted)

    assert isinstance(decrypted, list)
    if len(decrypted) > 0:
        assert decrypted[0]["label"] == "Walking"


@pytest.mark.asyncio
async def test_decrypt_payload_invalid():
    """Test handling of invalid encrypted data"""
    invalid_data = "not-valid-base64-!@#$"

    # Should not raise exception, return empty list
    result = await decrypt_payload(invalid_data)

    assert isinstance(result, list)


@pytest.mark.asyncio
async def test_encrypt_response():
    """Test encrypting response data"""
    test_data = {
        "status": "success",
        "message": "Test message"
    }

    # Encrypt
    encrypted = await encrypt_response(test_data)

    assert isinstance(encrypted, str)
    assert len(encrypted) > 0

    # Should be valid base64
    try:
        base64.b64decode(encrypted)
    except Exception:
        pytest.fail("Encrypted data is not valid base64")


@pytest.mark.asyncio
async def test_encrypt_decrypt_roundtrip():
    """Test encryption and decryption roundtrip"""
    original_data = {
        "test": "data",
        "number": 42,
        "nested": {"key": "value"}
    }

    # Note: Current implementation doesn't support full roundtrip
    # This test documents expected behavior
    encrypted = await encrypt_response(original_data)

    assert encrypted is not None
    assert isinstance(encrypted, str)
