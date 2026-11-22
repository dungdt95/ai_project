import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/media.dart';
import '../../data/models.dart';

class RepeatRecordActivity extends StatefulWidget {
  const RepeatRecordActivity({
    super.key,
    required this.words,
    required this.baseDir,
    required this.onFinished,
    required this.playAudio,
  });

  final List<Word> words;
  final String? baseDir;
  final VoidCallback onFinished;
  final void Function(String? path, String text) playAudio;

  @override
  State<RepeatRecordActivity> createState() => _RepeatRecordActivityState();
}

class _RepeatRecordActivityState extends State<RepeatRecordActivity> {
  int _index = 0;
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _promptWord());
  }

  void _promptWord() {
    if (widget.words.isEmpty) return;
    final w = widget.words[_index];
    widget.playAudio(w.audio, "Say: ${w.text}!");
  }

  void _toggleRecord() {
    setState(() => _isRecording = !_isRecording);

    if (_isRecording) {
      widget.playAudio(null, "I'm listening!");
      // Tự động dừng sau 3 giây và khen
      Future.delayed(3000.ms, () {
        if (!mounted || !_isRecording) return;
        setState(() => _isRecording = false);
        widget.playAudio(null, "Awesome! You sound great!");
        Future.delayed(1200.ms, () {
          if (!mounted) return;
          if (_index + 1 < widget.words.length) {
            setState(() => _index++);
            _promptWord();
          } else {
            widget.onFinished();
          }
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.words.isEmpty) return const SizedBox.shrink();
    final w = widget.words[_index];

    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Say it loud: ${w.text}!",
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFF3D2C2E)),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 140,
                    height: 140,
                    child: MediaImage(w.image, baseDir: widget.baseDir, label: w.text),
                  ),
                  const SizedBox(width: 24),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: _toggleRecord,
                        child: AnimatedContainer(
                          duration: 300.ms,
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                            color: _isRecording ? Colors.red : const Color(0xFFFF9F1C),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: (_isRecording ? Colors.red : const Color(0xFFFF9F1C)).withValues(alpha: 0.4),
                                blurRadius: 16,
                                spreadRadius: _isRecording ? 6 : 2,
                              ),
                            ],
                          ),
                          child: Icon(
                            _isRecording ? Icons.mic : Icons.mic_none_rounded,
                            color: Colors.white,
                            size: 46,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isRecording ? "Listening..." : "Tap to Speak",
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF3D2C2E)),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
