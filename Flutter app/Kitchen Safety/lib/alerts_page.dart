import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'mqtt_service.dart';
import 'supabase_service.dart';
import 'app_models.dart';
import 'app_theme.dart';
import 'notification_service.dart';
import 'package:permission_handler/permission_handler.dart';

class AlertsPage extends StatefulWidget {
  const AlertsPage({super.key});

  @override
  State<AlertsPage> createState() => _AlertsPageState();
}

class _AlertsPageState extends State<AlertsPage> {
  late MqttService mqttService;
  SharedPreferences? _prefs;
  String? _userId;
  bool _generalNotifications = false;
  bool _isLoading = false;
  final Map<String, bool> _notificationEnabled = {};
  final Map<String, String> _alertTypes = {};
  final Map<String, bool> _isOnline = {};
  final Map<String, bool> _isConnected = {};
  bool _ledOn = false;
  int _servoAngle = 0;
  bool _buzzerOn = false;
  late Set<SensorType> activeSensorTypes;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      await _initSharedPreferences();
      await NotificationService().init();
      await _initUserId();

      mqttService = MqttService(onUpdate: (updatedValues) {
        if (!mounted) return;
        mqttService.evaluateThresholdsAndAct(activeSensorTypes);
        setState(() {
          debugPrint('AlertsPage: Updated sensorValues: $sensorValues');
        });
      });

      mqttService.connect();

      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          await _loadGeneralNotificationState();
          await _loadSensorStates();
        });
      }
    } catch (e) {
      debugPrint('Error initializing app: $e');
      if (mounted) {
        _showErrorSnackBar('Error initializing app: $e');
      }
    }
  }

  Future<void> _initSharedPreferences() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      _generalNotifications = _prefs?.getBool('general_notifications') ?? false;
      debugPrint(
          'Loaded general_notifications from SharedPreferences: $_generalNotifications');
    } catch (e) {
      debugPrint('Error initializing SharedPreferences: $e');
      _generalNotifications = false;
      if (mounted) {
        _showErrorSnackBar('Failed to initialize notification settings: $e');
      }
    }
  }

  Future<void> _initUserId() async {
    try {
      final user = SupabaseService.client.auth.currentUser;
      if (user == null) {
        if (mounted) {
          _showErrorSnackBar('User not logged in');
        }
        return;
      }
      _userId = user.id;
      debugPrint('Current user: $_userId');
    } catch (e) {
      debugPrint('Error fetching user: $e');
      if (mounted) {
        _showErrorSnackBar('Error fetching user: $e');
      }
    }
  }

  Future<void> _loadGeneralNotificationState() async {
    if (_prefs == null) {
      debugPrint('SharedPreferences is not initialized');
      return;
    }

    try {
      _generalNotifications = _prefs!.getBool('general_notifications') ?? false;

      if (mounted) {
        setState(() {
          debugPrint(
              'UI updated with general notifications state: $_generalNotifications');
        });
      }
    } catch (e) {
      debugPrint('Error loading notification settings: $e');
      if (mounted) {
        _showErrorSnackBar('Error loading notification settings: $e');
      }
    }
  }

  Future<void> _loadSensorStates() async {
    if (_userId == null) return;

    try {
      setState(() {
        _isLoading = true;
      });

      final sensorsResponse = await SupabaseService.client
          .from('user_sensors')
          .select('sensor_type')
          .eq('user_id', _userId!)
          .then((data) => data as List<dynamic>? ?? []);

      final List<String> onlineSensors = sensorsResponse
          .map((e) => sensorTypeToString(
              stringToSensorType(e['sensor_type']?.toString() ?? '')))
          .where((name) => name.isNotEmpty)
          .toList();

      final alertsResponse = await SupabaseService.client
          .from('user_alerts')
          .select('sensor_type, alert_type')
          .eq('user_id', _userId!)
          .then((data) => data as List<dynamic>? ?? []);

      Map<String, String> alertTypes = {};
      Map<String, bool> notificationEnabled = {};

      for (var sensor in thresholds.keys) {
        final norm = sensorTypeToString(sensor);
        notificationEnabled[norm] = false;
        alertTypes[norm] = 'notifications';
        _isOnline[norm] = false;
      }

      for (var sensorName in onlineSensors) {
        _isOnline[sensorName] = true;
      }

      for (var alert in alertsResponse) {
        final sensorType = alert['sensor_type']?.toString() ?? '';
        final normName = sensorTypeToString(stringToSensorType(sensorType));
        String alertType = alert['alert_type']?.toString() ?? 'notifications';

        if (alertType != 'notifications' &&
            alertType != 'notifications with vibration') {
          alertType = 'notifications';
          try {
            await SupabaseService.client
                .from('user_alerts')
                .update({'alert_type': 'notifications'})
                .eq('user_id', _userId!)
                .eq('sensor_type', sensorType);
          } catch (updateError) {
            debugPrint('Error updating invalid alert type: $updateError');
          }
        }

        if (normName.isNotEmpty && _isOnline[normName] == true) {
          alertTypes[normName] = alertType;
          notificationEnabled[normName] = true;
        }
      }

      activeSensorTypes = _isOnline.entries
          .where((entry) => entry.value)
          .map((entry) => stringToSensorType(entry.key))
          .toSet();

      if (mounted) {
        setState(() {
          for (var sensor in thresholds.keys) {
            final norm = sensorTypeToString(sensor);
            _notificationEnabled[norm] = notificationEnabled[norm]!;
            _alertTypes[norm] = alertTypes[norm]!;
            _isConnected[norm] = _notificationEnabled[norm]!;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading sensor states: $e');
      if (mounted) {
        _showErrorSnackBar('Error loading sensor states: $e');
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleGeneralNotifications(bool value) async {
    try {
      if (_isLoading) {
        debugPrint('Toggle ignored: Loading in progress');
        return;
      }

      setState(() {
        _isLoading = true;
      });

      if (value) {
        final status = await NotificationService().requestPermission();
        if (status != PermissionStatus.granted) {
          if (mounted) {
            setState(() {
              _generalNotifications = false;
              _isLoading = false;
            });
            _showErrorSnackBar(
                'Notification permission is required for alerts');
          }
          return;
        }
      }

      if (_prefs != null) {
        bool success = await _prefs!.setBool('general_notifications', value);
        if (!success) {
          debugPrint(
              'Failed to save general_notifications to SharedPreferences');
          if (mounted) {
            _showErrorSnackBar('Failed to save notification settings');
          }
          setState(() {
            _isLoading = false;
          });
          return;
        }
        debugPrint('Saved general_notifications: $value to SharedPreferences');

        await NotificationService().setGeneralNotificationsEnabled(value);
      } else {
        debugPrint('SharedPreferences is null');
        if (mounted) {
          _showErrorSnackBar('Failed to access storage for notifications');
        }
        setState(() {
          _isLoading = false;
        });
        return;
      }

      if (mounted) {
        setState(() {
          _generalNotifications = value;
          _isLoading = false;
        });
        _showSuccessSnackBar(
            'General notifications ${value ? 'enabled' : 'disabled'}');
      }
    } catch (e) {
      debugPrint('Error toggling general notifications: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showErrorSnackBar('Error updating notifications: $e');
      }
    }
  }

  Future<void> _toggleSensorNotification(String sensor, bool value) async {
    if (_userId == null || _isLoading) return;

    if (value && !(_isOnline[sensor] ?? false)) {
      _showErrorSnackBar('Cannot enable notifications for offline sensor');
      return;
    }

    try {
      setState(() {
        _notificationEnabled[sensor] = value;
        _isConnected[sensor] = value;
      });

      if (value) {
        await SupabaseService.client.from('user_alerts').upsert({
          'user_id': _userId!,
          'sensor_type': sensor,
          'alert_type': _alertTypes[sensor] ?? 'notifications',
          'created_at': DateTime.now().toIso8601String(),
        });
      } else {
        await SupabaseService.client
            .from('user_alerts')
            .delete()
            .eq('user_id', _userId!)
            .eq('sensor_type', sensor);
      }

      if (_isOnline[sensor] == true) {
        if (value) {
          activeSensorTypes.add(stringToSensorType(sensor));
        } else {}
      }

      if (mounted) {
        if (value) {
          _showSuccessSnackBar(
              '${sensor[0].toUpperCase()}${sensor.substring(1)} notifications enabled');
        } else {
          _showSuccessSnackBar(
              '${sensor[0].toUpperCase()}${sensor.substring(1)} notifications disabled');
        }
      }
    } catch (e) {
      debugPrint('Error updating sensor notification: $e');
      if (mounted) {
        setState(() {
          _notificationEnabled[sensor] = !value;
          _isConnected[sensor] = !value;
        });
        _showErrorSnackBar('Error updating $sensor notification: $e');
      }
    }
  }

  Future<void> _updateAlertType(String sensor, String? type) async {
    if (_userId == null || type == null || _isLoading) return;

    if (type != 'notifications' && type != 'notifications with vibration') {
      if (mounted) {
        _showErrorSnackBar('Invalid alert type selected');
      }
      return;
    }

    try {
      setState(() {
        _alertTypes[sensor] = type;
      });

      await SupabaseService.client
          .from('user_alerts')
          .update({
            'alert_type': type,
            'created_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', _userId!)
          .eq('sensor_type', sensor);

      if (mounted) {
        _showSuccessSnackBar(
            'Alert type updated for ${sensor[0].toUpperCase()}${sensor.substring(1)}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _alertTypes[sensor] = type == 'notifications with vibration'
              ? 'notifications'
              : 'notifications with vibration';
        });
        _showErrorSnackBar('Error updating alert type: $e');
      }
    }
  }

  void _toggleLed(bool value) {
    try {
      setState(() {
        _ledOn = value;
      });
      mqttService.publishActuator('led', value ? 'ON' : 'OFF');
      debugPrint(
          'Published actuator: topic=led, message=${value ? 'ON' : 'OFF'}');
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Error toggling LED: $e');
      }
    }
  }

  void _setServo(int angle) {
    try {
      if (angle < 0 || angle > 180) return;
      setState(() {
        _servoAngle = angle;
      });
      mqttService.publishActuator('servo', angle.toString());
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Error setting servo: $e');
      }
    }
  }

  void _toggleBuzzer(bool value) {
    try {
      setState(() {
        _buzzerOn = value;
      });
      mqttService.publishActuator('buzzer', value ? 'ON' : 'OFF');
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Error toggling buzzer: $e');
      }
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.danger,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  void _showSuccessSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.success,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  void dispose() {
    mqttService.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.lightTheme,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Alerts & Controls'),
          backgroundColor: AppTheme.lightTheme.appBarTheme.backgroundColor,
          foregroundColor: AppTheme.lightTheme.appBarTheme.foregroundColor,
          elevation: 2,
        ),
        body: _isLoading
            ? Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSensorReadingsSection(),
                    SizedBox(height: 16),

                    // General Notifications Section
                    _buildGeneralNotificationsCard(),
                    SizedBox(height: 16),

                    _buildSensorsSection(),
                    SizedBox(height: 16),

                    _buildActuatorControlSection(),
                    SizedBox(height: 20),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildSensorReadingsSection() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.lightTheme.primaryColor.withOpacity(0.1),
              AppTheme.lightTheme.primaryColor.withOpacity(0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.sensors,
                  color: AppTheme.lightTheme.primaryColor,
                  size: 24,
                ),
                SizedBox(width: 8),
                Text(
                  'Live Sensor Readings',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: AppTheme.lightTheme.primaryColor,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Text(
                  getTelemetryString(activeSensorTypes),
                  style: TextStyle(
                    fontSize: 13,
                    fontFamily: 'monospace',
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGeneralNotificationsCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(4),
        child: SwitchListTile(
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          title: Text(
            'Enable General Notifications',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          subtitle: Text(
            'Required for all sensor alerts',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          value: _generalNotifications,
          onChanged: _isLoading ? null : _toggleGeneralNotifications,
          secondary: Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _generalNotifications
                  ? AppColors.success.withOpacity(0.1)
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _generalNotifications
                  ? Icons.notifications_active
                  : Icons.notifications_off,
              color: _generalNotifications
                  ? AppColors.success
                  : AppColors.mediumGrey,
              size: 24,
            ),
          ),
          activeColor: AppColors.success,
        ),
      ),
    );
  }

  Widget _buildSensorsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'Sensor Alerts Configuration',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.lightTheme.primaryColor,
            ),
          ),
        ),
        ...thresholds.keys.map((sensorType) {
          final sensorKey = sensorTypeToString(sensorType);
          return Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: _buildSensorCard(sensorKey),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildActuatorControlSection() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.lightTheme.primaryColor.withOpacity(0.08),
              AppTheme.lightTheme.primaryColor.withOpacity(0.03),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.settings_remote,
                  color: AppTheme.lightTheme.primaryColor,
                  size: 24,
                ),
                SizedBox(width: 8),
                Text(
                  'Actuator Control Panel',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.lightTheme.primaryColor,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            _buildActuatorTile(
              title: 'LED Light',
              subtitle: 'Toggle LED on/off',
              icon: _ledOn ? Icons.lightbulb : Icons.lightbulb_outline,
              iconColor: _ledOn ? AppColors.warning : AppColors.mediumGrey,
              isSwitch: true,
              switchValue: _ledOn,
              onSwitchChanged: _toggleLed,
            ),
            SizedBox(height: 12),
            _buildServoControl(),
            SizedBox(height: 12),
            _buildActuatorTile(
              title: 'Buzzer',
              subtitle: 'Sound alarm',
              icon: _buzzerOn ? Icons.volume_up : Icons.volume_off,
              iconColor: _buzzerOn ? AppColors.danger : AppColors.mediumGrey,
              isSwitch: true,
              switchValue: _buzzerOn,
              onSwitchChanged: _toggleBuzzer,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActuatorTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    bool isSwitch = false,
    bool switchValue = false,
    Function(bool)? onSwitchChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: SwitchListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: Text(
          title,
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(subtitle),
        value: switchValue,
        onChanged: onSwitchChanged,
        secondary: Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor == AppColors.mediumGrey
                ? Colors.grey.shade100
                : iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor, size: 24),
        ),
        activeColor: iconColor == AppColors.danger
            ? AppColors.danger
            : AppColors.success,
      ),
    );
  }

  Widget _buildServoControl() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.lightTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.rotate_right,
                  color: AppTheme.lightTheme.primaryColor,
                  size: 24,
                ),
              ),
              SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Servo Motor',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    'Current Angle: $_servoAngle°',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
              Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _servoAngle == 180
                      ? Colors.red.withOpacity(0.1)
                      : AppTheme.lightTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$_servoAngle°',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _servoAngle == 180
                        ? Colors.red
                        : AppTheme.lightTheme.primaryColor,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppTheme.lightTheme.primaryColor,
              inactiveTrackColor:
                  AppTheme.lightTheme.primaryColor.withOpacity(0.3),
              thumbColor: AppTheme.lightTheme.primaryColor,
              overlayColor: AppTheme.lightTheme.primaryColor.withOpacity(0.2),
              thumbShape: RoundSliderThumbShape(enabledThumbRadius: 12),
              trackHeight: 6,
            ),
            child: Slider(
              value: _servoAngle.toDouble(),
              min: 0,
              max: 180,
              divisions: 18,
              label: '$_servoAngle°',
              onChanged: (val) => _setServo(val.round()),
            ),
          ),
          if (_servoAngle == 180) ...[
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.red, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'Emergency Position - Door Fully Open',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSensorCard(String sensorKey) {
    final normSensor = sensorKey;
    final value = sensorValues[sensorKey] ?? '--';
    final threshold =
        thresholds[stringToSensorType(sensorKey)]?.toString() ?? '0.0';
    final isOnline = _isOnline[normSensor] ?? false;
    final isConnected = _isConnected[normSensor] ?? false;
    final isExceeded = sensorDanger[stringToSensorType(sensorKey)] ?? false;
    final alertType = _alertTypes[normSensor] ?? 'notifications';

    return Card(
      elevation: isExceeded ? 6 : 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: isExceeded ? AppColors.danger.withOpacity(0.05) : Colors.white,
      child: Container(
        decoration: isExceeded
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.danger.withOpacity(0.3), width: 1.5),
              )
            : null,
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isExceeded
                        ? AppColors.danger.withOpacity(0.1)
                        : AppTheme.lightTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _getSensorIcon(normSensor),
                    color: isExceeded
                        ? AppColors.danger
                        : AppTheme.lightTheme.primaryColor,
                    size: 28,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        normSensor.toUpperCase(),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: isExceeded
                              ? AppColors.danger
                              : AppTheme.lightTheme.primaryColor,
                        ),
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Text('Value: ',
                              style: TextStyle(color: Colors.grey.shade600)),
                          Text(
                            value,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: isExceeded
                                  ? AppColors.danger
                                  : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Text('Threshold: ',
                              style: TextStyle(color: Colors.grey.shade600)),
                          Text(
                            threshold,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isOnline
                            ? AppColors.success.withOpacity(0.1)
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isOnline ? Icons.wifi : Icons.wifi_off,
                        color:
                            isOnline ? AppColors.success : AppColors.mediumGrey,
                        size: 20,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      isOnline ? 'Online' : 'Offline',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color:
                            isOnline ? AppColors.success : AppColors.mediumGrey,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            if (isExceeded) ...[
              SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.danger.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.danger.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: AppColors.danger, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        normSensor == 'flame'
                            ? '🚨 DANGER: Flame detected!'
                            : '⚠️ ALERT: ${normSensor[0].toUpperCase()}${normSensor.substring(1)} exceeded threshold!',
                        style: TextStyle(
                          color: AppColors.danger,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: SwitchListTile(
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                title: Text(
                  'Enable ${normSensor[0].toUpperCase()}${normSensor.substring(1)} Alerts',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                subtitle: Text(
                  isOnline
                      ? 'Receive notifications for this sensor'
                      : 'Sensor is offline - notifications disabled',
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        isOnline ? Colors.grey.shade600 : Colors.red.shade600,
                  ),
                ),
                value: isConnected && isOnline,
                onChanged: (_isLoading || !isOnline)
                    ? null
                    : (val) => _toggleSensorNotification(normSensor, val),
                secondary: Container(
                  padding: EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: (isConnected && isOnline)
                        ? AppColors.success.withOpacity(0.1)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    (isConnected && isOnline)
                        ? Icons.notifications_active
                        : Icons.notifications_off,
                    color: (isConnected && isOnline)
                        ? AppColors.success
                        : AppColors.mediumGrey,
                    size: 20,
                  ),
                ),
                activeColor: AppColors.success,
              ),
            ),

            // Alert Type Dropdown
            if (isConnected && !_isLoading && isOnline) ...[
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: DropdownButtonFormField<String>(
                  value: alertType,
                  decoration: InputDecoration(
                    labelText: 'Alert Type',
                    labelStyle: TextStyle(fontSize: 14),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  isExpanded: true,
                  items: [
                    DropdownMenuItem(
                      value: 'notifications',
                      child: Row(
                        children: [
                          Icon(Icons.notifications,
                              size: 18, color: AppColors.success),
                          SizedBox(width: 8),
                          Text('Notifications only',
                              style: TextStyle(fontSize: 14)),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'notifications with vibration',
                      child: Row(
                        children: [
                          Icon(Icons.vibration,
                              size: 18,
                              color: AppTheme.lightTheme.primaryColor),
                          SizedBox(width: 8),
                          Text('Notifications + Vibration',
                              style: TextStyle(fontSize: 14)),
                        ],
                      ),
                    ),
                  ],
                  onChanged: _isLoading
                      ? null
                      : (val) => _updateAlertType(normSensor, val),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _getSensorIcon(String sensor) {
    switch (sensor.toLowerCase()) {
      case 'temp':
        return Icons.thermostat;
      case 'humidity':
        return Icons.water_drop;
      case 'gas':
        return Icons.local_gas_station;
      case 'flame':
        return Icons.local_fire_department;
      default:
        return Icons.sensor_door;
    }
  }
}
