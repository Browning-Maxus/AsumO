import 'package:flutter/material.dart';
import 'constants.dart';

class Setting extends StatelessWidget {
  const Setting({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _SettingTile(title: '通知設定', onPressed: () {}),
          const SizedBox(height: 8),
          _SettingTile(title: '自宅位置設定', onPressed: () {}),
        ],
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  final String title;
  final VoidCallback onPressed;
  const _SettingTile({required this.title, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.itemBackground,
      child: InkWell(
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.itemFrame),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 16)),
              const Icon(Icons.chevron_right, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}
