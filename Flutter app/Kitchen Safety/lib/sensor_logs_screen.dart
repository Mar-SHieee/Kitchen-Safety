import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:intl/intl.dart';
import 'app_theme.dart';
import 'mqtt_service.dart';
import 'app_models.dart';

class SensorLogsScreen extends StatefulWidget {
  const SensorLogsScreen({super.key});

  @override
  State<SensorLogsScreen> createState() => _SensorLogsScreenState();
}

class _SensorLogsScreenState extends State<SensorLogsScreen>
    with TickerProviderStateMixin {
  final _supa = Supabase.instance.client;

  late MqttService _mqttService;
  bool _mqttConnected = false;

  RealtimeChannel? _realtimeChannel;
  RealtimeChannel? _userSensorsChannel;

  late AnimationController _statusAnimationController;
  late AnimationController _controlsAnimationController;

  List<Map<String, dynamic>> sensorData = [];
  List<String> availableSensorTypes = [];
  Map<String, String> latestSensorValues = {
    'temp': '--',
    'humidity': '--',
    'gas': '--',
    'flame': '--',
    'led': '--',
    'buzzer': '--',
    'servo': '--',
    'status': 'All Safe',
  };
  bool isDangerMode = false;

  @override
  void initState() {
    super.initState();
    _statusAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _controlsAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..forward();

    _mqttService = MqttService(
      onUpdate: (values) {
        if (mounted) {
          _updateSensorValues(values);
        }
      },
    );

    _initializeScreen();
  }

  @override
  void dispose() {
    _statusAnimationController.dispose();
    _controlsAnimationController.dispose();
    _realtimeChannel?.unsubscribe();
    _userSensorsChannel?.unsubscribe();
    _mqttService.disconnect();
    super.dispose();
  }

  Future<void> _initializeScreen() async {
    final user = _supa.auth.currentUser;
    if (user == null) {
      if (mounted) {
        _showSnackBar('Please log in to view sensor data', isError: true);
      }
      return;
    }

    await _updateUserProfileToActive(user.id);
    await _fetchUserAvailableSensors(user.id);

    if (availableSensorTypes.isNotEmpty) {
      await _connectMqtt();
    }

    _fetchSensorDataFromSupabase();
    _subscribeToRealtimeSupabase();
    _subscribeToUserSensorsChanges();
  }

  Future<void> _connectMqtt() async {
    try {
      await _mqttService.connect();
      if (mounted) {
        setState(() {
          _mqttConnected = _mqttService.client.connectionStatus?.state ==
              MqttConnectionState.connected;
        });
      }

      _updateSensorValues(sensorValues);
    } catch (e) {
      debugPrint('MQTT connection error: $e');
      if (mounted) {
        _showSnackBar('MQTT connection failed: $e', isError: true);
      }
    }
  }

  void _updateSensorValues(Map<String, String> values) {
    setState(() {
      for (var sensorType in availableSensorTypes) {
        switch (sensorType.toLowerCase()) {
          case 'temp':
          case 'temperature':
            latestSensorValues['temp'] = values['temp'] ?? '--';
            break;
          case 'humidity':
          case 'hum':
            latestSensorValues['humidity'] = values['humidity'] ?? '--';
            break;
          case 'gas':
            latestSensorValues['gas'] = values['gas'] ?? '--';
            break;
          case 'flame':
            latestSensorValues['flame'] = values['flame'] ?? '--';
            break;
        }
      }

      latestSensorValues['led'] = values['led'] ?? '--';
      latestSensorValues['buzzer'] = values['buzzer'] ?? '--';
      latestSensorValues['servo'] = values['servo'] ?? '--';
      latestSensorValues['status'] = values['status'] ?? 'All Safe';

      isDangerMode =
          latestSensorValues['status']!.toLowerCase().contains('danger');

      _mqttConnected = _mqttService.client.connectionStatus?.state ==
          MqttConnectionState.connected;
    });

    debugPrint('Updated sensor values: $latestSensorValues');
  }

  Future<void> _updateUserProfileToActive(String userId) async {
    try {
      await _supa.from('profiles').update({'active': true}).eq('id', userId);
    } catch (e) {
      debugPrint('Error updating profile active status: $e');
    }
  }

  Future<void> _fetchUserAvailableSensors(String userId) async {
    try {
      final res = await _supa
          .from('user_sensors')
          .select('sensor_type')
          .eq('user_id', userId);
      if (mounted) {
        final newTypes =
            res.map<String>((e) => e['sensor_type'] as String).toList();
        setState(() {
          final removed = availableSensorTypes
              .where((type) => !newTypes.contains(type))
              .toList();
          for (var type in removed) {
            final key = _getSensorKey(type);
            if (key.isNotEmpty) {
              latestSensorValues[key] = '--';
            }
          }
          availableSensorTypes = newTypes;
        });

        activeSensorTypes = {};
        for (var type in newTypes) {
          switch (type.toLowerCase()) {
            case 'temp':
            case 'temperature':
              activeSensorTypes.add(SensorType.temperature);
              break;
            case 'humidity':
            case 'hum':
              activeSensorTypes.add(SensorType.humidity);
              break;
            case 'gas':
              activeSensorTypes.add(SensorType.gas);
              break;
            case 'flame':
              activeSensorTypes.add(SensorType.flame);
              break;
          }
        }

        if (newTypes.isEmpty && _mqttConnected) {
          _mqttService.disconnect();
          setState(() => _mqttConnected = false);
        } else if (newTypes.isNotEmpty && !_mqttConnected) {
          await _connectMqtt();
        }

        _fetchSensorDataFromSupabase();
      }
    } catch (e) {
      debugPrint('Error fetching user sensors: $e');
      if (mounted) {
        _showSnackBar('Error fetching user sensors: $e', isError: true);
      }
    }
  }

  String _getSensorKey(String type) {
    switch (type.toLowerCase()) {
      case 'temp':
      case 'temperature':
        return 'temp';
      case 'humidity':
      case 'hum':
        return 'humidity';
      case 'gas':
        return 'gas';
      case 'flame':
        return 'flame';
      default:
        return '';
    }
  }

  void _subscribeToUserSensorsChanges() {
    final user = _supa.auth.currentUser;
    if (user == null) return;

    _userSensorsChannel = _supa
        .channel('user_sensors_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'user_sensors',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: user.id,
          ),
          callback: (payload) {
            _fetchUserAvailableSensors(user.id);
          },
        )
        .subscribe();
  }

  Future<void> _fetchSensorDataFromSupabase() async {
    final user = _supa.auth.currentUser;
    if (user == null) return;

    try {
      final res = await _supa
          .from('sensors')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .range(0, 99);

      if (mounted) {
        setState(() {
          sensorData = List<Map<String, dynamic>>.from(res);
          if (sensorData.isNotEmpty) {
            _updateLatestValuesFromData(sensorData.first);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error fetching sensor data: $e', isError: true);
      }
    }
  }

  void _updateLatestValuesFromData(Map<String, dynamic> data) {
    setState(() {
      if (availableSensorTypes.contains('temp') ||
          availableSensorTypes.contains('temperature')) {
        latestSensorValues['temp'] = data['temp']?.toString() ?? '--';
      }
      if (availableSensorTypes.contains('humidity') ||
          availableSensorTypes.contains('hum')) {
        latestSensorValues['humidity'] = data['hum']?.toString() ?? '--';
      }
      if (availableSensorTypes.contains('gas')) {
        latestSensorValues['gas'] = data['gas']?.toString() ?? '--';
      }
      if (availableSensorTypes.contains('flame')) {
        latestSensorValues['flame'] = data['flame']?.toString() ?? '--';
      }

      latestSensorValues['led'] = data['led']?.toString() ?? '--';
      latestSensorValues['buzzer'] = data['buzzer']?.toString() ?? '--';
      latestSensorValues['servo'] = data['servo']?.toString() ?? '--';
      latestSensorValues['status'] = data['status']?.toString() ?? 'All Safe';

      isDangerMode =
          latestSensorValues['status']!.toLowerCase().contains('danger');
    });
  }

  void _subscribeToRealtimeSupabase() {
    final user = _supa.auth.currentUser;
    if (user == null) return;

    _realtimeChannel = _supa
        .channel('sensors_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'sensors',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: user.id,
          ),
          callback: (payload) {
            if (mounted) {
              setState(() {
                final newRecord = payload.newRecord;
                sensorData.insert(0, newRecord);
                _updateLatestValuesFromData(newRecord);
              });
            }
          },
        )
        .subscribe();
  }

  void _publishControl(String topic, String message) {
    try {
      _mqttService.publishActuator(topic, message);
      setState(() {
        latestSensorValues[topic] = message;
      });
      _showSnackBar('$topic → $message');
    } catch (e) {
      _showSnackBar('Error controlling $topic: $e', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.danger : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Smart Kitchen Monitor'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        foregroundColor: AppColors.darkGrey,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color:
                  _mqttConnected ? Colors.green.shade100 : Colors.red.shade100,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _mqttConnected ? Colors.green : Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _mqttConnected ? 'Online' : 'Offline',
                  style: TextStyle(
                    color: _mqttConnected
                        ? Colors.green.shade700
                        : Colors.red.shade700,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchSensorDataFromSupabase,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatusCard(),
              const SizedBox(height: 20),
              _buildSensorCards(),
              const SizedBox(height: 20),
              _buildControlsSection(),
              const SizedBox(height: 20),
              _buildHistorySection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return AnimatedBuilder(
      animation: _statusAnimationController,
      builder: (context, child) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDangerMode ? Colors.red.shade500 : Colors.green.shade500,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color:
                    (isDangerMode ? Colors.red : Colors.green).withOpacity(0.3),
                offset: const Offset(0, 8),
                blurRadius: 20,
              ),
            ],
          ),
          child: Column(
            children: [
              Transform.scale(
                scale: isDangerMode
                    ? (0.9 + _statusAnimationController.value * 0.2)
                    : 1.0,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isDangerMode ? Icons.warning_rounded : Icons.shield_rounded,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isDangerMode ? 'DANGER DETECTED!' : 'Kitchen is Safe',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                latestSensorValues['status']!,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSensorCards() {
    final sensorWidgets = <Widget>[];

    for (var sensorType in availableSensorTypes) {
      switch (sensorType.toLowerCase()) {
        case 'temp':
        case 'temperature':
          sensorWidgets.add(_buildSensorCard(
              'Temperature',
              latestSensorValues['temp']!,
              '°C',
              Icons.thermostat,
              Colors.orange));
          break;
        case 'humidity':
        case 'hum':
          sensorWidgets.add(_buildSensorCard(
              'Humidity',
              latestSensorValues['humidity']!,
              '%',
              Icons.water_drop,
              Colors.blue));
          break;
        case 'gas':
          sensorWidgets.add(_buildSensorCard('Gas Level',
              latestSensorValues['gas']!, '', Icons.gas_meter, Colors.purple));
          break;
        case 'flame':
          sensorWidgets.add(_buildSensorCard(
              'Flame',
              latestSensorValues['flame']!,
              '',
              Icons.local_fire_department,
              Colors.red));
          break;
      }
    }

    if (sensorWidgets.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sensor Readings',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkGrey,
                ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                Icon(Icons.sensors_off, size: 48, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  'No sensors configured',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Add sensors to start monitoring',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Sensor Readings',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkGrey,
                  ),
            ),
            Text(
              '${sensorWidgets.length} Active',
              style: TextStyle(
                color: Colors.green.shade700,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.3,
          children: sensorWidgets,
        ),
      ],
    );
  }

  Widget _buildSensorCard(
      String title, String value, String unit, IconData icon, Color color) {
    final isActive = value != '--';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, 4),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isActive ? Colors.green : Colors.grey,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: value,
                    style: TextStyle(
                      color:
                          isActive ? AppColors.darkGrey : Colors.grey.shade400,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextSpan(
                    text: unit,
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 14,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlsSection() {
    return AnimatedBuilder(
      animation: _controlsAnimationController,
      builder: (context, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.5),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: _controlsAnimationController,
            curve: Curves.easeOutBack,
          )),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Device Controls',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkGrey,
                    ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                      child: _buildControlCard(
                          'LED',
                          latestSensorValues['led']!,
                          Icons.lightbulb,
                          Colors.yellow.shade700)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _buildControlCard(
                          'Buzzer',
                          latestSensorValues['buzzer']!,
                          Icons.volume_up,
                          Colors.indigo)),
                ],
              ),
              const SizedBox(height: 12),
              _buildServoControlCard(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildControlCard(
      String title, String status, IconData icon, Color color) {
    final isOn = status.toLowerCase() == 'on';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, color: isOn ? color : Colors.grey, size: 24),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isOn ? color.withOpacity(0.1) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: isOn ? color : Colors.grey,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.darkGrey,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildControlButton('ON',
                    () => _publishControl(title.toLowerCase(), 'ON'), isOn),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildControlButton('OFF',
                    () => _publishControl(title.toLowerCase(), 'OFF'), !isOn),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildServoControlCard() {
    final servoValue = int.tryParse(latestSensorValues['servo']!) ?? 0;
    final isOpen = servoValue > 45;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.rotate_right,
                  color: isOpen ? Colors.green : Colors.orange, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Servo Motor',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.darkGrey,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color:
                      isOpen ? Colors.green.shade100 : Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${latestSensorValues['servo']}°',
                  style: TextStyle(
                    color:
                        isOpen ? Colors.green.shade700 : Colors.orange.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildControlButton(
                  'Open (90°)',
                  () => _publishControl('servo', '90'),
                  isOpen,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildControlButton(
                  'Close (0°)',
                  () => _publishControl('servo', '0'),
                  !isOpen,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton(
      String text, VoidCallback onPressed, bool isActive) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor:
            isActive ? AppColors.burgundy700 : Colors.grey.shade200,
        foregroundColor: isActive ? Colors.white : Colors.grey.shade600,
        elevation: isActive ? 2 : 0,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sensor History',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.darkGrey,
              ),
        ),
        const SizedBox(height: 16),
        if (sensorData.isEmpty) _buildEmptyState() else _buildHistoryCards(),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(Icons.sensors_off, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'No sensor data yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start monitoring to see historical data',
            style: TextStyle(
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCards() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sensorData.length,
      itemBuilder: (context, index) {
        final data = sensorData[index];
        final time = DateFormat('MMM dd, yyyy • HH:mm')
            .format(DateTime.parse(data['created_at']));
        final isDanger =
            data['status']?.toString().toLowerCase().contains('danger') ??
                false;

        final userId = data['user_id']?.toString() ?? '--';
        final shortUserId = userId.length > 8 ? userId.substring(0, 8) : userId;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDanger ? Colors.red.shade200 : Colors.grey.shade200,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                offset: const Offset(0, 2),
                blurRadius: 8,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isDanger
                        ? Icons.warning_rounded
                        : Icons.check_circle_rounded,
                    color: isDanger ? Colors.red : Colors.green,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          time,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'User: $shortUserId...',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 10,
                            fontWeight: FontWeight.w400,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDanger
                          ? Colors.red.shade100
                          : Colors.green.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      data['status']?.toString() ?? '--',
                      style: TextStyle(
                        color: isDanger
                            ? Colors.red.shade700
                            : Colors.green.shade700,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (availableSensorTypes.isNotEmpty) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var sensorType in availableSensorTypes)
                      _buildMiniSensorCardForType(sensorType, data),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildMiniControlCard('LED', data['led']?.toString() ?? '--',
                      Colors.yellow.shade700),
                  _buildMiniControlCard('Buzzer',
                      data['buzzer']?.toString() ?? '--', Colors.indigo),
                  _buildMiniControlCard(
                      'Servo', '${data['servo'] ?? '--'}°', Colors.green),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMiniSensorCardForType(String type, Map<String, dynamic> data) {
    switch (type.toLowerCase()) {
      case 'temp':
      case 'temperature':
        return _buildMiniSensorCard(
            'Temp', '${data['temp'] ?? '--'}°C', Colors.orange);
      case 'humidity':
      case 'hum':
        return _buildMiniSensorCard(
            'Humidity', '${data['hum'] ?? '--'}%', Colors.blue);
      case 'gas':
        return _buildMiniSensorCard(
            'Gas', data['gas']?.toString() ?? '--', Colors.purple);
      case 'flame':
        return _buildMiniSensorCard(
            'Flame', data['flame']?.toString() ?? '--', Colors.red);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildMiniSensorCard(String title, String value, Color color) {
    return Container(
      constraints: const BoxConstraints(minWidth: 80),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: TextStyle(
              color: _getColorShade(color, 700),
              fontSize: 8,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              color: _getColorShade(color, 800),
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildMiniControlCard(String title, String value, Color color) {
    return Container(
      constraints: const BoxConstraints(minWidth: 80),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 8,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 8,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Color _getColorShade(Color color, int shade) {
    if (color == Colors.orange) return Colors.orange[shade]!;
    if (color == Colors.blue) return Colors.blue[shade]!;
    if (color == Colors.purple) return Colors.purple[shade]!;
    if (color == Colors.red) return Colors.red[shade]!;
    return color;
  }
}
