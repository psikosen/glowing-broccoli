from sqlalchemy import Column, String, Float, Integer, DateTime, LargeBinary, Boolean
from sqlalchemy.dialects.postgresql import UUID, ARRAY
from datetime import datetime
import uuid
from app.db.session import Base

class Device(Base):
    __tablename__ = "devices"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    device_id = Column(String, unique=True, index=True, nullable=False)
    last_sync = Column(DateTime, default=datetime.utcnow)
    model_version = Column(Integer, default=1)
    created_at = Column(DateTime, default=datetime.utcnow)

class SyncData(Base):
    __tablename__ = "sync_data"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    device_id = Column(String, index=True, nullable=False)
    vector = Column(LargeBinary, nullable=False)  # Stores Float32 array as bytes
    label = Column(String, nullable=True)
    novelty_score = Column(Float, nullable=False)
    timestamp = Column(DateTime, nullable=False)
    synced_at = Column(DateTime, default=datetime.utcnow)

class TrainingData(Base):
    __tablename__ = "training_data"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    vector = Column(LargeBinary, nullable=False)
    label = Column(String, nullable=False)
    source_device_id = Column(String, nullable=True)  # Anonymized
    created_at = Column(DateTime, default=datetime.utcnow)
    used_in_training = Column(Boolean, default=False)

class ModelVersion(Base):
    __tablename__ = "model_versions"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    version = Column(Integer, unique=True, nullable=False)
    model_path = Column(String, nullable=False)
    tflite_path = Column(String, nullable=False)
    metrics = Column(String, nullable=True)  # JSON string
    created_at = Column(DateTime, default=datetime.utcnow)
    is_active = Column(Boolean, default=False)
