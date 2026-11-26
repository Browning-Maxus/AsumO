import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'constants.dart';
import 'device_store.dart';

class Pairing extends StatelessWidget {
  const Pairing({super.key});

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Container(color: AppColors.background),
      Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: SizedBox(
            width: 72,
            height: 72,
            child: ElevatedButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => const PairingScanDialog(),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.fab,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 32),
            ),
          ),
        ),
      ),
    ],
  );
}

class PairingScanDialog extends ConsumerStatefulWidget {
  const PairingScanDialog({super.key});
  @override
  ConsumerState<PairingScanDialog> createState() => _PairingScanDialogState();
}

class _PairingScanDialogState extends ConsumerState<PairingScanDialog> {
  bool _isScanning = true;
  bool _isSending = false;
  List<ScanResult> _candidates = [];
  StreamSubscription? _resultsSubscription;
  StreamSubscription? _scanningSubscription;

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  @override
  void dispose() {
    _resultsSubscription?.cancel();
    _scanningSubscription?.cancel();
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  Future<void> _startScan() async {
    try {
      if (!await _isBluetoothReady()) return;
      _listenToScan();
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 8));
    } catch (error) {
      _showErrorAndClose('スキャン開始エラー: $error');
    }
  }

  Future<bool> _isBluetoothReady() async {
    if (!await FlutterBluePlus.isSupported) {
      _showErrorAndClose('このデバイスはBLE非対応です');
      return false;
    }
    if (await FlutterBluePlus.adapterState.first != BluetoothAdapterState.on) {
      _showErrorAndClose('BLEを有効にしてください');
      return false;
    }
    return true;
  }

  void _listenToScan() {
    _scanningSubscription = FlutterBluePlus.isScanning.listen((value) {
      if (mounted) setState(() => _isScanning = value);
    });
    _resultsSubscription = FlutterBluePlus.scanResults.listen((results) {
      if (mounted) setState(() => _candidates = _filterCandidates(results));
    }, onError: (Object error) => _showError('スキャンエラー: $error'));
  }

  List<ScanResult> _filterCandidates(List<ScanResult> results) => results
      .where(
        (result) => result.advertisementData.serviceUuids.any(
          (uuid) => uuid.str.toLowerCase() == ASUMO_SERVICE_UUID.toLowerCase(),
        ),
      )
      .toList();

  Future<void> _registerDevice(ScanResult result) async {
    if (_isSending) return;
    setState(() => _isSending = true);
    final name = _deviceName(result);
    try {
      await _writeDeviceInfo(result.device, name);
      _saveDevice(result, name);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) setState(() => _isSending = false);
      _showError('登録エラー: $error');
    }
  }

  Future<void> _writeDeviceInfo(BluetoothDevice device, String name) async {
    var connected = false;
    try {
      await device.connect(
        license: License.nonprofit,
        timeout: const Duration(seconds: 5),
      );
      connected = true;
      final characteristic = await _targetCharacteristic(device);
      if (characteristic == null) throw Exception('対象のCharacteristicが見つかりません');
      await characteristic.write(
        utf8.encode(
          jsonEncode({'device_name': name, 'service_uuid': ASUMO_SERVICE_UUID}),
        ),
      );
    } finally {
      if (connected) await device.disconnect().catchError((_) {});
    }
  }

  Future<BluetoothCharacteristic?> _targetCharacteristic(
    BluetoothDevice device,
  ) async {
    final services = await device.discoverServices();
    for (final service in services) {
      if (service.uuid.str.toLowerCase() != ASUMO_SERVICE_UUID.toLowerCase()) {
        continue;
      }
      for (final characteristic in service.characteristics) {
      if (characteristic.uuid.str.toLowerCase() ==
          ASUMO_CHARACTERISTIC_UUID.toLowerCase()) {
          return characteristic;
      }
      }
    }
    return null;
  }

  void _saveDevice(ScanResult result, String name) {
    final timestamp = DateTime.now().toIso8601String();
    ref
        .read(deviceListProvider.notifier)
        .addDevice(
          DeviceData(
            serviceUuid: ASUMO_SERVICE_UUID,
            id: result.device.remoteId.str,
            deviceName: name,
            battery: '100',
            icon: 'AsumoLogoMark.svg',
            timestamp: timestamp,
            reservation: const [],
            rawJson: _registrationPayload(result, name, timestamp),
          ),
        );
  }

  void _showErrorAndClose(String message) {
    _showError(message);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) => _PairingDialog(
    isScanning: _isScanning,
    candidates: _candidates,
    isSending: _isSending,
    onSelected: _registerDevice,
  );
}

String _deviceName(ScanResult result) => result.device.platformName.isNotEmpty
    ? result.device.platformName
    : result.advertisementData.advName;

Map<String, dynamic> _registrationPayload(
  ScanResult result,
  String name,
  String timestamp,
) => {
  'id': result.device.remoteId.str,
  'name': name,
  'service_uuid': ASUMO_SERVICE_UUID,
  'advertisement': {
    'serviceUuids': result.advertisementData.serviceUuids
        .map((uuid) => uuid.str)
        .toList(),
    'manufacturerData': result.advertisementData.manufacturerData.map(
      (id, bytes) => MapEntry(id.toString(), bytes.toList()),
    ),
    'serviceData': result.advertisementData.serviceData.map(
      (uuid, bytes) => MapEntry(uuid.toString(), bytes.toList()),
    ),
    'localName': result.advertisementData.advName,
    'txPowerLevel': result.advertisementData.txPowerLevel,
  },
  'battery': 100,
  'reservation': <Map<String, dynamic>>[],
  'timestamp': timestamp,
};

class _PairingDialog extends StatelessWidget {
  final bool isScanning;
  final List<ScanResult> candidates;
  final bool isSending;
  final ValueChanged<ScanResult> onSelected;
  const _PairingDialog({
    required this.isScanning,
    required this.candidates,
    required this.isSending,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
    backgroundColor: AppColors.background,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    child: SizedBox(
      height: 400,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Bluetooth ペアリング',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(child: _body(context)),
          ],
        ),
      ),
    ),
  );

  Widget _body(BuildContext context) {
    if (isScanning) return const _ScanningState();
    if (candidates.isEmpty) return const _EmptyScanState();
    return _CandidateList(
      candidates: candidates,
      isSending: isSending,
      onSelected: onSelected,
    );
  }
}

class _ScanningState extends StatelessWidget {
  const _ScanningState();
  @override
  Widget build(BuildContext context) => const Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularProgressIndicator(),
        SizedBox(height: 20),
        Text('デバイスを検索しています…', style: TextStyle(color: Colors.white70)),
      ],
    ),
  );
}

class _EmptyScanState extends StatelessWidget {
  const _EmptyScanState();
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'AsumO 対応デバイスが見つかりませんでした。',
          style: TextStyle(color: Colors.white70),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.fab),
          child: const Text('閉じる'),
        ),
      ],
    ),
  );
}

class _CandidateList extends StatelessWidget {
  final List<ScanResult> candidates;
  final bool isSending;
  final ValueChanged<ScanResult> onSelected;
  const _CandidateList({
    required this.candidates,
    required this.isSending,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(
        child: ListView.separated(
          itemCount: candidates.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (_, index) {
            final result = candidates[index];
            return _CandidateTile(
              name: _deviceName(result),
              rssi: result.rssi,
              isLoading: isSending,
              onPressed: isSending ? null : () => onSelected(result),
            );
          },
        ),
      ),
      const SizedBox(height: 12),
      const Text(
        'タップしてデバイスを登録します。',
        style: TextStyle(color: Colors.white70, fontSize: 12),
        textAlign: TextAlign.center,
      ),
    ],
  );
}

class _CandidateTile extends StatelessWidget {
  final String name;
  final int rssi;
  final bool isLoading;
  final VoidCallback? onPressed;
  const _CandidateTile({
    required this.name,
    required this.rssi,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.itemBackground,
    child: InkWell(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.itemFrame),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'RSSI: $rssi dBm',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (isLoading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              const Icon(Icons.chevron_right, color: Colors.white),
          ],
        ),
      ),
    ),
  );
}
