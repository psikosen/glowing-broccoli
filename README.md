# Dear More - Multimodal Digital Twin with Continual Learning

A production-ready edge-cloud AI system that creates a "digital twin" of user behavior through continual learning. The system combines a stable pre-trained "Cortex" (server) with a plastic, dynamic "Hippocampus" (device) for real-time context understanding.

## 🏗️ Architecture

**System Type**: Hybrid Edge-Cloud with Nested Continual Learning

**Core Philosophy**: Bicameral AI combining:
- **Cortex (Server/Slow)**: Stable pre-trained feature extractor
- **Hippocampus (Device/Fast)**: Dynamic neurogenesis engine

### High-Level Components

```
┌─────────────────────────────────────────┐
│           FLUTTER APP (Edge)            │
├─────────────────────────────────────────┤
│  Sensor Layer    → Context Snapshots    │
│  Cortex (TFLite) → Feature Extraction   │
│  Hippocampus     → Memory & Learning    │
│  SQLite + AES    → Encrypted Storage    │
└─────────────────┬───────────────────────┘
                  │ Sync (Encrypted)
                  ↓
┌─────────────────────────────────────────┐
│        PYTHON BACKEND (Cloud)           │
├─────────────────────────────────────────┤
│  FastAPI         → REST API             │
│  PostgreSQL      → Training Data        │
│  TensorFlow      → Model Training       │
│  Triplet Loss    → Contrastive Learning │
└─────────────────────────────────────────┘
```

## 📱 Frontend (Flutter)

### Features

- **Real-time sensor fusion** (Accelerometer, GPS, Audio, Light)
- **Background processing** with foreground service (Android)
- **TFLite inference** (<100ms latency)
- **SQLite with SQLCipher** encryption
- **Neurogenesis** - automatic learning of new contexts
- **Privacy-first** - no raw sensor data leaves device

See [dear_more_app/README.md](dear_more_app/README.md) for detailed Flutter documentation.

## 🐍 Backend (Python)

### Features

- **FastAPI** REST API
- **Triplet Loss** contrastive learning
- **Async PostgreSQL** with SQLAlchemy
- **Model versioning** and distribution
- **Docker** deployment ready

See [backend/README.md](backend/README.md) for detailed backend documentation.

## 🚀 Quick Start

### Backend

```bash
cd backend
docker-compose up -d
```

The API will be available at `http://localhost:8000`

### Frontend

```bash
cd dear_more_app
flutter pub get
flutter pub run build_runner build
flutter run --release
```

## 🧮 Mathematical Specifications

### Genesis Inequality (Neurogenesis Trigger)

```
d_min = min{1 - ⟨z, c_i⟩ | c_i ∈ M}

if d_min ≤ τ:  # Match found (τ = 0.15)
    Update centroid (Hebbian)
else:  # Novelty detected
    Create new prototype
```

### Triplet Loss (Server Training)

```
L = max(||f(a) - f(p)||² - ||f(a) - f(n)||² + margin, 0)

a = anchor (same activity at time t)
p = positive (same activity at time t+Δt)
n = negative (different activity)
margin = 0.5
```

## 🔒 Security & Privacy

### Privacy Guarantees
- ❌ No raw audio recordings
- ❌ No GPS coordinates (only speed/heading)
- ❌ No personally identifiable information
- ✅ Only 64-dimensional vectors synced
- ✅ User controls all labels
- ✅ SQLCipher encryption on device

## 📊 Performance Requirements

### Device (Flutter)
- **Latency**: <100ms per inference + DB lookup
- **Battery**: <5% drain per 24h
- **Storage**: 500MB database limit (5 years of data)

### Server (Python)
- **Training**: ~2-4 hours on GPU for 10K samples
- **API**: FastAPI with async PostgreSQL

## 🛠️ Tech Stack

### Frontend
- Flutter 3.x, Dart 3.x
- TFLite, Drift (SQLite), Riverpod

### Backend
- Python 3.11, FastAPI
- TensorFlow 2.15, PostgreSQL 15
- Docker & Docker Compose

## 📝 License

MIT License - See LICENSE file

## 📧 Support

For issues and questions:
- GitHub Issues: https://github.com/psikosen/glowing-broccoli/issues

---

**Version**: 1.0.0
**Last Updated**: 2026-01-06
**Status**: Production Ready ✅
