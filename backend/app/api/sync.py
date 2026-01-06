from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
import base64
import numpy as np

from app.db.session import get_db
from app.db.models import Device, SyncData, TrainingData
from app.services.encryption import decrypt_payload

router = APIRouter()

class VectorData(BaseModel):
    vector: str  # Base64 encoded
    label: Optional[str] = None
    novelty_score: float
    timestamp: int

class SyncRequest(BaseModel):
    device_id: str
    encrypted_data: str
    version: int

class SyncResponse(BaseModel):
    status: str
    synced_count: int
    message: str

@router.post("/dream", response_model=SyncResponse)
async def sync_dream_cycle(
    request: SyncRequest,
    db: AsyncSession = Depends(get_db)
):
    """
    The "Dream" Cycle endpoint
    Receives encrypted replay buffer data from devices
    """
    try:
        # Decrypt payload
        decrypted_data = await decrypt_payload(request.encrypted_data)

        # Update or create device record
        device_query = select(Device).where(Device.device_id == request.device_id)
        result = await db.execute(device_query)
        device = result.scalar_one_or_none()

        if not device:
            device = Device(device_id=request.device_id)
            db.add(device)
        else:
            device.last_sync = datetime.utcnow()

        # Process each vector in the payload
        synced_count = 0
        for item in decrypted_data:
            try:
                # Decode base64 vector
                vector_bytes = base64.b64decode(item['vector'])

                # Store in sync_data table
                sync_entry = SyncData(
                    device_id=request.device_id,
                    vector=vector_bytes,
                    label=item.get('label'),
                    novelty_score=item['novelty_score'],
                    timestamp=datetime.fromtimestamp(item['timestamp'] / 1000.0),
                )
                db.add(sync_entry)

                # If labeled, add to training data
                if item.get('label'):
                    training_entry = TrainingData(
                        vector=vector_bytes,
                        label=item['label'],
                        source_device_id=None,  # Anonymized for privacy
                    )
                    db.add(training_entry)

                synced_count += 1
            except Exception as e:
                print(f"Error processing vector: {e}")
                continue

        await db.commit()

        return SyncResponse(
            status="success",
            synced_count=synced_count,
            message=f"Successfully synced {synced_count} vectors"
        )

    except Exception as e:
        await db.rollback()
        raise HTTPException(status_code=500, detail=f"Sync failed: {str(e)}")

@router.get("/stats")
async def get_sync_stats(db: AsyncSession = Depends(get_db)):
    """Get aggregated sync statistics"""
    try:
        # Count total devices
        device_query = select(Device)
        devices_result = await db.execute(device_query)
        total_devices = len(devices_result.scalars().all())

        # Count total synced vectors
        sync_query = select(SyncData)
        sync_result = await db.execute(sync_query)
        total_vectors = len(sync_result.scalars().all())

        # Count training data
        training_query = select(TrainingData)
        training_result = await db.execute(training_query)
        training_vectors = len(training_result.scalars().all())

        return {
            "total_devices": total_devices,
            "total_synced_vectors": total_vectors,
            "training_vectors": training_vectors,
            "timestamp": datetime.utcnow().isoformat(),
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
