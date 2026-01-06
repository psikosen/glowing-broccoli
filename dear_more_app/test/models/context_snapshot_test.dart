import 'package:flutter_test/flutter_test.dart';
import 'package:dear_more/models/context_snapshot.dart';
import 'dart:typed_data';

void main() {
  group('ContextSnapshot', () {
    test('creates snapshot with valid data', () {
      final snapshot = ContextSnapshot(
        timestamp: DateTime.now().millisecondsSinceEpoch,
        accelXBuffer: List.filled(50, 0.5),
        accelYBuffer: List.filled(50, 0.3),
        accelZBuffer: List.filled(50, 9.8),
        avgAudioDecibel: 45.0,
        gpsSpeed: 5.0,
        lightLux: 100,
      );

      expect(snapshot.accelXBuffer.length, 50);
      expect(snapshot.accelYBuffer.length, 50);
      expect(snapshot.accelZBuffer.length, 50);
      expect(snapshot.avgAudioDecibel, 45.0);
      expect(snapshot.gpsSpeed, 5.0);
      expect(snapshot.lightLux, 100);
    });

    test('converts to tensor input with correct shape', () {
      final snapshot = ContextSnapshot(
        timestamp: DateTime.now().millisecondsSinceEpoch,
        accelXBuffer: List.filled(50, 0.5),
        accelYBuffer: List.filled(50, 0.3),
        accelZBuffer: List.filled(50, 9.8),
        avgAudioDecibel: 45.0,
        gpsSpeed: 5.0,
        lightLux: 100,
      );

      final normStats = {
        'accel_x_mean': 0.0,
        'accel_x_std': 1.0,
        'accel_y_mean': 0.0,
        'accel_y_std': 1.0,
        'accel_z_mean': 9.8,
        'accel_z_std': 1.0,
        'audio_mean': 50.0,
        'audio_std': 10.0,
        'gps_speed_mean': 0.0,
        'gps_speed_std': 5.0,
        'light_mean': 100.0,
        'light_std': 50.0,
      };

      final tensorInput = snapshot.toTensorInput(normStats);

      expect(tensorInput.length, 200);
      expect(tensorInput, isA<Float32List>());
    });

    test('applies z-score normalization correctly', () {
      final snapshot = ContextSnapshot(
        timestamp: DateTime.now().millisecondsSinceEpoch,
        accelXBuffer: List.filled(50, 2.0),  // All same value
        accelYBuffer: List.filled(50, 0.0),
        accelZBuffer: List.filled(50, 0.0),
        avgAudioDecibel: 60.0,
        gpsSpeed: 10.0,
        lightLux: 200,
      );

      final normStats = {
        'accel_x_mean': 0.0,
        'accel_x_std': 2.0,
        'accel_y_mean': 0.0,
        'accel_y_std': 1.0,
        'accel_z_mean': 0.0,
        'accel_z_std': 1.0,
        'audio_mean': 50.0,
        'audio_std': 10.0,
        'gps_speed_mean': 5.0,
        'gps_speed_std': 5.0,
        'light_mean': 100.0,
        'light_std': 50.0,
      };

      final tensorInput = snapshot.toTensorInput(normStats);

      // First 50 values should be normalized accel_x
      // (2.0 - 0.0) / 2.0 = 1.0
      expect(tensorInput[0], closeTo(1.0, 0.01));
      expect(tensorInput[49], closeTo(1.0, 0.01));
    });

    test('serializes to and from JSON', () {
      final original = ContextSnapshot(
        timestamp: 1234567890,
        accelXBuffer: [1.0, 2.0, 3.0],
        accelYBuffer: [4.0, 5.0, 6.0],
        accelZBuffer: [7.0, 8.0, 9.0],
        avgAudioDecibel: 45.0,
        gpsSpeed: 5.0,
        lightLux: 100,
      );

      final json = original.toJson();
      final restored = ContextSnapshot.fromJson(json);

      expect(restored.timestamp, original.timestamp);
      expect(restored.accelXBuffer, original.accelXBuffer);
      expect(restored.avgAudioDecibel, original.avgAudioDecibel);
    });

    test('handles division by zero in normalization', () {
      final snapshot = ContextSnapshot(
        timestamp: DateTime.now().millisecondsSinceEpoch,
        accelXBuffer: List.filled(50, 1.0),
        accelYBuffer: List.filled(50, 1.0),
        accelZBuffer: List.filled(50, 1.0),
        avgAudioDecibel: 50.0,
        gpsSpeed: 5.0,
        lightLux: 100,
      );

      final normStats = {
        'accel_x_mean': 1.0,
        'accel_x_std': 0.0,  // Zero std deviation
        'accel_y_mean': 1.0,
        'accel_y_std': 0.0,
        'accel_z_mean': 1.0,
        'accel_z_std': 0.0,
        'audio_mean': 50.0,
        'audio_std': 0.0,
        'gps_speed_mean': 5.0,
        'gps_speed_std': 0.0,
        'light_mean': 100.0,
        'light_std': 0.0,
      };

      // Should not throw division by zero error
      expect(() => snapshot.toTensorInput(normStats), returnsNormally);

      final tensorInput = snapshot.toTensorInput(normStats);
      expect(tensorInput.every((v) => v.isFinite), true);
    });
  });
}
