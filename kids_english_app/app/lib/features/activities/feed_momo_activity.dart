import 'dart:math';
import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../core/media.dart';
import '../../data/models.dart';

/// Cho Momo ăn: Momo đòi một món ("Give me... apple!"), bé kéo đúng thẻ vào miệng Momo.
/// Không có ảnh momo_think → dùng momo_idle + lắc đầu khi sai, momo_cheer khi đúng.
class FeedMomoActivity extends StatefulWidget {
  const FeedMomoActivity({
    super.key,
    required this.words,
    required this.baseDir,
    required this.onWordAttempt,
    required this.onFinished,
    required this.playAudio,
    this.rounds = 4,
    this.wordBaseDirs,
  });

  final List<Word> words;
  final int rounds;
  final String? baseDir;

  /// Thư mục gói theo từng từ (ôn tập đa chủ đề). null → dùng [baseDir]; giá trị null = built-in.
  final Map<String, String?>? wordBaseDirs;
  final void Function(String wordId, bool isCorrect) onWordAttempt;
  final VoidCallback onFinished;
  final void Function(String? path, String text) playAudio;

  @override
  State<FeedMomoActivity> createState() => _FeedMomoActivityState();
}

class _FeedMomoActivityState extends State<FeedMomoActivity> {
  String? _dirFor(Word w) => widget.wordBaseDirs != null ? widget.wordBaseDirs![w.id] : widget.baseDir;

  final _random = Random();
  late final List<Word> _order; // thứ tự từ mục tiêu qua các vòng
  late Word _target;
  late List<Word> _cards;
  int _round = 0;
  int _shakes = 0; // tăng mỗi lần kéo nhầm → kích hoạt hoạt ảnh lắc đầu
  bool _locked = false; // đã cho ăn đúng, đang chờ sang vòng kế

  @override
  void initState() {
    super.initState();
    _order = List.of(widget.words)..shuffle(_random);
    _startRound();
  }

  void _startRound() {
    _locked = false;
    _target = _order[_round % _order.length];
    final others = widget.words.where((w) => w.id != _target.id).toList()..shuffle(_random);
    _cards = <Word>[_target, ...others.take(3)]..shuffle(_random); // 3–4 thẻ
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.playAudio(_target.audio, 'Give me... ${_target.text}!');
    });
  }

  void _onDrop(Word dropped) {
    if (_locked) return;
    final isCorrect = dropped.id == _target.id;
    widget.onWordAttempt(_target.id, isCorrect);

    if (isCorrect) {
      _locked = true;
      widget.playAudio(null, 'Yummy! Thank you! ${_target.text}!');
      setState(() {});
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (!mounted) return;
        if (_round + 1 >= widget.rounds) {
          widget.onFinished();
        } else {
          setState(() => _round++);
          _startRound();
        }
      });
    } else {
      // Nói tên thẻ vừa thả rồi nhắc lại mục tiêu — nhẹ nhàng, không báo lỗi gắt.
      widget.playAudio(dropped.audio, dropped.text);
      final round = _round;
      Future.delayed(const Duration(milliseconds: 900), () {
        if (!mounted || _locked || _round != round) return;
        widget.playAudio(_target.audio, 'Give me... ${_target.text}!');
      });
      setState(() => _shakes++);
    }
  }

  Widget _card(Word w, double size, {double alpha = 1}) => Container(
        width: size,
        height: size,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: alpha),
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
        ),
        child: MediaImage(w.image, baseDir: _dirFor(w), label: w.text),
      );

  Widget _momo(double size) {
    final cheer = _locked;
    final image = Image.asset(
      cheer ? 'assets/images/common/momo_cheer.png' : 'assets/images/common/momo_idle.png',
      key: Key(cheer ? 'momo_cheer' : 'momo_idle'),
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => Icon(Icons.pets_rounded, size: size * 0.6, color: AppColors.orange),
    );
    // Lắc đầu: đổi key theo _shakes để chạy lại; _shakes == 0 → đứng yên.
    final shaking = TweenAnimationBuilder<double>(
      key: ValueKey('shake_$_shakes'),
      tween: Tween(begin: 0, end: _shakes == 0 ? 0 : 1),
      duration: const Duration(milliseconds: 500),
      builder: (context, t, child) => Transform.translate(offset: Offset(sin(t * pi * 6) * (1 - t) * 16, 0), child: child),
      child: image,
    );
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        shaking,
        if (cheer)
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 900),
            builder: (context, t, _) => Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                for (var i = 0; i < 6; i++)
                  Transform.translate(
                    offset: Offset((i - 2.5) * size * 0.2, -size * 0.3 - t * size * 0.5),
                    child: Opacity(
                      opacity: 1 - t,
                      child: Icon(
                        i.isEven ? Icons.favorite_rounded : Icons.star_rounded,
                        color: i.isEven ? AppColors.pink : AppColors.yellow,
                        size: 30,
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        // Nhường chỗ cho bong bóng + hàng thẻ.
        final momoSize = (box.maxHeight - 270).clamp(100.0, 220.0);
        return Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Bong bóng suy nghĩ + loa
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3))],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton.filled(
                        key: const Key('momo_speaker'),
                        iconSize: 36,
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.orange,
                          minimumSize: const Size.square(kKidTouch),
                        ),
                        icon: const Icon(Icons.volume_up_rounded, color: Colors.white),
                        onPressed: () => widget.playAudio(_target.audio, 'Give me... ${_target.text}!'),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Give me... ${_target.text}!',
                        key: const Key('momo_prompt'),
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.ink),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${_round + 1}/${widget.rounds}',
                        key: const Key('momo_round'),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black45),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                // Momo = vùng thả
                DragTarget<Word>(
                  key: const Key('momo_target'),
                  onWillAcceptWithDetails: (_) => !_locked,
                  onAcceptWithDetails: (d) => _onDrop(d.data),
                  builder: (context, candidate, _) => AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: candidate.isNotEmpty ? AppColors.yellow.withValues(alpha: 0.5) : Colors.transparent,
                      borderRadius: BorderRadius.circular(32),
                    ),
                    child: _momo(momoSize),
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 14,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final w in _cards)
                      Draggable<Word>(
                        key: Key('momo_card_${w.id}'),
                        data: w,
                        feedback: Material(color: Colors.transparent, child: _card(w, 110, alpha: 0.9)),
                        childWhenDragging: Opacity(opacity: 0.3, child: _card(w, kKidTouch + 25)),
                        child: _card(w, kKidTouch + 25),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
