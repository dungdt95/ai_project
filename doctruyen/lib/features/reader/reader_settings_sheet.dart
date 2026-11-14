import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/models/reading_settings.dart';
import '../settings/settings_provider.dart';

Future<void> showReaderSettingsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _ReaderSettingsSheet(),
  );
}

class _ReaderSettingsSheet extends ConsumerWidget {
  const _ReaderSettingsSheet();

  static const Map<ReaderThemeId, String> _themeNames = {
    ReaderThemeId.light: 'Sáng',
    ReaderThemeId.dark: 'Tối',
    ReaderThemeId.sepia: 'Sepia',
    ReaderThemeId.black: 'Đen',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final n = ref.read(settingsProvider.notifier);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Giao diện đọc',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                for (final t in ReaderThemeId.values)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InkWell(
                        onTap: () => n.update(s.copyWith(theme: t)),
                        child: Container(
                          height: 48,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: ReaderPalette.of(t).background,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              width: s.theme == t ? 3 : 1,
                              color: s.theme == t
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.grey,
                            ),
                          ),
                          child: Text(
                            _themeNames[t]!,
                            style: TextStyle(color: ReaderPalette.of(t).text),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Cỡ chữ: ${s.fontSize.round()}'),
            Slider(
              value: s.fontSize,
              min: ReadingSettings.minFont,
              max: ReadingSettings.maxFont,
              divisions: 20,
              onChanged: (v) =>
                  n.update(s.copyWith(fontSize: v.roundToDouble())),
            ),
            Text('Giãn dòng: ${s.lineHeight.toStringAsFixed(1)}'),
            Slider(
              value: s.lineHeight,
              min: 1.2,
              max: 2.4,
              divisions: 12,
              onChanged: (v) =>
                  n.update(s.copyWith(lineHeight: (v * 10).round() / 10)),
            ),
            Text('Lề: ${s.margin.round()}'),
            Slider(
              value: s.margin,
              min: 8,
              max: 48,
              divisions: 10,
              onChanged: (v) => n.update(s.copyWith(margin: v.roundToDouble())),
            ),
            const Text('Phông chữ'),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              children: [
                for (final f in ReaderFont.values)
                  ChoiceChip(
                    label: Text(f.label),
                    selected: s.font == f,
                    onSelected: (_) => n.update(s.copyWith(font: f)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: false,
                  label: Text('Cuộn dọc'),
                  icon: Icon(Icons.swap_vert),
                ),
                ButtonSegment(
                  value: true,
                  label: Text('Lật trang'),
                  icon: Icon(Icons.auto_stories),
                ),
              ],
              selected: {s.pageMode},
              onSelectionChanged: (v) =>
                  n.update(s.copyWith(pageMode: v.first)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Giữ màn hình sáng'),
              value: s.keepScreenOn,
              onChanged: (v) => n.update(s.copyWith(keepScreenOn: v)),
            ),
          ],
        ),
      ),
    );
  }
}
