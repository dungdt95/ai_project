import 'package:doctruyen/features/reader/reader_controls.dart';
import 'package:doctruyen/services/tts_audio_handler.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<double> barHeight(WidgetTester tester, TtsUiState? tts) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: ReaderBottomBar(
              tts: tts,
              color: Colors.white,
              textColor: Colors.black,
              hasPrevious: true,
              hasNext: true,
              onPreviousChapter: () {},
              onNextChapter: () {},
              onPlayPause: () {},
              onPreviousSentence: () {},
              onNextSentence: () {},
              onStop: () {},
              onSpeedChanged: (_) {},
              onSleepTimer: () {},
              onVoiceSettings: () {},
            ),
          ),
        ),
      ),
    );
    return tester.getSize(find.byType(ReaderBottomBar)).height;
  }

  testWidgets('chừa chỗ đủ cho thanh điều khiển ở mọi trạng thái', (t) async {
    expect(
      await barHeight(t, null),
      lessThanOrEqualTo(ReaderBottomBar.maxContentHeight),
    );
    expect(
      await barHeight(t, const TtsUiState(chapterId: 1, loading: true)),
      lessThanOrEqualTo(ReaderBottomBar.maxContentHeight),
    );
    expect(
      await barHeight(t, const TtsUiState(chapterId: 1, playing: true)),
      lessThanOrEqualTo(ReaderBottomBar.maxContentHeight),
    );
  });
}
