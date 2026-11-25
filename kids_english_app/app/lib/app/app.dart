import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/models.dart';
import '../data/review_planner.dart';
import '../features/review/review_session_screen.dart';
import '../features/lesson_player/lesson_player_screen.dart';
import '../features/screen_time/bedtime_sleep_screen.dart';
import '../features/screens.dart';
import '../features/songs/song_karaoke_screen.dart';
import 'providers.dart';
import 'theme.dart';

final _router = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (_, _) => const SplashScreen()),
    GoRoute(path: '/profiles', builder: (_, _) => const ProfileSelectScreen()),
    GoRoute(path: '/home', builder: (_, _) => const KidHomeScreen()),
    GoRoute(path: '/topic/:id', builder: (_, s) => TopicScreen(topicId: s.pathParameters['id']!)),
    GoRoute(
      path: '/lesson/:topicId/:lessonId',
      builder: (_, s) => LessonPlayerScreen(topicId: s.pathParameters['topicId']!, lessonId: s.pathParameters['lessonId']!),
    ),
    GoRoute(
      path: '/song/:topicId',
      builder: (context, state) {
        final topicId = state.pathParameters['topicId']!;
        return Consumer(builder: (ctx, ref, _) {
          final topics = ref.watch(topicsProvider).value ?? const <Topic>[];
          final topic = topics.where((t) => t.id == topicId).firstOrNull;
          if (topic == null || topic.song == null) {
            return const Scaffold(body: Center(child: Text("Song not found")));
          }
          return SongKaraokeScreen(song: topic.song!, baseDir: topic.baseDir);
        });
      },
    ),
    GoRoute(
      path: '/review',
      builder: (_, s) => ReviewSessionScreen(
        mode: s.uri.queryParameters['mode'] == 'weak' ? ReviewMode.weakWordsOnly : ReviewMode.smartMix,
      ),
    ),
    GoRoute(path: '/sleep', builder: (_, _) => const BedtimeSleepScreen()),
    GoRoute(path: '/gate', builder: (_, _) => const ParentGateScreen()),
    GoRoute(path: '/parent', builder: (_, _) => const ParentHomeScreen()),
  ],
);

class BeVuiApp extends ConsumerWidget {
  const BeVuiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Kids English',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      routerConfig: _router,
    );
  }
}
