from cryptography.fernet import Fernet
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
from cryptography.hazmat.backends import default_backend
import base64
import json
from app.core.config import settings

# In production, use proper key management (KMS, HashiCorp Vault, etc.)
# This is a simplified implementation for demonstration

def get_encryption_key() -> bytes:
    """Get or generate encryption key"""
    # In production, load from secure key storage
    key = settings.SECRET_KEY.encode()
    # Ensure key is 32 bytes for AES-256
    return key[:32].ljust(32, b'0')

async def decrypt_payload(encrypted_data: str) -> list:
    """
    Decrypt payload from mobile devices

    In production, this would:
    1. Decrypt with device's symmetric key
    2. Verify signature
    3. Check replay attack protection
    """
    try:
        # For now, assume data is base64-encoded JSON (simplified)
        # In production, implement proper AES-CBC decryption
        decoded = base64.b64decode(encrypted_data)

        # Simplified: just decode JSON
        # Real implementation would decrypt first
        try:
            data = json.loads(decoded)
        except:
            # If not JSON, try to decrypt with Fernet
            key = get_encryption_key()
            f = Fernet(base64.urlsafe_b64encode(key))
            decrypted = f.decrypt(decoded)
            data = json.loads(decrypted)

        return data
    except Exception as e:
        # For development, return mock data if decryption fails
        print(f"Decryption warning: {e}")
        # Return empty list to prevent errors
        return []

async def encrypt_response(data: dict) -> str:
    """Encrypt response data for mobile devices"""
    try:
        key = get_encryption_key()
        f = Fernet(base64.urlsafe_b64encode(key))

        json_data = json.dumps(data).encode()
        encrypted = f.encrypt(json_data)

        return base64.b64encode(encrypted).decode()
    except Exception as e:
        print(f"Encryption error: {e}")
        raise
