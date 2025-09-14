import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vibration/vibration.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const String _generalNotificationsKey = 'general_notifications';

  Future<void> init() async {
    try {
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher1');

      final InitializationSettings initializationSettings =
          InitializationSettings(
        android: initializationSettingsAndroid,
      );

      await _notificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      print('Notification service initialized successfully');
    } catch (e) {
      print('Notification initialization failed: $e');
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    print('Notification tapped: ${response.payload}');
  }

  Future<PermissionStatus> requestPermission() async {
    try {
      final status = await Permission.notification.request();

      if (status.isGranted) {
        if (await Permission.scheduleExactAlarm.isDenied) {
          await Permission.scheduleExactAlarm.request();
        }
      }

      return status;
    } catch (e) {
      print('Error requesting notification permission: $e');
      return PermissionStatus.denied;
    }
  }

  Future<void> showNotification(
    String title,
    String body, {
    bool withVibration = false,
    String? payload,
  }) async {
    try {
      final isEnabled = await isGeneralNotificationsEnabled();
      if (!isEnabled) {
        print('General notifications are disabled');
        return;
      }

      final hasPermission = await Permission.notification.isGranted;
      if (!hasPermission) {
        print('Notification permission not granted');
        return;
      }

      AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'alert_channel',
        'Sensor Alerts',
        channelDescription: 'Notifications for sensor alerts',
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher1',
        playSound: true,
        enableVibration: withVibration,
        vibrationPattern:
            withVibration ? Int64List.fromList([0, 1000, 500, 1000]) : null,
        styleInformation: BigTextStyleInformation(
          body,
          contentTitle: title,
          summaryText: 'Smart Kitchen Alert',
        ),
        color: title.contains('Danger') ? const Color(0xFFFF0000) : null,
      );

      NotificationDetails details = NotificationDetails(
        android: androidDetails,
      );

      final int notificationId =
          DateTime.now().millisecondsSinceEpoch.remainder(100000);

      await _notificationsPlugin.show(
        notificationId,
        title,
        body,
        details,
        payload: payload,
      );

      if (withVibration) {
        await _triggerVibration();
      }

      print('Notification shown: $title');
    } catch (e) {
      print('Error showing notification: $e');
    }
  }

  Future<void> _triggerVibration() async {
    try {
      final hasVibrator = await Vibration.hasVibrator() ?? false;
      if (hasVibrator) {
        Vibration.vibrate(
          pattern: [0, 1000, 500, 1000],
          intensities: [0, 255, 0, 255],
        );
      }
    } catch (e) {
      print('Error triggering vibration: $e');
    }
  }

  Future<void> setGeneralNotificationsEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_generalNotificationsKey, enabled);
      print('General notifications set to: $enabled');
    } catch (e) {
      print('Error saving general notifications state: $e');
    }
  }

  Future<bool> isGeneralNotificationsEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool(_generalNotificationsKey) ?? false;
      print('General notifications enabled: $enabled');
      return enabled;
    } catch (e) {
      print('Error getting general notifications state: $e');
      return false;
    }
  }

  Future<void> cancelAllNotifications() async {
    try {
      await _notificationsPlugin.cancelAll();
      print('All notifications cancelled');
    } catch (e) {
      print('Error cancelling notifications: $e');
    }
  }

  Future<void> cancelNotification(int id) async {
    try {
      await _notificationsPlugin.cancel(id);
      print('Notification $id cancelled');
    } catch (e) {
      print('Error cancelling notification $id: $e');
    }
  }

  Future<bool> hasNotificationPermission() async {
    try {
      return await Permission.notification.isGranted;
    } catch (e) {
      print('Error checking notification permission: $e');
      return false;
    }
  }

  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    try {
      return await _notificationsPlugin.pendingNotificationRequests();
    } catch (e) {
      print('Error getting pending notifications: $e');
      return [];
    }
  }

  Future<void> createNotificationChannel({
    required String id,
    required String name,
    required String description,
    Importance importance = Importance.high,
  }) async {
    try {
      final AndroidNotificationChannel channel = AndroidNotificationChannel(
        id,
        name,
        description: description,
        importance: importance,
        playSound: true,
        enableVibration: true,
      );

      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      print('Notification channel created: $name');
    } catch (e) {
      print('Error creating notification channel: $e');
    }
  }

  Future<void> initializeNotificationChannels() async {
    await createNotificationChannel(
      id: 'danger_alerts',
      name: 'Danger Alerts',
      description: 'Critical alerts requiring immediate attention',
      importance: Importance.max,
    );

    await createNotificationChannel(
      id: 'warning_alerts',
      name: 'Warning Alerts',
      description: 'Warning notifications for sensor thresholds',
      importance: Importance.high,
    );

    await createNotificationChannel(
      id: 'info_alerts',
      name: 'Information Alerts',
      description: 'General information and updates',
      importance: Importance.defaultImportance,
    );
  }

  Future<void> showDangerNotification(String title, String body,
      {bool withVibration = true}) async {
    try {
      final isEnabled = await isGeneralNotificationsEnabled();
      if (!isEnabled) {
        print('General notifications are disabled');
        return;
      }

      AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'danger_alerts',
        'Danger Alerts',
        channelDescription: 'Critical alerts requiring immediate attention',
        importance: Importance.max,
        priority: Priority.max,
        icon: '@mipmap/ic_launcher1',
        playSound: true,
        sound: const RawResourceAndroidNotificationSound('alert'),
        enableVibration: withVibration,
        vibrationPattern: withVibration
            ? Int64List.fromList([0, 1000, 500, 1000, 500, 1000])
            : null,
        styleInformation: BigTextStyleInformation(
          body,
          contentTitle: title,
          summaryText: '🚨 EMERGENCY ALERT',
        ),
        color: const Color(0xFFFF0000),
        fullScreenIntent: true,
        category: AndroidNotificationCategory.alarm,
      );

      NotificationDetails details = NotificationDetails(
        android: androidDetails,
      );

      final int notificationId =
          DateTime.now().millisecondsSinceEpoch.remainder(100000);

      await _notificationsPlugin.show(
        notificationId,
        title,
        body,
        details,
        payload: 'danger',
      );

      if (withVibration) {
        await _triggerDangerVibration();
      }

      print('Danger notification shown: $title');
    } catch (e) {
      print('Error showing danger notification: $e');
    }
  }

  Future<void> _triggerDangerVibration() async {
    try {
      final hasVibrator = await Vibration.hasVibrator() ?? false;
      if (hasVibrator) {
        Vibration.vibrate(
          pattern: [0, 1000, 500, 1000, 500, 1000],
          intensities: [0, 255, 0, 255, 0, 255],
        );
      }
    } catch (e) {
      print('Error triggering danger vibration: $e');
    }
  }
}
