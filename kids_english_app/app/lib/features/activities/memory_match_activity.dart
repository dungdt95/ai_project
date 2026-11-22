import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/media.dart';
import '../../data/models.dart';

class _CardItem {
  _CardItem({required this.word, required this.id});
  final Word word;
  final int id;
  bool isFaceUp = false;
  bool isMatched = false;
}

class MemoryMatchActivity extends StatefulWidget {
  const MemoryMatchActivity({
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
  State<MemoryMatchActivity> createState() => _MemoryMatchActivityState();
}

class _MemoryMatchActivityState extends State<MemoryMatchActivity> {
  late List<_CardItem> _cards;
  _CardItem? _firstSelected;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final list = <_CardItem>[];
    int idCounter = 0;
    for (final w in widget.words.take(3)) {
      list.add(_CardItem(word: w, id: idCounter++));
      list.add(_CardItem(word: w, id: idCounter++));
    }
    list.shuffle();
    _cards = list;
  }

  void _onCardTap(_CardItem card) {
    if (_busy || card.isFaceUp || card.isMatched) return;

    setState(() => card.isFaceUp = true);
    widget.playAudio(card.word.audio, card.word.text);

    if (_firstSelected == null) {
      _firstSelected = card;
    } else {
      final first = _firstSelected!;
      _firstSelected = null;
      if (first.word.id == card.word.id) {
        // Matched!
        widget.playAudio(null, "Match! ${card.word.text}!");
        setState(() {
          first.isMatched = true;
          card.isMatched = true;
        });
        if (_cards.every((c) => c.isMatched)) {
          Future.delayed(1000.ms, widget.onFinished);
        }
      } else {
        // Not matched
        _busy = true;
        Future.delayed(900.ms, () {
          if (!mounted) return;
          setState(() {
            first.isFaceUp = false;
            card.isFaceUp = false;
            _busy = false;
          });
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            "Find the matching pairs!",
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFF3D2C2E)),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            alignment: WrapAlignment.center,
            children: _cards.map((card) {
              return GestureDetector(
                onTap: () => _onCardTap(card),
                child: AnimatedContainer(
                  duration: 300.ms,
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    color: card.isMatched
                        ? const Color(0xFFE8F5E9)
                        : (card.isFaceUp ? Colors.white : const Color(0xFFFF9F1C)),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: card.isMatched ? const Color(0xFF4CAF50) : const Color(0xFF3D2C2E),
                      width: 3,
                    ),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4)),
                    ],
                  ),
                  child: Center(
                    child: card.isFaceUp || card.isMatched
                        ? Padding(
                            padding: const EdgeInsets.all(12),
                            child: MediaImage(card.word.image, baseDir: widget.baseDir, label: card.word.text),
                          )
                        : const Text('❓', style: TextStyle(fontSize: 48)),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
