import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'supabase_service.dart';
import 'app_models.dart';
import 'app_theme.dart';
import 'mqtt_service.dart';

class LiveStatusScreen extends StatefulWidget {
  const LiveStatusScreen({super.key});

  @override
  State<LiveStatusScreen> createState() => _LiveStatusScreenState();
}

class _LiveStatusScreenState extends State<LiveStatusScreen>
    with TickerProviderStateMixin {
  late List<Sensor> sensors;
  SystemStatus systemStatus = SystemStatus.safe;
  late MqttService mqttService;
  List<SensorType> connectedSensors = [];
  bool _isLoading = true;
  bool _disposed = false;
  late AnimationController _pulseController;
  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    sensors = [];

    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    mqttService = MqttService(
      onUpdate: (values) {
        if (_disposed || !mounted) return;
        setState(() {
          _updateSensorsFromValues();
          _recomputeSystemStatus();
        });
      },
    );

    _loadUserSensors().then((_) {
      if (_disposed || !mounted) return;
      _initSensorsList();
      mqttService.connect();
      setState(() {
        _isLoading = false;
      });
      _fadeController.forward();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _pulseController.dispose();
    _fadeController.dispose();
    mqttService.disconnect();
    super.dispose();
  }

  Future<void> _loadUserSensors() async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) {
      debugPrint('LiveStatus: no logged-in user');
      connectedSensors = [];
      return;
    }

    try {
      final response = await SupabaseService.client
          .from('user_sensors')
          .select('sensor_type')
          .eq('user_id', userId);

      if (response is List) {
        connectedSensors = response
            .where((e) => e != null && e['sensor_type'] != null)
            .map<SensorType>((e) => _mapSensorType(e['sensor_type'].toString()))
            .toList();

        activeSensorTypes = Set.from(connectedSensors);
      } else {
        connectedSensors = [];
        activeSensorTypes = {};
      }
    } catch (e) {
      debugPrint('LiveStatus: _loadUserSensors error: $e');
      connectedSensors = [];
      activeSensorTypes = {};

      if (mounted && !_disposed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading sensor data: ${e.toString()}'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  void _initSensorsList() {
    if (_disposed) return;
    sensors = connectedSensors.map((type) {
      return Sensor(
          type: type,
          status: SensorStatus.online,
          lastUpdate: DateTime.now().toIso8601String(),
          value: '--');
    }).toList();
    if (mounted) setState(() {});
  }

  void _updateSensorsFromValues() {
    if (_disposed) return;
    sensors = sensors.map((s) {
      if (s.status == SensorStatus.offline) return s;

      String? value;
      switch (s.type) {
        case SensorType.gas:
          value = sensorValues['gas'];
          break;
        case SensorType.flame:
          value = sensorValues['flame'];
          break;
        case SensorType.temperature:
          value = sensorValues['temp'];
          break;
        case SensorType.humidity:
          value = sensorValues['humidity'];
          break;
      }

      return s.copyWith(
          value: value, lastUpdate: DateTime.now().toIso8601String());
    }).toList();
  }

  void _recomputeSystemStatus() {
    if (_disposed) return;

    final int buzzer = int.tryParse(sensorValues['buzzer'] ?? '0') ?? 0;
    final int led = int.tryParse(sensorValues['led'] ?? '0') ?? 0;
    final int servo = int.tryParse(sensorValues['servo'] ?? '0') ?? 0;

    if (buzzer == 1 || led == 1 || servo == 1) {
      systemStatus = SystemStatus.danger;
      return;
    }

    SystemStatus newStatus = SystemStatus.safe;

    for (final s in sensors) {
      if (s.status == SensorStatus.online &&
          s.value != null &&
          s.value != '--') {
        final val = double.tryParse(s.value!);
        final threshold = thresholds[s.type];
        if (val == null || val.isNaN || threshold == null) continue;

        if (s.type == SensorType.gas) {
          if (val > threshold) {
            newStatus = SystemStatus.danger;
            break;
          } else if (val > threshold * 0.8) {
            newStatus = SystemStatus.warning;
          }
        } else if (s.type == SensorType.flame) {
          if (val < threshold) {
            newStatus = SystemStatus.danger;
            break;
          } else if (val < threshold * 1.2) {
            newStatus = SystemStatus.warning;
          }
        } else if (s.type == SensorType.temperature ||
            s.type == SensorType.humidity) {
          if (val > threshold) {
            newStatus = SystemStatus.danger;
            break;
          } else if (val > threshold * 0.8) {
            newStatus = SystemStatus.warning;
          }
        }
      }
    }

    systemStatus = newStatus;
  }

  SensorType _mapSensorType(String type) {
    switch (type.toLowerCase()) {
      case 'gas':
        return SensorType.gas;
      case 'flame':
        return SensorType.flame;
      case 'temperature':
      case 'temp':
        return SensorType.temperature;
      case 'humidity':
      case 'hum':
        return SensorType.humidity;
      default:
        return SensorType.gas;
    }
  }

  String actuatorDisplay(String key) {
    final raw = sensorValues[key] ?? '0';
    if (raw == '1') return 'ON';
    if (raw == '0') return 'OFF';
    return raw;
  }

  String lastUpdateString() {
    final updates = sensors
        .where((s) =>
            s.status == SensorStatus.online &&
            (s.lastUpdate?.isNotEmpty ?? false))
        .map((s) => s.lastUpdate)
        .where((s) {
      try {
        DateTime.parse(s!);
        return true;
      } catch (_) {
        return false;
      }
    }).toList();

    if (updates.isEmpty) return 'No updates yet';
    updates.sort((a, b) => DateTime.parse(b!).compareTo(DateTime.parse(a!)));
    final dt = DateTime.parse(updates.first!);
    return DateFormat('hh:mm a').format(dt);
  }

  String _formatLastUpdate(String? lastUpdate) {
    if (lastUpdate == null || lastUpdate.isEmpty) return 'Not available';

    try {
      final dt = DateTime.parse(lastUpdate);
      final now = DateTime.now();
      final difference = now.difference(dt);

      if (difference.inSeconds < 60) {
        return 'Just now';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      } else {
        return DateFormat('hh:mm a').format(dt);
      }
    } catch (_) {
      return 'Invalid';
    }
  }

  Future<void> _refreshSensors() async {
    if (!mounted || _disposed) return;

    setState(() {
      _isLoading = true;
    });

    await _loadUserSensors();
    _initSensorsList();

    if (mounted && !_disposed) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('Sensors refreshed successfully'),
            ],
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: SafeArea(
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.burgundy700.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: 1.0 + (_pulseController.value * 0.1),
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.burgundy600,
                                AppColors.burgundy700
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.sensors,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Loading Sensors',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: AppColors.burgundy700,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please wait while we connect...',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.mediumGrey,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeController,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                expandedHeight: 100,
                floating: true,
                pinned: true,
                backgroundColor: Colors.transparent,
                elevation: 0,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.burgundy600.withOpacity(0.9),
                          AppColors.burgundy700.withOpacity(0.9),
                        ],
                      ),
                    ),
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.dashboard, color: Colors.white, size: 28),
                          SizedBox(height: 4),
                          Text(
                            'Live Status',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                actions: [
                  Container(
                    margin: const EdgeInsets.only(right: 16, top: 8),
                    child: Material(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: _refreshSensors,
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(Icons.refresh,
                              color: Colors.white, size: 20),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const SizedBox(height: 12),
                    _buildModernSystemStatusHeader(context, systemStatus),
                    const SizedBox(height: 16),
                    if (sensors.isEmpty)
                      _buildEmptyState(context)
                    else
                      _buildSensorsGrid(context),
                    const SizedBox(height: 12),
                    _buildModernSystemInfoCard(context, sensors),
                    const SizedBox(height: 16),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.burgundy600, AppColors.burgundy700],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.burgundy700.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          backgroundColor: Colors.transparent,
          elevation: 0,
          onPressed: () {
            try {
              final cur = sensorValues['led'] ?? '0';
              final next = cur == '1' ? 'OFF' : 'ON';
              mqttService.publishActuator('led', next);

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        next == 'ON'
                            ? Icons.lightbulb
                            : Icons.lightbulb_outline,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                          'Light ${next == 'ON' ? 'turned on' : 'turned off'}'),
                    ],
                  ),
                  backgroundColor:
                      next == 'ON' ? Colors.amber[600] : AppColors.mediumGrey,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              );
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline,
                          color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Text('Error controlling light: $e'),
                    ],
                  ),
                  backgroundColor: AppColors.danger,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              );
            }
          },
          icon: const Icon(Icons.lightbulb_outline, color: Colors.white),
          label: const Text('Control Light',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }

  Widget _buildModernSystemStatusHeader(
      BuildContext context, SystemStatus status) {
    Color statusColor;
    Color bgColor;
    String statusText;
    String statusDescription;
    IconData statusIcon;

    switch (status) {
      case SystemStatus.safe:
        statusColor = const Color(0xFF10B981);
        bgColor = const Color(0xFFECFDF5);
        statusText = 'All Systems Safe';
        statusDescription = 'Everything is running smoothly';
        statusIcon = Icons.verified_user;
        break;
      case SystemStatus.warning:
        statusColor = const Color(0xFFF59E0B);
        bgColor = const Color(0xFFFEF3C7);
        statusText = 'Warning Detected';
        statusDescription = 'Some readings need attention';
        statusIcon = Icons.warning_amber_rounded;
        break;
      case SystemStatus.danger:
        statusColor = const Color(0xFFEF4444);
        bgColor = const Color(0xFFFEE2E2);
        statusText = 'Critical Alert';
        statusDescription = 'Immediate action required!';
        statusIcon = Icons.emergency;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.2), width: 2),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(statusIcon, size: 24, color: statusColor),
          ),
          const SizedBox(height: 8),
          Text(
            statusText,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            statusDescription,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.mediumGrey,
                  fontSize: 12,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.burgundy700.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.schedule,
                  size: 14,
                  color: AppColors.burgundy700,
                ),
                const SizedBox(width: 4),
                Text(
                  'Last Update: ${lastUpdateString()}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.burgundy700,
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.mediumGrey.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.sensors_off,
              size: 36,
              color: AppColors.mediumGrey,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'No Connected Sensors',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.darkGrey,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Pull down to refresh and try again',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.mediumGrey,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildSensorsGrid(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Live Sensor Readings',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.burgundy700,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 1.5,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: sensors.length,
          itemBuilder: (context, index) {
            return _buildModernSensorCard(context, sensors[index]);
          },
        ),
      ],
    );
  }

  Widget _buildModernSensorCard(BuildContext context, Sensor sensor) {
    final isOnline = sensor.status == SensorStatus.online;
    final sensorColor = _getSensorColor(sensor.type);

    Color valueColor = sensorColor;
    String statusText = 'Normal';

    if (isOnline && sensor.value != null && sensor.value != '--') {
      final value = double.tryParse(sensor.value!);
      final threshold = thresholds[sensor.type];

      if (value != null && !value.isNaN && threshold != null) {
        if ((sensor.type == SensorType.gas && value > threshold) ||
            (sensor.type == SensorType.flame && value < threshold) ||
            ((sensor.type == SensorType.temperature ||
                    sensor.type == SensorType.humidity) &&
                value > threshold)) {
          valueColor = AppColors.danger;
          statusText = 'Critical';
        } else if ((sensor.type == SensorType.gas && value > threshold * 0.8) ||
            ((sensor.type == SensorType.temperature ||
                    sensor.type == SensorType.humidity) &&
                value > threshold * 0.8) ||
            (sensor.type == SensorType.flame && value < threshold * 1.2)) {
          valueColor = AppColors.warning;
          statusText = 'Warning';
        }
      }
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOnline
              ? sensorColor.withOpacity(0.2)
              : AppColors.mediumGrey.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: (isOnline ? sensorColor : AppColors.mediumGrey)
                .withOpacity(0.08),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: sensorColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  sensor.type.icon,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color:
                      isOnline ? const Color(0xFF10B981) : AppColors.mediumGrey,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      isOnline ? 'Live' : 'Off',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Flexible(
            child: Text(
              sensor.type.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.darkGrey,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
            ),
          ),
          Text(
            _formatLastUpdate(sensor.lastUpdate),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.mediumGrey,
                  fontSize: 10,
                ),
          ),
          const Spacer(),
          if (isOnline) ...[
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                sensor.value ?? '—',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: valueColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
              ),
            ),
            Text(
              statusText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: valueColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                  ),
            ),
          ] else ...[
            Text(
              'Offline',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.mediumGrey,
                    fontStyle: FontStyle.italic,
                    fontSize: 12,
                  ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildModernSystemInfoCard(
      BuildContext context, List<Sensor> sensors) {
    final onlineSensors =
        sensors.where((s) => s.status == SensorStatus.online).length;
    final totalSensors = sensors.length;
    final healthPercent =
        totalSensors > 0 ? (onlineSensors / totalSensors) * 100 : 0;

    Color healthColor;
    if (healthPercent > 80) {
      healthColor = const Color(0xFF10B981);
    } else if (healthPercent > 50) {
      healthColor = const Color(0xFFF59E0B);
    } else {
      healthColor = const Color(0xFFEF4444);
    }

    final mqttConnected = (mqttService.client.connectionStatus?.state ==
        MqttConnectionState.connected);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.burgundy700.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.info_outline,
                  color: AppColors.burgundy700,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'System Overview',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.burgundy700,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
              context, 'Total Sensors', '$totalSensors', Icons.sensors),
          _buildInfoRow(
              context, 'Online Sensors', '$onlineSensors', Icons.wifi),
          _buildInfoRow(context, 'System Health', '${healthPercent.round()}%',
              Icons.health_and_safety,
              valueColor: healthColor),
          _buildInfoRow(
              context, 'Last Check', lastUpdateString(), Icons.schedule),
          _buildInfoRow(
              context,
              'MQTT Status',
              mqttConnected ? 'Connected' : 'Disconnected',
              mqttConnected ? Icons.cloud_done : Icons.cloud_off,
              valueColor: mqttConnected
                  ? const Color(0xFF10B981)
                  : const Color(0xFFEF4444)),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
      BuildContext context, String label, String value, IconData icon,
      {Color? valueColor}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.burgundy700.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.burgundy700.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.burgundy700.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              icon,
              color: AppColors.burgundy700,
              size: 14,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.burgundy600,
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: valueColor ?? AppColors.burgundy800,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Color _getSensorColor(SensorType type) {
    switch (type) {
      case SensorType.gas:
        return const Color(0xFF8B5CF6);
      case SensorType.flame:
        return const Color(0xFFEF4444);
      case SensorType.temperature:
        return const Color(0xFFF59E0B);
      case SensorType.humidity:
        return const Color(0xFF3B82F6);
    }
  }
}
