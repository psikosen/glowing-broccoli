import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:encrypt/encrypt.dart' as encrypt_lib;
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database.dart';

/// Handles synchronization with the backend server
class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
  ));

  /// Sync replay buffer with server (The "Sleep" Cycle)
  Future<void> syncWithServer() async {
    final prefs = await SharedPreferences.getInstance();
    final serverUrl = prefs.getString('server_url') ?? 'https://api.dearmore.ai';

    final db = AppDatabase.instance;

    // Get top replay buffer entries (representative samples)
    final replayBuffers = await db.getTopReplayBuffers(100);

    if (replayBuffers.isEmpty) {
      print('No replay buffers to sync');
      return;
    }

    // Prepare payload
    final payload = replayBuffers.map((buffer) {
      return {
        'vector': _encodeVector(buffer.vector),
        'label': buffer.label,
        'novelty_score': buffer.noveltyScore,
        'timestamp': buffer.timestamp.millisecondsSinceEpoch,
      };
    }).toList();

    // Encrypt payload
    final encryptedPayload = await _encryptPayload(payload);

    try {
      // Send to server
      final response = await _dio.post(
        '$serverUrl/sync/v1/dream',
        data: {
          'device_id': await _getDeviceId(),
          'encrypted_data': encryptedPayload,
          'version': 1,
        },
      );

      if (response.statusCode == 200) {
        print('Sync successful');

        // Clear synced replay buffers
        await db.clearReplayBuffer();

        // Update last sync timestamp
        await prefs.setInt('last_sync', DateTime.now().millisecondsSinceEpoch);
      } else {
        throw Exception('Sync failed: ${response.statusCode}');
      }
    } catch (e) {
      print('Error syncing with server: $e');
      rethrow;
    }
  }

  /// Download updated model from server (The "Evolution" Cycle)
  Future<String?> downloadUpdatedModel() async {
    final prefs = await SharedPreferences.getInstance();
    final serverUrl = prefs.getString('server_url') ?? 'https://api.dearmore.ai';

    try {
      final response = await _dio.get(
        '$serverUrl/models/v1/latest',
        queryParameters: {
          'device_id': await _getDeviceId(),
          'current_version': 1,
        },
      );

      if (response.statusCode == 200 && response.data['update_available'] == true) {
        final modelUrl = response.data['model_url'] as String;

        // Download model
        // In production, this would download to a temporary location
        // and verify checksums before replacing the current model
        print('Model update available: $modelUrl');
        return modelUrl;
      }

      return null;
    } catch (e) {
      print('Error checking for model updates: $e');
      return null;
    }
  }

  String _encodeVector(List<int> blobData) {
    return base64Encode(blobData);
  }

  Future<String> _encryptPayload(List<Map<String, dynamic>> payload) async {
    // Generate symmetric encryption key (in production, use key exchange)
    final key = encrypt_lib.Key.fromLength(32);
    final iv = encrypt_lib.IV.fromLength(16);

    final encrypter = encrypt_lib.Encrypter(
      encrypt_lib.AES(key, mode: encrypt_lib.AESMode.cbc),
    );

    final jsonPayload = jsonEncode(payload);
    final encrypted = encrypter.encrypt(jsonPayload, iv: iv);

    // Return base64-encoded encrypted data
    // In production, also send the key encrypted with server's public key
    return encrypted.base64;
  }

  Future<String> _getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString('device_id');

    if (deviceId == null) {
      // Generate unique device ID
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final bytes = utf8.encode('dear_more_$timestamp');
      final digest = sha256.convert(bytes);
      deviceId = digest.toString();
      await prefs.setString('device_id', deviceId);
    }

    return deviceId;
  }
}
