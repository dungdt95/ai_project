import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/media.dart';
import '../../data/models.dart';

class DiscoverActivity extends StatefulWidget {
  const DiscoverActivity({
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
  State<DiscoverActivity> createState() => _DiscoverActivityState();
}

class _DiscoverActivityState extends State<DiscoverActivity> {
  final _page = PageController();
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _speakCurrent());
  }

  void _speakCurrent() {
    if (widget.words.isEmpty) return;
    final w = widget.words[_index];
    widget.playAudio(w.audio, w.text);
  }

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.words.isEmpty) return const SizedBox.shrink();
    final last = _index == widget.words.length - 1;

    return Stack(
      children: [
        PageView.builder(
          controller: _page,
          itemCount: widget.words.length,
          onPageChanged: (i) {
            setState(() => _index = i);
            _speakCurrent();
          },
          itemBuilder: (ctx, i) {
            final w = widget.words[i];
            return Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: GestureDetector(
                    onTap: () => widget.playAudio(w.audio, w.text),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 16,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            height: 140,
                            width: 140,
                            child: MediaImage(w.image, baseDir: widget.baseDir, label: w.text),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                w.text,
                                style: const TextStyle(
                                  fontSize: 42,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF3D2C2E),
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Icon(Icons.volume_up_rounded, color: Color(0xFFFF9F1C), size: 34),
                            ],
                          ),
                          if (w.sentence.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              w.sentence,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        Positioned(
          bottom: 24,
          right: 32,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF2EC4B6),
              shape: const CircleBorder(),
              padding: const EdgeInsets.all(20),
            ),
            onPressed: () {
              if (!last) {
                _page.nextPage(duration: 300.ms, curve: Curves.easeOut);
              } else {
                widget.onFinished();
              }
            },
            child: Icon(last ? Icons.check_rounded : Icons.arrow_forward_rounded, size: 40),
          ),
        ),
      ],
    );
  }
}
