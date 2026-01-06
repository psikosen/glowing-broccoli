import 'dart:typed_data';
import 'dart:math';
import 'package:tflite_flutter/tflite_flutter.dart';
import '../models/context_snapshot.dart';

/// The Cortex: Handles TFLite inference to extract embeddings from sensor data
class FeatureExtractor {
  static final FeatureExtractor _instance = FeatureExtractor._internal();
  factory FeatureExtractor() => _instance;
  FeatureExtractor._internal();

  Interpreter? _interpreter;
  bool _isInitialized = false;

  /// Initialize the TFLite model
  Future<void> initialize({String modelPath = 'assets/models/cortex_v1.tflite'}) async {
    if (_isInitialized) return;

    try {
      _interpreter = await Interpreter.fromAsset(modelPath);
      _isInitialized = true;
      print('FeatureExtractor initialized successfully');
    } catch (e) {
      print('Error initializing FeatureExtractor: $e');
      // For development, create a mock interpreter behavior
      _isInitialized = false;
    }
  }

  /// Extract embedding vector from context snapshot
  /// Returns a 64-dimensional L2-normalized vector
  Future<List<double>> extractEmbedding(
    ContextSnapshot snapshot,
    Map<String, double> normStats,
  ) async {
    if (!_isInitialized || _interpreter == null) {
      // Fallback: Generate deterministic pseudo-embedding for development
      return _generateMockEmbedding(snapshot);
    }

    try {
      // Prepare input tensor [1, 200]
      final input = snapshot.toTensorInput(normStats);
      final inputTensor = input.reshape([1, 200]);

      // Prepare output tensor [1, 64]
      final output = List.filled(1, List.filled(64, 0.0));

      // Run inference
      _interpreter!.run(inputTensor, output);

      // Extract and L2-normalize the embedding
      final embedding = List<double>.from(output[0]);
      return _l2Normalize(embedding);
    } catch (e) {
      print('Error during inference: $e');
      return _generateMockEmbedding(snapshot);
    }
  }

  /// L2 normalization: make vector magnitude = 1.0
  /// This ensures cosine similarity can be computed as dot product
  List<double> _l2Normalize(List<double> vector) {
    double magnitude = 0.0;
    for (final val in vector) {
      magnitude += val * val;
    }
    magnitude = sqrt(magnitude);

    if (magnitude < 1e-7) {
      // Avoid division by zero
      return List.filled(vector.length, 0.0);
    }

    return vector.map((v) => v / magnitude).toList();
  }

  /// Generate mock embedding for development/testing
  /// Uses hash of sensor values to create deterministic embeddings
  List<double> _generateMockEmbedding(ContextSnapshot snapshot) {
    final random = Random(snapshot.timestamp);

    // Create base embedding from sensor data
    final embedding = List<double>.generate(64, (i) {
      // Mix sensor values to create diverse embeddings
      final seed = snapshot.accelXBuffer[min(i, snapshot.accelXBuffer.length - 1)] +
          snapshot.accelYBuffer[min(i, snapshot.accelYBuffer.length - 1)] +
          snapshot.avgAudioDecibel * 0.1 +
          snapshot.gpsSpeed * 0.5;

      return (seed + random.nextDouble() - 0.5) * 0.1;
    });

    return _l2Normalize(embedding);
  }

  /// Update normalization statistics
  Future<void> updateNormStats(Map<String, double> newStats) async {
    // In production, this would update running statistics
    // For now, stats are managed by the MemoryEngine
  }

  /// Reload model (for model updates from server)
  Future<void> reloadModel(String newModelPath) async {
    _interpreter?.close();
    _isInitialized = false;
    await initialize(modelPath: newModelPath);
  }

  void dispose() {
    _interpreter?.close();
    _isInitialized = false;
  }

  bool get isInitialized => _isInitialized;
}
