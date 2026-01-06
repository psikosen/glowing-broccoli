import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:sqlcipher_flutter_libs/sqlcipher_flutter_libs.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

part 'database.g.dart';

/// Prototypes table: Stores learned activity centroids
class Prototypes extends Table {
  TextColumn get id => text()();
  TextColumn get label => text().nullable()();
  BlobColumn get vector => blob()();
  IntColumn get count => integer().withDefault(const Constant(1))();
  DateTimeColumn get lastSeen => dateTime()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// ReplayBuffer table: Stores high-novelty vectors for server sync
class ReplayBuffer extends Table {
  TextColumn get id => text()();
  BlobColumn get vector => blob()();
  TextColumn get label => text().nullable()();
  RealColumn get noveltyScore => real()();
  DateTimeColumn get timestamp => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// NormStats table: Stores normalization statistics for sensors
class NormStats extends Table {
  TextColumn get sensorName => text()();
  RealColumn get mean => real()();
  RealColumn get std => real()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {sensorName};
}

@DriftDatabase(tables: [Prototypes, ReplayBuffer, NormStats])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  static AppDatabase? _instance;

  static Future<void> initialize() async {
    _instance ??= AppDatabase();
  }

  static AppDatabase get instance {
    if (_instance == null) {
      throw StateError('Database not initialized. Call initialize() first.');
    }
    return _instance!;
  }

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
        },
        beforeOpen: (details) async {
          // Enable foreign key constraints
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  // Prototypes queries
  Future<List<Prototype>> getAllPrototypes() => select(prototypes).get();

  Future<Prototype?> getPrototypeById(String id) =>
      (select(prototypes)..where((p) => p.id.equals(id))).getSingleOrNull();

  Future<List<Prototype>> getPrototypesByLabel(String label) =>
      (select(prototypes)..where((p) => p.label.equals(label))).get();

  Future<int> insertPrototype(PrototypesCompanion prototype) =>
      into(prototypes).insert(prototype);

  Future<bool> updatePrototype(Prototype prototype) =>
      update(prototypes).replace(prototype);

  Future<int> deletePrototype(String id) =>
      (delete(prototypes)..where((p) => p.id.equals(id))).go();

  // ReplayBuffer queries
  Future<List<ReplayBufferData>> getAllReplayBuffers() =>
      select(replayBuffer).get();

  Future<int> insertReplayBuffer(ReplayBufferCompanion buffer) =>
      into(replayBuffer).insert(buffer);

  Future<int> clearReplayBuffer() => delete(replayBuffer).go();

  Future<List<ReplayBufferData>> getTopReplayBuffers(int limit) =>
      (select(replayBuffer)
            ..orderBy([(rb) => OrderingTerm.desc(rb.noveltyScore)])
            ..limit(limit))
          .get();

  // NormStats queries
  Future<Map<String, double>> getNormStats() async {
    final stats = await select(normStats).get();
    final result = <String, double>{};

    for (final stat in stats) {
      result['${stat.sensorName}_mean'] = stat.mean;
      result['${stat.sensorName}_std'] = stat.std;
    }

    return result;
  }

  Future<void> updateNormStat(String sensorName, double mean, double std) async {
    await into(normStats).insertOnConflictUpdate(
      NormStatsCompanion.insert(
        sensorName: sensorName,
        mean: mean,
        std: std,
        updatedAt: DateTime.now(),
      ),
    );
  }

  // Database maintenance
  Future<int> getDatabaseSize() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dbFolder.path, 'dear_more.db');
    final file = File(dbPath);
    if (await file.exists()) {
      return await file.length();
    }
    return 0;
  }

  Future<void> pruneOldData({int maxPrototypes = 10000}) async {
    // Keep only the most recently seen prototypes
    final oldPrototypes = await (select(prototypes)
          ..orderBy([(p) => OrderingTerm.asc(p.lastSeen)])
          ..limit(maxPrototypes))
        .get();

    if (oldPrototypes.length >= maxPrototypes) {
      // Delete oldest prototypes
      await (delete(prototypes)
            ..where((p) => p.lastSeen.isSmallerThanValue(
                oldPrototypes[oldPrototypes.length ~/ 2].lastSeen)))
          .go();
    }
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'dear_more.db'));

    // Get encryption key from secure storage
    const secureStorage = FlutterSecureStorage();
    String? encryptionKey = await secureStorage.read(key: 'db_encryption_key');

    if (encryptionKey == null) {
      // Generate new encryption key
      encryptionKey = _generateEncryptionKey();
      await secureStorage.write(key: 'db_encryption_key', value: encryptionKey);
    }

    // Ensure SQLCipher is loaded
    applyWorkaroundToOpenSqlCipherOnOldAndroidVersions();
    sqlite3.tempDirectory = (await getTemporaryDirectory()).path;

    return NativeDatabase.createInBackground(
      file,
      setup: (database) {
        // Set encryption key
        database.execute("PRAGMA key = '$encryptionKey'");
      },
    );
  });
}

String _generateEncryptionKey() {
  // Generate a random 64-character hex key
  final random = DateTime.now().millisecondsSinceEpoch;
  return random.toRadixString(16).padLeft(64, '0');
}
