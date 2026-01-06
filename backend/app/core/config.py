from pydantic_settings import BaseSettings
from typing import List
import os

class Settings(BaseSettings):
    # API Settings
    HOST: str = "0.0.0.0"
    PORT: int = 8000
    DEBUG: bool = False

    # Security
    SECRET_KEY: str = os.getenv("SECRET_KEY", "your-secret-key-change-in-production")
    ALLOWED_ORIGINS: List[str] = ["*"]

    # Database
    DATABASE_URL: str = os.getenv(
        "DATABASE_URL",
        "postgresql://postgres:postgres@localhost:5432/dear_more"
    )

    # Model Storage
    MODEL_STORAGE_PATH: str = "./models"
    TFLITE_MODEL_NAME: str = "cortex_v1.tflite"

    # Training
    BATCH_SIZE: int = 32
    EMBEDDING_DIM: int = 64
    INPUT_DIM: int = 200
    LEARNING_RATE: float = 0.001
    EPOCHS: int = 50

    # Triplet Loss
    TRIPLET_MARGIN: float = 0.5

    # Data Processing
    MIN_SAMPLES_PER_CLASS: int = 10
    VALIDATION_SPLIT: float = 0.2

    class Config:
        env_file = ".env"
        case_sensitive = True

settings = Settings()
