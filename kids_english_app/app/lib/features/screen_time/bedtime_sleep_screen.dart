import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/providers.dart';

class BedtimeSleepScreen extends ConsumerStatefulWidget {
  const BedtimeSleepScreen({super.key});

  @override
  ConsumerState<BedtimeSleepScreen> createState() => _BedtimeSleepScreenState();
}

class _BedtimeSleepScreenState extends ConsumerState<BedtimeSleepScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(audioProvider).instruction(
        'audio/instructions/time_up_sleep.mp3',
        "Yawn! I'm sleepy now. Time to rest your eyes and play outside! Bye-bye! See you tomorrow!",
        viPath: 'audio/vi/time_up_vi.mp3',
        viText: "Bạn Momo buồn ngủ rồi. Mình cất máy và ra ngoài chơi cùng bố mẹ nhé! Hẹn gặp bé ngày mai!",
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E293B), // Màu xanh tím đêm dịu mắt
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Trăng sao và Momo ngủ
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🌙', style: TextStyle(fontSize: 70))
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .scale(begin: const Offset(1, 1), end: const Offset(1.1, 1.1), duration: 2.seconds),
                  const SizedBox(width: 16),
                  const Text('🐵💤', style: TextStyle(fontSize: 90))
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .moveY(begin: 0, end: -10, duration: 1500.ms),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                "Momo is Sleepy!",
                style: TextStyle(
                  fontSize: 44,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFFFFD23F),
                ),
              ),
              const SizedBox(height: 12),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  "Great job today! Time to rest your eyes and play outside with Mommy and Daddy.\nSee you tomorrow! 👋",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: Colors.white70,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 36),
              // Nút phụ huynh mở khóa thêm giờ nếu cần
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Colors.white38),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                onPressed: () => context.push('/gate'),
                icon: const Icon(Icons.lock_outline, size: 20),
                label: const Text("Parent Options", style: TextStyle(fontSize: 18)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
