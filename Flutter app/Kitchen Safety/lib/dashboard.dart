import 'package:flutter/material.dart';
import 'mqtt_service.dart';
import 'supabase_service.dart';
import 'app_theme.dart';
import 'app_models.dart';
import 'add_sensor_page.dart';
import 'view_sensors_page.dart';
import 'live_status_screen.dart';
import 'alerts_page.dart';
import 'delete_sensor_page.dart';
import 'sensor_logs_screen.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> with TickerProviderStateMixin {
  late MqttService mqttService;
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));

    mqttService = MqttService(onUpdate: (updatedValues) {
      if (!mounted) return;

      setState(() {
        sensorValues = updatedValues;
      });

      _fetchCounts();
    });

    mqttService.connect();
    _fetchCounts();

    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    mqttService.disconnect();
    super.dispose();
  }

  Future<void> _fetchCounts() async {
    final user = SupabaseService.client.auth.currentUser;
    debugPrint('Current user: $user');
    if (user == null) {
      setState(() {
        mqttService.sensorCount = 0;
        mqttService.alertCount = 0;
        activeSensorTypes = {};
        debugPrint('No user logged in, resetting counts');
      });
      return;
    }

    try {
      final sensors = await SupabaseService.client
          .from('user_sensors')
          .select()
          .eq('user_id', user.id);
      debugPrint('Fetched sensors: $sensors');

      final alerts = await SupabaseService.client
          .from('user_alerts')
          .select()
          .eq('user_id', user.id);
      debugPrint('Fetched alerts: $alerts');

      setState(() {
        mqttService.sensorCount = sensors.length;
        activeSensorTypes = sensors
            .map((d) => stringToSensorType(d['sensor_type'] as String))
            .toSet();

        for (var alert in alerts) {
          final type = stringToSensorType(alert['sensor_type'] as String);
          if (alert['threshold'] != null) {
            thresholds[type] = (alert['threshold'] as num).toDouble();
          }
        }
        debugPrint(
            'Updated: sensorCount=${mqttService.sensorCount}, activeSensorTypes=$activeSensorTypes, thresholds=$thresholds');
      });
    } catch (e) {
      debugPrint('Supabase fetch failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to fetch counts: $e'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint(
        'Building Dashboard: sensorCount=${mqttService.sensorCount}, alertCount=${mqttService.alertCount}');

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: _buildAppBar(),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: RefreshIndicator(
            onRefresh: _fetchCounts,
            color: AppColors.burgundy700,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16), // قللت الـ padding
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildWelcomeHeader(),
                  const SizedBox(height: 20),
                  _buildSystemStatusCard(mqttService.systemStatus),
                  const SizedBox(height: 24),
                  _buildQuickStats(),
                  const SizedBox(height: 28),
                  _buildSectionHeader('Quick Access', Icons.dashboard),
                  const SizedBox(height: 16),
                  _buildNavigationGrid(context),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.burgundy700,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.security,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'Kitchen Safety',
            style: TextStyle(
              color: Color(0xFF2D3748),
              fontSize: 20,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: _fetchCounts,
          icon: Icon(
            Icons.refresh_rounded,
            color: AppColors.burgundy700,
            size: 24,
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildWelcomeHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dashboard Overview',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF2D3748),
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Monitor your kitchen safety in real-time',
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.burgundy700.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: AppColors.burgundy700,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF2D3748),
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildSystemStatusCard(SystemStatus status) {
    Color statusColor;
    String statusText;
    IconData statusIcon;
    String statusDescription;

    switch (status) {
      case SystemStatus.safe:
        statusColor = AppColors.success;
        statusText = 'All Systems Safe';
        statusIcon = Icons.verified_rounded;
        statusDescription = 'All sensors are operating normally';
        break;
      case SystemStatus.warning:
        statusColor = AppColors.warning;
        statusText = 'Warning Detected';
        statusIcon = Icons.warning_rounded;
        statusDescription = 'Some parameters require attention';
        break;
      case SystemStatus.danger:
        statusColor = AppColors.danger;
        statusText = 'Danger Alert!';
        statusIcon = Icons.error_rounded;
        statusDescription = 'Immediate action required';
        break;
    }

    final telemetry = getTelemetryString(activeSensorTypes);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            statusColor,
            statusColor.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 2,
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background pattern
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
              ),
              child: CustomPaint(
                painter: _PatternPainter(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    statusIcon,
                    size: 36,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  statusText,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  statusDescription,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.white.withOpacity(0.9),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 15,
                        color: Colors.white.withOpacity(0.9),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Updated ${DateTime.now().toString().substring(11, 16)}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.9),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (telemetry.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      telemetry,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.95),
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Total Sensors',
            mqttService.sensorCount.toString(),
            Icons.sensors_rounded,
            AppColors.burgundy700,
            'Connected devices',
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Active Alerts',
            mqttService.alertCount.toString(),
            Icons.notifications_active_rounded,
            AppColors.danger,
            'Notifications',
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color, String subtitle) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
            spreadRadius: 2,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 22, color: color),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.trending_up_rounded,
                    size: 15,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: color,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF2D3748),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationGrid(BuildContext context) {
    final liveSubtitle = getLiveSubtitle(activeSensorTypes);

    final navigationItems = [
      _NavigationItem(
        title: 'Add Sensor',
        subtitle: 'Connect new IoT sensors',
        icon: Icons.add_circle_rounded,
        gradient: [AppColors.burgundy700, AppColors.burgundy600],
        onTap: () async {
          final result = await Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const AddSensorPage()),
          );
          if (result == true) await _fetchCounts();
        },
      ),
      _NavigationItem(
        title: 'My Sensors',
        subtitle: 'Manage connected sensors',
        icon: Icons.devices_rounded,
        gradient: [AppColors.burgundy600, AppColors.burgundy500],
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const ViewSensorsPage()),
          );
          await _fetchCounts();
        },
      ),
      _NavigationItem(
        title: 'Live Status',
        subtitle: liveSubtitle.isEmpty ? 'No sensors' : liveSubtitle,
        icon: Icons.monitor_heart_rounded,
        gradient: [AppColors.burgundy500, AppColors.burgundy700],
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const LiveStatusScreen()),
          );
          await _fetchCounts();
        },
      ),
      _NavigationItem(
        title: 'Alert Settings',
        subtitle: 'Configure notifications',
        icon: Icons.notifications_rounded,
        gradient: [AppColors.burgundy700, AppColors.burgundy600],
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const AlertsPage()),
          );
          await _fetchCounts();
        },
      ),
      _NavigationItem(
        title: 'Sensor Logs',
        subtitle: 'View historical data',
        icon: Icons.history_rounded,
        gradient: [AppColors.burgundy600, AppColors.burgundy500],
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const SensorLogsScreen()),
          );
        },
      ),
      _NavigationItem(
        title: 'Delete Sensor',
        subtitle: 'Remove a sensor',
        icon: Icons.delete_rounded,
        gradient: [AppColors.burgundy500, AppColors.danger],
        onTap: () async {
          final result = await Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const DeleteSensorPage()),
          );
          if (result == true) await _fetchCounts();
        },
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final spacing = 12.0;
        final itemWidth = (availableWidth - spacing) / 2;

        final itemHeight = itemWidth * 0.8;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: itemWidth / itemHeight,
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
          ),
          itemCount: navigationItems.length,
          itemBuilder: (context, index) {
            final item = navigationItems[index];

            return TweenAnimationBuilder<double>(
              duration: Duration(milliseconds: 300 + (index * 100)),
              tween: Tween(begin: 0.0, end: 1.0),
              builder: (context, value, child) {
                return Transform.translate(
                  offset: Offset(0, 20 * (1 - value)),
                  child: Opacity(
                    opacity: value,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: item.gradient,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: item.gradient.first.withOpacity(0.25),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          onTap: item.onTap,
                          borderRadius: BorderRadius.circular(16),
                          splashColor: Colors.white.withOpacity(0.2),
                          highlightColor: Colors.white.withOpacity(0.1),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: CustomPaint(
                                      painter: _GridPatternPainter(),
                                    ),
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        item.icon,
                                        size: 20,
                                        color: Colors.white,
                                      ),
                                    ),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                            Text(
                                              item.title,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.white,
                                                letterSpacing: -0.3,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              item.subtitle,
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.white
                                                    .withOpacity(0.9),
                                                fontWeight: FontWeight.w500,
                                                height: 1.2,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _NavigationItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradient;
  final VoidCallback onTap;

  _NavigationItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });
}

class _PatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..strokeWidth = 1;

    final path = Path();

    for (int i = 0; i < 5; i++) {
      final y = size.height * (i / 5);
      path.moveTo(0, y);
      path.lineTo(size.width, y);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GridPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..strokeWidth = 0.5;

    for (int i = 0; i < 4; i++) {
      final x = size.width * (i / 4);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);

      final y = size.height * (i / 4);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
