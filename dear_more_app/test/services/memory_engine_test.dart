import 'package:flutter_test/flutter_test.dart';
import 'package:dear_more/services/memory_engine.dart';
import 'dart:math';

void main() {
  group('MemoryEngine', () {
    test('calculates cosine distance correctly', () {
      final engine = MemoryEngine();

      // Identical vectors
      final v1 = [1.0, 0.0, 0.0];
      final v2 = [1.0, 0.0, 0.0];

      // For unit vectors, cosine distance = 1 - dot_product
      // dot_product = 1.0, so distance = 0.0
      final distance = engine._cosineDistance(v1, v2);
      expect(distance, closeTo(0.0, 0.001));
    });

    test('calculates distance for orthogonal vectors', () {
      final engine = MemoryEngine();

      // Orthogonal unit vectors
      final v1 = [1.0, 0.0, 0.0];
      final v2 = [0.0, 1.0, 0.0];

      // dot_product = 0.0, so distance = 1.0
      final distance = engine._cosineDistance(v1, v2);
      expect(distance, closeTo(1.0, 0.001));
    });

    test('calculates distance for opposite vectors', () {
      final engine = MemoryEngine();

      // Opposite unit vectors
      final v1 = [1.0, 0.0, 0.0];
      final v2 = [-1.0, 0.0, 0.0];

      // dot_product = -1.0, so distance = 2.0
      final distance = engine._cosineDistance(v1, v2);
      expect(distance, closeTo(2.0, 0.001));
    });

    test('L2 normalizes vectors correctly', () {
      final engine = MemoryEngine();

      final vector = [3.0, 4.0, 0.0];
      final normalized = engine._l2Normalize(vector);

      // Magnitude should be 1.0
      final magnitude = sqrt(
        normalized.fold<double>(0.0, (sum, v) => sum + v * v)
      );

      expect(magnitude, closeTo(1.0, 0.001));
      expect(normalized[0], closeTo(0.6, 0.01));  // 3/5
      expect(normalized[1], closeTo(0.8, 0.01));  // 4/5
    });

    test('handles zero vector in L2 normalization', () {
      final engine = MemoryEngine();

      final zeroVector = [0.0, 0.0, 0.0];
      final normalized = engine._l2Normalize(zeroVector);

      // Should return zero vector, not NaN
      expect(normalized.every((v) => v == 0.0), true);
    });

    test('genesis threshold constant is correct', () {
      expect(MemoryEngine.genesisThreshold, 0.15);
    });

    test('fast learning rate constant is correct', () {
      expect(MemoryEngine.fastLearningRate, 0.05);
    });

    test('vector to blob conversion preserves data', () {
      final engine = MemoryEngine();

      final originalVector = List.generate(64, (i) => i * 0.1);
      final blob = engine._vectorToBlob(originalVector);
      final restoredVector = engine._blobToVector(blob);

      expect(restoredVector.length, originalVector.length);
      for (int i = 0; i < originalVector.length; i++) {
        expect(restoredVector[i], closeTo(originalVector[i], 0.0001));
      }
    });

    test('Hebbian update formula is correct', () {
      // Test the mathematical correctness of Hebbian plasticity
      // c_new = (1 - α) * c_old + α * z_new
      // With α = 0.05

      final alpha = MemoryEngine.fastLearningRate;
      final cOld = [1.0, 0.0, 0.0];
      final zNew = [0.0, 1.0, 0.0];

      final cNew = List.generate(3, (i) =>
        (1 - alpha) * cOld[i] + alpha * zNew[i]
      );

      expect(cNew[0], closeTo(0.95, 0.001));  // 0.95 * 1.0 + 0.05 * 0.0
      expect(cNew[1], closeTo(0.05, 0.001));  // 0.95 * 0.0 + 0.05 * 1.0
      expect(cNew[2], closeTo(0.0, 0.001));
    });
  });

  group('MemoryStats', () {
    test('creates stats with correct values', () {
      final stats = MemoryStats(
        totalPrototypes: 100,
        labeledPrototypes: 80,
        unlabeledPrototypes: 20,
        replayBufferSize: 50,
        labelDistribution: {'Walking': 30, 'Running': 50},
        databaseSize: 1024000,
      );

      expect(stats.totalPrototypes, 100);
      expect(stats.labeledPrototypes, 80);
      expect(stats.unlabeledPrototypes, 20);
      expect(stats.replayBufferSize, 50);
      expect(stats.labelDistribution['Walking'], 30);
      expect(stats.databaseSize, 1024000);
    });
  });

  group('MemoryProcessingResult', () {
    test('creates result for novel context', () {
      final result = MemoryProcessingResult(
        isNovel: true,
        prototypeId: 'proto_123',
        label: null,
        distance: 0.8,
        embedding: List.filled(64, 0.5),
      );

      expect(result.isNovel, true);
      expect(result.label, null);
      expect(result.distance, 0.8);
      expect(result.embedding.length, 64);
    });

    test('creates result for recognized context', () {
      final result = MemoryProcessingResult(
        isNovel: false,
        prototypeId: 'proto_456',
        label: 'Walking',
        distance: 0.05,
        embedding: List.filled(64, 0.3),
      );

      expect(result.isNovel, false);
      expect(result.label, 'Walking');
      expect(result.distance, 0.05);
    });
  });
}
