import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

final deviceListProvider = AsyncNotifierProvider<DeviceListNotifier, List<DeviceData>>(DeviceListNotifier.new,);

class DeviceData {
  final String serviceUuid;
  final String id;
  final String deviceName;
  final String battery;
  final String icon;
  final String timestamp;
  final dynamic reservation;
  final Map<String, dynamic> rawJson;

  DeviceData({
    required this.serviceUuid,
    required this.id,
    required this.deviceName,
    required this.battery,
    required this.icon,
    required this.timestamp,
    required this.reservation,
    required this.rawJson,
  });

  String get assetPath {
    return icon.isNotEmpty ? 'images/$icon' : 'images/AsumoLogoMark.svg';
  }

  Map<String, dynamic> toJson() {
    return {
      'service_uuid': serviceUuid,
      'id': id,
      'name': deviceName,
      'battery': int.tryParse(battery) ?? battery,
      'timestamp': timestamp,
      'reservation': reservation is List ? reservation : <dynamic>[],
      if (icon.isNotEmpty) 'icon': icon,
    };
  }

  DeviceData copyWith({
    String? serviceUuid,
    String? id,
    String? deviceName,
    String? battery,
    String? icon,
    String? timestamp,
    dynamic reservation,
    Map<String, dynamic>? rawJson,
  }) {
    return DeviceData(
      serviceUuid: serviceUuid ?? this.serviceUuid,
      id: id ?? this.id,
      deviceName: deviceName ?? this.deviceName,
      battery: battery ?? this.battery,
      icon: icon ?? this.icon,
      timestamp: timestamp ?? this.timestamp,
      reservation: reservation ?? this.reservation,
      rawJson: rawJson ?? this.rawJson,
    );
  }

  factory DeviceData.fromJson(Map<String, dynamic> json) {
    final normalized = json.map(
      (key, value) =>
          MapEntry(key.toString().toLowerCase(), _readDynamoValue(value)),
    );
    return DeviceData(
      serviceUuid: normalized['service_uuid']?.toString() ?? '',
      id: normalized['id']?.toString() ?? '',
      deviceName:
          normalized['name']?.toString() ??
          normalized['device_name']?.toString() ??
          normalized['device']?.toString() ??
          '',
      battery: normalized['battery']?.toString() ?? '',
      icon: normalized['icon']?.toString() ?? 'AsumoLogoMark.svg',
      timestamp: normalized['timestamp']?.toString() ?? '',
      reservation: normalized['reservation'],
      rawJson: json,
    );
  }
}

dynamic _readDynamoValue(dynamic value) {
  if (value is Map<String, dynamic> && value.length == 1) {
    if (value.containsKey('S')) return value['S'];
    if (value.containsKey('N')) return value['N'];
    if (value.containsKey('BOOL')) return value['BOOL'];
    if (value.containsKey('NULL')) return null;
    if (value.containsKey('L')) {
      final list = value['L'];
      return list is List ? list.map(_readDynamoValue).toList() : list;
    }
    if (value.containsKey('M')) {
      final map = value['M'];
      if (map is Map<String, dynamic>) {
        return map.map((key, entry) => MapEntry(key, _readDynamoValue(entry)));
      }
      return map;
    }
  }
  return value;
}

class DeviceListNotifier extends AsyncNotifier<List<DeviceData>> {
  final String kApiEndpoint = dotenv.env['API_ENDPOINT'] ?? '';

  @override
  Future<List<DeviceData>> build() async {
    return _fetchDevices();
  }

  Future<List<DeviceData>> _fetchDevices() async {
    if (kApiEndpoint.isEmpty) {
      return [];
    }

    final response = await http
        .get(Uri.parse(kApiEndpoint))
        .timeout(const Duration(seconds: 15));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return [];
    }

    final decoded = jsonDecode(response.body);
    final List<dynamic> listData;

    if (decoded is List) {
      listData = decoded;
    } else if (decoded is Map<String, dynamic>) {
      if (decoded['devices'] is List) {
        listData = decoded['devices'] as List<dynamic>;
      } else if (decoded['Items'] is List) {
        listData = decoded['Items'] as List<dynamic>;
      } else if (decoded['items'] is List) {
        listData = decoded['items'] as List<dynamic>;
      } else {
        listData = [decoded];
      }
    } else {
      listData = [];
    }

    return listData
        .whereType<Map<String, dynamic>>()
        .map(
          (element) => DeviceData.fromJson(Map<String, dynamic>.from(element)),
        )
        .toList();
  }

  void addDevice(DeviceData device) {
    final current = state.asData?.value ?? [];
    state = AsyncData(List<DeviceData>.from(current)..add(device));
  }

  void updateDevice(DeviceData device) {
    final current = state.asData?.value ?? [];
    state = AsyncData([
      for (final item in current)
        if (_isSameDevice(item, device)) device else item,
    ]);
  }

  Future<void> postDevices() async {
    if (kApiEndpoint.isEmpty) {
      return;
    }

    final file = await createDevicesJsonFile();
    if (file == null) {
      return;
    }
    final body = await file.readAsString();

    await http
        .post(
          Uri.parse(kApiEndpoint),
          headers: {'Content-Type': 'application/json'},
          body: body,
        )
        .timeout(const Duration(seconds: 10));
  }

  Future<File?> createDevicesJsonFile() async {
    final devices = state.asData?.value;
    if (devices == null) {
      return null;
    }

    final payload = {
      'devices': devices.map((device) => device.toJson()).toList(),
    };
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/asumo_devices.json');
    return file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(payload),
    );
  }
}

bool _isSameDevice(DeviceData a, DeviceData b) {
  if (a.id.isNotEmpty && b.id.isNotEmpty) {
    return a.id == b.id && a.serviceUuid == b.serviceUuid;
  }
  return identical(a, b);
}
