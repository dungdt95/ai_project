import 'dart:async';
import 'dart:io';

import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Ghi âm giọng bé + đo âm lượng + phát lại. Tách thành interface để test bằng bản giả.
/// Mọi xử lý nằm trên máy, không gửi giọng bé ra ngoài.
abstract class SpeechCapture {
  /// Xin/kiểm tra quyền micro. Trả false nếu bị từ chối hoặc thiết bị không hỗ trợ.
  Future<bool> ensurePermission();

  /// Bắt đầu ghi. [onLevel] nhận âm lượng hiện tại (dBFS, -160..0) khoảng 10 lần/giây.
  Future<void> start(void Function(double dbfs) onLevel);

  /// Dừng ghi, trả về đường dẫn file (null nếu lỗi).
  Future<String?> stop();

  /// Phát lại bản ghi (giọng cao hơn một chút cho vui). Chờ phát xong.
  Future<void> playBack(String path);

  Future<void> dispose();
}

class RecordSpeechCapture implements SpeechCapture {
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<Amplitude>? _ampSub;
  String? _path;

  @override
  Future<bool> ensurePermission() async {
    try {
      return await _recorder.hasPermission();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> start(void Function(double dbfs) onLevel) async {
    final dir = await getTemporaryDirectory();
    _path = '${dir.path}/repeat_record.m4a';
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc, numChannels: 1, sampleRate: 22050, bitRate: 64000),
      path: _path!,
    );
    await _ampSub?.cancel();
    _ampSub = _recorder.onAmplitudeChanged(const Duration(milliseconds: 100)).listen((a) => onLevel(a.current));
  }

  @override
  Future<String?> stop() async {
    await _ampSub?.cancel();
    _ampSub = null;
    try {
      return await _recorder.stop() ?? _path;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> playBack(String path) async {
    try {
      await _player.setFilePath(path);
      try {
        await _player.setPitch(1.25);
      } catch (_) {}
      await _player.play();
      await _player.stop();
    } catch (_) {}
  }

  @override
  Future<void> dispose() async {
    await _ampSub?.cancel();
    try {
      if (await _recorder.isRecording()) await _recorder.stop();
    } catch (_) {}
    await _recorder.dispose();
    await _player.dispose();
    final p = _path;
    if (p != null) {
      try {
        await File(p).delete();
      } catch (_) {}
    }
  }
}
