/// Mô hình dữ liệu nội dung (đọc từ JSON, bất biến).
library;

class Word {
  final String id;
  final String text;
  final String image;
  final String audio;
  final String sentence;
  final String sentenceAudio;
  final String? vi;

  const Word({
    required this.id,
    required this.text,
    required this.image,
    required this.audio,
    required this.sentence,
    required this.sentenceAudio,
    this.vi,
  });

  factory Word.fromJson(Map<String, dynamic> j) => Word(
        id: j['id'] as String,
        text: j['text'] as String,
        image: j['image'] as String,
        audio: j['audio'] as String,
        sentence: (j['sentence'] ?? '') as String,
        sentenceAudio: (j['sentence_audio'] ?? '') as String,
        vi: j['vi'] as String?,
      );
}

class Sentence {
  final String id;
  final String text;
  final String audio;
  final String vi;
  final String pronVi;

  const Sentence({
    required this.id,
    required this.text,
    required this.audio,
    required this.vi,
    required this.pronVi,
  });

  factory Sentence.fromJson(Map<String, dynamic> j) => Sentence(
        id: j['id'] as String,
        text: j['text'] as String,
        audio: (j['audio'] ?? '') as String,
        vi: (j['vi'] ?? '') as String,
        pronVi: (j['pron_vi'] ?? '') as String,
      );
}

class LyricLine {
  final num t;
  final String text;
  const LyricLine(this.t, this.text);
}

class Song {
  final String id;
  final String title;
  final String audio;
  final String cover;
  final List<LyricLine> lyrics;

  const Song({
    required this.id,
    required this.title,
    required this.audio,
    required this.cover,
    required this.lyrics,
  });

  factory Song.fromJson(Map<String, dynamic> j) => Song(
        id: j['id'] as String,
        title: j['title'] as String,
        audio: j['audio'] as String,
        cover: (j['cover'] ?? '') as String,
        lyrics: [
          for (final l in (j['lyrics'] as List? ?? const []))
            LyricLine(l['t'] as num, l['text'] as String),
        ],
      );
}

class Command {
  final String id;
  final String text;
  final String image;
  final String audio;

  const Command({
    required this.id,
    required this.text,
    required this.image,
    required this.audio,
  });

  factory Command.fromJson(Map<String, dynamic> j) => Command(
        id: j['id'] as String,
        text: j['text'] as String,
        image: (j['image'] ?? '') as String,
        audio: (j['audio'] ?? '') as String,
      );
}

/// Một bước trong bài học. [type] quyết định hoạt động nào được dựng;
/// [data] giữ nguyên các tham số còn lại từ JSON.
class LessonStep {
  final String type;
  final Map<String, dynamic> data;
  const LessonStep(this.type, this.data);

  List<String> get words => [for (final w in (data['words'] as List? ?? const [])) w as String];
  int get rounds => (data['rounds'] as num?)?.toInt() ?? 5;
  int get choices => (data['choices'] as num?)?.toInt() ?? 2;
  String? get sticker => data['sticker'] as String?;

  factory LessonStep.fromJson(Map<String, dynamic> j) => LessonStep(j['type'] as String, j);
}

class ParentTip {
  final List<String> sentenceIds;
  final String activityVi;
  const ParentTip(this.sentenceIds, this.activityVi);

  factory ParentTip.fromJson(Map<String, dynamic> j) => ParentTip(
        [for (final s in (j['sentences'] as List? ?? const [])) s as String],
        (j['activity_vi'] ?? '') as String,
      );
}

class Lesson {
  final String id;
  final int order;
  final List<String> newWords;
  final String? sentenceId;
  final List<LessonStep> steps;
  final ParentTip? parentTip;

  const Lesson({
    required this.id,
    required this.order,
    required this.newWords,
    required this.sentenceId,
    required this.steps,
    required this.parentTip,
  });

  factory Lesson.fromJson(Map<String, dynamic> j) => Lesson(
        id: j['id'] as String,
        order: (j['order'] as num?)?.toInt() ?? 0,
        newWords: [for (final w in (j['new_words'] as List)) w as String],
        sentenceId: j['sentence'] as String?,
        steps: [for (final s in (j['steps'] as List)) LessonStep.fromJson(s as Map<String, dynamic>)],
        parentTip: j['parent_tip'] == null ? null : ParentTip.fromJson(j['parent_tip'] as Map<String, dynamic>),
      );
}

class Topic {
  final String id;
  final int level;
  final int order;
  final String titleEn;
  final String titleVi;
  final String mapIcon;
  final Song? song;
  final List<Word> words;
  final List<Sentence> sentences;
  final List<Lesson> lessons;
  final List<Command> commands;

  /// null = nằm trong assets của APK; ngược lại là thư mục gói đã cài (dùng cho Content Pack).
  final String? baseDir;

  const Topic({
    required this.id,
    required this.level,
    required this.order,
    required this.titleEn,
    required this.titleVi,
    required this.mapIcon,
    required this.song,
    required this.words,
    required this.sentences,
    required this.lessons,
    required this.commands,
    this.baseDir,
  });

  Word? wordById(String id) {
    for (final w in words) {
      if (w.id == id) return w;
    }
    return null;
  }

  Sentence? sentenceById(String id) {
    for (final s in sentences) {
      if (s.id == id) return s;
    }
    return null;
  }

  factory Topic.fromJson(Map<String, dynamic> j, {String? baseDir}) => Topic(
        id: j['id'] as String,
        level: (j['level'] as num?)?.toInt() ?? 1,
        order: (j['order'] as num?)?.toInt() ?? 0,
        titleEn: j['title_en'] as String,
        titleVi: (j['title_vi'] ?? '') as String,
        mapIcon: (j['map_icon'] ?? '') as String,
        song: j['song'] == null ? null : Song.fromJson(j['song'] as Map<String, dynamic>),
        words: [for (final w in (j['words'] as List)) Word.fromJson(w as Map<String, dynamic>)],
        sentences: [for (final s in (j['sentences'] as List? ?? const [])) Sentence.fromJson(s as Map<String, dynamic>)],
        lessons: [for (final l in (j['lessons'] as List)) Lesson.fromJson(l as Map<String, dynamic>)],
        commands: [for (final c in (j['commands'] as List? ?? const [])) Command.fromJson(c as Map<String, dynamic>)],
        baseDir: baseDir,
      );
}
