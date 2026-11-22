import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:just_audio/just_audio.dart';

/// Phát giọng đọc: ưu tiên file thật (asset hoặc file trong gói chủ đề),
/// thiếu file thì tự động đọc bằng TTS en-US để không chặn việc dev.
class AudioService {
  AudioService({required bool Function() viHintsEnabled}) : _viEnabled = viHintsEnabled;

  final bool Function() _viEnabled;
  final AudioPlayer _voice = AudioPlayer();
  final FlutterTts _tts = FlutterTts();
  bool _ttsReady = false;

  Future<void> _initTts() async {
    if (_ttsReady) return;
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.4);
    await _tts.setPitch(1.1);
    await _tts.awaitSpeakCompletion(true);
    _ttsReady = true;
  }

  Future<void> stop() async {
    await _voice.stop();
    await _tts.stop();
  }

  /// Phát một đoạn giọng tiếng Anh. [path] tương đối so với assets/ (hoặc [baseDir] của gói).
  Future<void> play(String? path, String fallbackText, {String? baseDir}) async {
    await stop();
    if (path != null && path.isNotEmpty) {
      try {
        if (baseDir != null) {
          final f = File('$baseDir/$path');
          if (!await f.exists()) throw const FileSystemException('missing');
          await _voice.setFilePath(f.path);
        } else {
          await rootBundle.load('assets/$path'); // ném lỗi nếu thiếu
          await _voice.setAsset('assets/$path');
        }
        await _voice.play();
        return;
      } catch (_) {
        // rơi xuống TTS
      }
    }
    if (fallbackText.isEmpty) return;
    try {
      await _initTts();
      await _tts.speak(fallbackText);
    } catch (_) {}
  }

  /// Hướng dẫn của Momo. Nếu phụ huynh bật "gợi ý tiếng Việt" thì đọc thêm bản tiếng Việt
  /// (chỉ cần truyền [viPath]/[viText]; việc bật/tắt do dịch vụ này quyết định, không rải `if` ở UI).
  Future<void> instruction(String? path, String enText, {String? viPath, String? viText}) async {
    await play(path, enText);
    if (_viEnabled() && (viText != null || viPath != null)) {
      await _playVi(viPath, viText ?? '');
    }
  }

  Future<void> _playVi(String? path, String text) async {
    if (path != null && path.isNotEmpty) {
      try {
        await rootBundle.load('assets/$path');
        await _voice.setAsset('assets/$path');
        await _voice.play();
        return;
      } catch (_) {}
    }
    if (text.isEmpty) return;
    try {
      await _tts.setLanguage('vi-VN');
      await _tts.speak(text);
    } catch (_) {} finally {
      _ttsReady = false; // buộc đặt lại en-US lần sau
    }
  }

  Future<void> dispose() async {
    await _voice.dispose();
    await _tts.stop();
  }
}

/// Hiển thị ảnh từ assets hoặc gói; thiếu ảnh thì vẽ thẻ màu + chữ/emoji thay thế.
class MediaImage extends StatelessWidget {
  const MediaImage(this.path, {super.key, this.baseDir, this.label = '', this.fit = BoxFit.contain});

  final String path;
  final String? baseDir;
  final String label;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    Widget fallback(BuildContext c, Object e, StackTrace? s) => _Placeholder(label: label);
    if (path.isEmpty) return _Placeholder(label: label);
    if (baseDir != null) {
      return Image.file(File('$baseDir/$path'), fit: fit, errorBuilder: fallback);
    }
    return Image.asset('assets/$path', fit: fit, errorBuilder: fallback);
  }
}

const Map<String, String> wordEmojiMap = {
  // Hello & Family
  'hello': '👋',
  'goodbye': '👋',
  'boy': '👦',
  'girl': '👧',
  'mommy': '👩',
  'daddy': '👨',
  'baby': '👶',
  'friend': '🤝',
  // Colors
  'red': '🔴',
  'blue': '🔵',
  'yellow': '🟡',
  'green': '🟢',
  'orange': '🟠',
  'pink': '🌸',
  'purple': '🟣',
  'black': '⚫',
  'white': '⚪',
  'brown': '🟤',
  // Numbers
  'one': '1️⃣',
  'two': '2️⃣',
  'three': '3️⃣',
  'four': '4️⃣',
  'five': '5️⃣',
  'six': '6️⃣',
  'seven': '7️⃣',
  'eight': '8️⃣',
  'nine': '9️⃣',
  'ten': '🔟',
  // Animals
  'dog': '🐶',
  'cat': '🐱',
  'bird': '🐦',
  'fish': '🐟',
  'duck': '🦆',
  'chicken': '🐔',
  'cow': '🐮',
  'pig': '🐷',
  'horse': '🐴',
  'rabbit': '🐰',
  'mouse': '🐭',
  'sheep': '🐑',
  // My Body
  'head': '🗣️',
  'eyes': '👀',
  'ears': '👂',
  'nose': '👃',
  'mouth': '👄',
  'hair': '💇',
  'hands': '🙌',
  'fingers': '🖐️',
  'arms': '💪',
  'legs': '🦵',
  'feet': '🦶',
  'tummy': '🤰',
};

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final cleanKey = label.toLowerCase().trim();
    final emoji = wordEmojiMap[cleanKey];

    final hue = (label.codeUnits.fold<int>(0, (a, b) => a + b) * 37) % 360;
    final color = HSLColor.fromAHSL(1, hue.toDouble(), 0.6, 0.88).toColor();

    return LayoutBuilder(builder: (context, c) {
      final side = c.biggest.shortestSide.isFinite ? c.biggest.shortestSide : 120.0;
      return Center(
        child: Container(
          width: side,
          height: side,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(side * 0.2),
            boxShadow: const [
              BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3)),
            ],
          ),
          alignment: Alignment.center,
          padding: const EdgeInsets.all(8),
          child: emoji != null
              ? Text(
                  emoji,
                  style: TextStyle(fontSize: side * 0.52),
                )
              : FittedBox(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: side * 0.22,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF3D2C2E),
                    ),
                  ),
                ),
        ),
      );
    });
  }
}
