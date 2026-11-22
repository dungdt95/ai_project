import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/media.dart';
import '../../data/models.dart';

class SimonSaysActivity extends StatefulWidget {
  const SimonSaysActivity({
    super.key,
    required this.commands,
    required this.baseDir,
    required this.onFinished,
    required this.playAudio,
  });

  final List<Command> commands;
  final String? baseDir;
  final VoidCallback onFinished;
  final void Function(String? path, String text) playAudio;

  @override
  State<SimonSaysActivity> createState() => _SimonSaysActivityState();
}

class _SimonSaysActivityState extends State<SimonSaysActivity> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _speakCommand());
  }

  void _speakCommand() {
    if (widget.commands.isEmpty) return;
    final cmd = widget.commands[_index];
    widget.playAudio(cmd.audio, cmd.text);
  }

  void _next() {
    if (_index + 1 < widget.commands.length) {
      setState(() => _index++);
      _speakCommand();
    } else {
      widget.onFinished();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.commands.isEmpty) {
      widget.onFinished();
      return const SizedBox.shrink();
    }
    final cmd = widget.commands[_index];

    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Let's move together!",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF3D2C2E)),
              ),
              const SizedBox(height: 8),
              Text(
                cmd.text,
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFFFF9F1C)),
              ).animate(key: ValueKey(cmd.id)).scale(curve: Curves.elasticOut),
              const SizedBox(height: 12),
              SizedBox(
                width: 140,
                height: 140,
                child: MediaImage(cmd.image, baseDir: widget.baseDir, label: cmd.text),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2EC4B6),
                  padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 12),
                ),
                onPressed: _next,
                icon: const Icon(Icons.check_circle_rounded, size: 30),
                label: const Text("I did it!", style: TextStyle(fontSize: 22)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
