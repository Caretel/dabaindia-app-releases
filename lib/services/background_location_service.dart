import 'dart:convert';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dio/dio.dart';
import '../config/api_config.dart';
import '../models/geofence_zone.dart';

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(LocationTaskHandler());
}

class LocationTaskHandler extends TaskHandler {
  SendPort? _sendPort;
  Dio? _dio;
  String? _token;
  List<GeofenceZone> _zones = [];
  int _outsideMinutes = 0;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    
    // Retrieve token saved by main isolate
    _token = await FlutterForegroundTask.getData<String>(key: 'auth_token');
    
    // Retrieve zones saved by main isolate
    String? zonesJson = await FlutterForegroundTask.getData<String>(key: 'geofence_zones');
    if (zonesJson != null) {
      try {
        List<dynamic> list = jsonDecode(zonesJson);
        _zones = list.map((z) => GeofenceZone.fromJson(z)).toList();
      } catch (e) {
        print('Error parsing zones in isolate: $e');
      }
    }
    
    _dio = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      },
    ));
    
    print('Background Location Task Started with ${_zones.length} zones');
  }

  @override
  void onRepeatEvent(DateTime timestamp) async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      // Check geofence
      bool withinAnyZone = false;
      if (_zones.isEmpty) {
        withinAnyZone = true; // No zones defined, allow anything
      } else {
        for (var zone in _zones) {
          double dist = Geolocator.distanceBetween(
            position.latitude, position.longitude, zone.latitude, zone.longitude
          );
          if (dist <= zone.radius) {
            withinAnyZone = true;
            break;
          }
        }
      }

      if (!withinAnyZone) {
        _outsideMinutes++;
        if (_outsideMinutes >= 3) {
          // Trigger reminder
          FlutterForegroundTask.updateService(
            notificationTitle: '⚠️ GEOFENCE WARNING',
            notificationText: 'You have been outside for $_outsideMinutes minutes. Please return to the shop.',
          );
          // Optional: You could also use a more intrusive notification here
        } else {
          FlutterForegroundTask.updateService(
            notificationTitle: 'Active Shift (Outside)',
            notificationText: 'Outside zone for $_outsideMinutes min. Tracking: ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}',
          );
        }
      } else {
        _outsideMinutes = 0;
        FlutterForegroundTask.updateService(
          notificationTitle: 'Active Shift (Inside)',
          notificationText: 'Tracking location: ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}',
        );
      }

      if (_dio != null) {
        await _dio!.post(
          'attendance?action=update_location',
          data: {
            'lat': position.latitude,
            'lng': position.longitude,
            'is_outside': !withinAnyZone,
            'outside_minutes': _outsideMinutes,
          },
        );
      }
    } catch (e) {
      print('Background location error: $e');
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    print('Background Location Task Destroyed');
  }
}

class BackgroundLocationService {
  static void init() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'location_tracking',
        channelName: 'Location Tracking',
        channelDescription: 'Continuous location tracking during active shift.',
        channelImportance: NotificationChannelImportance.HIGH,
        priority: NotificationPriority.HIGH,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: true,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(1000 * 60), // 1 minute
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  static Future<void> startService(String token, String? zonesJson) async {
    if (await FlutterForegroundTask.isRunningService) {
      return;
    }
    
    await FlutterForegroundTask.saveData(key: 'auth_token', value: token);
    if (zonesJson != null) {
      await FlutterForegroundTask.saveData(key: 'geofence_zones', value: zonesJson);
    }

    await FlutterForegroundTask.startService(
      notificationTitle: 'Active Shift',
      notificationText: 'Initializing location tracking...',
      callback: startCallback,
    );
  }

  static Future<void> stopService() async {
    await FlutterForegroundTask.stopService();
  }
}
