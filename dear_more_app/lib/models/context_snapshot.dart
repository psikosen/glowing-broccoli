import 'dart:typed_data';

/// Represents a unified snapshot of all sensor data at a given moment
class ContextSnapshot {
  final int timestamp;
  final List<double> accelXBuffer;
  final List<double> accelYBuffer;
  final List<double> accelZBuffer;
  final double avgAudioDecibel;
  final double gpsSpeed;
  final int lightLux;

  ContextSnapshot({
    required this.timestamp,
    required this.accelXBuffer,
    required this.accelYBuffer,
    required this.accelZBuffer,
    required this.avgAudioDecibel,
    required this.gpsSpeed,
    required this.lightLux,
  });

  /// Convert to flattened float array for TFLite input
  /// Expected shape: [1, 200]
  /// Layout: 50 accel_x + 50 accel_y + 50 accel_z + 50 padding for other sensors
  Float32List toTensorInput(Map<String, double> normStats) {
    final input = Float32List(200);
    int offset = 0;

    // Accelerometer X (50 samples)
    for (int i = 0; i < 50; i++) {
      input[offset++] = _normalize(
        accelXBuffer[i],
        normStats['accel_x_mean'] ?? 0.0,
        normStats['accel_x_std'] ?? 1.0,
      );
    }

    // Accelerometer Y (50 samples)
    for (int i = 0; i < 50; i++) {
      input[offset++] = _normalize(
        accelYBuffer[i],
        normStats['accel_y_mean'] ?? 0.0,
        normStats['accel_y_std'] ?? 1.0,
      );
    }

    // Accelerometer Z (50 samples)
    for (int i = 0; i < 50; i++) {
      input[offset++] = _normalize(
        accelZBuffer[i],
        normStats['accel_z_mean'] ?? 0.0,
        normStats['accel_z_std'] ?? 1.0,
      );
    }

    // Additional features (50 values)
    // Audio decibel repeated
    for (int i = 0; i < 25; i++) {
      input[offset++] = _normalize(
        avgAudioDecibel,
        normStats['audio_mean'] ?? 0.0,
        normStats['audio_std'] ?? 1.0,
      );
    }

    // GPS speed repeated
    for (int i = 0; i < 15; i++) {
      input[offset++] = _normalize(
        gpsSpeed,
        normStats['gps_speed_mean'] ?? 0.0,
        normStats['gps_speed_std'] ?? 1.0,
      );
    }

    // Light lux repeated
    for (int i = 0; i < 10; i++) {
      input[offset++] = _normalize(
        lightLux.toDouble(),
        normStats['light_mean'] ?? 0.0,
        normStats['light_std'] ?? 1.0,
      );
    }

    return input;
  }

  /// Z-score normalization
  double _normalize(double value, double mean, double std) {
    const epsilon = 1e-7;
    return (value - mean) / (std + epsilon);
  }

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp,
        'accel_x_buffer': accelXBuffer,
        'accel_y_buffer': accelYBuffer,
        'accel_z_buffer': accelZBuffer,
        'avg_audio_decibel': avgAudioDecibel,
        'gps_speed': gpsSpeed,
        'light_lux': lightLux,
      };

  factory ContextSnapshot.fromJson(Map<String, dynamic> json) =>
      ContextSnapshot(
        timestamp: json['timestamp'] as int,
        accelXBuffer: List<double>.from(json['accel_x_buffer']),
        accelYBuffer: List<double>.from(json['accel_y_buffer']),
        accelZBuffer: List<double>.from(json['accel_z_buffer']),
        avgAudioDecibel: json['avg_audio_decibel'] as double,
        gpsSpeed: json['gps_speed'] as double,
        lightLux: json['light_lux'] as int,
      );
}
