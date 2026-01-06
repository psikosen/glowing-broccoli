# Backend Testing Guide

## Running Tests

### All Tests
```bash
pytest
```

### Specific Test File
```bash
pytest tests/test_api_sync.py
```

### With Coverage Report
```bash
pytest --cov=app --cov-report=html
```

### Async Tests Only
```bash
pytest -m asyncio
```

### Skip Slow Tests
```bash
pytest -m "not slow"
```

## Test Structure

```
tests/
├── conftest.py              # Fixtures and configuration
├── test_api_health.py       # Health check endpoint tests
├── test_api_sync.py         # Sync API tests
├── test_api_models.py       # Model distribution tests
├── test_ml_model.py         # ML model architecture tests
├── test_training.py         # Training pipeline tests
└── test_encryption.py       # Encryption service tests
```

## Fixtures Available

### Database Fixtures
- `test_engine` - Test database engine
- `db_session` - Database session for each test
- `sample_device` - Pre-created device record
- `sample_sync_data` - Pre-created sync data
- `sample_training_data` - Pre-created training data
- `sample_model_version` - Pre-created model version

### Client Fixture
- `client` - AsyncClient for API testing

## Test Database

Tests use a separate database: `dear_more_test`

Set custom test database URL:
```bash
export TEST_DATABASE_URL="postgresql+asyncpg://user:pass@localhost/test_db"
pytest
```

## Coverage Requirements

Target: **80%+ code coverage**

Current coverage:
```bash
pytest --cov=app --cov-report=term
```

## Writing New Tests

### API Test Example
```python
@pytest.mark.asyncio
async def test_my_endpoint(client):
    response = await client.get("/my/endpoint")
    assert response.status_code == 200
```

### Database Test Example
```python
@pytest.mark.asyncio
async def test_my_db_operation(db_session):
    # Create
    item = MyModel(field="value")
    db_session.add(item)
    await db_session.commit()

    # Verify
    assert item.id is not None
```

### ML Model Test Example
```python
def test_my_model():
    model = MyModel()
    output = model.predict(input_data)
    assert output.shape == expected_shape
```

## CI/CD Integration

Tests run automatically on:
- Push to main branch
- Pull request creation
- Pre-commit hooks (optional)

GitHub Actions configuration:
```yaml
- name: Run tests
  run: pytest --cov=app --cov-report=xml
```

## Troubleshooting

### Database Connection Issues
```bash
# Ensure PostgreSQL is running
docker-compose up -d postgres

# Create test database
docker-compose exec postgres createdb -U postgres dear_more_test
```

### Async Test Failures
Ensure `pytest-asyncio` is installed:
```bash
pip install pytest-asyncio
```

### Import Errors
Run tests from project root:
```bash
cd backend/
pytest
```
