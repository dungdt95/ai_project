import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/media.dart';
import '../../data/models.dart';

class DragDropActivity extends StatefulWidget {
  const DragDropActivity({
    super.key,
    required this.words,
    required this.baseDir,
    required this.onWordAttempt,
    required this.onFinished,
    required this.playAudio,
  });

  final List<Word> words;
  final String? baseDir;
  final void Function(String wordId, bool isCorrect) onWordAttempt;
  final VoidCallback onFinished;
  final void Function(String? path, String text) playAudio;

  @override
  State<DragDropActivity> createState() => _DragDropActivityState();
}

class _DragDropActivityState extends State<DragDropActivity> {
  final _random = Random();
  late Word _targetWord;
  late List<Word> _items;

  @override
  void initState() {
    super.initState();
    _startRound();
  }

  void _startRound() {
    _targetWord = widget.words[_random.nextInt(widget.words.length)];
    _items = List.of(widget.words)..shuffle(_random);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.playAudio(_targetWord.audio, "Put ${_targetWord.text} into the magic box!");
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "Drag ${_targetWord.text} into the box!",
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFF3D2C2E)),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Items to drag
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: _items.map((w) {
                  return Draggable<Word>(
                    data: w,
                    feedback: Material(
                      color: Colors.transparent,
                      child: Container(
                        width: 130,
                        height: 130,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 12)],
                        ),
                        child: MediaImage(w.image, baseDir: widget.baseDir, label: w.text),
                      ),
                    ),
                    childWhenDragging: Opacity(
                      opacity: 0.3,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: MediaImage(w.image, baseDir: widget.baseDir, label: w.text),
                      ),
                    ),
                    child: Container(
                      width: 120,
                      height: 120,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
                      ),
                      child: MediaImage(w.image, baseDir: widget.baseDir, label: w.text),
                    ),
                  );
                }).toList(),
              ),

              // Drop Target
              DragTarget<Word>(
                onWillAcceptWithDetails: (details) => true,
                onAcceptWithDetails: (details) {
                  final droppedWord = details.data;
                  final isCorrect = droppedWord.id == _targetWord.id;
                  widget.onWordAttempt(_targetWord.id, isCorrect);

                  if (isCorrect) {
                    widget.playAudio(null, "Yes! That's ${_targetWord.text}!");
                    Future.delayed(1000.ms, widget.onFinished);
                  } else {
                    widget.playAudio(null, "Not that one! Try again!");
                  }
                },
                builder: (context, candidateData, rejectedData) {
                  final isHovered = candidateData.isNotEmpty;
                  return AnimatedContainer(
                    duration: 200.ms,
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      color: isHovered ? const Color(0xFFFFD23F) : const Color(0xFF2EC4B6),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(color: Colors.white, width: 4),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))],
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox_rounded, size: 72, color: Colors.white),
                        SizedBox(height: 8),
                        Text("Drop Here", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
