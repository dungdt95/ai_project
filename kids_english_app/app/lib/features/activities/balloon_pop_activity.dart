import 'dart:math';
import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../core/media.dart';
import '../../data/models.dart';

/// Bóng bay: bé chạm vào quả bóng có hình đúng từ được đọc. Bóng bay từ dưới lên, lắc nhẹ;
/// bóng mục tiêu trôi hết màn hình thì bay lại từ dưới (không bao giờ "thua").
class BalloonPopActivity extends StatefulWidget {
  const BalloonPopActivity({
    super.key,
    required this.words,
    required this.allTopicWords,
    required this.baseDir,
    required this.onWordAttempt,
    required this.onFinished,
    required this.playAudio,
    this.rounds = 6,
    this.wordBaseDirs,
  });

  final List<Word> words;
  final List<Word> allTopicWords; // nguồn bóng nhiễu
  final int rounds;
  final String? baseDir;

  /// Thư mục gói theo từng từ (ôn tập đa chủ đề). null → dùng [baseDir]; giá trị null = built-in.
  final Map<String, String?>? wordBaseDirs;
  final void Function(String wordId, bool isCorrect) onWordAttempt;
  final VoidCallback onFinished;
  final void Function(String? path, String text) playAudio;

  @override
  State<BalloonPopActivity> createState() => _BalloonPopActivityState();
}

class _BalloonPopActivityState extends State<BalloonPopActivity> with TickerProviderStateMixin {
  static const _balloonW = 130.0;
  static const _balloonH = 160.0;
  static const _colors = [Color(0xFFFFB3C7), Color(0xFFB9E4FF), Color(0xFFFFE08A), Color(0xFFC4F0C5), Color(0xFFD9C7FF)];

  String? _dirFor(Word w) => widget.wordBaseDirs != null ? widget.wordBaseDirs![w.id] : widget.baseDir;

  final _random = Random();
  late final AnimationController _float; // bóng trôi lên, ~8 giây/lượt, lặp mãi
  late final AnimationController _bounce; // bóng chạm nhầm nảy lên
  late final List<Word> _order;
  late Word _target;
  late List<Word> _balloons;
  late List<double> _phases;
  int _round = 0;
  int _wrongs = 0; // số lần chạm nhầm trong vòng này
  bool _locked = false; // đã chạm đúng, đang pop + chờ sang vòng kế
  String? _bounceId;

  @override
  void initState() {
    super.initState();
    _float = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat();
    _bounce = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
    _order = List.of(widget.words)..shuffle(_random);
    _startRound();
  }

  @override
  void dispose() {
    _float.dispose();
    _bounce.dispose();
    super.dispose();
  }

  void _startRound() {
    _locked = false;
    _wrongs = 0;
    _bounceId = null;
    _target = _order[_round % _order.length];
    final pool = widget.allTopicWords.where((w) => w.id != _target.id).toList()..shuffle(_random);
    final count = _round < 3 ? 3 : 4; // thích ứng nhẹ: 3 bóng rồi 4 bóng
    final list = <Word>[_target, ...pool.take(count - 1)]..shuffle(_random);
    _balloons = list;
    // Mỗi bóng một "độ cao" khởi đầu khác nhau, đều nằm trong màn hình.
    final n = list.length;
    _phases = List.generate(n, (i) => 0.2 + 0.6 * i / max(1, n - 1))..shuffle(_random);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.playAudio(_target.audio, 'Pop ${_target.text}!');
    });
  }

  void _onTapBalloon(Word w) {
    if (_locked) return; // đang pop: bỏ qua chạm thêm (không đếm đôi)
    final isCorrect = w.id == _target.id;
    widget.onWordAttempt(_target.id, isCorrect);

    if (isCorrect) {
      _locked = true;
      widget.playAudio(null, "Pop! Good job! That's ${_target.text}!");
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
      // Nói tên quả bóng vừa chạm, rồi nhắc lại mục tiêu (nhẹ nhàng, không báo lỗi gắt).
      widget.playAudio(w.audio, w.text);
      final round = _round;
      Future.delayed(const Duration(milliseconds: 900), () {
        if (!mounted || _locked || _round != round) return;
        widget.playAudio(_target.audio, 'Find ${_target.text}!');
      });
      setState(() {
        _wrongs++;
        _bounceId = w.id;
      });
      _bounce.forward(from: 0);
    }
  }

  Widget _balloonBody(Word w, int index, bool hint) {
    final color = _colors[index % _colors.length];
    return SizedBox(
      width: _balloonW,
      height: _balloonH,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            bottom: 0,
            child: Container(width: 3, height: 30, color: Colors.white70), // dây bóng
          ),
          Container(
            key: hint ? const Key('balloon_hint') : null,
            width: _balloonW,
            height: _balloonH - 22,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.all(Radius.elliptical(_balloonW, _balloonH - 22)),
              border: Border.all(color: hint ? AppColors.yellow : Colors.white, width: hint ? 6 : 3),
              boxShadow: [
                if (hint) const BoxShadow(color: AppColors.yellow, blurRadius: 24, spreadRadius: 6),
                const BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4)),
              ],
            ),
            child: MediaImage(w.image, baseDir: _dirFor(w), label: w.text),
          ),
        ],
      ),
    );
  }

  Widget _popEffect(Widget balloon) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 450),
      builder: (context, t, _) => Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Opacity(opacity: 1 - t, child: Transform.scale(scale: 1 + 0.5 * t, child: balloon)),
          for (var i = 0; i < 6; i++)
            Transform.translate(
              offset: Offset(cos(i * pi / 3) * 90 * t, sin(i * pi / 3) * 90 * t),
              child: Opacity(
                opacity: 1 - t,
                child: Icon(i.isEven ? Icons.star_rounded : Icons.favorite_rounded, color: AppColors.yellow, size: 30),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFBFE6FF), Color(0xFFFFF4E0)],
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton.filled(
                  key: const Key('balloon_speaker'),
                  iconSize: 44,
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.orange,
                    minimumSize: const Size.square(kKidTouch),
                  ),
                  icon: const Icon(Icons.volume_up_rounded, color: Colors.white),
                  onPressed: () => widget.playAudio(_target.audio, 'Pop ${_target.text}!'),
                ),
                const SizedBox(width: 12),
                Text(
                  'Pop: ${_target.text}',
                  style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: AppColors.ink),
                ),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(color: Colors.white70, borderRadius: BorderRadius.circular(16)),
                  child: Text(
                    '${_round + 1} / ${widget.rounds}',
                    key: const Key('balloon_round'),
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.ink),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ClipRect(
              child: LayoutBuilder(
                builder: (context, box) {
                  final w = box.maxWidth;
                  final h = box.maxHeight;
                  final n = _balloons.length;
                  return AnimatedBuilder(
                    animation: Listenable.merge([_float, _bounce]),
                    builder: (context, _) {
                      return Stack(
                        children: [
                          for (var i = 0; i < n; i++)
                            _positioned(i, w, h, n),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _positioned(int i, double areaW, double areaH, int n) {
    final word = _balloons[i];
    final p = (_float.value + _phases[i]) % 1.0; // 0 = ngay dưới màn hình, 1 = vừa khuất đỉnh
    final slot = areaW / n;
    final sway = sin(2 * pi * (p * 2 + i * 0.25)) * 18;
    var top = areaH - p * (areaH + _balloonH);
    if (_bounceId == word.id) top -= sin(pi * _bounce.value) * 30; // nảy khi chạm nhầm
    final left = slot * i + (slot - _balloonW) / 2 + sway;
    final isTarget = word.id == _target.id;
    final hint = isTarget && _wrongs >= 2 && !_locked;
    final popping = _locked && isTarget;
    Widget body = _balloonBody(word, i, hint);
    if (popping) body = _popEffect(body);
    return Positioned(
      key: ValueKey('balloon_pos_${word.id}'),
      left: left,
      top: top,
      width: _balloonW,
      height: _balloonH,
      child: GestureDetector(
        key: Key('balloon_${word.id}'),
        behavior: HitTestBehavior.opaque,
        onTap: () => _onTapBalloon(word),
        child: body,
      ),
    );
  }
}
