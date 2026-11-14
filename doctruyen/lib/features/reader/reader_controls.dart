import 'package:flutter/material.dart';

import '../../core/utils/format.dart';
import '../../domain/tts/sleep_timer.dart';
import '../../services/tts_audio_handler.dart';

/// Thanh điều khiển dưới màn đọc: chuyển chương + điều khiển TTS.
class ReaderBottomBar extends StatelessWidget {
  const ReaderBottomBar({
    required this.tts,
    required this.hasPrevious,
    required this.hasNext,
    required this.onPreviousChapter,
    required this.onNextChapter,
    required this.onPlayPause,
    required this.onPreviousSentence,
    required this.onNextSentence,
    required this.onStop,
    required this.onSpeedChanged,
    required this.onSleepTimer,
    required this.onVoiceSettings,
    required this.color,
    required this.textColor,
    super.key,
  });

  /// Trạng thái TTS của truyện đang mở (null nếu đang đọc truyện khác/không phát).
  final TtsUiState? tts;
  final bool hasPrevious;
  final bool hasNext;
  final VoidCallback onPreviousChapter;
  final VoidCallback onNextChapter;
  final VoidCallback onPlayPause;
  final VoidCallback onPreviousSentence;
  final VoidCallback onNextSentence;
  final VoidCallback onStop;
  final ValueChanged<double> onSpeedChanged;
  final VoidCallback onSleepTimer;
  final VoidCallback onVoiceSettings;
  final Color color;
  final Color textColor;

  /// Chiều cao tối đa của thanh (chưa tính vùng an toàn phía dưới) khi đang đọc
  /// TTS: nút điều khiển + thanh tốc độ + thanh tiến trình. Chế độ lật trang
  /// chừa sẵn đúng chừng này để chữ không bao giờ nằm dưới thanh.
  static const double maxContentHeight = 112;

  @override
  Widget build(BuildContext context) {
    final t = tts;
    final active = t != null && t.active;
    final playing = t?.playing ?? false;
    final iconTheme = IconThemeData(color: textColor);
    return Material(
      color: color,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: IconTheme(
          data: iconTheme,
          child: DefaultTextStyle.merge(
            style: TextStyle(color: textColor),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (active && t.loading)
                  const LinearProgressIndicator(minHeight: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      tooltip: 'Chương trước',
                      icon: const Icon(Icons.skip_previous),
                      onPressed: hasPrevious ? onPreviousChapter : null,
                    ),
                    if (active)
                      IconButton(
                        tooltip: 'Câu trước',
                        icon: const Icon(Icons.fast_rewind),
                        onPressed: onPreviousSentence,
                      ),
                    FilledButton.icon(
                      onPressed: onPlayPause,
                      icon: Icon(playing ? Icons.pause : Icons.headphones),
                      label: Text(
                        playing ? 'Tạm dừng' : (active ? 'Tiếp tục' : 'Nghe'),
                      ),
                    ),
                    if (active)
                      IconButton(
                        tooltip: 'Câu sau',
                        icon: const Icon(Icons.fast_forward),
                        onPressed: onNextSentence,
                      ),
                    IconButton(
                      tooltip: 'Chương sau',
                      icon: const Icon(Icons.skip_next),
                      onPressed: hasNext ? onNextChapter : null,
                    ),
                  ],
                ),
                if (active)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 4, 4),
                    child: Row(
                      children: [
                        Text('${t.speed.toStringAsFixed(1)}x'),
                        Expanded(
                          child: Slider(
                            value: t.speed,
                            min: 0.5,
                            max: 2.0,
                            divisions: 15,
                            onChanged: (v) =>
                                onSpeedChanged((v * 10).round() / 10),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: onSleepTimer,
                          icon: Icon(
                            Icons.bedtime_outlined,
                            color: t.sleepMode == SleepTimerMode.off
                                ? textColor
                                : Theme.of(context).colorScheme.primary,
                          ),
                          label: Text(
                            _sleepLabel(t),
                            style: TextStyle(color: textColor),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Giọng đọc',
                          icon: const Icon(Icons.tune),
                          onPressed: onVoiceSettings,
                        ),
                        IconButton(
                          tooltip: 'Dừng đọc',
                          icon: const Icon(Icons.stop_circle_outlined),
                          onPressed: onStop,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _sleepLabel(TtsUiState t) {
    switch (t.sleepMode) {
      case SleepTimerMode.off:
        return 'Hẹn giờ';
      case SleepTimerMode.endOfChapter:
        return 'Hết chương';
      case SleepTimerMode.duration:
        return Fmt.clock(t.sleepRemaining ?? Duration.zero);
    }
  }
}
