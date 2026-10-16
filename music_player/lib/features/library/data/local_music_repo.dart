import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../../core/database/hive_boxes.dart';
import '../domain/song.dart';

class LocalMusicRepo {
  final _query = OnAudioQuery();

  // ── Permissions ───────────────────────────────────────────────────────────

  Future<bool> requestPermission() async {
    return await _query.permissionsRequest();
  }

  // ── Scan via Android MediaStore (real ID3 metadata) ───────────────────────

  Future<List<Song>> scanStorage() async {
    final granted = await requestPermission();
    if (!granted) return [];

    final existing = HiveBoxes.songs.values.map((s) => s.id).toSet();
    final added = <Song>[];

    final songModels = await _query.querySongs(
      sortType: SongSortType.TITLE,
      orderType: OrderType.ASC_OR_SMALLER,
      uriType: UriType.EXTERNAL,
      ignoreCase: true,
    );

    for (final model in songModels) {
      if (existing.contains(model.id.toString())) continue;
      // Skip very short clips (< 30s) — ringtones, notif sounds etc.
      if ((model.duration ?? 0) < 30000) continue;
      if (model.data == null || !File(model.data!).existsSync()) continue;

      final artPath = await _saveArtwork(model.id);
      final song = Song(
        id: model.id.toString(),
        title: model.title,
        artist: model.artist ?? 'Unknown',
        album: model.album ?? 'Unknown Album',
        filePath: model.data!,
        durationMs: model.duration ?? 0,
        artworkPath: artPath,
        addedAt: DateTime.now(),
      );
      await HiveBoxes.songs.put(song.id, song);
      added.add(song);
    }
    return added;
  }

  // ── Pick individual files ─────────────────────────────────────────────────

  Future<List<Song>> pickFiles() async {
    final files = await FilePicker.pickFiles(
      type: FileType.audio,
      allowMultiple: true,
    );

    final added = <Song>[];
    for (final f in files) {
      final path = f.path;
      if (path == null) continue;

      final id = path.hashCode.abs().toString();
      if (HiveBoxes.songs.containsKey(id)) continue;

      final name = p.basenameWithoutExtension(path);
      String title = name, artist = 'Unknown';
      if (name.contains(' - ')) {
        final parts = name.split(' - ');
        artist = parts[0].trim();
        title = parts.sublist(1).join(' - ').trim();
      }

      final song = Song(
        id: id,
        title: title,
        artist: artist,
        album: 'Unknown Album',
        filePath: path,
        durationMs: 0,
        addedAt: DateTime.now(),
      );
      await HiveBoxes.songs.put(song.id, song);
      added.add(song);
    }
    return added;
  }

  // ── Artwork ───────────────────────────────────────────────────────────────

  Future<String?> _saveArtwork(int songId) async {
    try {
      final bytes = await _query.queryArtwork(
        songId,
        ArtworkType.AUDIO,
        quality: 85,
        size: 300,
      );
      if (bytes == null || bytes.isEmpty) return null;
      return await _writeBytesToCache(songId.toString(), bytes);
    } catch (e) {
      debugPrint('Artwork error for $songId: $e');
      return null;
    }
  }

  static Future<String?> _writeBytesToCache(String id, Uint8List bytes) async {
    try {
      final dir = await getApplicationCacheDirectory();
      final artDir = Directory(p.join(dir.path, 'artworks'));
      if (!artDir.existsSync()) artDir.createSync();
      final file = File(p.join(artDir.path, '$id.jpg'));
      await file.writeAsBytes(bytes);
      return file.path;
    } catch (_) {
      return null;
    }
  }

  // ── Read ──────────────────────────────────────────────────────────────────

  List<Song> getAllSongs() {
    return HiveBoxes.songs.values.toList();
  }

  Future<void> removeSong(String id) async {
    await HiveBoxes.songs.delete(id);
  }
}
