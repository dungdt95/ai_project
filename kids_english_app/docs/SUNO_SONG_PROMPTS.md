# HƯỚNG DẪN TẠO NHẠC BẰNG SUNO AI CHO CÁC CHỦ ĐỀ (KIDS ENGLISH APP)

Tài liệu này cung cấp toàn bộ **Style Prompt, Lời bài hát (Custom Lyrics), Cấu trúc nhịp điệu** cho 5 chủ đề MVP hiện tại và **Mẫu chuẩn (Template)** để bổ sung các chủ đề mới sau này.

---

## 1. Hướng Dẫn Sử Dụng Suno AI (Tạo Miễn Phí 100%)

1. Truy cập [suno.com](https://suno.com) và đăng nhập bằng tài khoản Google (nhận ngay **50 credits miễn phí/ngày**, đủ tạo 10 bài hát).
2. Nhấn vào mục **Create** (menu bên trái).
3. **BẬT công tắc "Custom Mode"** (Chế độ tùy chỉnh):
   - **Lyrics:** Dán toàn bộ phần lời bài hát trong khung `Custom Lyrics` của chủ đề tương ứng.
   - **Style of Music:** Dán đoạn prompt phong cách âm nhạc trong khung `Style Prompt`.
   - **Title:** Đặt tên bài hát theo tên file gợi ý (Ví dụ: `Hello Song`, `Rainbow Colors`,...).
4. Bấm **Create**: Hệ thống sẽ tạo ra 2 phiên bản (Version A & Version B) trong khoảng 20–30 giây.
5. Nghe thử, chọn bản bạn ưng ý nhất:
   - Bấm vào biểu tượng **3 chấm (...) -> Download Audio** để tải file `.mp3` về máy.
   - Đổi tên file tải về thành tên file chuẩn (ví dụ `s01_hello_song.mp3`).
6. Chép file vào thư mục của ứng dụng:
   ```text
   kids_english_app/app/assets/audio/songs/
   ```
7. Báo cho Antigravity hoặc cập nhật mốc giây Karaoke trong file JSON chủ đề tương ứng (`t01_hello.json` ...).

> [!TIP]
> **Mẹo tạo bài hát hay nhất trên Suno cho bé 4 tuổi:**
> - Giữ nguyên các thẻ `[Intro]`, `[Verse]`, `[Chorus]`, `[Outro]` trong lời bài hát vì Suno sẽ căn nhạc dạo và ngắt nghỉ theo các thẻ này rất chuẩn.
> - Nếu một lần tạo chưa ưng ý (giọng hát quá nhanh hoặc quá người lớn), bạn chỉ cần bấm **Create** lại một lần nữa để Suno đổi ca sĩ và hòa âm khác.

---

## 2. Danh Sách 5 Chủ Đề MVP Hiện Tại

---

### Chủ đề 1: Hello & Family (`t01_hello`)

* **Tên file đích:** `assets/audio/songs/s01_hello_song.mp3`
* **File JSON đồng bộ:** `assets/content/topics/t01_hello.json`
* **Từ vựng cốt lõi:** `Hello`, `Goodbye`, `Mommy`, `Daddy`, `Baby`, `Boy`, `Girl`, `Friend`
* **Thời lượng lý tưởng:** ~36 – 40 giây (105 BPM)

#### 🎵 Style of Music Prompt (Suno):
```text
Joyful upbeat preschool nursery rhyme, cheerful young female teacher singing warmly with kids chorus, acoustic ukulele, bright marimba, playful claps, bouncy drums, high energy, catchy preschool melody, 105 BPM, studio quality
```

#### 📝 Custom Lyrics (Suno):
```text
[Intro: Cheerful ukulele and marimba, handclaps]

Hello, hello! How are you?
Hello, hello! How are you?
I'm fine, I'm happy, thank you!
Hello Mommy! Hello Daddy!
Hello little baby, too!
Happy boy and happy girl,
Wave your hands: Goodbye, bye-bye!
See you soon, my good friend!

[Outro: Playful glockenspiel sparkle, kids cheering "Hooray!"]
```

---

### Chủ đề 2: Colors (`t02_colors`)

* **Tên file đích:** `assets/audio/songs/s02_rainbow_colors.mp3`
* **File JSON đồng bộ:** `assets/content/topics/t02_colors.json`
* **Từ vựng cốt lõi:** Đủ 10 màu sắc (`Red`, `Yellow`, `Green`, `Blue`, `Orange`, `Pink`, `Purple`, `Black`, `White`, `Brown`)
* **Thời lượng lý tưởng:** ~36 – 40 giây (105 BPM)

#### 🎵 Style of Music Prompt (Suno):
```text
Bright happy preschool nursery rhyme, cheerful female vocal, kids choir backing, acoustic guitar, bright xylophone, glockenspiel chimes, playful clapping, 105 BPM, warm educational vibe
```

#### 📝 Custom Lyrics (Suno):
```text
[Intro: Sparkling glockenspiel and sweet acoustic guitar]

Red and yellow, green and blue,
Orange, pink, and purple too!
Black and white and chocolate brown,
Pretty colors all around!
What color is it? Look and see!
Sing the rainbow song with me!
Red, blue, yellow, green! Hooray!

[Outro: Joyful acoustic chime, gentle finish]
```

---

### Chủ đề 3: Numbers 1–10 (`t03_numbers`)

* **Tên file đích:** `assets/audio/songs/s03_ten_little_fingers.mp3`
* **File JSON đồng bộ:** `assets/content/topics/t03_numbers.json`
* **Từ vựng cốt lõi:** Các số từ 1 đến 10 (`One` đến `Ten`)
* **Thời lượng lý tưởng:** ~36 – 42 giây (98 BPM - nhịp đếm chậm, rõ chữ)

#### 🎵 Style of Music Prompt (Suno):
```text
Playful counting song for toddlers, bouncy pizzicato strings, glockenspiel, upbeat acoustic drums, warm clear female vocal en-US, slow clear rhythmic counting, 98 BPM, cute cartoon vibe, studio quality
```

#### 📝 Custom Lyrics (Suno):
```text
[Intro: Bouncy pizzicato strings and playful glockenspiel]

One and two, and three bright stars,
Four and five, and six so far!
Seven, eight, and nine, and ten,
Let's all count them once again!
Show your fingers, ready, go!
One, two, three, four, five in a row!
Six, seven, eight, nine, ten up high!
Clap your hands and touch the sky!

[Outro: Rhythmic double clap, kids cheering "Hooray!"]
```

---

### Chủ đề 4: Animals (`t04_animals`)

* **Tên file đích:** `assets/audio/songs/s04_old_macdonald.mp3`
* **File JSON đồng bộ:** `assets/content/topics/t04_animals.json`
* **Từ vựng cốt lõi:** `Dog`, `Cat`, `Duck`, `Cow`, `Pig`, `Bird`, `Fish`, `Sheep`
* **Thời lượng lý tưởng:** ~38 – 42 giây (102 BPM)

#### 🎵 Style of Music Prompt (Suno):
```text
Cheerful country farm nursery rhyme, acoustic guitar, bouncy banjo, fun farm animal sounds, joyful clear female vocal with kids shouting animal sounds, upbeat 102 BPM, super fun and engaging
```

#### 📝 Custom Lyrics (Suno):
```text
[Intro: Cheerful banjo strum and playful whistle]

Welcome to Momo's happy farm!
Little puppy dog says woof, woof, woof!
Fluffy kitty cat says meow, meow, meow!
Yellow baby duck says quack, quack, quack!
Happy farm cow says moo, moo, moo!
Little pink pig says oink, oink, oink!
Bird in the sky and fish in the pond,
Sing with the animals all day long!

[Outro: Fun animal farm sound effects, kids cheering "Hooray!"]
```

---

### Chủ đề 5: My Body (`t05_body`)

* **Tên file đích:** `assets/audio/songs/s05_head_shoulders.mp3`
* **File JSON đồng bộ:** `assets/content/topics/t05_body.json`
* **Từ vựng cốt lõi:** `Head`, `Tummy`, `Arms`, `Legs`, `Eyes`, `Ears`, `Mouth`, `Nose`, `Hands`, `Feet`
* **Thời lượng lý tưởng:** ~36 – 40 giây (105 BPM - nhịp vận động TPR)

#### 🎵 Style of Music Prompt (Suno):
```text
High-energy preschool action song, upbeat marimba, handclaps, cheerful acoustic drums, bright warm female vocal with kids chorus, interactive dance rhythm, 105 BPM, happy movement song
```

#### 📝 Custom Lyrics (Suno):
```text
[Intro: Upbeat marimba roll and rhythmic handclaps]

Head and tummy, arms and legs, arms and legs!
Head and tummy, arms and legs, arms and legs!
And eyes, and ears, and mouth, and nose!
Clap your hands and stamp your feet, stamp your feet!
Touch your hair and wiggle your fingers, too!
Eyes, and ears, and mouth, and nose! Hooray!

[Outro: Fast drum roll, kids cheering "Hooray!"]
```

---

## 3. Mẫu Chuẩn Khi Bổ Sung Chủ Đề Mới (Template)

Khi thêm chủ đề mới (ví dụ Chủ đề 6: Trái cây, Chủ đề 7: Phương tiện giao thông,...), bạn hãy copy đoạn mẫu sau vào cuối file này để quản lý thống nhất:

```markdown
### Chủ đề [X]: [Tên Chủ Đề] (`t0[X]_[name]`)

* **Tên file đích:** `assets/audio/songs/s0[X]_[song_name].mp3`
* **File JSON đồng bộ:** `assets/content/topics/t0[X]_[name].json`
* **Từ vựng cốt lõi:** [Liệt kê 6-8 từ vựng chính cần xuất hiện trong bài hát]
* **Thời lượng lý tưởng:** ~35 – 45 giây (100 – 110 BPM)

#### 🎵 Style of Music Prompt (Suno):
`[Mô tả phong cách: preschool nursery rhyme, warm clear female vocal en-US, nhạc cụ tươi sáng: ukulele, marimba, piano, handclaps, tempo 100-105 BPM]`

#### 📝 Custom Lyrics (Suno):
```text
[Intro: Nhạc dạo 4 giây vui nhộn]

[Câu hát 1 - Nhắc từ vựng 1 & 2]
[Câu hát 2 - Lặp lại hoặc nhấn giai điệu]
[Câu hát 3 - Nhắc từ vựng 3 & 4]
[Câu hát 4 - Động tác tương tác hoặc câu hỏi]
[Câu hát 5 - Nhắc từ vựng 5 & 6]
[Câu hát 6 - Kết thúc vui tươi]

[Outro: Nhạc kết thúc nhẹ nhàng hoặc tiếng reo Hooray]
\```
```

---

## 4. Quy Trình Cập Nhật Sau Khi Tải File MP3 Về Máy

1. Đặt file tải về vào thư mục:
   `c:\workspace\ai_project\kids_english_app\app\assets\audio\songs\<tên_file>.mp3`
2. Mở file JSON chủ đề tương ứng trong `app/assets/content/topics/` (hoặc gửi thông báo cho Antigravity).
3. Kiểm tra mảng `song.lyrics` trong JSON để đảm bảo trường `"t"` (mốc giây bắt đầu hát của từng câu) khớp với file âm thanh thực tế.
4. Chạy app trên máy ảo hoặc thiết bị thật để thưởng thức màn hình Karaoke đồng bộ hoàn hảo!
