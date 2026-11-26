import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'constants.dart';
import 'device_setting.dart';
import 'device_store.dart';

class Devices extends ConsumerWidget {
  const Devices({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncDevices = ref.watch(deviceListProvider);

    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: asyncDevices.when(
        data: (items) {
          if (items.isEmpty) {
            return const SizedBox.shrink();
          }
          return GridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            children: items.map((item) => _Tile(item: item)).toList(),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const SizedBox.shrink(),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final DeviceData item;
  const _Tile({required this.item});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => DeviceSetting(device: item)),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.itemBackground,
          border: Border.all(color: AppColors.itemFrame),
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _SvgDeviceIcon(assetPath: item.assetPath),
            const SizedBox(height: 12),
            Text(item.deviceName, style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 8),
            Text(
              item.battery,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

class _SvgDeviceIcon extends StatelessWidget {
  final String assetPath;

  const _SvgDeviceIcon({required this.assetPath});

  Future<bool> _assetExists(String path) async {
    try {
      await rootBundle.load(path);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _assetExists(assetPath),
      builder: (context, snapshot) {
        final assetToUse = (snapshot.data == true)
            ? assetPath
            : 'images/AsumoLogoMark.svg';
        return SvgPicture.asset(
          assetToUse,
          width: 48,
          height: 48,
          placeholderBuilder: (context) => const SizedBox(
            width: 48,
            height: 48,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        );
      },
    );
  }
}
