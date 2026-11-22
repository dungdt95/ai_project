// Sinh JSON nội dung 5 chủ đề MVP từ dữ liệu trong docs/ASSET_SPEC.md.
// Chạy từ thư mục app/:  dart run tools/gen_content.dart
// Sau khi sinh có thể chỉnh tay JSON; app đọc dữ liệu, không cần sửa code.
import 'dart:convert';
import 'dart:io';

typedef W = (String, String, String); // key, text, example sentence

class T {
  final String id, en, vi, map, songId, songTitle, cover;
  final int order;
  final List<W> words;
  final List<String> sentences, tpr;
  final List<(int, String)> lyrics;
  T(this.id, this.order, this.en, this.vi, this.map, this.words, this.sentences, this.tpr, this.songId, this.songTitle,
      this.cover, this.lyrics);
}

final topics = <T>[
  T('t01_hello', 1, 'Hello!', 'Chào hỏi & Gia đình', 'island_t01_hello', [
    ('hello', 'Hello', 'Hello! Nice to meet you!'), ('goodbye', 'Goodbye', 'Goodbye! See you soon!'),
    ('boy', 'Boy', 'I am a happy boy!'), ('girl', 'Girl', 'I am a happy girl!'),
    ('mommy', 'Mommy', 'I love my mommy!'), ('daddy', 'Daddy', 'I love my daddy!'),
    ('baby', 'Baby', 'Look at the cute baby!'), ('friend', 'Friend', 'You are my good friend!'),
  ], ['p_hello_name', 'p_my_name', 'p_how_are_you', 'p_magic_words'], ['cmd_wave_hello'], 's01_hello_song', 'Hello Song',
      'cover_s01_hello', [
    (4, 'Hello, hello! How are you?'), (8, 'Hello, hello! How are you?'), (12, "I'm fine, I'm happy, thank you!"),
    (16, 'Hello Mommy! Hello Daddy!'), (20, 'Hello little baby, too!'), (24, 'Wave your hands and say hello!'),
    (28, 'Wave your hands: Goodbye, bye-bye!'), (32, 'See you soon, my friend!'),
  ]),
  T('t02_colors', 2, 'Colors', 'Màu sắc', 'island_t02_colors', [
    ('red', 'Red', "It's red! A red apple."), ('blue', 'Blue', "It's blue! The sky is blue."),
    ('yellow', 'Yellow', "It's yellow! A yellow sun."), ('green', 'Green', "It's green! A green leaf."),
    ('orange', 'Orange', "It's orange! I like orange."), ('pink', 'Pink', "It's pink! A pink flower."),
    ('purple', 'Purple', "It's purple! Purple grapes."), ('black', 'Black', "It's black! A black hat."),
    ('white', 'White', "It's white! A white cloud."), ('brown', 'Brown', "It's brown! Momo is brown."),
  ], ['p_what_color', 'p_i_like_color'], ['cmd_clap_hands'], 's02_rainbow_colors', 'Rainbow Colors', 'cover_s02_colors', [
    (4, 'Red and yellow, green and blue,'), (8, 'Orange, pink, and purple too!'),
    (12, 'Black and white and chocolate brown,'), (16, 'Pretty colors all around!'),
    (20, 'What color is it? Look and see!'), (24, 'Sing the rainbow song with me!'),
    (28, 'Red, blue, yellow, green! Hooray!'),
  ]),
  T('t03_numbers', 3, 'Numbers', 'Số đếm 1-10', 'island_t03_numbers', [
    ('one', 'One', 'One! One little star.'), ('two', 'Two', 'Two! One, two strawberries.'),
    ('three', 'Three', 'Three! Three yellow ducks.'), ('four', 'Four', 'Four! I am four years old!'),
    ('five', 'Five', 'Five! Give me high five!'), ('six', 'Six', 'Six! Six big balloons.'),
    ('seven', 'Seven', 'Seven! Seven rainbow stars.'), ('eight', 'Eight', 'Eight! Eight yummy carrots.'),
    ('nine', 'Nine', 'Nine! Nine blue butterflies.'), ('ten', 'Ten', 'Ten! Ten little fingers!'),
  ], ['p_lets_count', 'p_how_many', 'p_how_old'], ['cmd_jump_high'], 's03_ten_little_fingers', 'Ten Little Fingers',
      'cover_s03_numbers', [
    (4, 'One little, two little, three little fingers,'), (8, 'Four little, five little, six little fingers,'),
    (12, 'Seven little, eight little, nine little fingers,'), (16, 'Ten little fingers on my hands!'),
    (20, "Let's count together!"), (24, 'One, two, three, four, five!'), (28, 'Six, seven, eight, nine, ten!'),
    (32, 'Clap, clap, ten little fingers!'),
  ]),
  T('t04_animals', 4, 'Animals', 'Con vật', 'island_t04_animals', [
    ('dog', 'Dog', "It's a dog! Woof, woof!"), ('cat', 'Cat', "It's a cat! Meow, meow!"),
    ('bird', 'Bird', "It's a bird! Tweet, tweet!"), ('fish', 'Fish', 'Look! The fish can swim!'),
    ('duck', 'Duck', "It's a duck! Quack, quack!"), ('chicken', 'Chicken', "It's a chicken! Cluck, cluck!"),
    ('cow', 'Cow', "It's a cow! Moo, moo!"), ('pig', 'Pig', "It's a cute pink pig! Oink, oink!"),
    ('horse', 'Horse', 'The horse runs fast! Neigh!'), ('rabbit', 'Rabbit', 'Hop, hop like a rabbit!'),
    ('mouse', 'Mouse', 'A little mouse! Squeak, squeak!'), ('sheep', 'Sheep', 'A white sheep! Baa, baa!'),
  ], ['p_whats_this', 'p_animal_says', 'p_i_like_animal'], ['cmd_fly_bird', 'cmd_swim_fish'], 's04_old_macdonald',
      'Old MacDonald', 'cover_s04_animals', [
    (4, 'Old MacDonald had a farm, E-I-E-I-O!'), (8, 'And on his farm he had a dog, E-I-E-I-O!'),
    (12, 'With a woof-woof here, and a woof-woof there!'), (16, 'And on his farm he had a cat, E-I-E-I-O!'),
    (20, 'With a meow-meow here, and a meow-meow there!'), (24, 'And on his farm he had a duck, E-I-E-I-O!'),
    (28, 'With a quack-quack here, and a moo-moo there!'), (32, 'Old MacDonald had a farm, E-I-E-I-O!'),
  ]),
  T('t05_body', 5, 'My Body', 'Cơ thể của bé', 'island_t05_body', [
    ('head', 'Head', 'Touch your head!'), ('eyes', 'Eyes', 'Close your eyes. Open your eyes!'),
    ('ears', 'Ears', 'These are my ears.'), ('nose', 'Nose', 'This is my little nose!'),
    ('mouth', 'Mouth', 'Open your mouth! Ah!'), ('hair', 'Hair', 'Brush your nice hair.'),
    ('hands', 'Hands', 'Clap your hands!'), ('fingers', 'Fingers', 'Wiggle your ten fingers!'),
    ('arms', 'Arms', 'Stretch your arms up high!'), ('legs', 'Legs', 'Look at my two legs!'),
    ('feet', 'Feet', 'Stamp your feet!'), ('tummy', 'Tummy', 'Pat your round tummy!'),
  ], ['p_touch_your', 'p_clap_hands', 'p_this_is_my'],
      ['cmd_touch_nose', 'cmd_touch_head', 'cmd_stamp_feet', 'cmd_clap_hands'], 's05_head_shoulders', 'Head & Tummy',
      'cover_s05_body', [
    (4, 'Head and tummy, arms and legs, arms and legs!'), (8, 'Head and tummy, arms and legs, arms and legs!'),
    (12, 'And eyes, and ears, and mouth, and nose!'), (16, 'Clap your hands and stamp your feet, stamp your feet!'),
    (20, 'Touch your hair and wiggle your fingers, too!'), (24, 'Eyes, and ears, and mouth, and nose! Hooray!'),
  ]),
];

const sent = <String, (String, String, String)>{
  'p_hello_name': ("Hello! What's your name?", 'Xin chào! Tên con là gì?', 'Hê-lâu! Quát-xơ gio nêm?'),
  'p_my_name': ('My name is Momo!', 'Tên tớ là Momo!', 'Mai nêm i-zơ Mô-mô!'),
  'p_how_are_you': ("How are you? I'm happy!", 'Con có khỏe không? Con rất vui!', 'Hao a diu? Ai-mơ hép-pi!'),
  'p_what_color': ("What color is it? It's red!", 'Đây là màu gì? Màu đỏ đấy!', 'Quát có-lờ i-zít? Ít-xơ rét!'),
  'p_i_like_color': ('I like blue!', 'Con thích màu xanh dương!', 'Ai lai-kơ b-lu!'),
  'p_lets_count': ("Let's count! One, two, three!", 'Cùng đếm nào! Một, hai, ba!', 'Lét-xơ cao-tờ! Oăn, tu, th-ri!'),
  'p_how_many': ('How many? Five!', 'Có bao nhiêu nhỉ? Năm!', 'Hao me-ni? Fai-vờ!'),
  'p_how_old': ("I'm four years old!", 'Con lên bốn tuổi!', 'Ai-mơ fo gia-zơ âu!'),
  'p_whats_this': ("What's this? It's a dog!", 'Đây là con gì? Là con chó đấy!', 'Quát-xơ đít? Ít-xơ ờ đóc!'),
  'p_animal_says': ('The cat says meow, meow!', 'Con mèo kêu meo meo!', 'Đờ két xây-zơ mi-ao, mi-ao!'),
  'p_i_like_animal': ('I like rabbits!', 'Con thích những chú thỏ!', 'Ai lai-kơ rép-bịt-xơ!'),
  'p_touch_your': ('Touch your nose!', 'Hãy chạm vào mũi của con nào!', 'Tắt-chơ gio nâu-zơ!'),
  'p_clap_hands': ('Clap your hands!', 'Vỗ tay nào!', 'C-lép gio hen-zơ!'),
  'p_this_is_my': ('This is my tummy!', 'Đây là cái bụng của con!', 'Đít i-zơ mai tăm-mi!'),
  'p_magic_words': ('Please! Thank you! Good job!', 'Làm ơn! Cảm ơn! Con giỏi lắm!', 'P-li-zơ! Thanh kiu! Gút chóp!'),
};

const tprText = {
  'cmd_wave_hello': 'Wave your hands! Say hello!',
  'cmd_clap_hands': 'Clap your hands!',
  'cmd_touch_nose': 'Touch your nose!',
  'cmd_touch_head': 'Touch your head!',
  'cmd_stamp_feet': 'Stamp your feet!',
  'cmd_jump_high': 'Jump up high!',
  'cmd_fly_bird': 'Fly like a little bird!',
  'cmd_swim_fish': 'Swim like a happy fish!',
};

Map<String, dynamic> build(T t) {
  final prefix = t.id.split('_').first;
  final words = [
    for (final (key, text, s) in t.words)
      {
        'id': '${prefix}_$key',
        'text': text,
        'image': 'images/topics/${t.id}/$key.png',
        'audio': 'audio/words/${prefix}_$key.mp3',
        'sentence': s,
        'sentence_audio': 'audio/sentences/${prefix}_${key}_s.mp3',
      }
  ];
  final sentences = [
    for (final sid in t.sentences)
      {
        'id': sid,
        'text': sent[sid]!.$1,
        'audio': 'audio/sentences/$sid.mp3',
        'vi': sent[sid]!.$2,
        'pron_vi': sent[sid]!.$3,
      }
  ];
  final ids = [for (final w in words) w['id'] as String];
  final lessons = <Map<String, dynamic>>[];
  for (var i = 0, n = 1; i < ids.length; i += 3, n++) {
    final grp = ids.sublist(i, i + 3 > ids.length ? ids.length : i + 3);
    final sid = t.sentences[(n - 1) % t.sentences.length];
    lessons.add({
      'id': '${t.id}_l$n',
      'order': n,
      'new_words': grp,
      'sentence': sid,
      'steps': [
        {'type': 'warmup', 'audio': 'audio/instructions/warmup_start.mp3'},
        {'type': 'discover', 'words': grp},
        {'type': 'tap_find', 'words': grp, 'rounds': 6, 'choices': 2},
        {'type': 'memory_match', 'words': grp, 'pairs': grp.length},
        {'type': 'repeat_record', 'words': grp.take(2).toList()},
        if (t.tpr.isNotEmpty) {'type': 'simon_says', 'commands': [t.tpr[(n - 1) % t.tpr.length]]},
        {'type': 'celebrate', 'sticker': 'stk_${prefix}_${n > 4 ? 4 : n}'},
      ],
      'parent_tip': {
        'sentences': [sid],
        'activity_vi': 'Bố mẹ dùng các từ này trong lúc chơi và sinh hoạt hằng ngày cùng bé.',
      },
    });
  }
  return {
    'id': t.id,
    'level': 1,
    'order': t.order,
    'title_en': t.en,
    'title_vi': t.vi,
    'map_icon': 'images/map/${t.map}.png',
    'song': {
      'id': t.songId,
      'title': t.songTitle,
      'audio': 'audio/songs/${t.songId}.mp3',
      'cover': 'images/songs/${t.cover}.png',
      'lyrics': [for (final (s, x) in t.lyrics) {'t': s, 'text': x}],
    },
    'words': words,
    'sentences': sentences,
    'lessons': lessons,
    'commands': [
      for (final c in t.tpr)
        {'id': c, 'text': tprText[c], 'image': 'images/tpr/$c.png', 'audio': 'audio/instructions/$c.mp3'}
    ],
  };
}

void main() {
  const enc = JsonEncoder.withIndent('  ');
  final out = Directory('assets/content/topics')..createSync(recursive: true);
  for (final t in topics) {
    File('${out.path}/${t.id}.json').writeAsStringSync(enc.convert(build(t)));
  }
  File('assets/content/curriculum.json').writeAsStringSync(enc.convert({
    'schemaVersion': 1,
    'topics': [for (final t in topics) {'id': t.id, 'file': 'topics/${t.id}.json'}],
  }));
  stdout.writeln('OK ${topics.length} topics');
}
