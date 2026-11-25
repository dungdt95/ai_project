import 'dart:math';

import 'package:be_vui_tieng_anh/core/media.dart';
import 'package:be_vui_tieng_anh/data/models.dart';
import 'package:be_vui_tieng_anh/features/activities/balloon_pop_activity.dart';
import 'package:be_vui_tieng_anh/features/activities/drag_drop_activity.dart';
import 'package:be_vui_tieng_anh/features/activities/feed_momo_activity.dart';
import 'package:be_vui_tieng_anh/features/activities/memory_match_activity.dart';
import 'package:be_vui_tieng_anh/features/activities/tap_find_activity.dart';
import 'package:be_vui_tieng_anh/features/review/review_session_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'review_ui_test.dart' show FakeAudio, FakeCapture, baseOverrides, pumpApp, sixWordTopics, storageWith, stub, word;

const _ms = Duration(milliseconds: 100);

Future<void> pumpW(WidgetTester tester, Widget w) async {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: w)));
  await tester.pump();
}

/// Bóng đang trôi: chờ tới khi tâm bóng nằm trong vùng thấy được rồi chạm.
Future<void> tapBalloon(WidgetTester tester, String id) async {
  final f = find.byKey(Key('balloon_$id'));
  for (var i = 0; i < 100; i++) {
    final c = tester.getCenter(f);
    if (c.dy > 200 && c.dy < 700) break;
    await tester.pump(_ms);
  }
  await tester.tap(f);
  await tester.pump();
}

String balloonTarget(WidgetTester tester) => tester.widget<Text>(find.textContaining('Pop: ')).data!.substring(5);

String roundText(WidgetTester tester) => tester.widget<Text>(find.byKey(const Key('balloon_round'))).data!;

String wrongBalloon(WidgetTester tester, String target) {
  final keys = tester
      .widgetList<GestureDetector>(find.byWidgetPredicate((w) => w is GestureDetector && w.key.toString().contains("'balloon_")))
      .map((g) => (g.key as ValueKey<String>).value.substring('balloon_'.length));
  final others = keys.where((k) => k != target).toList();
  // Ưu tiên bóng đang trong tầm nhìn để khỏi phải chờ nó trôi tới (làm trôi thời gian của vòng).
  bool visible(String k) {
    final y = tester.getCenter(find.byKey(Key('balloon_$k'))).dy;
    return y > 200 && y < 700;
  }

  return others.firstWhere(visible, orElse: () => others.first);
}

Future<void> playBalloonRound(WidgetTester tester) async {
  await tapBalloon(tester, balloonTarget(tester));
  await tester.pump(const Duration(milliseconds: 1100));
}

String momoTarget(WidgetTester tester) {
  final t = tester.widget<Text>(find.byKey(const Key('momo_prompt'))).data!;
  return t.substring('Give me... '.length, t.length - 1);
}

Future<void> dragCard(WidgetTester tester, String id) async {
  final card = find.byKey(Key('momo_card_$id'));
  final to = tester.getCenter(find.byKey(const Key('momo_target')));
  await tester.drag(card, to - tester.getCenter(card), warnIfMissed: false);
  await tester.pump();
}

Future<void> playMomoRound(WidgetTester tester) async {
  await dragCard(tester, momoTarget(tester));
  await tester.pump(const Duration(milliseconds: 1100));
}

void main() {
  final ws = [word('a'), word('b'), word('c'), word('d'), word('e'), word('f')];

  // ============================================================ Balloon Pop
  group('BalloonPopActivity', () {
    Future<(List<(String, bool)>, List<int>, List<(String?, String)>)> pumpBalloon(WidgetTester tester, {int rounds = 3}) async {
      final attempts = <(String, bool)>[];
      final finished = <int>[];
      final audio = <(String?, String)>[];
      await pumpW(
        tester,
        BalloonPopActivity(
          words: ws.take(4).toList(),
          allTopicWords: ws,
          rounds: rounds,
          baseDir: null,
          wordBaseDirs: const {'a': '/packs/x'},
          onWordAttempt: (id, ok) => attempts.add((id, ok)),
          onFinished: () => finished.add(1),
          playAudio: (p, t) => audio.add((p, t)),
        ),
      );
      return (attempts, finished, audio);
    }

    testWidgets('xong đủ N vòng: onWordAttempt(đúng) mỗi vòng, onFinished đúng 1 lần', (tester) async {
      final (attempts, finished, _) = await pumpBalloon(tester, rounds: 3);
      for (var r = 0; r < 3; r++) {
        expect(roundText(tester), '${r + 1} / 3');
        await playBalloonRound(tester);
      }
      expect(finished.length, 1);
      expect(attempts.length, 3);
      expect(attempts.every((a) => a.$2), isTrue);
      await tester.pumpWidget(const SizedBox()); // dispose controller
    });

    testWidgets('3 bóng ở 3 vòng đầu rồi 4 bóng; bóng ≥ kKidTouch; ảnh theo wordBaseDirs', (tester) async {
      await pumpBalloon(tester, rounds: 5);
      expect(find.byType(MediaImage), findsNWidgets(3));
      final size = tester.getSize(find.byWidgetPredicate((w) => w is GestureDetector && w.key.toString().contains("'balloon_")).first);
      expect(size.width, inInclusiveRange(120, 140));
      expect(size.height, greaterThanOrEqualTo(80));
      for (final m in tester.widgetList<MediaImage>(find.byType(MediaImage))) {
        expect(m.baseDir, m.path.contains('/a.') ? '/packs/x' : isNull);
      }
      for (var r = 0; r < 3; r++) {
        await playBalloonRound(tester);
      }
      expect(find.byType(MediaImage), findsNWidgets(4));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('chạm nhầm: ghi sai, không sang vòng; sau 2 lần nhầm → viền vàng gợi ý; rồi chạm đúng', (tester) async {
      final (attempts, finished, audio) = await pumpBalloon(tester, rounds: 2);
      final target = balloonTarget(tester);
      expect(find.byKey(const Key('balloon_hint')), findsNothing);

      final w1 = wrongBalloon(tester, target);
      await tapBalloon(tester, w1);
      await tester.pump(const Duration(milliseconds: 500)); // bóng nảy xong
      expect(attempts.last, (target, false));
      expect(roundText(tester), '1 / 2');
      expect(find.byKey(const Key('balloon_hint')), findsNothing);
      expect(audio.any((a) => a.$2 == w1), isTrue, reason: 'đọc tên quả bóng vừa chạm');
      await tester.pump(const Duration(milliseconds: 1000));
      expect(audio.last.$2, 'Find $target!', reason: 'nhắc lại mục tiêu');

      await tapBalloon(tester, wrongBalloon(tester, target));
      await tester.pump(const Duration(milliseconds: 500));
      expect(attempts.where((a) => !a.$2).length, 2);
      expect(roundText(tester), '1 / 2');
      expect(find.byKey(const Key('balloon_hint')), findsOneWidget);
      expect(finished, isEmpty);

      await tapBalloon(tester, target);
      await tester.pump(const Duration(milliseconds: 1100));
      expect(attempts.last, (target, true));
      expect(roundText(tester), '2 / 2');
      expect(find.byKey(const Key('balloon_hint')), findsNothing, reason: 'vòng mới reset gợi ý');
      await playBalloonRound(tester);
      expect(finished.length, 1);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('đang pop: chạm thêm bị bỏ qua, không đếm đôi', (tester) async {
      final (attempts, finished, _) = await pumpBalloon(tester, rounds: 2);
      final target = balloonTarget(tester);
      await tapBalloon(tester, target);
      await tester.pump(const Duration(milliseconds: 100));
      await tapBalloon(tester, target); // chạm lại bóng đang pop
      await tapBalloon(tester, wrongBalloon(tester, target)); // và bóng khác
      expect(attempts, [(target, true)]);
      await tester.pump(const Duration(milliseconds: 1100));
      expect(roundText(tester), '2 / 2');
      expect(attempts.length, 1);
      expect(finished, isEmpty);
      await tester.pump(const Duration(milliseconds: 1100)); // dọn timer
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('bóng mục tiêu bay lại từ dưới sau khi khuất đỉnh (không mất bóng)', (tester) async {
      await pumpBalloon(tester, rounds: 1);
      final target = balloonTarget(tester);
      final f = find.byKey(Key('balloon_$target'));
      var wrapped = false;
      var last = tester.getCenter(f).dy;
      for (var i = 0; i < 90; i++) {
        await tester.pump(_ms);
        final y = tester.getCenter(f).dy;
        if (y > last + 100) wrapped = true; // nhảy từ trên xuống dưới = bay lại
        last = y;
      }
      expect(wrapped, isTrue);
      expect(f, findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });

  // ============================================================ Feed Momo
  group('FeedMomoActivity', () {
    Future<(List<(String, bool)>, List<int>, List<(String?, String)>)> pumpMomo(WidgetTester tester, {int rounds = 4}) async {
      final attempts = <(String, bool)>[];
      final finished = <int>[];
      final audio = <(String?, String)>[];
      await pumpW(
        tester,
        FeedMomoActivity(
          words: ws.take(4).toList(),
          rounds: rounds,
          baseDir: null,
          wordBaseDirs: const {'a': '/packs/x'},
          onWordAttempt: (id, ok) => attempts.add((id, ok)),
          onFinished: () => finished.add(1),
          playAudio: (p, t) => audio.add((p, t)),
        ),
      );
      return (attempts, finished, audio);
    }

    testWidgets('xong 4 vòng: mỗi vòng một từ khác nhau, onFinished đúng 1 lần; ảnh theo wordBaseDirs', (tester) async {
      final (attempts, finished, audio) = await pumpMomo(tester);
      expect(find.byType(Draggable<Word>), findsNWidgets(4));
      for (final m in tester.widgetList<MediaImage>(find.byType(MediaImage))) {
        expect(m.baseDir, m.path.contains('/a.') ? '/packs/x' : isNull);
      }
      expect(find.byKey(const Key('momo_idle')), findsOneWidget);
      for (var r = 0; r < 4; r++) {
        expect(tester.widget<Text>(find.byKey(const Key('momo_round'))).data, '${r + 1}/4');
        await playMomoRound(tester);
      }
      expect(finished.length, 1);
      expect(attempts.length, 4);
      expect(attempts.every((a) => a.$2), isTrue);
      expect(attempts.map((a) => a.$1).toSet().length, 4);
      expect(audio.any((a) => a.$2.startsWith('Give me... ')), isTrue);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('kéo nhầm: ghi sai, không sang vòng, đọc tên thẻ rồi nhắc mục tiêu; kéo đúng → momo_cheer', (tester) async {
      final (attempts, finished, audio) = await pumpMomo(tester);
      final target = momoTarget(tester);
      final wrong = ['a', 'b', 'c', 'd'].firstWhere((i) => i != target);
      await dragCard(tester, wrong);
      await tester.pump(const Duration(milliseconds: 600));
      expect(attempts, [(target, false)]);
      expect(tester.widget<Text>(find.byKey(const Key('momo_round'))).data, '1/4');
      expect(find.byKey(const Key('momo_idle')), findsOneWidget);
      expect(audio.any((a) => a.$2 == wrong), isTrue);
      await tester.pump(const Duration(milliseconds: 600));
      expect(audio.last.$2, 'Give me... $target!');
      expect(finished, isEmpty);

      await dragCard(tester, target);
      expect(find.byKey(const Key('momo_cheer')), findsOneWidget);
      expect(attempts.last, (target, true));
      await tester.pump(const Duration(milliseconds: 1100));
      expect(tester.widget<Text>(find.byKey(const Key('momo_round'))).data, '2/4');
      expect(find.byKey(const Key('momo_idle')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('thả đôi sau khi đúng (đang chờ sang vòng) không đếm thêm', (tester) async {
      final (attempts, _, _) = await pumpMomo(tester, rounds: 2);
      final target = momoTarget(tester);
      await dragCard(tester, target);
      await dragCard(tester, target);
      await dragCard(tester, ['a', 'b', 'c', 'd'].firstWhere((i) => i != target));
      expect(attempts, [(target, true)]);
      await tester.pump(const Duration(milliseconds: 1100));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('vùng chạm: thẻ và nút loa >= kKidTouch', (tester) async {
      await pumpMomo(tester);
      expect(tester.getSize(find.byKey(const Key('momo_speaker'))).shortestSide, greaterThanOrEqualTo(80));
      for (final d in tester.widgetList(find.byType(Draggable<Word>))) {
        expect(tester.getSize(find.byWidget(d)).shortestSide, greaterThanOrEqualTo(80));
      }
      await tester.pumpWidget(const SizedBox());
    });
  });

  // ============================================================ Xoay vòng trong phiên
  group('ReviewSessionScreen - xoay vòng mini-game (G5)', () {
    GoRouter router({bool? balloon, bool? momo, Random? random}) => GoRouter(initialLocation: '/home', routes: [
          GoRoute(path: '/home', builder: (_, _) => stub('HOME PAGE')),
          GoRoute(
            path: '/review',
            builder: (_, _) => ReviewSessionScreen(
              random: random ?? Random(11),
              useBalloonPop: balloon,
              useFeedMomo: momo,
              capture: FakeCapture(),
              recordDuration: const Duration(milliseconds: 300),
            ),
          ),
        ]);

    Future<void> open(WidgetTester tester, GoRouter r) async {
      r.push('/review');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    testWidgets('ép TapFind + DragDrop → không có game mới', (tester) async {
      final topics = sixWordTopics();
      final r = router(balloon: false, momo: false);
      await pumpApp(tester, baseOverrides(storageWith(topics), topics, audio: FakeAudio()), r);
      await open(tester, r);
      expect(find.byType(TapFindActivity), findsOneWidget);
      expect(find.byType(BalloonPopActivity), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Random cố định: biến thể chọn 1 lần và đúng 1 trong 2 game ở chặng 1', (tester) async {
      final topics = sixWordTopics();
      final r = router(random: Random(5));
      await pumpApp(tester, baseOverrides(storageWith(topics), topics, audio: FakeAudio()), r);
      await open(tester, r);
      final tap = find.byType(TapFindActivity).evaluate().length;
      final balloon = find.byType(BalloonPopActivity).evaluate().length;
      expect(tap + balloon, 1);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('BalloonPop + FeedMomo trong phiên: đủ chặng, ghi Leitner 1 lần/từ theo lần chấm đầu', (tester) async {
      final topics = sixWordTopics();
      final st = storageWith(topics);
      final audio = FakeAudio();
      final r = router(balloon: true, momo: true);
      await pumpApp(tester, baseOverrides(st, topics, audio: audio), r);
      await open(tester, r);

      expect(find.byType(BalloonPopActivity), findsOneWidget);
      expect(find.byType(TapFindActivity), findsNothing);
      // vòng đầu chạm nhầm → lần chấm đầu của từ đó là sai
      final firstTarget = balloonTarget(tester);
      await tapBalloon(tester, wrongBalloon(tester, firstTarget));
      await tester.pump(const Duration(milliseconds: 500));
      for (var i = 0; i < 6; i++) {
        await playBalloonRound(tester);
      }
      expect(find.byType(MemoryMatchActivity), findsOneWidget);
      expect(st.writes, isEmpty);

      // Memory Match
      final cards = find.descendant(of: find.byType(Wrap), matching: find.byType(GestureDetector));
      final matched = <int>{};
      final known = <int, String>{};
      String labelAt(int i) => tester.widget<MediaImage>(find.descendant(of: cards.at(i), matching: find.byType(MediaImage))).label;
      while (matched.length < 6) {
        final i = List.generate(6, (k) => k).firstWhere((k) => !matched.contains(k));
        await tester.tap(cards.at(i));
        await tester.pump(const Duration(milliseconds: 50));
        final li = labelAt(i);
        final partner = known.entries.where((e) => e.key != i && !matched.contains(e.key) && e.value == li).firstOrNull;
        if (partner != null) {
          await tester.tap(cards.at(partner.key));
          await tester.pump(const Duration(milliseconds: 50));
          matched..add(i)..add(partner.key);
        } else {
          final k = List.generate(6, (x) => x).firstWhere((x) => x != i && !matched.contains(x) && !known.containsKey(x));
          await tester.tap(cards.at(k));
          await tester.pump(const Duration(milliseconds: 50));
          final lk = labelAt(k);
          if (lk == li) {
            matched..add(i)..add(k);
          } else {
            known[i] = li;
            known[k] = lk;
            await tester.pump(const Duration(milliseconds: 1000));
          }
        }
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pump(const Duration(milliseconds: 1100));

      expect(find.byType(FeedMomoActivity), findsOneWidget);
      expect(find.byType(DragDropActivity), findsNothing);
      for (var i = 0; i < 4; i++) {
        await playMomoRound(tester);
      }
      // Repeat & Record
      for (var i = 0; i < 2; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        await tester.tap(find.byKey(const Key('repeat_record_mic')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('You are a Review Super Star!'), findsOneWidget);

      final ids = st.writes.map((w) => w.$1).toList();
      expect(ids, isNotEmpty);
      expect(ids.toSet().length, ids.length, reason: 'mỗi từ ghi tối đa 1 lần');
      expect(st.writes.firstWhere((w) => w.$1 == firstTarget).$2, isFalse, reason: 'lần chấm đầu (nhầm) quyết định');
      expect(st.stats[firstTarget]!.box, 1);
      for (final w in st.writes.where((w) => w.$2)) {
        expect(st.stats[w.$1]!.box, 2, reason: w.$1);
      }
      await tester.tap(find.text('Finish!'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('HOME PAGE'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
