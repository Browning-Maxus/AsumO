import 'package:asumo/device_setting.dart';
import 'package:asumo/device_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('PushBot displays its dedicated controls', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: DeviceSetting(
            device: DeviceData(
              serviceUuid: 'service',
              id: 'id',
              deviceName: 'PushBot Coffee',
              battery: '100',
              icon: '',
              timestamp: '',
              reservation: const [],
              rawJson: const {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('動作'), findsOneWidget);
    expect(find.text('通常'), findsOneWidget);
    expect(find.text('押す'), findsOneWidget);
    expect(find.text('予約'), findsOneWidget);
  });
}
