from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from typing import Optional
from datetime import datetime
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, desc
import os

from app.db.session import get_db
from app.db.models import ModelVersion, Device
from app.core.config import settings

router = APIRouter()

class ModelInfoResponse(BaseModel):
    update_available: bool
    current_version: int
    latest_version: int
    model_url: Optional[str] = None
    model_size: Optional[int] = None
    changelog: Optional[str] = None

@router.get("/latest", response_model=ModelInfoResponse)
async def get_latest_model(
    device_id: str,
    current_version: int,
    db: AsyncSession = Depends(get_db)
):
    """
    Check for model updates and return download URL if available
    The "Evolution" Cycle endpoint
    """
    try:
        # Get latest active model version
        query = select(ModelVersion).where(
            ModelVersion.is_active == True
        ).order_by(desc(ModelVersion.version))

        result = await db.execute(query)
        latest_model = result.scalar_one_or_none()

        if not latest_model:
            raise HTTPException(status_code=404, detail="No active model found")

        update_available = latest_model.version > current_version

        model_url = None
        model_size = None

        if update_available:
            # Generate download URL
            model_url = f"/models/v1/download/{latest_model.version}"

            # Get file size
            if os.path.exists(latest_model.tflite_path):
                model_size = os.path.getsize(latest_model.tflite_path)

        # Update device model version tracking
        device_query = select(Device).where(Device.device_id == device_id)
        device_result = await db.execute(device_query)
        device = device_result.scalar_one_or_none()

        if device and update_available:
            device.model_version = latest_model.version
            await db.commit()

        return ModelInfoResponse(
            update_available=update_available,
            current_version=current_version,
            latest_version=latest_model.version,
            model_url=model_url,
            model_size=model_size,
            changelog=f"Model v{latest_model.version} - Improved accuracy"
        )

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/download/{version}")
async def download_model(
    version: int,
    db: AsyncSession = Depends(get_db)
):
    """Download a specific model version"""
    try:
        query = select(ModelVersion).where(ModelVersion.version == version)
        result = await db.execute(query)
        model = result.scalar_one_or_none()

        if not model:
            raise HTTPException(status_code=404, detail="Model version not found")

        if not os.path.exists(model.tflite_path):
            raise HTTPException(status_code=404, detail="Model file not found")

        # In production, this would use FileResponse or presigned S3 URLs
        return {
            "version": version,
            "download_url": f"https://cdn.dearmore.ai/models/cortex_v{version}.tflite",
            "checksum": "sha256:...",
        }

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
