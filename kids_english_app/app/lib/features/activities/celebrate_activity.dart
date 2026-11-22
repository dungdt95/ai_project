import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/media.dart';

class CelebrateActivity extends StatefulWidget {
  const CelebrateActivity({
    super.key,
    required this.stickerPath,
    required this.baseDir,
    required this.onFinished,
    required this.playAudio,
  });

  final String? stickerPath;
  final String? baseDir;
  final VoidCallback onFinished;
  final void Function(String? path, String text) playAudio;

  @override
  State<CelebrateActivity> createState() => _CelebrateActivityState();
}

class _CelebrateActivityState extends State<CelebrateActivity> {
  late ConfettiController _confetti;

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 3));
    _confetti.play();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.playAudio(
        'audio/instructions/celebrate_sticker.mp3',
        "Hooray! You finished the lesson! Good job!",
      );
    });
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confetti,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            colors: const [
              Color(0xFFFF9F1C),
              Color(0xFF2EC4B6),
              Color(0xFFFF6B9A),
              Color(0xFFFFD23F),
            ],
          ),
        ),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🌟🌟🌟', style: TextStyle(fontSize: 52))
                  .animate()
                  .scale(duration: 500.ms, curve: Curves.elasticOut),
              const SizedBox(height: 12),
              const Text(
                "You are amazing!",
                style: TextStyle(fontSize: 38, fontWeight: FontWeight.w900, color: Color(0xFF3D2C2E)),
              ),
              const SizedBox(height: 24),
              if (widget.stickerPath != null)
                Container(
                  width: 160,
                  height: 160,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 16)],
                    border: Border.all(color: const Color(0xFFFFD23F), width: 6),
                  ),
                  child: MediaImage(widget.stickerPath!, baseDir: widget.baseDir, label: "Sticker"),
                ).animate().rotate(duration: 800.ms, curve: Curves.easeOutBack),
              const SizedBox(height: 32),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFF9F1C),
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 20),
                ),
                onPressed: widget.onFinished,
                child: const Text("Finish!", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              ).animate().scale(delay: 500.ms),
            ],
          ),
        ),
      ],
    );
  }
}
