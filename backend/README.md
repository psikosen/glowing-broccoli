# Dear More Backend API

FastAPI backend for the Dear More multimodal digital twin system.

## Quick Start

### With Docker Compose (Recommended)

```bash
# Start all services
docker-compose up -d

# Check logs
docker-compose logs -f api

# Stop services
docker-compose down
```

The API will be available at `http://localhost:8000`

### Manual Setup

```bash
# Create virtual environment
python -m venv venv
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Set up environment
cp .env.example .env
# Edit .env with your settings

# Start PostgreSQL (or use Docker)
docker run -d \
  --name dear_more_postgres \
  -e POSTGRES_DB=dear_more \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=postgres \
  -p 5432:5432 \
  postgres:15-alpine

# Run migrations (auto-created on first run)
# Tables will be created automatically

# Start API server
uvicorn main:app --reload
```

## API Documentation

Once running, visit:
- **Swagger UI**: http://localhost:8000/docs
- **ReDoc**: http://localhost:8000/redoc

## Training a Model

```bash
# Activate virtual environment
source venv/bin/activate

# Run training
python -m app.cli.train --epochs 50

# Monitor training
# The model will be saved to ./models/cortex_vX.h5 and cortex_vX.tflite
```

## Project Structure

```
backend/
├── main.py                 # FastAPI application entry point
├── app/
│   ├── api/               # API endpoints
│   │   ├── sync.py        # Sync endpoints (dream cycle)
│   │   ├── models.py      # Model distribution endpoints
│   │   └── health.py      # Health checks
│   ├── core/
│   │   └── config.py      # Configuration settings
│   ├── db/
│   │   ├── models.py      # SQLAlchemy models
│   │   └── session.py     # Database session management
│   ├── ml/
│   │   ├── model.py       # TensorFlow model architecture
│   │   └── training.py    # Training pipeline
│   ├── services/
│   │   └── encryption.py  # Encryption utilities
│   └── cli/
│       └── train.py       # Training CLI tool
├── models/                # Saved model files
├── Dockerfile            # Docker image definition
├── docker-compose.yml    # Multi-container setup
├── nginx.conf           # Nginx reverse proxy config
└── requirements.txt     # Python dependencies
```

## Environment Variables

See `.env.example` for all configuration options.

Key variables:
- `DATABASE_URL`: PostgreSQL connection string
- `SECRET_KEY`: Encryption/signing key (change in production!)
- `DEBUG`: Enable debug mode (False in production)
- `EMBEDDING_DIM`: Embedding vector size (64)
- `TRIPLET_MARGIN`: Triplet loss margin (0.5)

## Development

```bash
# Install dev dependencies
pip install -r requirements.txt

# Run tests
pytest

# Run with auto-reload
uvicorn main:app --reload --host 0.0.0.0 --port 8000

# Format code
black app/
isort app/

# Type checking
mypy app/
```

## Production Deployment

### Option 1: Docker Compose

```bash
# Set production environment variables
export SECRET_KEY="your-strong-secret-key-here"

# Start services
docker-compose up -d

# View logs
docker-compose logs -f
```

### Option 2: Kubernetes

Create Kubernetes manifests based on the Docker Compose configuration.

Key considerations:
- Use secrets for `SECRET_KEY` and database credentials
- Configure persistent volumes for model storage
- Set up ingress for HTTPS
- Configure horizontal pod autoscaling

### Option 3: Cloud Services

Deploy to:
- **AWS**: ECS + RDS PostgreSQL
- **GCP**: Cloud Run + Cloud SQL
- **Azure**: Container Apps + PostgreSQL

## API Endpoints

### Sync

**POST /sync/v1/dream**
- Receives encrypted replay buffers from devices
- Stores vectors for training

**GET /sync/v1/stats**
- Returns sync statistics

### Models

**GET /models/v1/latest**
- Checks for model updates
- Returns download URL if update available

**GET /models/v1/download/{version}**
- Downloads specific model version

### Health

**GET /health**
- Basic health check

**GET /health/db**
- Database connectivity check

## Security

### Authentication
Currently using device IDs. For production, implement:
- JWT tokens
- API keys
- OAuth 2.0

### Rate Limiting
Configured in nginx.conf:
- 10 requests/second per IP
- Burst of 20 requests

### Encryption
- AES-256 for data at rest
- TLS for data in transit
- Device-specific encryption keys

## Monitoring

### Logs
```bash
# Docker Compose
docker-compose logs -f api

# Container
docker logs dear_more_api -f
```

### Metrics
Consider adding:
- Prometheus for metrics collection
- Grafana for visualization
- Sentry for error tracking

## Troubleshooting

### Database Connection Issues
```bash
# Check PostgreSQL is running
docker-compose ps postgres

# Test connection
docker-compose exec postgres psql -U postgres -d dear_more

# Reset database
docker-compose down -v
docker-compose up -d
```

### Model Training Failures
- Ensure sufficient training data (min 10 samples per class)
- Check GPU availability: `tensorflow.config.list_physical_devices('GPU')`
- Verify INPUT_DIM matches app sensor data (200)

### Port Already in Use
```bash
# Find process using port 8000
lsof -i :8000

# Kill process
kill -9 <PID>
```

## Performance Tuning

### Database
- Enable connection pooling (already configured)
- Add indices on frequently queried columns
- Regular VACUUM for PostgreSQL

### API
- Enable response compression
- Cache frequently accessed data
- Use async/await throughout

### Training
- Use GPU: `docker-compose --profile gpu up`
- Adjust batch size based on GPU memory
- Use mixed precision training

## License

MIT License
