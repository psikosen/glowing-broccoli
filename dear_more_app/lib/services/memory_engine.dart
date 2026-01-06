import 'dart:math';
import 'dart:typed_data';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' as drift;
import '../database/database.dart';
import '../models/context_snapshot.dart';
import 'feature_extractor.dart';

/// The Hippocampus: Manages neurogenesis and memory consolidation
class MemoryEngine {
  static final MemoryEngine _instance = MemoryEngine._internal();
  factory MemoryEngine() => _instance;
  MemoryEngine._internal();

  final FeatureExtractor _featureExtractor = FeatureExtractor();
  final Uuid _uuid = const Uuid();

  // Genesis Inequality parameters
  static const double genesisThreshold = 0.15; // τ
  static const double fastLearningRate = 0.05; // α (Hebbian plasticity)

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    await _featureExtractor.initialize();
    _isInitialized = true;

    // Initialize default normalization stats if needed
    await _initializeNormStats();
  }

  /// Process a new context snapshot (The "Wake" Cycle)
  /// Returns the label if recognized, null if novel (needs user input)
  Future<MemoryProcessingResult> processSnapshot(
      ContextSnapshot snapshot) async {
    if (!_isInitialized) {
      throw StateError('MemoryEngine not initialized');
    }

    final db = AppDatabase.instance;

    // Step 1: Get normalization stats
    final normStats = await db.getNormStats();

    // Step 2: Extract embedding vector
    final embedding = await _featureExtractor.extractEmbedding(
      snapshot,
      normStats,
    );

    // Step 3: Find nearest prototype (The Genesis Inequality)
    final prototypes = await db.getAllPrototypes();

    if (prototypes.isEmpty) {
      // First ever observation - trigger neurogenesis
      final prototypeId = await _createNewPrototype(embedding, null);
      return MemoryProcessingResult(
        isNovel: true,
        prototypeId: prototypeId,
        label: null,
        distance: double.infinity,
        embedding: embedding,
      );
    }

    // Find nearest neighbor using cosine distance
    NearestPrototype? nearest;
    double minDistance = double.infinity;

    for (final prototype in prototypes) {
      final prototypeVector = _blobToVector(prototype.vector);
      final distance = _cosineDistance(embedding, prototypeVector);

      if (distance < minDistance) {
        minDistance = distance;
        nearest = NearestPrototype(
          prototype: prototype,
          distance: distance,
        );
      }
    }

    // Step 4: Apply Genesis Inequality
    if (minDistance <= genesisThreshold) {
      // Match found - Update existing prototype (Hebbian Learning)
      await _updatePrototype(nearest!.prototype, embedding);

      return MemoryProcessingResult(
        isNovel: false,
        prototypeId: nearest.prototype.id,
        label: nearest.prototype.label,
        distance: minDistance,
        embedding: embedding,
      );
    } else {
      // Novelty detected - Trigger neurogenesis
      final prototypeId = await _createNewPrototype(embedding, null);

      // Add to replay buffer (high novelty)
      await _addToReplayBuffer(embedding, null, minDistance);

      return MemoryProcessingResult(
        isNovel: true,
        prototypeId: prototypeId,
        label: null,
        distance: minDistance,
        embedding: embedding,
      );
    }
  }

  /// Update an existing prototype using Hebbian plasticity
  Future<void> _updatePrototype(Prototype prototype, List<double> newVector) async {
    final db = AppDatabase.instance;

    // Load current centroid
    final currentCentroid = _blobToVector(prototype.vector);

    // Apply fast weight update: c_new = (1-α)*c_old + α*z_new
    final updatedCentroid = List<double>.generate(
      currentCentroid.length,
      (i) => (1 - fastLearningRate) * currentCentroid[i] +
          fastLearningRate * newVector[i],
    );

    // L2 normalize the updated centroid
    final normalizedCentroid = _l2Normalize(updatedCentroid);

    // Update database
    await db.updatePrototype(
      prototype.copyWith(
        vector: _vectorToBlob(normalizedCentroid),
        count: prototype.count + 1,
        lastSeen: DateTime.now(),
      ),
    );
  }

  /// Create a new prototype (Neurogenesis)
  Future<String> _createNewPrototype(List<double> vector, String? label) async {
    final db = AppDatabase.instance;
    final id = _uuid.v4();

    await db.insertPrototype(
      PrototypesCompanion.insert(
        id: id,
        vector: _vectorToBlob(vector),
        label: drift.Value(label),
        count: const drift.Value(1),
        lastSeen: DateTime.now(),
        createdAt: DateTime.now(),
      ),
    );

    return id;
  }

  /// Add high-novelty vector to replay buffer
  Future<void> _addToReplayBuffer(
    List<double> vector,
    String? label,
    double noveltyScore,
  ) async {
    final db = AppDatabase.instance;

    await db.insertReplayBuffer(
      ReplayBufferCompanion.insert(
        id: _uuid.v4(),
        vector: _vectorToBlob(vector),
        label: drift.Value(label),
        noveltyScore: noveltyScore,
        timestamp: DateTime.now(),
      ),
    );

    // Limit replay buffer size
    await _pruneReplayBuffer();
  }

  /// Update label for a prototype (User feedback)
  Future<void> updatePrototypeLabel(String prototypeId, String label) async {
    final db = AppDatabase.instance;
    final prototype = await db.getPrototypeById(prototypeId);

    if (prototype != null) {
      await db.updatePrototype(
        prototype.copyWith(label: label),
      );

      // Update replay buffer entries with the same prototype
      // Note: This is simplified - in production, you'd track prototype IDs in replay buffer
    }
  }

  /// Cosine distance: 1 - cosine_similarity
  /// Since vectors are L2-normalized, cosine_sim = dot_product
  double _cosineDistance(List<double> a, List<double> b) {
    double dotProduct = 0.0;
    for (int i = 0; i < a.length; i++) {
      dotProduct += a[i] * b[i];
    }
    return 1.0 - dotProduct;
  }

  /// L2 normalization
  List<double> _l2Normalize(List<double> vector) {
    double magnitude = 0.0;
    for (final val in vector) {
      magnitude += val * val;
    }
    magnitude = sqrt(magnitude);

    if (magnitude < 1e-7) {
      return List.filled(vector.length, 0.0);
    }

    return vector.map((v) => v / magnitude).toList();
  }

  /// Convert vector to blob for database storage
  Uint8List _vectorToBlob(List<double> vector) {
    final buffer = Float32List.fromList(vector);
    return buffer.buffer.asUint8List();
  }

  /// Convert blob to vector
  List<double> _blobToVector(Uint8List blob) {
    final buffer = blob.buffer.asFloat32List();
    return buffer.toList();
  }

  /// Initialize default normalization statistics
  Future<void> _initializeNormStats() async {
    final db = AppDatabase.instance;
    final stats = await db.getNormStats();

    if (stats.isEmpty) {
      // Set default normalization stats
      await db.updateNormStat('accel_x', 0.0, 1.0);
      await db.updateNormStat('accel_y', 0.0, 1.0);
      await db.updateNormStat('accel_z', 0.0, 1.0);
      await db.updateNormStat('audio', 0.0, 1.0);
      await db.updateNormStat('gps_speed', 0.0, 1.0);
      await db.updateNormStat('light', 0.0, 1.0);
    }
  }

  /// Prune replay buffer to keep only top entries
  Future<void> _pruneReplayBuffer() async {
    final db = AppDatabase.instance;
    final buffers = await db.getAllReplayBuffers();

    if (buffers.length > 1000) {
      // Keep only top 500 by novelty score
      await db.clearReplayBuffer();

      final topBuffers = buffers..sort((a, b) => b.noveltyScore.compareTo(a.noveltyScore));

      for (int i = 0; i < min(500, topBuffers.length); i++) {
        await db.insertReplayBuffer(
          ReplayBufferCompanion.insert(
            id: topBuffers[i].id,
            vector: topBuffers[i].vector,
            label: drift.Value(topBuffers[i].label),
            noveltyScore: topBuffers[i].noveltyScore,
            timestamp: topBuffers[i].timestamp,
          ),
        );
      }
    }
  }

  /// Get statistics about the memory system
  Future<MemoryStats> getMemoryStats() async {
    final db = AppDatabase.instance;
    final prototypes = await db.getAllPrototypes();
    final replayBuffers = await db.getAllReplayBuffers();

    final labelCounts = <String, int>{};
    for (final prototype in prototypes) {
      if (prototype.label != null) {
        labelCounts[prototype.label!] = (labelCounts[prototype.label!] ?? 0) + 1;
      }
    }

    return MemoryStats(
      totalPrototypes: prototypes.length,
      labeledPrototypes: prototypes.where((p) => p.label != null).length,
      unlabeledPrototypes: prototypes.where((p) => p.label == null).length,
      replayBufferSize: replayBuffers.length,
      labelDistribution: labelCounts,
      databaseSize: await db.getDatabaseSize(),
    );
  }

  bool get isInitialized => _isInitialized;
}

class MemoryProcessingResult {
  final bool isNovel;
  final String prototypeId;
  final String? label;
  final double distance;
  final List<double> embedding;

  MemoryProcessingResult({
    required this.isNovel,
    required this.prototypeId,
    required this.label,
    required this.distance,
    required this.embedding,
  });
}

class NearestPrototype {
  final Prototype prototype;
  final double distance;

  NearestPrototype({
    required this.prototype,
    required this.distance,
  });
}

class MemoryStats {
  final int totalPrototypes;
  final int labeledPrototypes;
  final int unlabeledPrototypes;
  final int replayBufferSize;
  final Map<String, int> labelDistribution;
  final int databaseSize;

  MemoryStats({
    required this.totalPrototypes,
    required this.labeledPrototypes,
    required this.unlabeledPrototypes,
    required this.replayBufferSize,
    required this.labelDistribution,
    required this.databaseSize,
  });
}
