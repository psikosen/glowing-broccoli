import 'package:flutter_test/flutter_test.dart';
import 'package:dear_more/services/feature_extractor.dart';
import 'package:dear_more/models/context_snapshot.dart';
import 'dart:math';

void main() {
  group('FeatureExtractor', () {
    test('L2 normalization produces unit vectors', () {
      final extractor = FeatureExtractor();

      final vector = List.generate(64, (i) => Random().nextDouble() * 10);
      final normalized = extractor._l2Normalize(vector);

      // Calculate magnitude
      double magnitude = 0.0;
      for (final v in normalized) {
        magnitude += v * v;
      }
      magnitude = sqrt(magnitude);

      expect(magnitude, closeTo(1.0, 0.001));
    });

    test('L2 normalization handles zero vector', () {
      final extractor = FeatureExtractor();

      final zeroVector = List.filled(64, 0.0);
      final normalized = extractor._l2Normalize(zeroVector);

      expect(normalized.every((v) => v == 0.0), true);
      expect(normalized.length, 64);
    });

    test('generates mock embedding when model not initialized', () async {
      final extractor = FeatureExtractor();
      // Don't initialize - use mock mode

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

      final embedding = await extractor.extractEmbedding(snapshot, normStats);

      expect(embedding.length, 64);
      expect(embedding.every((v) => v.isFinite), true);

      // Should be normalized
      double magnitude = 0.0;
      for (final v in embedding) {
        magnitude += v * v;
      }
      magnitude = sqrt(magnitude);
      expect(magnitude, closeTo(1.0, 0.01));
    });

    test('mock embeddings are deterministic for same timestamp', () async {
      final extractor = FeatureExtractor();

      final timestamp = 1234567890;
      final snapshot1 = ContextSnapshot(
        timestamp: timestamp,
        accelXBuffer: List.filled(50, 0.5),
        accelYBuffer: List.filled(50, 0.3),
        accelZBuffer: List.filled(50, 9.8),
        avgAudioDecibel: 45.0,
        gpsSpeed: 5.0,
        lightLux: 100,
      );

      final snapshot2 = ContextSnapshot(
        timestamp: timestamp,  // Same timestamp
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

      final embedding1 = await extractor.extractEmbedding(snapshot1, normStats);
      final embedding2 = await extractor.extractEmbedding(snapshot2, normStats);

      // Should produce similar embeddings for same input
      for (int i = 0; i < 64; i++) {
        expect(embedding1[i], closeTo(embedding2[i], 0.1));
      }
    });

    test('isInitialized returns false before initialization', () {
      final extractor = FeatureExtractor();
      expect(extractor.isInitialized, false);
    });

    test('embedding dimension is 64', () async {
      final extractor = FeatureExtractor();

      final snapshot = ContextSnapshot(
        timestamp: DateTime.now().millisecondsSinceEpoch,
        accelXBuffer: List.filled(50, 0.5),
        accelYBuffer: List.filled(50, 0.3),
        accelZBuffer: List.filled(50, 9.8),
        avgAudioDecibel: 45.0,
        gpsSpeed: 5.0,
        lightLux: 100,
      );

      final normStats = <String, double>{};
      final embedding = await extractor.extractEmbedding(snapshot, normStats);

      expect(embedding.length, 64);
    });
  });
}
