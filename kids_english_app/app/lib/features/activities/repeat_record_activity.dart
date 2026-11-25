import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/media.dart';
import '../../data/models.dart';
import 'speech_capture.dart';

/// Bé nghe Momo đọc → bấm micro → nói (tối đa 3 giây) → app phát lại giọng bé → khen.
/// Không chấm phát âm (trẻ nhỏ + nhận diện giọng kém chính xác) nhưng PHẢI có tiếng nói mới qua:
/// im lặng → "I can't hear you!" và thử lại; sau [maxSilentTries] lần vẫn cho qua để bé không bị kẹt.
class RepeatRecordActivity extends StatefulWidget {
  const RepeatRecordActivity({
    super.key,
    required this.words,
    required this.baseDir,
    required this.onFinished,
    required this.playAudio,
    this.capture,
    this.recordDuration = const Duration(seconds: 3),
    this.wordBaseDirs,
  });

  final List<Word> words;
  final String? baseDir;

  /// Thư mục gói theo từng từ (ôn tập đa chủ đề). null → dùng [baseDir]; giá trị null = built-in.
  final Map<String, String?>? wordBaseDirs;
  final VoidCallback onFinished;
  final Future<void> Function(String? path, String text) playAudio;

  /// Bộ ghi âm; null → dùng micro thật ([RecordSpeechCapture]).
  final SpeechCapture? capture;
  final Duration recordDuration;

  /// Ngưỡng coi là "có tiếng nói" (dBFS). Tiếng ồn phòng thường < -45, giọng nói gần máy ~ -30..-10.
  static const double voiceThresholdDb = -38;

  /// Cần ít nhất ngần này mẫu (mỗi mẫu ~100ms) vượt ngưỡng → khoảng 0,2 giây có tiếng.
  static const int minVoicedSamples = 2;
  static const int maxSilentTries = 3;

  @override
  State<RepeatRecordActivity> createState() => _RepeatRecordActivityState();
}

enum _Phase { prompting, idle, listening, playingBack, feedback }

class _RepeatRecordActivityState extends State<RepeatRecordActivity> {
  String? _dirFor(Word w) => widget.wordBaseDirs != null ? widget.wordBaseDirs![w.id] : widget.baseDir;

  late final SpeechCapture _capture = widget.capture ?? RecordSpeechCapture();
  int _index = 0;
  _Phase _phase = _Phase.prompting;
  int _silentTries = 0;
  int _voicedSamples = 0;
  double _level = 0; // 0..1 để vẽ thanh âm lượng
  bool? _micAllowed;
  Timer? _stopTimer;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _promptWord());
  }

  @override
  void dispose() {
    _disposed = true;
    _stopTimer?.cancel();
    _capture.dispose();
    super.dispose();
  }

  bool get _alive => mounted && !_disposed;

  void _setPhase(_Phase p) {
    if (_alive) setState(() => _phase = p);
  }

  Future<void> _promptWord() async {
    if (widget.words.isEmpty) return;
    _setPhase(_Phase.prompting);
    final w = widget.words[_index];
    await widget.playAudio(w.audio, "Say: ${w.text}!");
    _setPhase(_Phase.idle);
  }

  Future<void> _onMicTap() async {
    if (_phase == _Phase.listening) {
      await _finishListening();
      return;
    }
    if (_phase != _Phase.idle) return;

    _micAllowed ??= await _capture.ensurePermission();
    if (!_alive) return;
    if (_micAllowed != true) {
      // Không có micro: vẫn khen và cho qua để bài học không bị kẹt.
      await _praiseAndNext(playback: null);
      return;
    }

    _voicedSamples = 0;
    _level = 0;
    try {
      await _capture.start(_onLevel);
    } catch (_) {
      _micAllowed = false;
      await _praiseAndNext(playback: null);
      return;
    }
    if (!_alive) return;
    _setPhase(_Phase.listening);
    _stopTimer = Timer(widget.recordDuration, _finishListening);
  }

  void _onLevel(double dbfs) {
    if (dbfs > RepeatRecordActivity.voiceThresholdDb) _voicedSamples++;
    if (!_alive) return;
    // -60 dB → 0, 0 dB → 1
    setState(() => _level = ((dbfs + 60) / 60).clamp(0.0, 1.0));
  }

  Future<void> _finishListening() async {
    if (_phase != _Phase.listening) return;
    _stopTimer?.cancel();
    _setPhase(_Phase.feedback);
    final path = await _capture.stop();
    if (!_alive) return;
    setState(() => _level = 0);

    final heardVoice = _voicedSamples >= RepeatRecordActivity.minVoicedSamples;
    if (heardVoice) {
      await _praiseAndNext(playback: path);
      return;
    }

    _silentTries++;
    if (_silentTries >= RepeatRecordActivity.maxSilentTries) {
      await widget.playAudio(null, "Good try! Let's keep going!");
      await _next();
    } else {
      await widget.playAudio(null, "I can't hear you! Let's try again!");
      if (_alive) await _promptWord();
    }
  }

  Future<void> _praiseAndNext({required String? playback}) async {
    if (playback != null) {
      _setPhase(_Phase.playingBack);
      await _capture.playBack(playback);
      if (!_alive) return;
    }
    _setPhase(_Phase.feedback);
    await widget.playAudio(null, "Awesome! You sound great!");
    await _next();
  }

  Future<void> _next() async {
    if (!_alive) return;
    _silentTries = 0;
    if (_index + 1 < widget.words.length) {
      setState(() => _index++);
      await _promptWord();
    } else {
      widget.onFinished();
    }
  }

  String get _hint => switch (_phase) {
        _Phase.prompting => "Listen...",
        _Phase.idle => _silentTries > 0 ? "Try again! Tap to Speak" : "Tap to Speak",
        _Phase.listening => "Listening...",
        _Phase.playingBack => "That's you!",
        _Phase.feedback => "",
      };

  @override
  Widget build(BuildContext context) {
    if (widget.words.isEmpty) return const SizedBox.shrink();
    final w = widget.words[_index];
    final listening = _phase == _Phase.listening;
    final enabled = _phase == _Phase.idle || listening;
    final color = listening ? Colors.red : (enabled ? const Color(0xFFFF9F1C) : Colors.grey);

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
                    child: MediaImage(w.image, baseDir: _dirFor(w), label: w.text),
                  ),
                  const SizedBox(width: 24),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        key: const Key('repeat_record_mic'),
                        onTap: enabled ? _onMicTap : null,
                        child: AnimatedContainer(
                          duration: 150.ms,
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: color.withValues(alpha: 0.4),
                                blurRadius: 16,
                                spreadRadius: listening ? 4 + _level * 18 : 2,
                              ),
                            ],
                          ),
                          child: Icon(
                            _phase == _Phase.playingBack
                                ? Icons.volume_up_rounded
                                : (listening ? Icons.mic : Icons.mic_none_rounded),
                            color: Colors.white,
                            size: 46,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _hint,
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
