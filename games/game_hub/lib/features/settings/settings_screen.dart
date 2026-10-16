import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/storage/settings_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key, required this.settings});
  final SettingsService settings;

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late ThemeMode _theme;
  late bool _sound;
  late bool _haptic;
  late String _playerName;
  late String? _locale;

  @override
  void initState() {
    super.initState();
    final s = widget.settings;
    _theme = s.themeMode;
    _sound = s.soundEnabled;
    _haptic = s.hapticEnabled;
    _playerName = s.playerName;
    _locale = s.locale?.languageCode;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cài đặt')),
      body: ListView(
        children: [
          _SectionHeader('Giao diện'),
          ListTile(
            title: const Text('Theme'),
            trailing: DropdownButton<ThemeMode>(
              value: _theme,
              items: const [
                DropdownMenuItem(value: ThemeMode.system, child: Text('Theo hệ thống')),
                DropdownMenuItem(value: ThemeMode.light, child: Text('Sáng')),
                DropdownMenuItem(value: ThemeMode.dark, child: Text('Tối')),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() => _theme = v);
                widget.settings.themeMode = v;
              },
            ),
          ),
          ListTile(
            title: const Text('Ngôn ngữ'),
            trailing: DropdownButton<String?>(
              value: _locale,
              items: const [
                DropdownMenuItem(value: null, child: Text('Theo hệ thống')),
                DropdownMenuItem(value: 'vi', child: Text('Tiếng Việt')),
                DropdownMenuItem(value: 'en', child: Text('English')),
              ],
              onChanged: (v) {
                setState(() => _locale = v);
                widget.settings.locale = v != null ? Locale(v) : null;
              },
            ),
          ),
          _SectionHeader('Âm thanh & phản hồi'),
          SwitchListTile(
            title: const Text('Hiệu ứng âm thanh'),
            value: _sound,
            onChanged: (v) {
              setState(() => _sound = v);
              widget.settings.soundEnabled = v;
            },
          ),
          SwitchListTile(
            title: const Text('Rung phản hồi'),
            value: _haptic,
            onChanged: (v) {
              setState(() => _haptic = v);
              widget.settings.hapticEnabled = v;
            },
          ),
          _SectionHeader('Người chơi'),
          ListTile(
            title: const Text('Tên của bạn'),
            subtitle: Text(_playerName),
            trailing: const Icon(Icons.edit_outlined),
            onTap: () => _editName(context),
          ),
        ],
      ),
    );
  }

  Future<void> _editName(BuildContext context) async {
    final controller = TextEditingController(text: _playerName);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tên của bạn'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Huỷ')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: const Text('Lưu')),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      setState(() => _playerName = result);
      widget.settings.playerName = result;
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(
          text,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
        ),
      );
}
