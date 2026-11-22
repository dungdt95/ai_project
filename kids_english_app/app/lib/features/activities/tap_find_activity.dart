import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/media.dart';
import '../../data/models.dart';

class TapFindActivity extends StatefulWidget {
  const TapFindActivity({
    super.key,
    required this.words,
    required this.allTopicWords,
    required this.rounds,
    required this.baseDir,
    required this.onWordAttempt,
    required this.onFinished,
    required this.playAudio,
  });

  final List<Word> words;
  final List<Word> allTopicWords;
  final int rounds;
  final String? baseDir;
  final void Function(String wordId, bool isCorrect) onWordAttempt;
  final VoidCallback onFinished;
  final void Function(String? path, String text) playAudio;

  @override
  State<TapFindActivity> createState() => _TapFindActivityState();
}

class _TapFindActivityState extends State<TapFindActivity> {
  final _random = Random();
  late Word _targetWord;
  late List<Word> _choices;
  int _currentRound = 0;
  int _consecutiveCorrect = 0;
  int _consecutiveWrong = 0;
  int _choicesCount = 2; // Thích ứng: 2 -> 3 -> 4
  bool _showHint = false;

  @override
  void initState() {
    super.initState();
    _startRound();
  }

  void _startRound() {
    _showHint = false;
    _targetWord = widget.words[_random.nextInt(widget.words.length)];

    final distractorPool = widget.allTopicWords.where((w) => w.id != _targetWord.id).toList();
    distractorPool.shuffle(_random);

    final choices = <Word>[_targetWord];
    for (var i = 0; i < _choicesCount - 1 && i < distractorPool.length; i++) {
      choices.add(distractorPool[i]);
    }
    choices.shuffle(_random);
    _choices = choices;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.playAudio(
        _targetWord.audio,
        "Where is ${_targetWord.text}?",
      );
    });
  }

  void _onTapChoice(Word word) {
    final isCorrect = word.id == _targetWord.id;
    widget.onWordAttempt(_targetWord.id, isCorrect);

    if (isCorrect) {
      widget.playAudio(null, "Good job! That's ${_targetWord.text}!");
      setState(() {
        _consecutiveCorrect++;
        _consecutiveWrong = 0;
        if (_consecutiveCorrect >= 3 && _choicesCount < 4) {
          _choicesCount++;
          _consecutiveCorrect = 0;
        }
      });

      Future.delayed(1000.ms, () {
        if (!mounted) return;
        if (_currentRound + 1 >= widget.rounds) {
          widget.onFinished();
        } else {
          setState(() {
            _currentRound++;
          });
          _startRound();
        }
      });
    } else {
      widget.playAudio(null, "Oops! Try again!");
      setState(() {
        _consecutiveWrong++;
        _consecutiveCorrect = 0;
        if (_consecutiveWrong >= 2) {
          _showHint = true;
          if (_choicesCount > 2) _choicesCount--;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton.filled(
                    iconSize: 40,
                    style: IconButton.styleFrom(backgroundColor: const Color(0xFFFF9F1C)),
                    icon: const Icon(Icons.volume_up_rounded, color: Colors.white),
                    onPressed: () => widget.playAudio(_targetWord.audio, "Where is ${_targetWord.text}?"),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    "Find: ${_targetWord.text}",
                    style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: Color(0xFF3D2C2E)),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 20,
                runSpacing: 20,
                alignment: WrapAlignment.center,
                children: _choices.map((w) {
                  final isTarget = w.id == _targetWord.id;
                  Widget card = GestureDetector(
                    onTap: () => _onTapChoice(w),
                    child: Container(
                      width: 140,
                      height: 140,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _showHint && isTarget ? const Color(0xFFFFD23F) : Colors.transparent,
                          width: 4,
                        ),
                        boxShadow: const [
                          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4)),
                        ],
                      ),
                      child: MediaImage(w.image, baseDir: widget.baseDir, label: w.text),
                    ),
                  );

                  if (_showHint && isTarget) {
                    card = card.animate(onPlay: (c) => c.repeat(reverse: true)).scale(
                      begin: const Offset(1, 1),
                      end: const Offset(1.08, 1.08),
                      duration: 500.ms,
                    );
                  }
                  return card;
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
