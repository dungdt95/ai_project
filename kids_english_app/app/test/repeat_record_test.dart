import 'package:be_vui_tieng_anh/data/models.dart';
import 'package:be_vui_tieng_anh/features/activities/repeat_record_activity.dart';
import 'package:be_vui_tieng_anh/features/activities/speech_capture.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Micro giả: mỗi lần ghi phát ra danh sách mức âm lượng định sẵn.
class FakeCapture implements SpeechCapture {
  FakeCapture({this.allowed = true, required this.takes});
  final bool allowed;
  final List<List<double>> takes; // mỗi lần ghi một danh sách dBFS
  int started = 0;
  final playedBack = <String>[];

  @override
  Future<bool> ensurePermission() async => allowed;

  @override
  Future<void> start(void Function(double dbfs) onLevel) async {
    final levels = takes[started < takes.length ? started : takes.length - 1];
    started++;
    for (final l in levels) {
      onLevel(l);
    }
  }

  @override
  Future<String?> stop() async => '/tmp/rec_$started.m4a';

  @override
  Future<void> playBack(String path) async => playedBack.add(path);

  @override
  Future<void> dispose() async {}
}

const silence = [-70.0, -65.0, -60.0];
const voice = [-60.0, -25.0, -20.0, -30.0];

Word word(String id) => Word(id: id, text: id, image: '', audio: '', sentence: '', sentenceAudio: '');

void main() {
  late List<String> spoken;
  late int finished;

  Future<void> pumpActivity(WidgetTester tester, FakeCapture cap, {List<Word>? words}) async {
    spoken = [];
    finished = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: RepeatRecordActivity(
          words: words ?? [word('dog')],
          baseDir: null,
          capture: cap,
          recordDuration: const Duration(milliseconds: 500),
          onFinished: () => finished++,
          playAudio: (path, text) async => spoken.add(text),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> speak(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('repeat_record_mic')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600)); // hết thời gian ghi
    await tester.pumpAndSettle();
  }

  testWidgets('có tiếng nói -> phát lại giọng bé, khen, qua bài', (tester) async {
    final cap = FakeCapture(takes: [voice]);
    await pumpActivity(tester, cap);
    expect(spoken, ['Say: dog!']);
    await speak(tester);
    expect(cap.playedBack, hasLength(1));
    expect(spoken.last, 'Awesome! You sound great!');
    expect(finished, 1);
  });

  testWidgets('im lặng -> không qua, yêu cầu nói lại', (tester) async {
    final cap = FakeCapture(takes: [silence]);
    await pumpActivity(tester, cap);
    await speak(tester);
    expect(finished, 0);
    expect(cap.playedBack, isEmpty);
    expect(spoken, contains("I can't hear you! Let's try again!"));
    expect(spoken.last, 'Say: dog!');
    expect(find.text('Try again! Tap to Speak'), findsOneWidget);
  });

  testWidgets('im lặng rồi nói được -> qua bài', (tester) async {
    final cap = FakeCapture(takes: [silence, voice]);
    await pumpActivity(tester, cap);
    await speak(tester);
    expect(finished, 0);
    await speak(tester);
    expect(finished, 1);
    expect(cap.playedBack, hasLength(1));
  });

  testWidgets('im lặng 3 lần -> vẫn cho qua để bé không bị kẹt', (tester) async {
    final cap = FakeCapture(takes: [silence]);
    await pumpActivity(tester, cap);
    await speak(tester);
    await speak(tester);
    expect(finished, 0);
    await speak(tester);
    expect(spoken, contains("Good try! Let's keep going!"));
    expect(finished, 1);
    expect(cap.playedBack, isEmpty);
  });

  testWidgets('một tiếng động ngắn (1 mẫu) chưa tính là nói', (tester) async {
    final cap = FakeCapture(takes: [
      [-70.0, -20.0, -70.0],
    ]);
    await pumpActivity(tester, cap);
    await speak(tester);
    expect(finished, 0);
  });

  testWidgets('nhiều từ: chuyển từ tiếp theo, đếm im lặng tính lại cho từng từ', (tester) async {
    final cap = FakeCapture(takes: [silence, silence, voice, silence]);
    await pumpActivity(tester, cap, words: [word('dog'), word('cat')]);
    await speak(tester); // dog: im lặng 1
    await speak(tester); // dog: im lặng 2
    await speak(tester); // dog: nói -> sang cat
    expect(find.text('Say it loud: cat!'), findsOneWidget);
    await speak(tester); // cat: im lặng 1 -> chưa được cho qua
    expect(finished, 0);
  });

  testWidgets('không có quyền micro -> vẫn cho qua (không kẹt bài)', (tester) async {
    final cap = FakeCapture(allowed: false, takes: [silence]);
    await pumpActivity(tester, cap);
    await tester.tap(find.byKey(const Key('repeat_record_mic')));
    await tester.pumpAndSettle();
    expect(cap.started, 0);
    expect(finished, 1);
  });
}
