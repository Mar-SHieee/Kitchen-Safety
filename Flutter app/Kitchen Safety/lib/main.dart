import 'package:flutter/material.dart';
import 'supabase_service.dart';
import 'splash_screen.dart';
import 'app_theme.dart';
import 'mqtt_service.dart';
import 'notification_service.dart';
import 'app_models.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SupabaseService.init();

  await NotificationService().init();
  await NotificationService().initializeNotificationChannels();

  await _initializeGlobalServices();

  runApp(const KitchenSafetyApp());
}

Future<void> _initializeGlobalServices() async {
  try {
    final mqttService = MqttService.instance;

    mqttService.addUpdateCallback(_globalThresholdChecker);

    await mqttService.connect();

    debugPrint('Global MQTT service initialized successfully');
  } catch (e) {
    debugPrint('Error initializing global services: $e');
  }
}

Future<void> _globalThresholdChecker(Map<String, String> sensorData) async {
  try {
    final notificationService = NotificationService();
    final generalNotificationsEnabled =
        await notificationService.isGeneralNotificationsEnabled();

    if (!generalNotificationsEnabled) {
      debugPrint('Global notifications disabled - skipping alerts');
      return;
    }

    final mqttService = MqttService.instance;

    List<String> exceededSensors = [];
    for (var sensor in mqttService.sensorDanger.keys) {
      if (mqttService.sensorDanger[sensor] == true) {
        exceededSensors.add(sensorTypeToString(sensor));
      }
    }

    if (exceededSensors.isNotEmpty) {
      debugPrint('Global alert triggered for sensors: $exceededSensors');

      if (mqttService.systemStatus == SystemStatus.danger) {
        await notificationService.showDangerNotification(
          'Danger Alert!',
          'The door is open, there is a danger, leave the kitchen now!!!',
          withVibration: true,
        );
      }

      for (var sensor in exceededSensors) {
        await _sendSensorAlert(sensor, notificationService);
      }
    }
  } catch (e) {
    debugPrint('Error in global threshold checking: $e');
  }
}

Future<void> _sendSensorAlert(
    String sensor, NotificationService notificationService) async {
  try {
    String title =
        'Sensor Alert - ${sensor[0].toUpperCase()}${sensor.substring(1)}';
    String body = (sensor == 'flame')
        ? 'There is a flame detected!'
        : '$sensor has exceeded its threshold limit!';

    await notificationService.showNotification(
      title,
      body,
      withVibration: true,
    );

    debugPrint('Sent global alert for sensor: $sensor');
  } catch (e) {
    debugPrint('Error sending alert for sensor $sensor: $e');
  }
}

class KitchenSafetyApp extends StatelessWidget {
  const KitchenSafetyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kitchen Safety',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme.copyWith(
        textTheme: ThemeData.light().textTheme.apply(fontFamily: 'OpenSans'),
      ),
      darkTheme: AppTheme.creamyTheme.copyWith(
        textTheme: ThemeData.light().textTheme.apply(fontFamily: 'OpenSans'),
      ),
      themeMode: ThemeMode.system,
      home: const SplashScreen(),
    );
  }
}

class AppLifecycleManager extends StatefulWidget {
  final Widget child;

  const AppLifecycleManager({required this.child, super.key});

  @override
  State<AppLifecycleManager> createState() => _AppLifecycleManagerState();
}

class _AppLifecycleManagerState extends State<AppLifecycleManager>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    MqttService.instance.forceDisconnect();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
        _ensureMqttConnection();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        break;
      default:
        break;
    }
  }

  Future<void> _ensureMqttConnection() async {
    try {
      final mqttService = MqttService.instance;
      if (!mqttService.isConnected) {
        debugPrint('App resumed - reconnecting MQTT...');
        await mqttService.connect();
      }
    } catch (e) {
      debugPrint('Error reconnecting MQTT on app resume: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
