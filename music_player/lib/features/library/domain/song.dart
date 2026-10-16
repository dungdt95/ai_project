import 'package:hive/hive.dart';

part 'song.g.dart';

@HiveType(typeId: 0)
class Song extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  String artist;

  @HiveField(3)
  String album;

  @HiveField(4)
  String filePath;

  @HiveField(5)
  int durationMs;

  @HiveField(6)
  String? artworkPath;

  @HiveField(7)
  DateTime addedAt;

  Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.filePath,
    required this.durationMs,
    this.artworkPath,
    required this.addedAt,
  });

  String get durationLabel {
    final total = Duration(milliseconds: durationMs);
    final m = total.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = total.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${total.inHours > 0 ? '${total.inHours}:' : ''}$m:$s';
  }

  @override
  String toString() => 'Song($title – $artist)';
}
