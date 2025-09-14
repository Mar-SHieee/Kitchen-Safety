enum SensorType { gas, flame, temperature, humidity }

enum SensorStatus { online, offline }

enum SystemStatus { safe, warning, danger }

enum LogStatus { safe, warning, danger }

extension SensorTypeExtension on SensorType {
  String get name {
    switch (this) {
      case SensorType.gas:
        return 'Gas';
      case SensorType.flame:
        return 'Flame';
      case SensorType.temperature:
        return 'Temperature';
      case SensorType.humidity:
        return 'Humidity';
    }
  }

  String get icon {
    switch (this) {
      case SensorType.gas:
        return '🛢️';
      case SensorType.flame:
        return '🔥';
      case SensorType.temperature:
        return '🌡️';
      case SensorType.humidity:
        return '💧';
    }
  }
}

SensorType stringToSensorType(String s) {
  switch (s.toLowerCase()) {
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
      throw Exception('Unknown sensor type: $s');
  }
}

String sensorTypeToString(SensorType type) {
  switch (type) {
    case SensorType.gas:
      return 'gas';
    case SensorType.flame:
      return 'flame';
    case SensorType.temperature:
      return 'temp';
    case SensorType.humidity:
      return 'humidity';
  }
}

final Map<SensorType, double> thresholds = {
  SensorType.gas: 2000.0,
  SensorType.flame: 1000.0,
  SensorType.temperature: 40.0,
  SensorType.humidity: 80.0,
};

Map<String, String> sensorValues = {
  "temp": "--",
  "humidity": "--",
  "gas": "--",
  "flame": "--",
  "buzzer": "0",
  "led": "0",
  "servo": "0",
  "status": "Safe",
};

final Map<SensorType, bool> sensorDanger = {
  for (var t in SensorType.values) t: false,
};

Set<SensorType> activeSensorTypes = {};

String getTelemetryString(Set<SensorType> activeSensorTypes) {
  final List<String> parts = [];
  for (var type in activeSensorTypes) {
    final key = sensorTypeToString(type);
    final value = sensorValues[key] ?? '--';
    String part;
    switch (type) {
      case SensorType.temperature:
        part = 'T: $value°';
        break;
      case SensorType.humidity:
        part = 'H: $value%';
        break;
      case SensorType.gas:
        part = 'Gas: $value';
        break;
      case SensorType.flame:
        part = 'Flame: $value';
        break;
    }
    parts.add(part);
  }
  final status = sensorValues['status'] ?? 'Unknown';
  parts.add('Status: $status');
  return parts.join('  •  ');
}

String getLiveSubtitle(Set<SensorType> activeSensorTypes) {
  final List<String> parts = [];
  for (var type in activeSensorTypes) {
    final key = sensorTypeToString(type);
    final value = sensorValues[key] ?? '--';
    String part;
    switch (type) {
      case SensorType.temperature:
        part = 'T:$value';
        break;
      case SensorType.humidity:
        part = 'H:$value';
        break;
      case SensorType.gas:
        part = 'G:$value';
        break;
      case SensorType.flame:
        part = 'F:$value';
        break;
    }
    parts.add(part);
  }
  final status = sensorValues['status'] ?? 'Unknown';
  parts.add('S:$status');
  return parts.join(' ');
}

class User {
  final String email;
  final String username;

  User({
    required this.email,
    required this.username,
  });
}

class Sensor {
  final SensorType type;
  final SensorStatus status;
  final String lastUpdate;
  final String? value;

  Sensor({
    required this.type,
    required this.status,
    required this.lastUpdate,
    this.value,
  });

  Sensor copyWith({
    SensorType? type,
    SensorStatus? status,
    String? lastUpdate,
    String? value,
  }) {
    return Sensor(
      type: type ?? this.type,
      status: status ?? this.status,
      lastUpdate: lastUpdate ?? this.lastUpdate,
      value: value ?? this.value,
    );
  }
}

class SensorLog {
  final String id;
  final SensorType sensorType;
  final String value;
  final LogStatus status;
  final DateTime timestamp;
  final double? rawValue;

  SensorLog({
    required this.id,
    required this.sensorType,
    required this.value,
    required this.status,
    required this.timestamp,
    this.rawValue,
  });

  String get sensorTypeName => sensorType.name;
}

class AlertSettings {
  final SensorType sensorType;
  final bool enabled;
  final String threshold;

  AlertSettings({
    required this.sensorType,
    required this.enabled,
    required this.threshold,
  });

  AlertSettings copyWith({
    SensorType? sensorType,
    bool? enabled,
    String? threshold,
  }) {
    return AlertSettings(
      sensorType: sensorType ?? this.sensorType,
      enabled: enabled ?? this.enabled,
      threshold: threshold ?? this.threshold,
    );
  }
}
