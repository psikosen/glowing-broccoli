import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'sensor_collector_service.dart';
import 'memory_engine.dart';
import '../database/database.dart';

class BackgroundServiceManager {
  static Future<void> initialize() async {
    final service = FlutterBackgroundService();

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'dear_more_foreground',
      'Dear More Background Service',
      description: 'Learning your context in the background',
      importance: Importance.low,
    );

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: true,
        isForegroundMode: true,
        notificationChannelId: 'dear_more_foreground',
        initialNotificationTitle: 'Dear More',
        initialNotificationContent: 'Learning your context...',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );

    service.startService();
  }

  @pragma('vm:entry-point')
  static Future<bool> onIosBackground(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    return true;
  }

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();

    if (service is AndroidServiceInstance) {
      service.on('setAsForeground').listen((event) {
        service.setAsForegroundService();
      });

      service.on('setAsBackground').listen((event) {
        service.setAsBackgroundService();
      });
    }

    service.on('stopService').listen((event) {
      service.stopSelf();
    });

    // Initialize database and memory engine
    await AppDatabase.initialize();
    final memoryEngine = MemoryEngine();
    await memoryEngine.initialize();

    // Initialize sensor collector
    final sensorCollector = SensorCollectorService();
    await sensorCollector.startCollection();

    // Listen to snapshots and process them
    sensorCollector.snapshotStream?.listen((snapshot) async {
      try {
        final result = await memoryEngine.processSnapshot(snapshot);

        // Update service notification with current activity
        if (service is AndroidServiceInstance) {
          if (result.isNovel) {
            await service.setForegroundNotificationInfo(
              title: 'Dear More - New Context Detected',
              content: 'Tap to label this activity',
            );

            // Send event to UI to show labeling prompt
            service.invoke('novel_context', {
              'prototype_id': result.prototypeId,
              'distance': result.distance,
            });
          } else if (result.label != null) {
            await service.setForegroundNotificationInfo(
              title: 'Dear More',
              content: 'Current: ${result.label}',
            );
          }
        }

        // Send stats update
        final stats = await memoryEngine.getMemoryStats();
        service.invoke('memory_stats', {
          'total_prototypes': stats.totalPrototypes,
          'labeled': stats.labeledPrototypes,
          'unlabeled': stats.unlabeledPrototypes,
        });
      } catch (e) {
        print('Error processing snapshot: $e');
      }
    });

    // Periodic cleanup (every hour)
    Timer.periodic(const Duration(hours: 1), (timer) async {
      final db = AppDatabase.instance;
      await db.pruneOldData();
    });
  }

  static Future<void> stopService() async {
    final service = FlutterBackgroundService();
    service.invoke('stopService');
  }
}
