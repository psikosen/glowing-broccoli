import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:record/record.dart';
import 'package:light/light.dart';
import '../models/context_snapshot.dart';

/// Manages collection and synchronization of all sensor data
class SensorCollectorService {
  static final SensorCollectorService _instance =
      SensorCollectorService._internal();
  factory SensorCollectorService() => _instance;
  SensorCollectorService._internal();

  // Sensor buffers (50 samples @ ~50Hz = ~1 second)
  final List<double> _accelXBuffer = [];
  final List<double> _accelYBuffer = [];
  final List<double> _accelZBuffer = [];

  // Current sensor values
  double _avgAudioDecibel = 0.0;
  double _gpsSpeed = 0.0;
  int _lightLux = 0;

  // Subscriptions
  StreamSubscription? _accelerometerSubscription;
  StreamSubscription? _locationSubscription;
  Timer? _collectionTimer;
  Timer? _lightTimer;

  // Audio recorder
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isAudioRecording = false;

  // State
  bool _isCollecting = false;
  StreamController<ContextSnapshot>? _snapshotController;

  /// Start collecting sensor data
  Future<void> startCollection() async {
    if (_isCollecting) return;
    _isCollecting = true;

    _snapshotController = StreamController<ContextSnapshot>.broadcast();

    // Subscribe to accelerometer
    _accelerometerSubscription =
        accelerometerEventStream().listen(_onAccelerometerEvent);

    // Subscribe to location updates
    _locationSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.low,
        distanceFilter: 10,
      ),
    ).listen(_onLocationUpdate);

    // Start audio monitoring
    await _startAudioMonitoring();

    // Start light sensor monitoring
    _startLightMonitoring();

    // Start periodic snapshot generation (every 5 seconds)
    _collectionTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _generateSnapshot(),
    );
  }

  /// Stop collecting sensor data
  Future<void> stopCollection() async {
    _isCollecting = false;

    await _accelerometerSubscription?.cancel();
    await _locationSubscription?.cancel();
    _collectionTimer?.cancel();
    _lightTimer?.cancel();

    if (_isAudioRecording) {
      await _audioRecorder.stop();
      _isAudioRecording = false;
    }

    await _snapshotController?.close();
    _snapshotController = null;

    _clearBuffers();
  }

  /// Stream of context snapshots
  Stream<ContextSnapshot>? get snapshotStream => _snapshotController?.stream;

  void _onAccelerometerEvent(AccelerometerEvent event) {
    _accelXBuffer.add(event.x);
    _accelYBuffer.add(event.y);
    _accelZBuffer.add(event.z);

    // Keep only the last 50 samples
    if (_accelXBuffer.length > 50) {
      _accelXBuffer.removeAt(0);
      _accelYBuffer.removeAt(0);
      _accelZBuffer.removeAt(0);
    }
  }

  void _onLocationUpdate(Position position) {
    _gpsSpeed = position.speed;
  }

  Future<void> _startAudioMonitoring() async {
    if (await _audioRecorder.hasPermission()) {
      // Start recording to get amplitude data
      // Note: In production, we only monitor amplitude, not raw audio
      _isAudioRecording = true;

      // Monitor audio amplitude every 100ms
      Timer.periodic(const Duration(milliseconds: 100), (timer) async {
        if (!_isCollecting) {
          timer.cancel();
          return;
        }

        try {
          final amplitude = await _audioRecorder.getAmplitude();
          // Convert amplitude to decibels (rough approximation)
          _avgAudioDecibel = _amplitudeToDecibels(amplitude.current);
        } catch (e) {
          _avgAudioDecibel = 0.0;
        }
      });
    }
  }

  void _startLightMonitoring() {
    _lightTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!_isCollecting) {
        timer.cancel();
        return;
      }

      try {
        final light = Light();
        final luxValue = await light.lightSensorStream.first;
        _lightLux = luxValue.toInt();
      } catch (e) {
        _lightLux = 0;
      }
    });
  }

  double _amplitudeToDecibels(double amplitude) {
    if (amplitude <= 0) return 0.0;
    // Reference: -160 dB to 0 dB range
    return 20 * log(amplitude) / ln10;
  }

  void _generateSnapshot() {
    if (_accelXBuffer.length < 50) {
      // Not enough data yet, pad with zeros
      while (_accelXBuffer.length < 50) {
        _accelXBuffer.add(0.0);
        _accelYBuffer.add(0.0);
        _accelZBuffer.add(0.0);
      }
    }

    final snapshot = ContextSnapshot(
      timestamp: DateTime.now().millisecondsSinceEpoch,
      accelXBuffer: List.from(_accelXBuffer),
      accelYBuffer: List.from(_accelYBuffer),
      accelZBuffer: List.from(_accelZBuffer),
      avgAudioDecibel: _avgAudioDecibel,
      gpsSpeed: _gpsSpeed,
      lightLux: _lightLux,
    );

    _snapshotController?.add(snapshot);
  }

  void _clearBuffers() {
    _accelXBuffer.clear();
    _accelYBuffer.clear();
    _accelZBuffer.clear();
    _avgAudioDecibel = 0.0;
    _gpsSpeed = 0.0;
    _lightLux = 0;
  }

  bool get isCollecting => _isCollecting;
}
