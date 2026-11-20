import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/format.dart';
import '../../data/data_providers.dart';
import '../../domain/tts/sleep_timer.dart';
import 'tts_provider.dart';

Future<void> showSleepTimerSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => const _SleepTimerSheet(),
  );
}

class _SleepTimerSheet extends ConsumerWidget {
  const _SleepTimerSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final handler = ref.read(ttsHandlerProvider);
    final tts = ref.watch(ttsStateProvider).value;

    Widget option(String label, VoidCallback onTap) => ListTile(
      title: Text(label),
      onTap: () {
        onTap();
        Navigator.pop(context);
      },
    );

    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Hẹn giờ tắt', style: Theme.of(context).textTheme.titleLarge),
            if (tts != null && tts.sleepMode != SleepTimerMode.off)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  tts.sleepMode == SleepTimerMode.endOfChapter
                      ? 'Đang hẹn: dừng khi hết chương'
                      : 'Còn lại ${Fmt.clock(tts.sleepRemaining ?? Duration.zero)}',
                ),
              ),
            for (final m in const [15, 30, 45, 60])
              option(
                '$m phút',
                () => handler.startSleepTimer(Duration(minutes: m)),
              ),
            option('Hết chương', handler.startSleepEndOfChapter),
            ListTile(
              title: const Text('Tùy chọn...'),
              onTap: () async {
                Navigator.pop(context);
                final minutes = await _askMinutes(context);
                if (minutes != null && minutes > 0) {
                  handler.startSleepTimer(Duration(minutes: minutes));
                }
              },
            ),
            if (tts != null && tts.sleepMode != SleepTimerMode.off)
              option('Tắt hẹn giờ', handler.cancelSleepTimer),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<int?> _askMinutes(BuildContext context) {
    final controller = TextEditingController(text: '20');
    return showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hẹn giờ tùy chọn'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(suffixText: 'phút'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(ctx, int.tryParse(controller.text.trim())),
            child: const Text('Đặt'),
          ),
        ],
      ),
    );
  }
}
