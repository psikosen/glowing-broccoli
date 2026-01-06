"""
Pytest configuration and fixtures for backend tests
"""
import pytest
import asyncio
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from httpx import AsyncClient
from app.db.session import Base
from app.db.models import Device, SyncData, TrainingData, ModelVersion
from main import app
import os

# Test database URL
TEST_DATABASE_URL = os.getenv(
    "TEST_DATABASE_URL",
    "postgresql+asyncpg://postgres:postgres@localhost:5432/dear_more_test"
)


@pytest.fixture(scope="session")
def event_loop():
    """Create an event loop for the test session"""
    loop = asyncio.get_event_loop_policy().new_event_loop()
    yield loop
    loop.close()


@pytest.fixture(scope="session")
async def test_engine():
    """Create test database engine"""
    engine = create_async_engine(TEST_DATABASE_URL, echo=False)

    # Create all tables
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    yield engine

    # Drop all tables after tests
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)

    await engine.dispose()


@pytest.fixture
async def db_session(test_engine):
    """Create a new database session for each test"""
    async_session = async_sessionmaker(
        test_engine,
        class_=AsyncSession,
        expire_on_commit=False,
    )

    async with async_session() as session:
        yield session
        await session.rollback()


@pytest.fixture
async def client(db_session):
    """Create test client with database dependency override"""
    from app.db.session import get_db

    async def override_get_db():
        yield db_session

    app.dependency_overrides[get_db] = override_get_db

    async with AsyncClient(app=app, base_url="http://test") as ac:
        yield ac

    app.dependency_overrides.clear()


@pytest.fixture
async def sample_device(db_session):
    """Create a sample device for testing"""
    device = Device(device_id="test_device_123")
    db_session.add(device)
    await db_session.commit()
    await db_session.refresh(device)
    return device


@pytest.fixture
async def sample_sync_data(db_session, sample_device):
    """Create sample sync data"""
    import numpy as np

    vector = np.random.randn(64).astype(np.float32)

    sync_data = SyncData(
        device_id=sample_device.device_id,
        vector=vector.tobytes(),
        label="Walking",
        novelty_score=0.8,
        timestamp=asyncio.get_event_loop().time()
    )
    db_session.add(sync_data)
    await db_session.commit()
    await db_session.refresh(sync_data)
    return sync_data


@pytest.fixture
async def sample_training_data(db_session):
    """Create sample training data"""
    import numpy as np

    data = []
    for label in ["Walking", "Running", "Sitting"]:
        for _ in range(5):
            vector = np.random.randn(200).astype(np.float32)
            training = TrainingData(
                vector=vector.tobytes(),
                label=label,
                source_device_id=None
            )
            db_session.add(training)
            data.append(training)

    await db_session.commit()
    return data


@pytest.fixture
async def sample_model_version(db_session):
    """Create a sample model version"""
    model = ModelVersion(
        version=1,
        model_path="/tmp/model_v1.h5",
        tflite_path="/tmp/model_v1.tflite",
        metrics='{"loss": 0.5}',
        is_active=True
    )
    db_session.add(model)
    await db_session.commit()
    await db_session.refresh(model)
    return model
