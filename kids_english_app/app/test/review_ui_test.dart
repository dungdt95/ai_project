import 'dart:math';

import 'package:be_vui_tieng_anh/app/providers.dart';
import 'package:be_vui_tieng_anh/core/media.dart';
import 'package:be_vui_tieng_anh/data/leitner.dart';
import 'package:be_vui_tieng_anh/data/models.dart';
import 'package:be_vui_tieng_anh/data/review_planner.dart';
import 'package:be_vui_tieng_anh/data/storage.dart';
import 'package:be_vui_tieng_anh/features/activities/drag_drop_activity.dart';
import 'package:be_vui_tieng_anh/features/activities/memory_match_activity.dart';
import 'package:be_vui_tieng_anh/features/activities/repeat_record_activity.dart';
import 'package:be_vui_tieng_anh/features/activities/speech_capture.dart';
import 'package:be_vui_tieng_anh/features/activities/tap_find_activity.dart';
import 'package:be_vui_tieng_anh/features/parent/progress_report_tab.dart';
import 'package:be_vui_tieng_anh/features/review/review_session_screen.dart';
import 'package:be_vui_tieng_anh/features/screen_time/screen_time_controller.dart';
import 'package:be_vui_tieng_anh/features/screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

// ---------------------------------------------------------------- fakes

/// Storage trong bộ nhớ: không đụng Hive/đĩa nên chạy được trong testWidgets.
class FakeStorage extends Storage {
  FakeStorage({this.profileList = const [], Map<String, WordStat>? stats, Set<String>? doneLessons})
      : stats = stats ?? {},
        doneLessons = doneLessons ?? {};

  final List<ChildProfile> profileList;
  final Map<String, WordStat> stats;
  final Set<String> doneLessons;
  late final settings = <String, Object>{
    if (profileList.isNotEmpty) SettingKeys.activeProfile: profileList.first.id,
  };
  final writes = <(String, bool)>[]; // recordWordAttempt theo thứ tự gọi

  @override
  List<ChildProfile> profiles() => profileList;
  @override
  T setting<T>(String key, T fallback) => (settings[key] as T?) ?? fallback;
  @override
  Future<void> putSetting(String key, Object value) async => settings[key] = value;
  @override
  bool isLessonDone(String profileId, String lessonId) => doneLessons.contains(lessonId);
  @override
  WordStat? wordStat(String profileId, String wordId) => stats[wordId];
  @override
  Future<void> recordWordAttempt(String profileId, String wordId, {required bool correct, DateTime? now}) async {
    writes.add((wordId, correct));
    final cur = stats[wordId] ?? WordStat(nextReview: now ?? DateTime.now());
    stats[wordId] = cur.update(isCorrect: correct, now: now ?? DateTime.now());
  }

  @override
  int secondsPlayed(String profileId, DateTime day) => 0;
}

class FakeAudio extends Fake implements AudioService {
  final plays = <(String?, String, String?)>[]; // path, text, baseDir
  @override
  Future<void> play(String? path, String fallbackText, {String? baseDir}) async => plays.add((path, fallbackText, baseDir));
  @override
  Future<void> playWord(String? path, String enText, {String? viText, String? baseDir}) async =>
      plays.add((path, enText, baseDir));
  @override
  Future<void> instruction(String? path, String enText, {String? viPath, String? viText}) async =>
      plays.add((path, enText, null));
}

class FakeScreenTime extends ScreenTimeController {
  FakeScreenTime(this.timeUp);
  final bool timeUp;
  @override
  ScreenTimeState build() =>
      ScreenTimeState(playedMinutes: 0, limitMinutes: 20, isTimeUp: timeUp, isWarning: false);
}

class FakeCapture implements SpeechCapture {
  @override
  Future<bool> ensurePermission() async => true;
  @override
  Future<void> start(void Function(double dbfs) onLevel) async {
    for (final l in const [-60.0, -25.0, -20.0, -30.0]) {
      onLevel(l);
    }
  }

  @override
  Future<String?> stop() async => '/tmp/rec.m4a';
  @override
  Future<void> playBack(String path) async {}
  @override
  Future<void> dispose() async {}
}

// ---------------------------------------------------------------- dữ liệu

final now = DateTime.now();
final yesterday = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1));

Word word(String id, {String? vi}) =>
    Word(id: id, text: id, image: 'images/$id.png', audio: 'audio/$id.mp3', sentence: '', sentenceAudio: '', vi: vi ?? 'vi_$id');

Topic topic(String id, List<String> ids, {String? baseDir}) => Topic(
      id: id,
      level: 1,
      order: 1,
      titleEn: 'T $id',
      titleVi: id,
      mapIcon: '',
      song: null,
      words: [for (final w in ids) word(w)],
      sentences: const [],
      lessons: const [],
      commands: const [],
      baseDir: baseDir,
    );

WordStat due({int box = 1, int wrong = 0}) => WordStat(exposures: 2, wrong: wrong, box: box, nextReview: yesterday);

final profile = const ChildProfile(id: 'p1', nickname: 'Bo', avatarId: 'monkey');

/// 3 từ built-in + 3 từ của gói t06 (6 từ → phiên 6 từ).
List<Topic> sixWordTopics() => [
      topic('t01', ['t01_a', 't01_b', 't01_c']),
      topic('t06', ['t06_a', 't06_b', 't06_c'], baseDir: '/packs/t06'),
    ];

FakeStorage storageWith(List<Topic> topics, {int words = 6}) {
  final ids = [for (final t in topics) ...t.words.map((w) => w.id)].take(words);
  return FakeStorage(profileList: [profile], stats: {for (final id in ids) id: due()});
}

List<Override> baseOverrides(FakeStorage storage, List<Topic> topics, {FakeAudio? audio, bool timeUp = false}) => [
      storageProvider.overrideWithValue(storage),
      topicsProvider.overrideWith((ref) async => topics),
      screenTimeProvider.overrideWith(() => FakeScreenTime(timeUp)),
      if (audio != null) audioProvider.overrideWithValue(audio),
    ];

Future<void> pumpApp(WidgetTester tester, List<Override> overrides, GoRouter router) async {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(overrides: overrides, child: MaterialApp.router(routerConfig: router)));
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100)); // cho timer 0ms của flutter_animate chạy hết
}

Widget stub(String text) => Scaffold(body: Center(child: Text(text)));

void main() {
  // ============================================================ Nút Review ở bản đồ
  group('Nút Review ⭐ trên bản đồ', () {
    GoRouter homeRouter() => GoRouter(routes: [
          GoRoute(path: '/', builder: (_, _) => const KidHomeScreen()),
          GoRoute(path: '/review', builder: (_, _) => stub('REVIEW PAGE')),
          GoRoute(path: '/gate', builder: (_, _) => stub('GATE')),
        ]);

    testWidgets('ẩn khi kho < 4 từ', (tester) async {
      final topics = [
        topic('t01', ['a', 'b', 'c'])
      ];
      final st = storageWith(topics, words: 3);
      await pumpApp(tester, baseOverrides(st, topics), homeRouter());
      expect(find.byType(ReviewStarButton), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('hiện + badge số từ cần ôn khi kho >= 4; chạm → /review', (tester) async {
      final topics = sixWordTopics();
      final st = storageWith(topics, words: 6);
      // 2 từ box 3 chưa đến hạn → còn 4 từ cần ôn.
      st.stats['t06_b'] = WordStat(box: 3, nextReview: now.add(const Duration(days: 3)));
      st.stats['t06_c'] = WordStat(box: 3, nextReview: now.add(const Duration(days: 3)));
      await pumpApp(tester, baseOverrides(st, topics), homeRouter());
      expect(find.byType(ReviewStarButton), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('review_badge')), matching: find.text('4')), findsOneWidget);
      // kích thước >= kKidTouch
      expect(tester.getSize(find.byType(ReviewStarButton)).height, greaterThanOrEqualTo(80));
      await tester.tap(find.byType(ReviewStarButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('REVIEW PAGE'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('không có từ cần ôn → hiện nút nhưng không có badge', (tester) async {
      final topics = sixWordTopics();
      final st = FakeStorage(profileList: [profile], stats: {
        for (final w in topics.expand((t) => t.words)) w.id: WordStat(box: 4, nextReview: now.add(const Duration(days: 7))),
      });
      await pumpApp(tester, baseOverrides(st, topics), homeRouter());
      expect(find.byType(ReviewStarButton), findsOneWidget);
      expect(find.byKey(const Key('review_badge')), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('khoá phụ huynh và avatar vẫn còn (không bị nút che)', (tester) async {
      final topics = sixWordTopics();
      await pumpApp(tester, baseOverrides(storageWith(topics), topics), homeRouter());
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      expect(find.text('Bo'), findsOneWidget);
      final lock = tester.getRect(find.byIcon(Icons.lock_outline));
      final btn = tester.getRect(find.byType(ReviewStarButton));
      expect(btn.overlaps(lock), isFalse);
      await tester.pumpWidget(const SizedBox());
    });
  });

  // ============================================================ Kho từ vựng phụ huynh
  group('ProgressReportTab - kho từ vựng', () {
    ReviewSummary summaryOf(List<Topic> topics, Map<String, WordStat> stats) => buildReviewSummary(
          topics: topics,
          isLessonDone: (_) => false,
          wordStat: (id) => stats[id],
          now: now,
        );

    Future<void> pumpTab(WidgetTester tester, ReviewSummary summary, GoRouter router, {FakeAudio? audio}) async {
      await pumpApp(
        tester,
        [
          storageProvider.overrideWithValue(FakeStorage(profileList: [profile])),
          reviewSummaryProvider.overrideWithValue(summary),
          audioProvider.overrideWithValue(audio ?? FakeAudio()),
        ],
        router,
      );
    }

    GoRouter tabRouter({String initial = '/'}) => GoRouter(initialLocation: initial, routes: [
          GoRoute(path: '/home', builder: (_, _) => stub('HOME PAGE')),
          GoRoute(
            path: '/',
            builder: (ctx, _) => Consumer(
              builder: (c, ref, _) => Scaffold(body: ProgressReportTab(profileId: 'p1', storage: ref.read(storageProvider))),
            ),
          ),
          GoRoute(path: '/review', builder: (_, s) => stub('REVIEW ${s.uri.queryParameters['mode']}')),
        ]);

    int tileValue(WidgetTester tester, String key) {
      final t = find.descendant(of: find.byKey(Key(key)), matching: find.byType(Text));
      // Text đầu = emoji, thứ hai = số.
      return int.parse((tester.widget<Text>(t.at(1))).data!);
    }

    testWidgets('hiển thị đúng 3 con số: đã học / đã thuộc / cần ôn', (tester) async {
      final topics = sixWordTopics();
      final stats = {
        't01_a': due(), // cần ôn
        't01_b': due(wrong: 3), // cần ôn
        't01_c': WordStat(box: 2, nextReview: now.add(const Duration(days: 1))), // củng cố
        't06_a': WordStat(box: 3, nextReview: now.add(const Duration(days: 3))), // thuộc
        't06_b': WordStat(box: 5, nextReview: now.add(const Duration(days: 14))), // thuộc
      };
      await pumpTab(tester, summaryOf(topics, stats), tabRouter());
      expect(tileValue(tester, 'stat_learned'), 5);
      expect(tileValue(tester, 'stat_mastered'), 2);
      expect(tileValue(tester, 'stat_due'), 2);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('3 nhóm ExpansionTile; nhóm cần ôn mở sẵn; chạm từ → phát âm đúng baseDir', (tester) async {
      final topics = sixWordTopics();
      final stats = {
        't06_a': due(),
        't01_c': WordStat(box: 2, nextReview: now.add(const Duration(days: 1))),
        't01_a': WordStat(box: 4, nextReview: now.add(const Duration(days: 7))),
        't01_b': WordStat(box: 4, nextReview: now.add(const Duration(days: 7))),
      };
      final audio = FakeAudio();
      await pumpTab(tester, summaryOf(topics, stats), tabRouter(), audio: audio);
      expect(find.byType(ExpansionTile), findsNWidgets(3));
      expect(find.text('🔴 Cần ôn tập (1)'), findsOneWidget);
      expect(find.text('🟡 Đang củng cố (1)'), findsOneWidget);
      expect(find.text('🟢 Đã thuộc (2)'), findsOneWidget);
      // Nhóm đầu mở sẵn → thấy từ t06_a (gói); ảnh dùng đúng baseDir của gói.
      final tile = find.byKey(const Key('vocab_t06_a'));
      expect(tile, findsOneWidget);
      final img = tester.widget<MediaImage>(find.descendant(of: tile, matching: find.byType(MediaImage)));
      expect(img.baseDir, '/packs/t06');
      expect(find.descendant(of: tile, matching: find.text('vi_t06_a')), findsOneWidget);
      // box 1 → đúng 1 sao đầy
      expect(find.descendant(of: tile, matching: find.byIcon(Icons.star_rounded)), findsOneWidget);
      expect(find.descendant(of: tile, matching: find.byIcon(Icons.star_border_rounded)), findsNWidgets(4));
      await tester.tap(tile);
      await tester.pump();
      expect(audio.plays.single, ('audio/t06_a.mp3', 't06_a', '/packs/t06'));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('kho rỗng → thông báo thân thiện, nút ôn tắt', (tester) async {
      await pumpTab(tester, ReviewSummary.empty, tabRouter());
      expect(find.textContaining('chưa học từ nào'), findsOneWidget);
      expect(tileValue(tester, 'stat_learned'), 0);
      final btn = tester.widget<FilledButton>(find.byKey(const Key('review_now_button')));
      expect(btn.onPressed, isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('kho < 4 từ → nút ôn tắt dù có từ cần ôn', (tester) async {
      final topics = [
        topic('t01', ['a', 'b', 'c'])
      ];
      await pumpTab(tester, summaryOf(topics, {'a': due(), 'b': due(), 'c': due()}), tabRouter());
      final btn = tester.widget<FilledButton>(find.byKey(const Key('review_now_button')));
      expect(btn.onPressed, isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('không có từ cần ôn → nút ôn tắt', (tester) async {
      final topics = sixWordTopics();
      final stats = {
        for (final w in topics.expand((t) => t.words)) w.id: WordStat(box: 4, nextReview: now.add(const Duration(days: 7))),
      };
      await pumpTab(tester, summaryOf(topics, stats), tabRouter());
      final btn = tester.widget<FilledButton>(find.byKey(const Key('review_now_button')));
      expect(btn.onPressed, isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('nút ôn ngay → /home rồi /review?mode=weak; quay lại thì về /home', (tester) async {
      final topics = sixWordTopics();
      final stats = {for (final w in topics.expand((t) => t.words)) w.id: due()};
      // Mô phỏng đường vào thật: /home → /gate-ish → màn phụ huynh (push chồng nhiều lớp).
      final router = GoRouter(initialLocation: '/home', routes: [
        GoRoute(path: '/home', builder: (_, _) => stub('HOME PAGE')),
        GoRoute(
          path: '/parent',
          builder: (ctx, _) => Consumer(
            builder: (c, ref, _) => Scaffold(body: ProgressReportTab(profileId: 'p1', storage: ref.read(storageProvider))),
          ),
        ),
        GoRoute(path: '/review', builder: (_, s) => stub('REVIEW ${s.uri.queryParameters['mode']}')),
      ]);
      await pumpTab(tester, summaryOf(topics, stats), router);
      router.push('/parent');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final btn = find.byKey(const Key('review_now_button'));
      await tester.scrollUntilVisible(btn, 200, scrollable: find.byType(Scrollable).first);
      await tester.tap(btn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('REVIEW weak'), findsOneWidget);
      expect(find.byType(ProgressReportTab), findsNothing); // ngăn xếp đã được thay bằng /home
      router.pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('HOME PAGE'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });

  // ============================================================ wordBaseDirs ở 4 activity
  group('Activity đa nguồn baseDir (wordBaseDirs)', () {
    final a = word('a');
    final b = word('b');
    const dirs = <String, String?>{'a': '/packs/x', 'b': null};

    Set<String?> imageDirs(WidgetTester tester) =>
        tester.widgetList<MediaImage>(find.byType(MediaImage)).map((m) => m.baseDir).toSet();

    Future<void> pumpW(WidgetTester tester, Widget w) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: w)));
      await tester.pump();
    }

    testWidgets('TapFind: ảnh mỗi từ theo đúng thư mục của nó', (tester) async {
      await pumpW(
        tester,
        TapFindActivity(
          words: [a],
          allTopicWords: [a, b],
          rounds: 1,
          baseDir: '/ignored',
          wordBaseDirs: dirs,
          onWordAttempt: (_, _) {},
          onFinished: () {},
          playAudio: (_, _) {},
        ),
      );
      expect(imageDirs(tester), {'/packs/x', null});
    });

    testWidgets('TapFind: không truyền wordBaseDirs → dùng baseDir như cũ', (tester) async {
      await pumpW(
        tester,
        TapFindActivity(
          words: [a],
          allTopicWords: [a, b],
          rounds: 1,
          baseDir: '/legacy',
          onWordAttempt: (_, _) {},
          onFinished: () {},
          playAudio: (_, _) {},
        ),
      );
      expect(imageDirs(tester), {'/legacy'});
    });

    testWidgets('MemoryMatch: thẻ lật ra dùng đúng thư mục theo từ', (tester) async {
      await pumpW(
        tester,
        MemoryMatchActivity(words: [a, b], baseDir: '/ignored', wordBaseDirs: dirs, onFinished: () {}, playAudio: (_, _) {}),
      );
      final cards = find.descendant(of: find.byType(Wrap), matching: find.byType(GestureDetector));
      await tester.tap(cards.at(0)); // lật 1 thẻ (chưa lật thẻ thứ hai nên chưa bị úp lại)
      await tester.pump(const Duration(milliseconds: 400));
      expect(imageDirs(tester).difference({'/packs/x', null}), isEmpty);
      expect(imageDirs(tester), isNotEmpty);
    });

    testWidgets('DragDrop: các thẻ kéo dùng đúng thư mục theo từ', (tester) async {
      await pumpW(
        tester,
        DragDropActivity(
          words: [a, b],
          baseDir: '/ignored',
          wordBaseDirs: dirs,
          onWordAttempt: (_, _) {},
          onFinished: () {},
          playAudio: (_, _) {},
        ),
      );
      expect(imageDirs(tester), {'/packs/x', null});
    });

    testWidgets('RepeatRecord: ảnh từ hiện tại theo wordBaseDirs', (tester) async {
      await pumpW(
        tester,
        RepeatRecordActivity(
          words: [a],
          baseDir: '/ignored',
          wordBaseDirs: dirs,
          capture: FakeCapture(),
          onFinished: () {},
          playAudio: (_, _) async {},
        ),
      );
      expect(imageDirs(tester), {'/packs/x'});
    });

    testWidgets('DragDrop rounds: 3 vòng, mỗi vòng một từ mục tiêu khác nhau, onFinished đúng 1 lần', (tester) async {
      final ws = [word('a'), word('b'), word('c')];
      final targets = <String>[];
      var finished = 0;
      await pumpW(
        tester,
        DragDropActivity(
          words: ws,
          baseDir: null,
          rounds: 3,
          onWordAttempt: (id, ok) {
            if (ok) targets.add(id);
          },
          onFinished: () => finished++,
          playAudio: (_, _) {},
        ),
      );
      for (var r = 0; r < 3; r++) {
        final title = tester.widget<Text>(find.textContaining('Drag ')).data!;
        final target = ws.firstWhere((w) => title == 'Drag ${w.text} into the box!');
        final item = find.byWidgetPredicate((w) => w is Draggable<Word> && w.data!.id == target.id);
        final to = tester.getCenter(find.text('Drop Here'));
        await tester.drag(item, to - tester.getCenter(item), warnIfMissed: false);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1100));
      }
      expect(finished, 1);
      expect(targets.toSet().length, 3);
    });
  });

  // ============================================================ ReviewSessionScreen
  group('ReviewSessionScreen', () {
    GoRouter sessionRouter({ReviewMode mode = ReviewMode.smartMix}) => GoRouter(initialLocation: '/home', routes: [
          GoRoute(path: '/home', builder: (_, _) => stub('HOME PAGE')),
          GoRoute(path: '/sleep', builder: (_, _) => stub('SLEEP PAGE')),
          GoRoute(
            path: '/review',
            builder: (_, _) => ReviewSessionScreen(
              mode: mode,
              random: Random(11),
              useBalloonPop: false, // các test chặng này dùng Tap & Find / Drag & Drop; biến thể mới test ở review_games_test
              useFeedMomo: false,
              capture: FakeCapture(),
              recordDuration: const Duration(milliseconds: 300),
            ),
          ),
        ]);

    Future<void> openReview(WidgetTester tester, GoRouter router) async {
      router.push('/review');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    testWidgets('kho < 4 từ → quay về /home an toàn', (tester) async {
      final topics = [
        topic('t01', ['a', 'b', 'c'])
      ];
      final router = sessionRouter();
      await pumpApp(tester, baseOverrides(storageWith(topics, words: 3), topics, audio: FakeAudio()), router);
      await openReview(tester, router);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('HOME PAGE'), findsOneWidget);
      expect(find.byType(ReviewSessionScreen), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('không có hồ sơ → quay về /home', (tester) async {
      final topics = sixWordTopics();
      final st = FakeStorage(stats: {for (final w in topics.expand((t) => t.words)) w.id: due()});
      final router = sessionRouter();
      await pumpApp(tester, baseOverrides(st, topics, audio: FakeAudio()), router);
      await openReview(tester, router);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('HOME PAGE'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('hết giờ chơi → chuyển /sleep', (tester) async {
      final topics = sixWordTopics();
      final router = sessionRouter();
      await pumpApp(tester, baseOverrides(storageWith(topics), topics, audio: FakeAudio(), timeUp: true), router);
      await openReview(tester, router);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('SLEEP PAGE'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('thoát giữa chừng (X → Yes) → về /home và KHÔNG ghi Leitner', (tester) async {
      final topics = sixWordTopics();
      final st = storageWith(topics);
      final router = sessionRouter();
      await pumpApp(tester, baseOverrides(st, topics, audio: FakeAudio()), router);
      await openReview(tester, router);
      expect(find.byType(TapFindActivity), findsOneWidget);
      // làm 1 lượt đúng (outcome có dữ liệu) rồi thoát giữa chừng
      final target = tester.widget<Text>(find.textContaining('Find: ')).data!.substring(6);
      final right = tester.widgetList<MediaImage>(find.byType(MediaImage)).firstWhere((m) => m.label == target);
      await tester.tap(find.byWidgetPredicate((w) => w == right));
      await tester.pump();
      await tester.tap(find.byKey(const Key('review_exit')));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(find.text('Quit review?'), findsOneWidget);
      await tester.tap(find.text('Yes'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('HOME PAGE'), findsOneWidget);
      expect(st.writes, isEmpty);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('chặng 1 dùng wordBaseDirs: ảnh gói có baseDir của gói, ảnh built-in là null', (tester) async {
      final topics = sixWordTopics();
      final router = sessionRouter();
      await pumpApp(tester, baseOverrides(storageWith(topics), topics, audio: FakeAudio()), router);
      await openReview(tester, router);
      final dirs = tester.widgetList<MediaImage>(find.byType(MediaImage)).toList();
      expect(dirs, isNotEmpty);
      for (final m in dirs) {
        expect(m.baseDir, m.path.contains('t06_') ? '/packs/t06' : isNull, reason: m.path);
      }
      await tester.pumpWidget(const SizedBox());
    });

    // Điều khiển từng chặng ---------------------------------------------------
    Future<void> playTapFind(WidgetTester tester, {required bool firstWrong}) async {
      for (var r = 0; r < 6; r++) {
        final target = tester.widget<Text>(find.textContaining('Find: ')).data!.substring(6);
        final cards = find.byType(MediaImage);
        if (r == 0 && firstWrong) {
          final wrong = tester.widgetList<MediaImage>(cards).firstWhere((m) => m.label != target);
          await tester.tap(find.byWidgetPredicate((w) => w == wrong));
          await tester.pump();
        }
        final right = tester.widgetList<MediaImage>(cards).firstWhere((m) => m.label == target);
        await tester.tap(find.byWidgetPredicate((w) => w == right));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1100));
      }
    }

    Future<void> playMemory(WidgetTester tester) async {
      final cards = find.descendant(of: find.byType(Wrap), matching: find.byType(GestureDetector));
      final matched = <int>{};
      final known = <int, String>{};
      String labelAt(int i) =>
          tester.widget<MediaImage>(find.descendant(of: cards.at(i), matching: find.byType(MediaImage))).label;
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
            await tester.pump(const Duration(milliseconds: 1000)); // úp lại
          }
        }
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pump(const Duration(milliseconds: 1100));
    }

    Future<void> playDragDrop(WidgetTester tester) async {
      for (var r = 0; r < 4; r++) {
        final title = tester.widget<Text>(find.textContaining('Drag ')).data!;
        final target = title.substring(5, title.length - ' into the box!'.length);
        final item = find.byWidgetPredicate((w) => w is Draggable<Word> && w.data!.text == target);
        await tester.drag(item, tester.getCenter(find.text('Drop Here')) - tester.getCenter(item), warnIfMissed: false);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1100));
      }
    }

    Future<void> playRepeat(WidgetTester tester) async {
      for (var i = 0; i < 2; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        await tester.tap(find.byKey(const Key('repeat_record_mic')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    testWidgets('chơi trọn phiên: ghi Leitner đúng 1 lần/từ theo lần chấm đầu; Memory/Repeat không ghi', (tester) async {
      final topics = sixWordTopics();
      final st = storageWith(topics);
      final audio = FakeAudio();
      final router = sessionRouter();
      await pumpApp(tester, baseOverrides(st, topics, audio: audio), router);
      await openReview(tester, router);

      expect(find.byType(TapFindActivity), findsOneWidget);
      await playTapFind(tester, firstWrong: true);
      expect(find.byType(MemoryMatchActivity), findsOneWidget);
      expect(st.writes, isEmpty, reason: 'chưa ghi gì trước khi xong cả phiên');

      await playMemory(tester);
      expect(find.byType(DragDropActivity), findsOneWidget);
      await playDragDrop(tester);
      expect(find.byType(RepeatRecordActivity), findsOneWidget);
      expect(st.writes, isEmpty);

      await playRepeat(tester);
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('You are a Review Super Star!'), findsOneWidget);

      // Đã ghi: mỗi từ tối đa 1 lần, chỉ từ trong phiên.
      final ids = st.writes.map((w) => w.$1).toList();
      expect(ids.toSet().length, ids.length, reason: 'mỗi từ ghi tối đa 1 lần');
      expect(ids, isNotEmpty);
      final all = topics.expand((t) => t.words).map((w) => w.id).toSet();
      expect(all.containsAll(ids), isTrue);
      // Lần chấm đầu của Tap&Find là sai → đúng 1 từ bị ghi sai (box về 1, wrong tăng).
      expect(st.writes.where((w) => !w.$2).length, 1);
      final wrongId = st.writes.firstWhere((w) => !w.$2).$1;
      expect(st.stats[wrongId]!.wrong, 1);
      expect(st.stats[wrongId]!.box, 1);
      // Từ ghi đúng (đang đến hạn ở box 1) → lên box 2.
      for (final w in st.writes.where((w) => w.$2)) {
        expect(st.stats[w.$1]!.box, 2, reason: w.$1);
      }

      // Âm thanh: đường dẫn nào có baseDir đúng theo chủ đề chứa nó.
      expect(audio.plays.where((p) => p.$1 != null), isNotEmpty);
      for (final p in audio.plays.where((p) => p.$1 != null && p.$1!.contains('/t0'))) {
        expect(p.$3, p.$1!.contains('t06_') ? '/packs/t06' : isNull, reason: p.$1);
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
