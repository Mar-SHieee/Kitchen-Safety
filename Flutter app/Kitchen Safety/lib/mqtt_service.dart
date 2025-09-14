import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'app_models.dart';

class MqttService {
  static MqttService? _instance;
  static MqttService get instance {
    _instance ??= MqttService._internal();
    return _instance!;
  }

  MqttService._internal();

  factory MqttService({void Function(Map<String, String>)? onUpdate}) {
    final instance = MqttService.instance;
    if (onUpdate != null) {
      instance.onUpdate = onUpdate;
    }
    return instance;
  }

  late MqttServerClient client;
  Map<SensorType, bool> sensorDanger = {
    for (var t in SensorType.values) t: false
  };
  SystemStatus systemStatus = SystemStatus.safe;
  int sensorCount = 0;
  int alertCount = 0;

  void Function(Map<String, String>)? onUpdate;

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  final List<void Function(Map<String, String>)> _updateCallbacks = [];

  void addUpdateCallback(void Function(Map<String, String>) callback) {
    if (!_updateCallbacks.contains(callback)) {
      _updateCallbacks.add(callback);
    }
  }

  void removeUpdateCallback(void Function(Map<String, String>) callback) {
    _updateCallbacks.remove(callback);
  }

  void _notifyCallbacks(Map<String, String> data) {
    for (var callback in _updateCallbacks) {
      try {
        callback(data);
      } catch (e) {
        debugPrint('Error in callback: $e');
      }
    }

    if (onUpdate != null) {
      try {
        onUpdate!(data);
      } catch (e) {
        debugPrint('Error in main callback: $e');
      }
    }
  }

  Future<void> connect() async {
    if (_isConnected &&
        client.connectionStatus?.state == MqttConnectionState.connected) {
      debugPrint('MQTT already connected');
      return;
    }

    client = MqttServerClient(
      'f397af5cc99248cda55980326253181b.s1.eu.hivemq.cloud',
      'flutter_dashboard_${DateTime.now().millisecondsSinceEpoch}',
    );

    client.port = 8883;
    client.secure = true;
    client.logging(on: false);

    client.onConnected = () {
      debugPrint('MQTT Connected successfully');
      _isConnected = true;
    };

    client.onDisconnected = () {
      debugPrint('MQTT Disconnected');
      _isConnected = false;
    };

    final connMessage = MqttConnectMessage()
        .withClientIdentifier(
            'flutter_dashboard_${DateTime.now().millisecondsSinceEpoch}')
        .authenticateAs('Mar_Shieee', 'Marammarshiemaram2005')
        .startClean();
    client.connectionMessage = connMessage;

    try {
      await client.connect();
      if (client.connectionStatus?.state == MqttConnectionState.connected) {
        _isConnected = true;
        _subscribeToTopics();
      }
    } catch (e) {
      debugPrint('MQTT connect failed: $e');
      _isConnected = false;
      client.disconnect();
      rethrow;
    }
  }

  void disconnect() {
    if (_updateCallbacks.isEmpty && onUpdate == null) {
      try {
        if (_isConnected) {
          client.disconnect();
          _isConnected = false;
          debugPrint('MQTT disconnected - no active listeners');
        }
      } catch (e) {
        debugPrint('MQTT disconnect failed: $e');
      }
    } else {
      debugPrint(
          'MQTT service still in use by ${_updateCallbacks.length} listeners');
    }
  }

  void forceDisconnect() {
    try {
      _updateCallbacks.clear();
      onUpdate = null;
      if (_isConnected) {
        client.disconnect();
        _isConnected = false;
        debugPrint('MQTT force disconnected');
      }
    } catch (e) {
      debugPrint('Error force disconnecting MQTT: $e');
    }
  }

  void _subscribeToTopics() {
    const topics = ['sensors/data', 'led', 'buzzer', 'servo'];
    for (var topic in topics) {
      client.subscribe(topic, MqttQos.atMostOnce);
    }
    debugPrint('Subscribed to MQTT topics: $topics');

    client.updates?.listen((List<MqttReceivedMessage<MqttMessage>> messages) {
      if (messages.isEmpty) return;
      final recMsg = messages[0].payload as MqttPublishMessage;
      final payload =
          MqttPublishPayload.bytesToStringAsString(recMsg.payload.message);
      final topic = messages[0].topic;

      try {
        if (topic == 'sensors/data') {
          final parsed = jsonDecode(payload);
          if (parsed is Map<String, dynamic>) {
            sensorValues['temp'] = parsed['temp']?.toString() ??
                parsed['temperature']?.toString() ??
                sensorValues['temp']!;
            sensorValues['humidity'] = parsed['hum']?.toString() ??
                parsed['humidity']?.toString() ??
                sensorValues['humidity']!;
            sensorValues['gas'] =
                parsed['gas']?.toString() ?? sensorValues['gas']!;
            sensorValues['flame'] =
                parsed['flame']?.toString() ?? sensorValues['flame']!;
            sensorValues['status'] =
                parsed['status']?.toString() ?? sensorValues['status']!;
            debugPrint('Parsed MQTT payload: $sensorValues');
          }
        } else if (topic == 'led' || topic == 'buzzer' || topic == 'servo') {
          sensorValues[topic] = payload.trim();
        }

        evaluateThresholdsAndAct(activeSensorTypes);

        _notifyCallbacks(sensorValues);
      } catch (e) {
        debugPrint('MQTT payload parse error on topic $topic: $e');
      }
    });
  }

  void evaluateThresholdsAndAct(Set<SensorType> activeSensorTypes) {
    final gasVal = parseDoubleSafe(sensorValues['gas']);
    final flameVal = parseDoubleSafe(sensorValues['flame']);
    final tempVal = parseDoubleSafe(sensorValues['temp']);
    final humVal = parseDoubleSafe(sensorValues['humidity']);

    final gasDanger = activeSensorTypes.contains(SensorType.gas) &&
        gasVal > (thresholds[SensorType.gas] ?? double.infinity);

    final flameDanger = activeSensorTypes.contains(SensorType.flame) &&
        flameVal < (thresholds[SensorType.flame] ?? double.negativeInfinity);

    final tempDanger = activeSensorTypes.contains(SensorType.temperature) &&
        tempVal > (thresholds[SensorType.temperature] ?? double.infinity);

    final humDanger = activeSensorTypes.contains(SensorType.humidity) &&
        humVal > (thresholds[SensorType.humidity] ?? double.infinity);

    sensorDanger[SensorType.gas] = gasDanger;
    sensorDanger[SensorType.flame] = flameDanger;
    sensorDanger[SensorType.temperature] = tempDanger;
    sensorDanger[SensorType.humidity] = humDanger;

    alertCount = sensorDanger.values.where((v) => v).length;

    final int buzzer =
        int.tryParse(sensorValues['buzzer']?.toString() ?? '0') ?? 0;
    final int led = int.tryParse(sensorValues['led']?.toString() ?? '0') ?? 0;
    final double servo = parseDoubleSafe(sensorValues['servo']);

    systemStatus = (gasDanger ||
            flameDanger ||
            tempDanger ||
            humDanger ||
            buzzer == 1 ||
            led == 1 ||
            servo == 90 ||
            servo == 180)
        ? SystemStatus.danger
        : SystemStatus.safe;

    sensorValues['status'] = systemStatus.toString().split('.').last;
  }

  void publishActuator(String topic, String message) {
    try {
      if (!_isConnected ||
          client.connectionStatus?.state != MqttConnectionState.connected) {
        debugPrint('Cannot publish: MQTT not connected');
        throw Exception('MQTT not connected');
      }
      final builder = MqttClientPayloadBuilder();
      builder.addString(message);
      client.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
      debugPrint('Published to $topic: $message');
    } catch (e) {
      debugPrint('Error publishing to $topic: $e');
      rethrow;
    }
  }

  double parseDoubleSafe(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) {
      final cleaned = value.replaceAll(RegExp(r'[^0-9\.\-]'), '');
      return double.tryParse(cleaned) ?? 0.0;
    }
    return 0.0;
  }
}
