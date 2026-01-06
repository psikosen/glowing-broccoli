# Dear More - Flutter App

The mobile application for Dear More digital twin system.

## Features

✅ Real-time sensor fusion (Accelerometer, GPS, Audio, Light)
✅ Background processing with foreground service
✅ TFLite on-device inference (<100ms)
✅ Encrypted local database (SQLCipher)
✅ Automatic context learning (Neurogenesis)
✅ Privacy-first design

## Getting Started

### Prerequisites

- Flutter SDK 3.0+
- Dart SDK 3.0+
- Android Studio / Xcode
- Android device (Android 8.0+) or iOS device (iOS 13.0+)

### Installation

```bash
# Clone the repository
git clone https://github.com/your-org/dear-more.git
cd dear-more/dear_more_app

# Install dependencies
flutter pub get

# Generate database code
flutter pub run build_runner build --delete-conflicting-outputs

# Run on device
flutter run --release
```

### Project Structure

```
lib/
├── main.dart                    # App entry point
├── models/
│   └── context_snapshot.dart    # Sensor data model
├── services/
│   ├── sensor_collector_service.dart   # Sensor fusion
│   ├── feature_extractor.dart         # TFLite inference
│   ├── memory_engine.dart             # Neurogenesis logic
│   ├── background_service.dart        # Background processing
│   └── sync_service.dart              # Server sync
├── database/
│   ├── database.dart            # Drift database
│   └── database.g.dart          # Generated code
└── ui/
    ├── home_screen.dart         # Main dashboard
    ├── memory_screen.dart       # Memory browser
    └── settings_screen.dart     # Settings
```

## How It Works

### 1. Sensor Collection (Every 5 seconds)
```dart
SensorCollectorService()
  .startCollection()
  .listen((ContextSnapshot snapshot) {
    // 50 samples of accel_x, accel_y, accel_z
    // + audio amplitude, GPS speed, light lux
  });
```

### 2. Feature Extraction
```dart
final embedding = await FeatureExtractor()
  .extractEmbedding(snapshot, normStats);
// Returns 64D L2-normalized vector
```

### 3. Memory Processing (Genesis Inequality)
```dart
final result = await MemoryEngine()
  .processSnapshot(snapshot);

if (result.isNovel) {
  // Show notification: "New context detected. Label?"
} else {
  // Match found: result.label
}
```

### 4. Background Sync
```dart
// Automatic sync when charging + WiFi
await SyncService().syncWithServer();
// Uploads encrypted replay buffer to server
```

## Configuration

### Server URL

Edit in Settings screen or modify:
```dart
// lib/ui/settings_screen.dart
String _serverUrl = 'https://api.dearmore.ai';
```

### Genesis Threshold

Adjust neurogenesis sensitivity:
```dart
// lib/services/memory_engine.dart
static const double genesisThreshold = 0.15; // Lower = more sensitive
```

### Learning Rate

Control how fast prototypes adapt:
```dart
static const double fastLearningRate = 0.05; // Higher = faster adaptation
```

## Permissions

### Android (AndroidManifest.xml)
- `ACCESS_FINE_LOCATION` - GPS speed
- `RECORD_AUDIO` - Ambient sound levels
- `FOREGROUND_SERVICE` - Background learning
- `SENSORS` - Accelerometer, gyroscope

### iOS (Info.plist)
- `NSLocationAlwaysAndWhenInUseUsageDescription`
- `NSMicrophoneUsageDescription`
- `NSMotionUsageDescription`
- `UIBackgroundModes`: location, fetch, processing

## Building for Production

### Android

```bash
# Generate keystore (first time only)
keytool -genkey -v -keystore dear-more-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias dear-more

# Create key.properties
cat > android/key.properties << EOF
storePassword=<password>
keyPassword=<password>
keyAlias=dear-more
storeFile=../dear-more-key.jks
EOF

# Build release APK
flutter build apk --release

# Build App Bundle (for Play Store)
flutter build appbundle --release
```

### iOS

```bash
# Configure signing in Xcode
open ios/Runner.xcworkspace

# Build for release
flutter build ios --release

# Archive in Xcode
# Product > Archive
```

## Testing

### Unit Tests
```bash
flutter test
```

### Integration Tests
```bash
flutter test integration_test/
```

### Manual Testing Checklist
- [ ] Background service starts on app launch
- [ ] Sensor data collection works
- [ ] Novel context triggers notification
- [ ] User can label contexts
- [ ] Labels persist after app restart
- [ ] Sync completes successfully
- [ ] Battery drain <5% per 24h

## Troubleshooting

### Database Issues
```bash
# Clear app data (development only)
flutter clean
flutter pub get
flutter run

# Or on device:
# Settings > Apps > Dear More > Storage > Clear Data
```

### TFLite Model Not Found
```bash
# Ensure model exists
ls assets/models/cortex_v1.tflite

# If missing, download from server or use mock mode
# The app will use mock embeddings if model is missing
```

### Background Service Not Running

**Android**:
```dart
// Check battery optimization
// Settings > Apps > Dear More > Battery > Unrestricted
```

**iOS**:
```dart
// Ensure location permission is "Always"
// Settings > Dear More > Location > Always
```

### High Battery Drain

Adjust collection frequency:
```dart
// lib/services/sensor_collector_service.dart
Timer.periodic(
  const Duration(seconds: 10), // Increase from 5 to 10
  (_) => _generateSnapshot(),
);
```

## Privacy & Security

### What We Collect
- ✅ Accelerometer patterns (not raw values)
- ✅ GPS speed and heading (not coordinates)
- ✅ Audio amplitude (not recordings)
- ✅ Light sensor readings

### What We DON'T Collect
- ❌ Raw audio recordings
- ❌ GPS coordinates
- ❌ Personal information
- ❌ Contacts, messages, etc.

### Data Protection
- Local database encrypted with SQLCipher
- Encryption keys in secure storage
- Only 64D vectors synced to server
- User controls all labels

## Performance Optimization

### Battery
- Duty cycle: 5s active, adjust as needed
- Sensors only when screen on (optional)
- Sync only on WiFi + charging

### Storage
- Auto-prune at 500MB limit
- Keep only centroids + recent replay buffer
- Compress old prototypes

### CPU
- TFLite optimized for mobile
- Float16 quantization
- Async processing throughout

## Contributing

1. Fork the repo
2. Create feature branch
3. Follow Flutter style guide
4. Add tests
5. Submit PR

## License

MIT License

## Support

- Issues: GitHub Issues
- Email: support@dearmore.ai
- Docs: https://docs.dearmore.ai
