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

  /// Luồng cập nhật thời gian phát hiện tại cho màn hình Karaoke.
  Stream<Duration> get positionStream => _voice.positionStream;

  /// Trạng thái phát của AudioPlayer.
  Stream<PlayerState> get playerStateStream => _voice.playerStateStream;

  /// Độ dài bài hát hiện tại.
  Duration? get duration => _voice.duration;

  bool _iosTtsConfigured = false;

  /// iOS: mặc định TTS bị tắt tiếng khi gạt công tắc im lặng → đặt category playback (như just_audio)
  /// (không kèm option: defaultToSpeaker chỉ hợp lệ với playAndRecord). Chỉ làm một lần; Android không bị ảnh hưởng.
  Future<void> _configureIosTts() async {
    if (_iosTtsConfigured || !Platform.isIOS) return;
    _iosTtsConfigured = true;
    try {
      await _tts.setSharedInstance(true);
      await _tts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        const [],
        IosTextToSpeechAudioMode.defaultMode,
      );
    } catch (_) {}
  }

  Future<void> _initTts() async {
    if (_ttsReady) return;
    await _configureIosTts();
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
          if (await f.exists()) {
            print('>>> [AudioService] Playing FILE: ${f.path}');
            await _voice.setFilePath(f.path);
          } else {
            await rootBundle.load('assets/$path');
            await _voice.setAsset('assets/$path');
          }
        } else {
          print('>>> [AudioService] Loading ASSET: assets/$path');
          await rootBundle.load('assets/$path'); // ném lỗi nếu thiếu
          await _voice.setAsset('assets/$path');
        }
        print('>>> [AudioService] Play STARTING: $path, duration: ${_voice.duration}');
        await _voice.play();
        print('>>> [AudioService] Play CALLED successfully for: $path');
        return;
      } catch (e, s) {
        print('>>> [AudioService] ERROR playing asset ($path): $e');
        debugPrint('[AudioService] Play asset error ($path): $e\n$s');
        // rơi xuống TTS
      }
    }
    if (fallbackText.isEmpty) return;
    try {
      print('>>> [AudioService] FALLBACK TO TTS: $fallbackText');
      await _initTts();
      await _tts.speak(fallbackText);
    } catch (_) {}
  }

  /// Phát từ vựng: tiếng Anh trước (bằng audio asset hoặc TTS en-US).
  /// Nếu [_viEnabled] là true và [viText] không rỗng, phát nối tiếp giọng đọc tiếng Việt bằng TTS vi-VN.
  Future<void> playWord(String? path, String enText, {String? viText, String? baseDir}) async {
    await play(path, enText, baseDir: baseDir);
    if (_viEnabled() && viText != null && viText.isNotEmpty) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await _playVi(null, viText);
    }
  }

  /// Hướng dẫn của Momo. Nếu phụ huynh bật "gợi ý tiếng Việt" thì đọc thêm bản tiếng Việt
  /// (chỉ cần truyền [viPath]/[viText]; việc bật/tắt do dịch vụ này quyết định, không rải `if` ở UI).
  Future<void> instruction(String? path, String enText, {String? viPath, String? viText}) async {
    await play(path, enText);
    if (_viEnabled() && ((viText != null && viText.isNotEmpty) || (viPath != null && viPath.isNotEmpty))) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
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
      await _configureIosTts();
      await _tts.setLanguage('vi-VN');
      await _tts.setSpeechRate(0.4);
      await _tts.setPitch(1.0);
      await _tts.awaitSpeakCompletion(true);
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
      return Image.file(
        File('$baseDir/$path'),
        fit: fit,
        errorBuilder: (c, e, s) => Image.asset('assets/$path', fit: fit, errorBuilder: fallback),
      );
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
  // t06 My Big Family
  'family': '👨‍👩‍👧‍👦',
  'grandma': '👵',
  'grandpa': '👴',
  'brother': '👦',
  'sister': '👧',
  'uncle': '👨',
  'aunt': '👩',
  'cousin': '🧑‍🤝‍🧑',
  'home': '🏡',
  'love': '❤️',
  // t07 Zoo Animals
  'lion': '🦁',
  'tiger': '🐯',
  'elephant': '🐘',
  'monkey': '🐒',
  'bear': '🐻',
  'giraffe': '🦒',
  'zebra': '🦓',
  'hippo': '🦛',
  'crocodile': '🐊',
  'snake': '🐍',
  'panda': '🐼',
  'kangaroo': '🦘',
  // t08 Ocean & Bugs
  'shark': '🦈',
  'whale': '🐋',
  'dolphin': '🐬',
  'turtle': '🐢',
  'crab': '🦀',
  'octopus': '🐙',
  'starfish': '⭐',
  'bee': '🐝',
  'butterfly': '🦋',
  'ladybug': '🐞',
  // t09 Fun Shapes
  'circle': '⭕',
  'square': '🟦',
  'triangle': '🔺',
  'star': '⭐',
  'heart': '💖',
  'rectangle': '▬',
  'oval': '🥚',
  'diamond': '🔷',
  'rainbow': '🌈',
  'line': '➖',
  // t10 Numbers & Sizes
  'eleven': '1️⃣1️⃣',
  'twelve': '1️⃣2️⃣',
  'fifteen': '1️⃣5️⃣',
  'twenty': '2️⃣0️⃣',
  'big': '🐘',
  'small': '🐁',
  'tall': '🦒',
  'short': '🐕',
  'long': '🚆',
  'heavy': '🏋️',
  // t11 Yummy Fruits ('orange' already mapped above)
  'apple': '🍎',
  'banana': '🍌',
  'mango': '🥭',
  'watermelon': '🍉',
  'grapes': '🍇',
  'strawberry': '🍓',
  'pineapple': '🍍',
  'peach': '🍑',
  'coconut': '🥥',
  // t12 Food & Drinks
  'rice': '🍚',
  'bread': '🍞',
  'egg': '🥚',
  'soup': '🍲',
  'noodles': '🍜',
  'pizza': '🍕',
  'cake': '🍰',
  'ice cream': '🍦',
  'milk': '🥛',
  'water': '💧',
  'juice': '🧃',
  'cookie': '🍪',
  // t13 My Toys
  'ball': '⚽',
  'doll': '🪆',
  'teddy bear': '🧸',
  'toy car': '🚗',
  'blocks': '🧱',
  'kite': '🪁',
  'robot': '🤖',
  'balloon': '🎈',
  'puzzle': '🧩',
  'drum': '🥁',
  // t14 My Clothes
  'shirt': '👔',
  't-shirt': '👕',
  'pants': '👖',
  'shorts': '🩳',
  'dress': '👗',
  'skirt': '👗',
  'shoes': '👟',
  'socks': '🧦',
  'hat': '👒',
  'jacket': '🧥',
  // t15 My Cozy House
  'house': '🏠',
  'door': '🚪',
  'window': '🪟',
  'bedroom': '🛏️',
  'kitchen': '🍳',
  'bathroom': '🛁',
  'bed': '🛏️',
  'table': '🪑',
  'chair': '🪑',
  'sofa': '🛋️',
  'lamp': '💡',
  'clock': '🕰️',
  // t16 My Feelings
  'happy': '😄',
  'sad': '😢',
  'angry': '😠',
  'scared': '😨',
  'sleepy': '😴',
  'tired': '🥱',
  'hungry': '😋',
  'thirsty': '🥤',
  'surprised': '😮',
  'excited': '🤩',
  // t17 Let's Move!
  'run': '🏃',
  'jump': '🤸',
  'walk': '🚶',
  'dance': '💃',
  'sing': '🎤',
  'swim': '🏊',
  'fly': '🕊️',
  'climb': '🧗',
  'sit': '🧘',
  'stand': '🧍',
  'laugh': '😂',
  'hug': '🤗',
  // t18 Daily Routines
  'wake up': '☀️',
  'brush teeth': '🪥',
  'wash face': '💦',
  'wash hands': '🧼',
  'comb hair': '💇',
  'take a bath': '🛁',
  'eat breakfast': '🥣',
  'read a book': '📖',
  'go to bed': '🛌',
  'good night': '🌙',
  // t19 Mealtime Tools
  'spoon': '🥄',
  'fork': '🍴',
  'bowl': '🥣',
  'plate': '🍽️',
  'cup': '☕',
  'glass': '🥛',
  'bottle': '🍼',
  'napkin': '🧻',
  'chopsticks': '🥢',
  'pot': '🍲',
  // t20 Fun Opposites
  'hot': '🔥',
  'cold': '❄️',
  'fast': '🐇',
  'slow': '🐢',
  'up': '⬆️',
  'down': '⬇️',
  'open': '📂',
  'close': '📁',
  'clean': '✨',
  'dirty': '🐾',
  // t21 Beep! Vehicles
  'car': '🚗',
  'bus': '🚌',
  'bike': '🚲',
  'motorbike': '🛵',
  'train': '🚆',
  'airplane': '✈️',
  'helicopter': '🚁',
  'boat': '⛵',
  'ship': '🚢',
  'truck': '🚚',
  'fire truck': '🚒',
  'police car': '🚓',
  // t22 Weather & Nature
  'sun': '☀️',
  'moon': '🌙',
  'cloud': '☁️',
  'rain': '🌧️',
  'wind': '💨',
  'snow': '❄️',
  'tree': '🌳',
  'flower': '🌸',
  'grass': '🌿',
  'sunny': '🌞',
  'rainy': '☔',
  'windy': '🌬️',
  // t23 My Preschool
  'school': '🏫',
  'teacher': '👩‍🏫',
  'classroom': '🧑‍🏫',
  'book': '📚',
  'crayon': '🖍️',
  'pencil': '✏️',
  'paper': '📄',
  'bag': '🎒',
  'scissors': '✂️',
  'playground': '🛝',
  // t24 Cool Jobs
  'doctor': '👨‍⚕️',
  'nurse': '👩‍⚕️',
  'firefighter': '👨‍🚒',
  'police officer': '👮',
  'chef': '👨‍🍳',
  'farmer': '👨‍🌾',
  'driver': '🚌',
  'builder': '👷',
  'singer': '🧑‍🎤',
  'astronaut': '👨‍🚀',
  // t25 Party & Holidays
  'birthday': '🎂',
  'gift': '🎁',
  'candle': '🕯️',
  'party hat': '🥳',
  'crown': '👑',
  'music': '🎵',
  'fireworks': '🎆',
  'lantern': '🏮',
  'wish': '🌠',
  'celebrate': '🎉',
  // Topic island & song cover fallback emojis (t06..t25)
  'my big family': '👨‍👩‍👧‍👦',
  'zoo animals': '🦁',
  'ocean & bugs': '🐬',
  'fun shapes': '⭐',
  'numbers & sizes': '🔢',
  'yummy fruits': '🍎',
  'food & drinks': '🍱',
  'my toys': '🧸',
  'my clothes': '👕',
  'my cozy house': '🏡',
  'my feelings': '😊',
  "let's move!": '🤸',
  'daily routines': '🪥',
  'mealtime tools': '🍽️',
  'fun opposites': '🔥',
  'beep! vehicles': '🚗',
  'weather & nature': '🌈',
  'my preschool': '🏫',
  'cool jobs': '👨‍⚕️',
  'party & holidays': '🎉',
  'sticker': '🌟',
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
