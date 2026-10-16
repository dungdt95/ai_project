import 'package:hive_flutter/hive_flutter.dart';
import '../../features/library/domain/song.dart';
import '../../features/library/domain/playlist.dart';

class HiveBoxes {
  static const songBox = 'songs';
  static const playlistBox = 'playlists';

  static Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(SongAdapter());
    Hive.registerAdapter(PlaylistAdapter());
    await Hive.openBox<Song>(songBox);
    await Hive.openBox<Playlist>(playlistBox);
  }

  static Box<Song> get songs => Hive.box<Song>(songBox);
  static Box<Playlist> get playlists => Hive.box<Playlist>(playlistBox);
}
