import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../data/models.dart';

class WarmupActivity extends StatefulWidget {
  const WarmupActivity({
    super.key,
    required this.lesson,
    required this.onFinished,
    required this.playAudio,
  });

  final Lesson lesson;
  final VoidCallback onFinished;
  final void Function(String? path, String text) playAudio;

  @override
  State<WarmupActivity> createState() => _WarmupActivityState();
}

class _WarmupActivityState extends State<WarmupActivity> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.playAudio(
        'audio/instructions/warmup_start.mp3',
        "Hello! Are you ready? Let's start!",
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🐵', style: TextStyle(fontSize: 100))
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scale(
                begin: const Offset(1, 1),
                end: const Offset(1.15, 1.15),
                duration: 800.ms,
                curve: Curves.easeInOut,
              )
              .shake(hz: 2, curve: Curves.easeInOut),
          const SizedBox(height: 16),
          const Text(
            "Hello! Are you ready?",
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w900,
              color: Color(0xFF3D2C2E),
            ),
          ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.2, end: 0),
          const SizedBox(height: 24),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFF9F1C),
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
            ),
            onPressed: widget.onFinished,
            icon: const Icon(Icons.play_arrow_rounded, size: 40),
            label: const Text("I'm Ready!", style: TextStyle(fontSize: 28)),
          ).animate(delay: 500.ms).scale(curve: Curves.elasticOut),
        ],
      ),
    );
  }
}
