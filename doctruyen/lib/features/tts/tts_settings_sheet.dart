import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/data_providers.dart';
import '../../services/tts_audio_handler.dart';
import '../settings/settings_provider.dart';

/// Báo máy chưa có giọng tiếng Việt, kèm nút mở cài đặt TTS của Android.
Future<void> showNoVoiceDialog(BuildContext context, WidgetRef ref) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Chưa có giọng đọc tiếng Việt'),
      content: const Text(
        'Máy chưa cài giọng đọc tiếng Việt (vi-VN). Hãy mở cài đặt '
        'Chuyển văn bản thành giọng nói, chọn bộ máy (ví dụ Google) rồi tải '
        'dữ liệu giọng tiếng Việt.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Đóng'),
        ),
        FilledButton(
          onPressed: () async {
            final ok = await ref.read(systemChannelProvider).openTtsSettings();
            if (ctx.mounted) Navigator.pop(ctx);
            if (!ok && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Không mở được cài đặt. Vào Cài đặt > Ngôn ngữ > Chuyển văn bản thành giọng nói.',
                  ),
                ),
              );
            }
          },
          child: const Text('Mở cài đặt TTS'),
        ),
      ],
    ),
  );
}

Future<void> showTtsSettingsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _TtsSettingsSheet(),
  );
}

class _TtsSettingsSheet extends ConsumerStatefulWidget {
  const _TtsSettingsSheet();

  @override
  ConsumerState<_TtsSettingsSheet> createState() => _TtsSettingsSheetState();
}

class _TtsSettingsSheetState extends ConsumerState<_TtsSettingsSheet> {
  List<TtsVoice>? _voices;
  List<String>? _engines;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final h = ref.read(ttsHandlerProvider);
    try {
      final voices = await h.vietnameseVoices();
      final engines = await h.engines();
      if (mounted) {
        setState(() {
          _voices = voices;
          _engines = engines;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final handler = ref.read(ttsHandlerProvider);
    final voices = _voices ?? const <TtsVoice>[];
    final engines = _engines ?? const <String>[];

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Giọng đọc', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Text('Tốc độ: ${s.ttsSpeed.toStringAsFixed(1)}x'),
            Slider(
              value: s.ttsSpeed,
              min: 0.5,
              max: 2.0,
              divisions: 15,
              onChanged: (v) {
                final r = (v * 10).round() / 10;
                notifier.update(s.copyWith(ttsSpeed: r));
              },
              onChangeEnd: (v) => handler.changeSpeed((v * 10).round() / 10),
            ),
            Text('Cao độ: ${s.ttsPitch.toStringAsFixed(1)}'),
            Slider(
              value: s.ttsPitch,
              min: 0.5,
              max: 2.0,
              divisions: 15,
              onChanged: (v) =>
                  notifier.update(s.copyWith(ttsPitch: (v * 10).round() / 10)),
              onChangeEnd: (v) => handler.changePitch((v * 10).round() / 10),
            ),
            const SizedBox(height: 8),
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(),
                ),
              )
            else ...[
              if (engines.length > 1) ...[
                const Text('Bộ máy TTS'),
                DropdownButton<String>(
                  isExpanded: true,
                  value: engines.contains(s.ttsEngine) ? s.ttsEngine : null,
                  hint: const Text('Mặc định hệ thống'),
                  items: [
                    for (final e in engines)
                      DropdownMenuItem(
                        value: e,
                        child: Text(e, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (v) async {
                    if (v == null) return;
                    notifier.update(s.copyWith(ttsEngine: v));
                    handler.configure(engine: v);
                    final fresh = await handler.vietnameseVoices();
                    if (mounted) setState(() => _voices = fresh);
                  },
                ),
                const SizedBox(height: 8),
              ],
              const Text('Giọng tiếng Việt'),
              if (voices.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Không thấy giọng tiếng Việt riêng nào. Nếu nghe không ra tiếng, hãy cài giọng tiếng Việt trong cài đặt TTS của Android.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                )
              else
                DropdownButton<String>(
                  isExpanded: true,
                  value: voices.any((v) => v.name == s.ttsVoiceName)
                      ? s.ttsVoiceName
                      : null,
                  hint: const Text('Mặc định của bộ máy'),
                  items: [
                    for (final v in voices)
                      DropdownMenuItem(
                        value: v.name,
                        child: Text(
                          '${v.name} (${v.locale})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (name) {
                    if (name == null) return;
                    final v = voices.firstWhere((e) => e.name == name);
                    notifier.update(
                      s.copyWith(
                        ttsVoiceName: v.name,
                        ttsVoiceLocale: v.locale,
                      ),
                    );
                    handler.configure(voiceName: v.name, voiceLocale: v.locale);
                  },
                ),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () =>
                  ref.read(systemChannelProvider).openTtsSettings(),
              icon: const Icon(Icons.settings_voice_outlined),
              label: const Text('Mở cài đặt TTS của Android'),
            ),
          ],
        ),
      ),
    );
  }
}
