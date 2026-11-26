import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'constants.dart';
import 'device_store.dart';

class DeviceSetting extends ConsumerStatefulWidget {
  final DeviceData device;
  const DeviceSetting({super.key, required this.device});
  @override
  ConsumerState<DeviceSetting> createState() => _DeviceSettingState();
}

class _DeviceSettingState extends ConsumerState<DeviceSetting> {
  late final List<_Reservation> _reservations;
  String _pressType = 'Normal';
  String _direction = 'Up';
  bool get _isPushBot =>
      widget.device.deviceName.toLowerCase().contains('pushbot');

  @override
  void initState() {
    super.initState();
    _reservations = _parseReservations(widget.device.reservation);
  }

  void _sync() {
    final json = _reservations.map((item) => item.toJson()).toList();
    ref
        .read(deviceListProvider.notifier)
        .updateDevice(
          widget.device.copyWith(
            reservation: json,
            rawJson: {...widget.device.rawJson, 'reservation': json},
          ),
        );
  }

  Future<void> _addReservation() async {
    final item = await showModalBottomSheet<_Reservation>(
      context: context,
      backgroundColor: AppColors.background,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) =>
          _ReservationSheet(action: _pressType, direction: _direction),
    );
    if (item == null || !mounted) return;
    setState(() {
      _reservations.add(item);
      _reservations.sort((a, b) => a.minutes.compareTo(b.minutes));
    });
    _sync();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.device.deviceName.isEmpty
        ? 'デバイス設定'
        : widget.device.deviceName;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.appbar,
        foregroundColor: Colors.white,
        title: Text(title),
      ),
      floatingActionButton: _isPushBot
          ? FloatingActionButton(
              onPressed: _addReservation,
              backgroundColor: AppColors.fab,
              foregroundColor: Colors.white,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
              child: const Icon(Icons.add, size: 32),
            )
          : null,
      body: _isPushBot ? _pushBot() : _GenericSettings(device: widget.device),
    );
  }

  Widget _pushBot() => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(16, 18, 16, 100),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('動作', style: _sectionStyle),
        const SizedBox(height: 12),
        _ChoiceRow(
          values: const ['Normal', 'Hold', 'Double'],
          selected: _pressType,
          onChanged: (v) => setState(() => _pressType = v),
        ),
        const SizedBox(height: 12),
        _ChoiceRow(
          values: const ['UP', 'DOWN'],
          selected: _direction,
          onChanged: (v) => setState(() => _direction = v),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 58,
          child: ElevatedButton.icon(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$_direction・$_pressType押しを実行しました')),
            ),
            icon: const Text('👆', style: TextStyle(fontSize: 21)),
            label: const Text(
              'push',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: AppColors.fab,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Divider(color: AppColors.itemFrame),
        ),
        const Text('予約', style: _sectionStyle),
        const SizedBox(height: 12),
        if (_reservations.isEmpty) const _EmptyReservation(),
        ...List.generate(
          _reservations.length,
          (index) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ReservationTile(
              reservation: _reservations[index],
              onChanged: (enabled) {
                setState(
                  () => _reservations[index] = _reservations[index].copyWith(
                    enabled: enabled,
                  ),
                );
                _sync();
              },
              onDelete: () {
                setState(() => _reservations.removeAt(index));
                _sync();
              },
            ),
          ),
        ),
      ],
    ),
  );
}

const _sectionStyle = TextStyle(
  color: Colors.white,
  fontSize: 18,
  fontWeight: FontWeight.w700,
);

class _ChoiceRow extends StatelessWidget {
  final List<String> values;
  final String selected;
  final ValueChanged<String> onChanged;
  const _ChoiceRow({
    required this.values,
    required this.selected,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) => Row(
    children: values
        .map(
          (value) => Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: value == values.last ? 0 : 8),
              child: Material(
                color: AppColors.itemBackground,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  onTap: () => onChanged(value),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    height: 82,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: selected == value
                            ? AppColors.activeTab
                            : AppColors.itemFrame,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Radio<String>(
                          value: value,
                          groupValue: selected,
                          activeColor: AppColors.activeTab,
                          onChanged: (v) => onChanged(v!),
                        ),
                        Text(
                          value,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        )
        .toList(),
  );
}

class _ReservationTile extends StatelessWidget {
  final _Reservation reservation;
  final ValueChanged<bool> onChanged;
  final VoidCallback onDelete;
  const _ReservationTile({
    required this.reservation,
    required this.onChanged,
    required this.onDelete,
  });
  @override
  Widget build(BuildContext context) => Dismissible(
    key: ValueKey(
      '${reservation.timeLabel}-${reservation.actionType}-${reservation.direction}',
    ),
    direction: DismissDirection.horizontal,
    onDismissed: (_) => onDelete(),
    background: _deleteBackground(Alignment.centerLeft),
    secondaryBackground: _deleteBackground(Alignment.centerRight),
    child: Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      decoration: BoxDecoration(
        color: AppColors.itemBackground,
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
                  reservation.timeLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${reservation.weekdayLabel}・${reservation.direction}・${reservation.actionType}押し',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          Switch(
            value: reservation.enabled,
            activeColor: AppColors.activeTab,
            onChanged: onChanged,
          ),
        ],
      ),
    ),
  );
  Widget _deleteBackground(Alignment alignment) => Container(
    alignment: alignment,
    padding: EdgeInsets.only(
      left: alignment == Alignment.centerLeft ? 20 : 0,
      right: alignment == Alignment.centerRight ? 20 : 0,
    ),
    decoration: BoxDecoration(
      color: Colors.red.shade700,
      borderRadius: BorderRadius.circular(8),
    ),
    child: const Icon(Icons.delete, color: Colors.white),
  );
}

class _EmptyReservation extends StatelessWidget {
  const _EmptyReservation();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppColors.itemBackground,
      border: Border.all(color: AppColors.itemFrame),
      borderRadius: BorderRadius.circular(8),
    ),
    child: const Text(
      '予約はありません',
      textAlign: TextAlign.center,
      style: TextStyle(color: Colors.white70),
    ),
  );
}

class _GenericSettings extends StatelessWidget {
  final DeviceData device;
  const _GenericSettings({required this.device});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.itemBackground,
        border: Border.all(color: AppColors.itemFrame),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        device.id.isEmpty ? 'このデバイス用の設定画面は準備中です。' : 'ID: ${device.id}',
        style: const TextStyle(color: Colors.white),
      ),
    ),
  );
}

class _ReservationSheet extends StatefulWidget {
  final String action;
  final String direction;
  const _ReservationSheet({required this.action, required this.direction});
  @override
  State<_ReservationSheet> createState() => _ReservationSheetState();
}

class _ReservationSheetState extends State<_ReservationSheet> {
  DateTime _dateTime = DateTime(2026, 1, 1);
  final List<bool> _weekdays = List.filled(7, true);
  late String _action = widget.action;
  late String _direction = widget.direction;
  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).viewInsets.bottom + 18,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white30,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 150,
            child: CupertinoTheme(
              data: const CupertinoThemeData(brightness: Brightness.dark),
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.time,
                use24hFormat: true,
                initialDateTime: _dateTime,
                onDateTimeChanged: (v) => _dateTime = v,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(7, (i) {
              const labels = ['日', '月', '火', '水', '木', '金', '土'];
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i == 6 ? 0 : 4),
                  child: Material(
                    color: _weekdays[i]
                        ? AppColors.activeTab
                        : AppColors.itemBackground,
                    borderRadius: BorderRadius.circular(6),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () => setState(() => _weekdays[i] = !_weekdays[i]),
                      child: Container(
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.itemFrame),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          labels[i],
                          maxLines: 1,
                          style: TextStyle(
                            color: _weekdays[i] ? Colors.black : AppColors.text,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'Normal', label: Text('通常')),
              ButtonSegment(value: 'Hold', label: Text('長押し')),
              ButtonSegment(value: 'Double', label: Text('2回押し')),
            ],
            selected: {_action},
            style: ButtonStyle(
              foregroundColor: const WidgetStatePropertyAll(AppColors.text),
              backgroundColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? AppColors.activeTab
                    : Colors.transparent,
              ),
            ),
            onSelectionChanged: (v) => setState(() => _action = v.first),
          ),
          const SizedBox(height: 10),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'UP', label: Text('上')),
              ButtonSegment(value: 'DOWN', label: Text('下')),
            ],
            selected: {_direction},
            style: ButtonStyle(
              foregroundColor: const WidgetStatePropertyAll(AppColors.text),
              backgroundColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? AppColors.activeTab
                    : Colors.transparent,
              ),
            ),
            onSelectionChanged: (v) => setState(() => _direction = v.first),
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: () => Navigator.pop(
                context,
                _Reservation(
                  time: TimeOfDay.fromDateTime(_dateTime),
                  weekdays: List.of(_weekdays),
                  actionType: _action,
                  direction: _direction,
                ),
              ),
              style: FilledButton.styleFrom(backgroundColor: AppColors.fab),
              child: const Text('追加'),
            ),
          ),
        ],
      ),
    ),
  );
}

class _Reservation {
  static const _labels = ['日', '月', '火', '水', '木', '金', '土'];
  final TimeOfDay time;
  final List<bool> weekdays;
  final String actionType;
  final String direction;
  final bool enabled;
  const _Reservation({
    required this.time,
    required this.weekdays,
    this.actionType = 'Normal',
    this.direction = 'UP',
    this.enabled = true,
  });
  int get minutes => time.hour * 60 + time.minute;
  String get timeLabel =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  String get weekdayLabel => List.generate(
    7,
    (i) => i < weekdays.length && weekdays[i] ? _labels[i] : '',
  ).join();
  _Reservation copyWith({bool? enabled}) => _Reservation(
    time: time,
    weekdays: weekdays,
    actionType: actionType,
    direction: direction,
    enabled: enabled ?? this.enabled,
  );
  Map<String, dynamic> toJson() => {
    'time': timeLabel,
    'weekdays': weekdays,
    'action_type': actionType,
    'direction': direction,
    'isReserved': enabled,
  };
  factory _Reservation.fromJson(Map<String, dynamic> json) {
    final parts = (json['time']?.toString() ?? '00:00').split(':');
    final h = int.tryParse(parts.first) ?? 0;
    final m = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    final rawDays = json['weekdays'] ?? json['days'];
    final days = rawDays is List
        ? List.generate(
            7,
            (i) =>
                i < rawDays.length &&
                (rawDays[i] == true ||
                    rawDays[i] == 1 ||
                    rawDays[i].toString().toLowerCase() == 'true'),
          )
        : List.filled(7, true);
    return _Reservation(
      time: TimeOfDay(hour: h.clamp(0, 23), minute: m.clamp(0, 59)),
      weekdays: days,
      actionType:
          json['action_type']?.toString() ??
          json['actionType']?.toString() ??
          'Normal',
      direction: json['direction']?.toString() ?? 'UP',
      enabled: json['isReserved'] is bool
          ? json['isReserved'] as bool
          : json['enabled'] is bool
          ? json['enabled'] as bool
          : true,
    );
  }
}

List<_Reservation> _parseReservations(dynamic data) => data is List
    ? data
          .whereType<Map>()
          .map((e) => _Reservation.fromJson(Map<String, dynamic>.from(e)))
          .toList()
    : const [];
