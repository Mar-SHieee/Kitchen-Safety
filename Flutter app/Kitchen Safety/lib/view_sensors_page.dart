import 'package:flutter/material.dart';
import 'supabase_service.dart';
import 'app_theme.dart';
import 'app_models.dart';
import 'mqtt_service.dart';
import 'add_sensor_page.dart';

class ViewSensorsPage extends StatefulWidget {
  const ViewSensorsPage({super.key});

  @override
  State<ViewSensorsPage> createState() => _ViewSensorsPageState();
}

class _ViewSensorsPageState extends State<ViewSensorsPage> {
  late MqttService mqttService;
  bool isLoading = true;
  String? errorMessage;
  List<Map<String, dynamic>> sensors = [];
  Map<String, String> sensorValues = {};

  @override
  void initState() {
    super.initState();
    mqttService = MqttService(onUpdate: _handleMqttUpdate);
    _initialize();
  }

  @override
  void dispose() {
    mqttService.disconnect();
    super.dispose();
  }

  Future<void> _initialize() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
      sensorValues.clear();
    });

    try {
      await Future.wait([
        mqttService.connect(),
        _refreshData(),
      ]);

      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = 'Failed to initialize: $e';
          isLoading = false;
        });
      }
    }
  }

  void _handleMqttUpdate(Map<String, String> updatedValues) {
    if (mounted) {
      setState(() {
        sensorValues.addAll(updatedValues);
      });
    }
  }

  Future<List<Map<String, dynamic>>> fetchSensors() async {
    final user = SupabaseService.client.auth.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please log in to view sensors'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
      return [];
    }

    try {
      final data = await SupabaseService.client
          .from('user_sensors')
          .select('sensor_type, profiles(username)')
          .eq('user_id', user.id);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('Supabase fetch error: $e');
      throw Exception('Failed to fetch sensors: $e');
    }
  }

  Future<void> _refreshData() async {
    try {
      final fetchedSensors = await fetchSensors();
      if (mounted) {
        setState(() {
          sensors = fetchedSensors;
          errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = 'Failed to refresh: $e';
        });
      }
    }
  }

  String getSensorValue(SensorType type) {
    final keyMap = {
      SensorType.temperature: 'temp',
      SensorType.humidity: 'humidity',
      SensorType.gas: 'gas',
      SensorType.flame: 'flame',
    };
    final key = keyMap[type];
    return key != null ? sensorValues[key] ?? '--' : '--';
  }

  bool _isDanger(SensorType type, String? value) {
    final val = mqttService.parseDoubleSafe(value);
    final threshold = thresholds[type] ?? double.infinity;

    switch (type) {
      case SensorType.gas:
        return val > threshold;
      case SensorType.flame:
        return val < threshold;
      case SensorType.temperature:
      case SensorType.humidity:
        return val > threshold;
    }
  }

  Color _getSensorColor(SensorType type) {
    switch (type) {
      case SensorType.gas:
        return AppColors.danger;
      case SensorType.flame:
        return AppColors.warning;
      case SensorType.temperature:
        return AppColors.burgundy700;
      case SensorType.humidity:
        return AppColors.burgundy600;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('My Sensors',
              style: TextStyle(fontFamily: 'OpenSans')),
          backgroundColor: theme.colorScheme.primary,
          centerTitle: true,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (errorMessage != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('My Sensors',
              style: TextStyle(fontFamily: 'OpenSans')),
          backgroundColor: theme.colorScheme.primary,
          centerTitle: true,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                errorMessage!,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: AppColors.danger),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _initialize,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (sensors.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('My Sensors',
              style: TextStyle(fontFamily: 'OpenSans')),
          backgroundColor: theme.colorScheme.primary,
          centerTitle: true,
        ),
        body: _buildEmptyState(context),
        floatingActionButton: _buildFAB(context),
      );
    }

    bool anyDanger = false;
    final cards = sensors.map((sensor) {
      final typeString = sensor['sensor_type'] as String? ?? 'gas';
      final username = sensor['profiles']?['username']?.toString() ?? 'Unknown';

      final type = SensorType.values.firstWhere(
        (e) => e.name.toLowerCase() == typeString.toLowerCase(),
        orElse: () => SensorType.gas,
      );

      final rawValue = getSensorValue(type);
      final isDanger = _isDanger(type, rawValue);
      if (isDanger) anyDanger = true;

      return _buildSensorCard(context, type, rawValue, username, isDanger);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title:
            const Text('My Sensors', style: TextStyle(fontFamily: 'OpenSans')),
        backgroundColor: theme.colorScheme.primary,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: Container(
          color: anyDanger
              ? AppColors.danger.withOpacity(0.03)
              : Colors.transparent,
          child: ListView(
            padding: const EdgeInsets.all(16),
            physics: const AlwaysScrollableScrollPhysics(),
            children: cards,
          ),
        ),
      ),
      floatingActionButton: _buildFAB(context),
    );
  }

  Widget _buildFAB(BuildContext context) {
    return FloatingActionButton(
      backgroundColor: Theme.of(context).colorScheme.primary,
      child: const Icon(Icons.add),
      onPressed: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddSensorPage()),
        );

        if (result == true) {
          await _refreshData();
        }
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.sensors_off, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            "No sensors found",
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddSensorPage()),
              );

              if (result == true) {
                await _refreshData();
              }
            },
            child: const Text("Add Sensor"),
          ),
        ],
      ),
    );
  }

  Widget _buildSensorCard(
    BuildContext context,
    SensorType type,
    String value,
    String username,
    bool isDanger,
  ) {
    final theme = Theme.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      child: Card(
        elevation: isDanger ? 8.0 : 2.0,
        shadowColor: isDanger ? AppColors.danger : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.only(bottom: 16),
        color: isDanger ? AppColors.danger.withOpacity(0.15) : Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _getSensorColor(type).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child:
                        Text(type.icon, style: const TextStyle(fontSize: 24)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          type.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.darkGrey,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'User: $username',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.mediumGrey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDanger ? AppColors.danger : AppColors.success,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isDanger ? 'Danger' : 'Normal',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.burgundy50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.burgundy200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current Reading:',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.burgundy600,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          value,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: isDanger
                                ? AppColors.danger
                                : AppColors.burgundy800,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Updated: ${DateTime.now().toString().substring(11, 19)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.mediumGrey,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
