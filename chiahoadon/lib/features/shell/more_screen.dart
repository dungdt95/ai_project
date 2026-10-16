import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../groups/groups_provider.dart';
import '../groups/groups_screen.dart';
import '../home/dev_check_screen.dart';
import '../items/item_presets_provider.dart';
import '../items/item_presets_screen.dart';
import '../members/members_provider.dart';
import '../members/members_screen.dart';
import '../settings/settings_screen.dart';
import '../settlement/settlement_screen.dart';

/// Tab "Khác": lối vào các màn hình quản lý.
class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final members = ref.watch(membersProvider).value;
    final groups = ref.watch(groupsProvider).value;
    final presets = ref.watch(itemPresetsProvider).value;

    return Scaffold(
      appBar: AppBar(title: const Text(AppConstants.appName)),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppTheme.s8),
        children: [
          _Tile(
            icon: Icons.group_outlined,
            title: 'Thành viên',
            subtitle: members == null
                ? null
                : '${members.where((m) => m.isActive).length} người đang hoạt động',
            onTap: () => MembersScreen.push(context),
          ),
          _Tile(
            icon: Icons.groups_outlined,
            title: 'Nhóm',
            subtitle: groups == null ? null : '${groups.length} nhóm',
            onTap: () => GroupsScreen.push(context),
          ),
          _Tile(
            icon: Icons.restaurant_menu_outlined,
            title: 'Món có sẵn',
            subtitle: presets == null
                ? 'Đặt sẵn tên và giá để chọn nhanh'
                : '${presets.length} món',
            onTap: () => ItemPresetsScreen.push(context),
          ),
          const Divider(height: AppTheme.s24),

          _Tile(
            icon: Icons.handshake_outlined,
            title: 'Quyết toán',
            subtitle: 'Ai nợ ai, và cách trả ít giao dịch nhất',
            onTap: () => SettlementScreen.push(context),
          ),
          _Tile(
            icon: Icons.settings_outlined,
            title: 'Cài đặt',
            subtitle: 'Giao diện, làm tròn, sao lưu',
            onTap: () => SettingsScreen.push(context),
          ),

          if (kDebugMode) ...[
            const Divider(height: AppTheme.s24),
            _Tile(
              icon: Icons.bug_report_outlined,
              title: 'Kiểm tra nền tảng',
              subtitle: 'Chỉ hiện ở bản debug',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (context) => const DevCheckScreen(),
                ),
              ),
            ),
          ],

          const SizedBox(height: AppTheme.s24),
          Center(
            child: Text(
              'Dữ liệu chỉ lưu trên máy này.\n'
              'App không truy cập mạng.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ListTile(
      leading: Icon(icon, color: scheme.primary),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
    );
  }
}
