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
    this.wordBaseDirs,
    this.rounds = 1,
  });

  final List<Word> words;
  final String? baseDir;

  /// Thư mục gói theo từng từ (ôn tập đa chủ đề). null → dùng [baseDir]; giá trị null = built-in.
  final Map<String, String?>? wordBaseDirs;

  /// Số vòng kéo thả liên tiếp (mỗi vòng một từ mục tiêu khác nhau khi đủ từ). Mặc định 1 = hành vi cũ.
  final int rounds;
  final void Function(String wordId, bool isCorrect) onWordAttempt;
  final VoidCallback onFinished;
  final void Function(String? path, String text) playAudio;

  @override
  State<DragDropActivity> createState() => _DragDropActivityState();
}

class _DragDropActivityState extends State<DragDropActivity> {
  String? _dirFor(Word w) => widget.wordBaseDirs != null ? widget.wordBaseDirs![w.id] : widget.baseDir;

  final _random = Random();
  late final List<Word> _order; // thứ tự từ mục tiêu qua các vòng
  late Word _targetWord;
  late List<Word> _items;
  int _round = 0;
  bool _locked = false; // đã kéo đúng, đang chờ sang vòng kế

  @override
  void initState() {
    super.initState();
    _order = List.of(widget.words)..shuffle(_random);
    _startRound();
  }

  void _startRound() {
    _locked = false;
    _targetWord = _order[_round % _order.length];
    _items = List.of(widget.words)..shuffle(_random);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.playAudio(_targetWord.audio, "Put ${_targetWord.text} into the magic box!");
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Drag ${_targetWord.text} into the box!",
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFF3D2C2E)),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Items to drag
                Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: _items.map((w) {
                    return Draggable<Word>(
                      data: w,
                      feedback: Material(
                        color: Colors.transparent,
                        child: Container(
                          width: 110,
                          height: 110,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
                          ),
                          child: MediaImage(w.image, baseDir: _dirFor(w), label: w.text),
                        ),
                      ),
                      childWhenDragging: Opacity(
                        opacity: 0.3,
                        child: Container(
                          width: 105,
                          height: 105,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: MediaImage(w.image, baseDir: _dirFor(w), label: w.text),
                        ),
                      ),
                      child: Container(
                        width: 105,
                        height: 105,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
                        ),
                        child: MediaImage(w.image, baseDir: _dirFor(w), label: w.text),
                      ),
                    );
                  }).toList(),
                ),

                // Drop Target
                DragTarget<Word>(
                  onWillAcceptWithDetails: (details) => true,
                  onAcceptWithDetails: (details) {
                    if (_locked) return;
                    final droppedWord = details.data;
                    final isCorrect = droppedWord.id == _targetWord.id;
                    widget.onWordAttempt(_targetWord.id, isCorrect);

                    if (isCorrect) {
                      _locked = true;
                      widget.playAudio(null, "Yes! That's ${_targetWord.text}!");
                      Future.delayed(1000.ms, () {
                        if (!mounted) return;
                        if (_round + 1 >= widget.rounds) {
                          widget.onFinished();
                        } else {
                          setState(() => _round++);
                          _startRound();
                        }
                      });
                    } else {
                      widget.playAudio(null, "Not that one! Try again!");
                    }
                  },
                  builder: (context, candidateData, rejectedData) {
                    final isHovered = candidateData.isNotEmpty;
                    return AnimatedContainer(
                      duration: 200.ms,
                      width: 145,
                      height: 145,
                      decoration: BoxDecoration(
                        color: isHovered ? const Color(0xFFFFD23F) : const Color(0xFF2EC4B6),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: Colors.white, width: 4),
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))],
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox_rounded, size: 56, color: Colors.white),
                          SizedBox(height: 6),
                          Text("Drop Here", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
