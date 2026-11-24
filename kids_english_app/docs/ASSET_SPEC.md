# ĐẶC TẢ TÀI NGUYÊN (ASSET SPECIFICATION) – App "Bé Vui Tiếng Anh"

> **Mục đích của tài liệu:** Tài liệu này được thiết kế độc lập để bạn có thể **copy sang một session AI khác (Midjourney, DALL-E/ChatGPT, ElevenLabs, Suno/Udio, hoặc giao cho Designer/Voice Actor)** để sản xuất toàn bộ hình ảnh và âm thanh cho bản MVP (5 chủ đề đầu tiên) mà vẫn đảm bảo **đúng tên file, đúng kích thước và đồng nhất 100% về phong cách**.

---

## MỤC LỤC
1. [Hướng dẫn sử dụng tài liệu này ở Session khác](#1-hướng-dẫn-sử-dụng-tài-liệu-này-ở-session-khác)
2. [Style Guide & Master Prompt (Bắt buộc đọc trước khi tạo ảnh)](#2-style-guide--master-prompt-bắt-buộc-đọc-trước-khi-tạo-ảnh)
3. [Quy chuẩn kỹ thuật (Hình ảnh & Âm thanh)](#3-quy-chuẩn-kỹ-thuật-hình-ảnh--âm-thanh)
4. [PHẦN A – DANH SÁCH HÌNH ẢNH (IMAGES)](#4-phần-a--danh-sách-hình-ảnh-images)
   - [A1. Nhân vật Mascot Momo (8 trạng thái)](#a1-nhân-vật-mascot-momo-8-trạng-thái)
   - [A2. Giao diện chung, Bản đồ & Avatar hồ sơ (21 file)](#a2-giao-diện-chung-bản-đồ--avatar-hồ-sơ-21-file)
   - [A3. Hình từ vựng & Sticker – Chủ đề 1: Hello! (12 file)](#a3-hình-từ-vựng--sticker--chủ-đề-1-hello-12-file)
   - [A4. Hình từ vựng & Sticker – Chủ đề 2: Colors (14 file)](#a4-hình-từ-vựng--sticker--chủ-đề-2-colors-14-file)
   - [A5. Hình từ vựng & Sticker – Chủ đề 3: Numbers 1–10 (14 file)](#a5-hình-từ-vựng--sticker--chủ-đề-3-numbers-110-14-file)
   - [A6. Hình từ vựng & Sticker – Chủ đề 4: Animals (16 file)](#a6-hình-từ-vựng--sticker--chủ-đề-4-animals-16-file)
   - [A7. Hình từ vựng & Sticker – Chủ đề 5: My Body (16 file)](#a7-hình-từ-vựng--sticker--chủ-đề-5-my-body-16-file)
   - [A8. Hình minh họa động tác TPR – Simon Says (8 file)](#a8-hình-minh-họa-động-tác-tpr--simon-says-8-file)
5. [PHẦN B – DANH SÁCH ÂM THANH (AUDIO)](#5-phần-b--danh-sách-âm-thanh-audio)
   - [B1. Giọng đọc Từ vựng & Câu ví dụ – 5 Chủ đề (104 file)](#b1-giọng-đọc-từ-vựng--câu-ví-dụ--5-chủ-đề-104-file)
   - [B2. Giọng đọc Mẫu câu giao tiếp & Hướng dẫn Phụ huynh (15 file)](#b2-giọng-đọc-mẫu-câu-giao-tiếp--hướng-dẫn-phụ-huynh-15-file)
   - [B3. Giọng Mascot Momo hướng dẫn, khen ngợi & TPR (28 file)](#b3-giọng-mascot-momo-hướng-dẫn-khen-ngợi--tpr-28-file)
   - [B4. Gợi ý Tiếng Việt (khi bật chế độ hỗ trợ Tiếng Việt) (15 file)](#b4-gợi-ý-tiếng-việt-khi-bật-chế-độ-hỗ-trợ-tiếng-việt-15-file)
   - [B5. Bài hát chủ đề – 5 bài Public Domain (5 file nhạc + mốc lời)](#b5-bài-hát-chủ-đề--5-bài-public-domain-5-file-nhạc--mốc-lời)
   - [B6. Hiệu ứng âm thanh – SFX & Nhạc nền (12 file)](#b6-hiệu-ứng-âm-thanh--sfx--nhạc-nền-12-file)

---

## 1. Hướng dẫn sử dụng tài liệu này ở Session khác

Khi bạn mở một session AI mới để tạo tài nguyên, hãy copy **Mục 2 (Style Guide)** kèm theo bảng của từng mục nhỏ (ví dụ **Mục A3**) và yêu cầu:

> *"Hãy đóng vai trò họa sĩ minh họa cho ứng dụng trẻ em 4 tuổi. Tuân thủ tuyệt đối `[MASTER STYLE PROMPT]` và `[CHARACTER SHEET - MOMO]` bên dưới để tạo từng hình trong danh sách, lưu hoặc đặt tên theo đúng cột `Đường dẫn file`."*

Với âm thanh (TTS / ElevenLabs / OpenAI Audio script):
> *"Hãy dùng script Python/Node hoặc công cụ TTS giọng Anh-Mỹ (en-US) theo đúng cấu hình ở Mục 3.2 để sinh hàng loạt file `.mp3` từ bảng văn bản dưới đây, lưu đúng theo cột `Đường dẫn file`."*

---

## 2. Style Guide & Master Prompt (Bắt buộc đọc trước khi tạo ảnh)

Để trẻ 4 tuổi dễ nhận biết và toàn bộ app không bị "lệch tông" giữa các lần tạo ảnh khác nhau, **mọi câu lệnh tạo hình (prompt)** đều phải ghép nối với **Master Style Prompt** dưới đây.

### 2.1. Master Style Prompt (Hậu tố gắn vào mọi prompt tạo hình đồ vật/từ vựng)
```text
children's book flat vector illustration for 4-year-old preschoolers, cute rounded friendly shapes, thick clean dark-brown outlines (#3D2C2E), warm soft pastel color palette, minimal details, single clear subject centered, isolated on a pure transparent background (or solid white #FFFFFF for easy background removal), no text, no watermark, no complex shadows, Duolingo ABC and Khan Academy Kids art style
```

### 2.2. Character Sheet – Chú khỉ MOMO (Gắn vào mọi prompt có nhân vật Momo)
```text
CHARACTER MOMO: A cute happy baby monkey mascot, 4 years old look, warm cinnamon brown fur (#C67D3B), cream beige face and round tummy (#FFF1D6), big expressive dark brown eyes, round ears, wearing a bright turquoise T-shirt (#2EC4B6) with a small yellow star (#FFD23F) on the chest, short tail curled up. Flat vector illustration style, thick clean dark-brown outlines (#3D2C2E), consistent proportions (big head, small chubby body, 2.5 heads tall).
```

### 2.3. Bảng màu chuẩn của App
- **Cam năng lượng:** `#FF9F1C`
- **Xanh ngọc (áo Momo):** `#2EC4B6`
- **Hồng ấm:** `#FF6B9A`
- **Vàng sao:** `#FFD23F`
- **Nền kem dịu mắt:** `#FFF8E7`
- **Nền bầu trời:** `#E3F4FF`
- **Nét viền nhân vật/đồ vật:** Nâu đậm ấm `#3D2C2E` (không dùng đen tuyền `#000000` để hình mềm mại hơn).

---

## 3. Quy chuẩn kỹ thuật (Hình ảnh & Âm thanh)

### 3.1. Hình ảnh (Images)
| Loại hình | Định dạng | Kích thước (px) | Nền | Ghi chú |
|---|---|---|---|---|
| **Từ vựng (`images/topics/...`)** | PNG (hoặc WebP) | `512 × 512` | Trong suốt (Transparent) | Đối tượng chiếm ~80% khung hình, căn giữa |
| **Sticker (`images/stickers/...`)** | PNG | `512 × 512` | Trong suốt | Có viền trắng dày kiểu sticker dán (`thick white die-cut sticker border`) |
| **Mascot Momo (`images/common/momo_*`)** | PNG | `512 × 512` | Trong suốt | Toàn thân, căn giữa |
| **Icon đảo trên bản đồ (`images/map/...`)** | PNG | `512 × 512` | Trong suốt | Hình hòn đảo nổi 2.5D dễ thương |
| **Nền màn hình (`images/map/bg_*`, `images/common/bg_*`)** | PNG / WebP | `1920 × 1080` (16:9 ngang) | Kín khung | Ít chi tiết ở giữa để không rối các nút bấm |
| **Avatar hồ sơ bé (`images/common/avatar_*`)** | PNG | `256 × 256` | Tròn hoặc nền màu pastel | Khuôn mặt các con vật dễ thương |
| **Bìa bài hát (`images/songs/...`)** | PNG / WebP | `600 × 600` | Kín khung | Tươi vui, có nhân vật Momo |

### 3.2. Âm thanh (Audio)
| Loại âm thanh | Định dạng | Thông số | Yêu cầu giọng đọc |
|---|---|---|---|
| **Từ vựng & Câu (`audio/words/`, `audio/sentences/`)** | `.mp3` | 44.1kHz, Mono, 64–128kbps | Giọng **Anh – Mỹ (en-US)**, nữ hoặc giọng trẻ em lớn, ấm áp, phát âm chuẩn, **tốc độ chậm hơn bình thường ~15–20%**, rõ từng âm cuối, cắt khoảng lặng đầu/cuối `< 100ms` |
| **Giọng Momo (`audio/instructions/`)** | `.mp3` | 44.1kHz, Mono, 64–128kbps | Giọng hoạt hình trẻ thơ, hào hứng, thân thiện, khích lệ |
| **Gợi ý Tiếng Việt (`audio/vi/`)** | `.mp3` | 44.1kHz, Mono, 64–128kbps | Giọng nữ tiếng Việt nhẹ nhàng, truyền cảm (như cô giáo mầm non) |
| **Bài hát (`audio/songs/`)** | `.mp3` | 44.1kHz, Stereo, 128kbps | Tempo vừa phải (95–110 BPM), nhạc cụ tươi sáng (ukulele, marimba, piano), lời hát cực kỳ rõ ràng, độ dài **60–90 giây/bài** |
| **Hiệu ứng SFX (`audio/sfx/`)** | `.mp3` hoặc `.wav` | 44.1kHz, Mono | Ngắn gọn (`0.2s – 1.5s`), âm lượng cân bằng, không chói tai |

---

## 4. PHẦN A – DANH SÁCH HÌNH ẢNH (IMAGES)

> Tất cả đường dẫn tính từ thư mục `app/assets/`.

### A1. Nhân vật Mascot Momo (8 trạng thái)
*Gắn `[CHARACTER MOMO]` + prompt bên dưới + `[Master Style Prompt]`.*

| # | Đường dẫn file | Trạng thái | Prompt chi tiết (tiếng Anh để đưa vào AI tạo ảnh) |
|---|---|---|---|
| 1 | `images/common/momo_idle.png` | Đứng bình thường | `[CHARACTER MOMO]`, standing facing forward with a gentle warm smile, arms relaxed, friendly welcoming posture |
| 2 | `images/common/momo_wave.png` | Vẫy tay chào | `[CHARACTER MOMO]`, waving one hand high with a big cheerful open-mouth smile, saying hello |
| 3 | `images/common/momo_talk.png` | Đang nói / hướng dẫn | `[CHARACTER MOMO]`, one hand gesturing forward while speaking happily, mouth open mid-word, curious bright eyes |
| 4 | `images/common/momo_cheer.png` | Khen ngợi / nhảy vui | `[CHARACTER MOMO]`, jumping in the air with both arms raised in celebration, sparkles and tiny stars around, super excited expression |
| 5 | `images/common/momo_think.png` | Gợi ý / suy nghĩ | `[CHARACTER MOMO]`, tilting head slightly with one finger tapping chin, encouraging gentle smile, "try again" friendly look |
| 6 | `images/common/momo_listen.png` | Lắng nghe bé nói | `[CHARACTER MOMO]`, cupping one hand around a big round ear to listen carefully, leaning slightly forward with an encouraging smile |
| 7 | `images/common/momo_sleepy.png` | Hết giờ / đi ngủ | `[CHARACTER MOMO]`, wearing a cute light-blue nightcap with a yellow pom-pom, yawning sweetly with eyes half-closed, hugging a soft white pillow |
| 8 | `images/common/momo_sing.png` | Ca hát | `[CHARACTER MOMO]`, holding a colorful toy microphone, singing happily with musical notes floating around |

---

### A2. Giao diện chung, Bản đồ & Avatar hồ sơ (21 file)

| # | Đường dẫn file | Kích thước | Mô tả / Prompt chi tiết |
|---|---|---|---|
| 1 | `images/common/app_logo.png` | 512×512 | App icon: `[CHARACTER MOMO]` peeking out from a bright orange rounded frame with a colorful ABC blocks and a yellow star, vibrant preschool app icon |
| 2 | `images/common/bg_kid_default.png` | 1920×1080 | Soft pastel landscape background for kids game: gentle rolling light-green hills, pale blue sky (`#E3F4FF`) with a few fluffy white clouds, warm sunlight, empty clean center area |
| 3 | `images/map/bg_ocean_map.png` | 1920×1080 | Top-down 2.5D adventure map background: calm turquoise-blue pastel ocean with soft wave patterns, dotted stepping-stone path connecting 5 island spots from left to right, cute tiny sailboats and clouds |
| 4 | `images/map/island_t01_hello.png` | 512×512 | Cute 2.5D floating cartoon island with a cozy treehouse, a welcoming rainbow arch, and a waving flag, preschool game map icon |
| 5 | `images/map/island_t02_colors.png` | 512×512 | Cute 2.5D floating cartoon island shaped like a giant artist paint palette with colorful flowers, rainbow waterfall, and paintbrushes |
| 6 | `images/map/island_t03_numbers.png` | 512×512 | Cute 2.5D floating cartoon island with giant colorful wooden number blocks (1, 2, 3) and playful stepping stones |
| 7 | `images/map/island_t04_animals.png` | 512×512 | Cute 2.5D floating cartoon farm island with a red barn, green pasture, white fence, and hay bales |
| 8 | `images/map/island_t05_body.png` | 512×512 | Cute 2.5D floating cartoon playground island with a slide, trampoline, and cheerful movement symbols |
| 9 | `images/map/island_generic.png` | 512×512 | Cute 2.5D floating cartoon green tropical island with palm trees and a treasure chest (dùng mặc định cho các gói chủ đề nạp thêm nếu gói không có icon riêng) |
| 10 | `images/common/avatar_monkey.png` | 256×256 | Circular kid profile avatar: cute baby monkey face on a soft yellow pastel circle background |
| 11 | `images/common/avatar_puppy.png` | 256×256 | Circular kid profile avatar: cute golden puppy face with floppy ears on a soft blue pastel circle background |
| 12 | `images/common/avatar_kitten.png` | 256×256 | Circular kid profile avatar: cute orange tabby kitten face on a soft pink pastel circle background |
| 13 | `images/common/avatar_bunny.png` | 256×256 | Circular kid profile avatar: cute white bunny face with long pink ears on a soft mint green circle background |
| 14 | `images/common/avatar_panda.png` | 256×256 | Circular kid profile avatar: cute chubby panda face on a soft lavender pastel circle background |
| 15 | `images/common/avatar_lion.png` | 256×256 | Circular kid profile avatar: cute baby lion cub face with fluffy mane on a soft peach circle background |
| 16 | `images/common/placeholder_word.png` | 512×512 | Cute colorful gift box with a question mark and stars (hình mặc định khi gói chủ đề nạp thêm chỉ có JSON chưa có ảnh) |
| 17 | `images/songs/cover_s01_hello.png` | 600×600 | Song cover art: `[CHARACTER MOMO]` and animal friends waving hello under a sunny rainbow |
| 18 | `images/songs/cover_s02_colors.png` | 600×600 | Song cover art: `[CHARACTER MOMO]` painting a big bright rainbow in the sky with a giant brush |
| 19 | `images/songs/cover_s03_numbers.png` | 600×600 | Song cover art: Five cute little monkeys jumping happily on a soft bed with numbers 1 to 5 floating |
| 20 | `images/songs/cover_s04_animals.png` | 600×600 | Song cover art: `[CHARACTER MOMO]` wearing a straw farmer hat in front of a red barn with a dog, cat, duck, and cow |
| 21 | `images/songs/cover_s05_body.png` | 600×600 | Song cover art: `[CHARACTER MOMO]` touching his head and dancing with musical notes around |

---

### A3. Hình từ vựng & Sticker – Chủ đề 1: Hello! (`t01_hello`) (12 file)

| # | `word_id` | Đường dẫn file | Prompt chi tiết (+ `[Master Style Prompt]`) |
|---|---|---|---|
| 1 | `t01_hello` | `images/topics/t01_hello/hello.png` | A cute cheerful 4-year-old child waving hand with a big friendly smile, warm welcoming gesture |
| 2 | `t01_goodbye` | `images/topics/t01_hello/goodbye.png` | A cute child wearing a small backpack walking towards an open door and waving goodbye back with a warm smile |
| 3 | `t01_boy` | `images/topics/t01_hello/boy.png` | A cute happy 4-year-old boy with short dark hair, wearing a yellow T-shirt and blue shorts, standing and smiling |
| 4 | `t01_girl` | `images/topics/t01_hello/girl.png` | A cute happy 4-year-old girl with two pigtails, wearing a pink dress, standing and smiling |
| 5 | `t01_mommy` | `images/topics/t01_hello/mommy.png` | A warm loving young mother with a gentle smile and open arms, wearing a cozy coral sweater |
| 6 | `t01_daddy` | `images/topics/t01_hello/daddy.png` | A kind cheerful young father with a big warm smile, waving hand, wearing a light blue polo shirt |
| 7 | `t01_baby` | `images/topics/t01_hello/baby.png` | An adorable chubby baby sitting in a yellow onesie, giggling with a tiny curl of hair on top |
| 8 | `t01_friend` | `images/topics/t01_hello/friend.png` | Two cute diverse 4-year-old kids (a boy and a girl) giving each other a happy high-five |
| 9 | *(sticker 1)* | `images/stickers/stk_t01_1.png` | Die-cut sticker with thick white border: `[CHARACTER MOMO]` giving a big two-handed wave with a rainbow behind |
| 10 | *(sticker 2)* | `images/stickers/stk_t01_2.png` | Die-cut sticker with thick white border: Two smiling star friends giving a high-five |
| 11 | *(sticker 3)* | `images/stickers/stk_t01_3.png` | Die-cut sticker with thick white border: A happy family heart badge with Mommy, Daddy, and Baby smiling inside |
| 12 | *(sticker 4)* | `images/stickers/stk_t01_4.png` | Die-cut sticker with thick white border: Golden trophy cup with a waving hand emblem and sparkles |

---

### A4. Hình từ vựng & Sticker – Chủ đề 2: Colors (`t02_colors`) (14 file)
> **Lưu ý sư phạm:** Trẻ 4 tuổi hiểu màu sắc tốt nhất qua **mảng màu lớn, rõ ràng** (hình đốm sơn / ngôi sao / quả bóng màu đồng nhất có khuôn mặt dễ thương), không nên dùng cảnh phức tạp nhiều màu làm trẻ bối rối.

| # | `word_id` | Đường dẫn file | Mã màu chuẩn | Prompt chi tiết (+ `[Master Style Prompt]`) |
|---|---|---|---|---|
| 1 | `t02_red` | `images/topics/t02_colors/red.png` | `#EF476F` | A big glossy bright RED (`#EF476F`) paint splash blob character with cute smiling eyes, pure solid red color |
| 2 | `t02_blue` | `images/topics/t02_colors/blue.png` | `#118AB2` | A big glossy bright SKY BLUE (`#118AB2`) paint splash blob character with cute smiling eyes, pure solid blue color |
| 3 | `t02_yellow` | `images/topics/t02_colors/yellow.png` | `#FFD166` | A big glossy bright SUNNY YELLOW (`#FFD166`) paint splash blob character with cute smiling eyes, pure solid yellow color |
| 4 | `t02_green` | `images/topics/t02_colors/green.png` | `#06D6A0` | A big glossy bright LEAF GREEN (`#06D6A0`) paint splash blob character with cute smiling eyes, pure solid green color |
| 5 | `t02_orange` | `images/topics/t02_colors/orange.png` | `#FF9F1C` | A big glossy bright ORANGE (`#FF9F1C`) paint splash blob character with cute smiling eyes, pure solid orange color |
| 6 | `t02_pink` | `images/topics/t02_colors/pink.png` | `#FF70A6` | A big glossy bright BUBBLEGUM PINK (`#FF70A6`) paint splash blob character with cute smiling eyes, pure solid pink color |
| 7 | `t02_purple` | `images/topics/t02_colors/purple.png` | `#9B5DE5` | A big glossy bright GRAPE PURPLE (`#9B5DE5`) paint splash blob character with cute smiling eyes, pure solid purple color |
| 8 | `t02_black` | `images/topics/t02_colors/black.png` | `#2B2D42` | A big glossy CHARCOAL BLACK (`#2B2D42`) paint splash blob character with cute bright white smiling eyes |
| 9 | `t02_white` | `images/topics/t02_colors/white.png` | `#FFFFFF` | A big puffy PURE WHITE (`#FFFFFF`) cloud-shaped paint blob character with cute smiling eyes and a clear dark-brown outline |
| 10 | `t02_brown` | `images/topics/t02_colors/brown.png` | `#8D5B4C` | A big glossy CHOCOLATE BROWN (`#8D5B4C`) paint splash blob character with cute smiling eyes, pure solid brown color |
| 11 | *(sticker 1)* | `images/stickers/stk_t02_1.png` | — | Die-cut sticker with thick white border: A cheerful smiling 7-color rainbow with two fluffy white clouds |
| 12 | *(sticker 2)* | `images/stickers/stk_t02_2.png` | — | Die-cut sticker with thick white border: A wooden artist palette with colorful paint dots and a happy paintbrush |
| 13 | *(sticker 3)* | `images/stickers/stk_t02_3.png` | — | Die-cut sticker with thick white border: A bunch of three shiny balloons in red, blue, and yellow tied with a ribbon |
| 14 | *(sticker 4)* | `images/stickers/stk_t02_4.png` | — | Die-cut sticker with thick white border: `[CHARACTER MOMO]` wearing a beret hat holding a rainbow paintbrush |

---

### A5. Hình từ vựng & Sticker – Chủ đề 3: Numbers 1–10 (`t03_numbers`) (14 file)
> **Lưu ý sư phạm:** Trẻ 4 tuổi học số cần nhìn thấy **con số lớn kèm đúng số lượng vật thể (chấm tròn/quả dâu/ngôi sao) dễ đếm bằng ngón tay**.

| # | `word_id` | Đường dẫn file | Prompt chi tiết (+ `[Master Style Prompt]`) |
|---|---|---|---|
| 1 | `t03_one` | `images/topics/t03_numbers/one.png` | Big chunky rounded number "1" in bright red next to exactly ONE cute smiling yellow star, clear and easy for a toddler to count |
| 2 | `t03_two` | `images/topics/t03_numbers/two.png` | Big chunky rounded number "2" in bright orange next to exactly TWO cute red strawberries side by side |
| 3 | `t03_three` | `images/topics/t03_numbers/three.png` | Big chunky rounded number "3" in sunny yellow next to exactly THREE cute yellow rubber ducks in a row |
| 4 | `t03_four` | `images/topics/t03_numbers/four.png` | Big chunky rounded number "4" in leaf green next to exactly FOUR colorful cupcakes arranged in a 2x2 grid |
| 5 | `t03_five` | `images/topics/t03_numbers/five.png` | Big chunky rounded number "5" in sky blue next to a cute open hand showing 5 fingers and FIVE shiny apples |
| 6 | `t03_six` | `images/topics/t03_numbers/six.png` | Big chunky rounded number "6" in purple next to exactly SIX colorful balloons arranged in two rows of three |
| 7 | `t03_seven` | `images/topics/t03_numbers/seven.png` | Big chunky rounded number "7" in pink next to exactly SEVEN bright rainbow stars arranged neatly |
| 8 | `t03_eight` | `images/topics/t03_numbers/eight.png` | Big chunky rounded number "8" in turquoise next to exactly EIGHT cute orange carrots arranged in two rows of four |
| 9 | `t03_nine` | `images/topics/t03_numbers/nine.png` | Big chunky rounded number "9" in coral red next to exactly NINE cute blue butterflies arranged in a 3x3 grid |
| 10 | `t03_ten` | `images/topics/t03_numbers/ten.png` | Big chunky rounded number "10" in gold next to two open hands showing all 10 fingers with tiny stars on each fingertip |
| 11 | *(sticker 1)* | `images/stickers/stk_t03_1.png` | Die-cut sticker with thick white border: Number blocks 1, 2, 3 stacked together with sparkles |
| 12 | *(sticker 2)* | `images/stickers/stk_t03_2.png` | Die-cut sticker with thick white border: A cute high-five hand with number "5" on the palm |
| 13 | *(sticker 3)* | `images/stickers/stk_t03_3.png` | Die-cut sticker with thick white border: A birthday cake with 4 lit candles (for a 4-year-old) |
| 14 | *(sticker 4)* | `images/stickers/stk_t03_4.png` | Die-cut sticker with thick white border: `[CHARACTER MOMO]` wearing a golden crown with number "10" |

---

### A6. Hình từ vựng & Sticker – Chủ đề 4: Animals (`t04_animals`) (16 file)

| # | `word_id` | Đường dẫn file | Prompt chi tiết (+ `[Master Style Prompt]`) |
|---|---|---|---|
| 1 | `t04_dog` | `images/topics/t04_animals/dog.png` | A cute friendly golden puppy dog sitting happily with tongue out, wagging tail, wearing a red collar |
| 2 | `t04_cat` | `images/topics/t04_animals/cat.png` | A cute chubby orange tabby kitten sitting and smiling with soft whiskers and a curled tail |
| 3 | `t04_bird` | `images/topics/t04_animals/bird.png` | A cute round little bluebird with wings slightly spread, singing happily |
| 4 | `t04_fish` | `images/topics/t04_animals/fish.png` | A cute bright orange-and-white clownfish swimming with a happy smile and a few tiny water bubbles |
| 5 | `t04_duck` | `images/topics/t04_animals/duck.png` | A cute fluffy yellow duckling with an orange beak and webbed feet, waddling happily |
| 6 | `t04_chicken` | `images/topics/t04_animals/chicken.png` | A cute plump white-and-brown farm hen with a small red comb on top, smiling warmly |
| 7 | `t04_cow` | `images/topics/t04_animals/cow.png` | A cute friendly dairy cow, white with black patches, pink snout, and small horns, smiling happily |
| 8 | `t04_pig` | `images/topics/t04_animals/pig.png` | A cute chubby pink piglet with a curly tail and big round snout, smiling cheerfully |
| 9 | `t04_horse` | `images/topics/t04_animals/horse.png` | A cute friendly brown pony horse with a cream mane and tail, trotting happily |
| 10 | `t04_rabbit` | `images/topics/t04_animals/rabbit.png` | A cute fluffy white rabbit with long pink-lined ears, holding a tiny orange carrot |
| 11 | `t04_mouse` | `images/topics/t04_animals/mouse.png` | A cute tiny gray mouse with big round pink ears and a long tail, holding a small piece of yellow cheese |
| 12 | `t04_sheep` | `images/topics/t04_animals/sheep.png` | A cute fluffy cloud-like white wool sheep with a warm beige face and floppy ears, smiling |
| 13 | *(sticker 1)* | `images/stickers/stk_t04_1.png` | Die-cut sticker with thick white border: Cute puppy and kitten hugging each other |
| 14 | *(sticker 2)* | `images/stickers/stk_t04_2.png` | Die-cut sticker with thick white border: Cute yellow duckling wearing a captain hat |
| 15 | *(sticker 3)* | `images/stickers/stk_t04_3.png` | Die-cut sticker with thick white border: Cute cow and pig smiling in front of a little red barn |
| 16 | *(sticker 4)* | `images/stickers/stk_t04_4.png` | Die-cut sticker with thick white border: `[CHARACTER MOMO]` riding happily on a friendly brown pony |

---

### A7. Hình từ vựng & Sticker – Chủ đề 5: My Body (`t05_body`) (16 file)
> **Lưu ý sư phạm:** Mỗi hình bộ phận cơ thể nên có **cận cảnh rõ bộ phận đó** hoặc một em bé dễ thương chỉ mũi tên/bàn tay vào đúng bộ phận đó để trẻ 4 tuổi không nhầm giữa `head`, `face`, `hair`, `arms`, `hands`.

| # | `word_id` | Đường dẫn file | Prompt chi tiết (+ `[Master Style Prompt]`) |
|---|---|---|---|
| 1 | `t05_head` | `images/topics/t05_body/head.png` | A cute smiling 4-year-old child tapping the top of their HEAD with both hands, a soft glowing highlight circle around the head |
| 2 | `t05_eyes` | `images/topics/t05_body/eyes.png` | Close-up of a cute child's face pointing gently towards their two big bright sparkling brown EYES |
| 3 | `t05_ears` | `images/topics/t05_body/ears.png` | A cute smiling child cupping both hands behind their two EARS, highlighted clearly |
| 4 | `t05_nose` | `images/topics/t05_body/nose.png` | Close-up of a cute smiling child touching the tip of their little button NOSE with one finger |
| 5 | `t05_mouth` | `images/topics/t05_body/mouth.png` | Close-up of a cute child pointing to their wide happy smiling MOUTH showing clean white teeth |
| 6 | `t05_hair` | `images/topics/t05_body/hair.png` | A cute child brushing their soft wavy dark-brown HAIR with a colorful comb, hair highlighted |
| 7 | `t05_hands` | `images/topics/t05_body/hands.png` | Two cute open child HANDS held up palms facing forward, clean and bright |
| 8 | `t05_fingers` | `images/topics/t05_body/fingers.png` | A cute child's hand wiggling five FINGERS with tiny colorful star sparkles at the fingertips |
| 9 | `t05_arms` | `images/topics/t05_body/arms.png` | A cute child stretching both ARMS out wide to the sides in a big happy gesture, arms highlighted |
| 10 | `t05_legs` | `images/topics/t05_body/legs.png` | A cute child wearing shorts pointing down to their two strong LEGS, legs highlighted clearly |
| 11 | `t05_feet` | `images/topics/t05_body/feet.png` | Two cute bare child FEET side by side wiggling toes happily on a soft mat |
| 12 | `t05_tummy` | `images/topics/t05_body/tummy.png` | A cute giggling child patting their round TUMMY (belly) with both hands after a yummy meal |
| 13 | *(sticker 1)* | `images/stickers/stk_t05_1.png` | Die-cut sticker with thick white border: Two clapping hands with colorful music notes and sparkles |
| 14 | *(sticker 2)* | `images/stickers/stk_t05_2.png` | Die-cut sticker with thick white border: A cute smiling star flexing its strong arms |
| 15 | *(sticker 3)* | `images/stickers/stk_t05_3.png` | Die-cut sticker with thick white border: Two happy footprints in bright paint colors |
| 16 | *(sticker 4)* | `images/stickers/stk_t05_4.png` | Die-cut sticker with thick white border: `[CHARACTER MOMO]` touching his toes in a playful gymnastic pose |

---

### A8. Hình minh họa động tác TPR – Simon Says (8 file)
*Dùng cho hoạt động vận động cơ thể: Momo làm mẫu để bé bắt chước ngoài đời thực.*

| # | `command_id` | Đường dẫn file | Prompt chi tiết (+ `[Master Style Prompt]`) |
|---|---|---|---|
| 1 | `cmd_wave_hello` | `images/tpr/cmd_wave_hello.png` | `[CHARACTER MOMO]` waving both hands high in the air with curved motion lines, big cheerful smile |
| 2 | `cmd_clap_hands` | `images/tpr/cmd_clap_hands.png` | `[CHARACTER MOMO]` clapping both hands together in front of chest with yellow sound-burst lines |
| 3 | `cmd_touch_nose` | `images/tpr/cmd_touch_nose.png` | `[CHARACTER MOMO]` touching the tip of his round nose with one finger, winking playfully |
| 4 | `cmd_touch_head` | `images/tpr/cmd_touch_head.png` | `[CHARACTER MOMO]` placing both hands on top of his head with a big goofy grin |
| 5 | `cmd_stamp_feet` | `images/tpr/cmd_stamp_feet.png` | `[CHARACTER MOMO]` lifting one foot and stamping down on the ground with cute puff clouds around the feet |
| 6 | `cmd_jump_high` | `images/tpr/cmd_jump_high.png` | `[CHARACTER MOMO]` jumping high off the ground with knees bent and arms up, motion lines below |
| 7 | `cmd_fly_bird` | `images/tpr/cmd_fly_bird.png` | `[CHARACTER MOMO]` spreading both arms out like bird wings and flapping happily |
| 8 | `cmd_swim_fish` | `images/tpr/cmd_swim_fish.png` | `[CHARACTER MOMO]` putting hands together in front and wiggling like a swimming fish |

---

## 5. PHẦN B – DANH SÁCH ÂM THANH (AUDIO)

> Tất cả đường dẫn tính từ thư mục `app/assets/`.
> Giọng đọc tiếng Anh: **Anh – Mỹ (en-US)**, phát âm rõ, chậm rãi, tươi vui.

### B1. Giọng đọc Từ vựng & Câu ví dụ – 5 Chủ đề (104 file: 52 từ + 52 câu)

#### Chủ đề 1: Hello! (`t01_hello`)
| # | `word_id` | File âm thanh TỪ (`audio/words/...`) | Văn bản đọc (Từ) | File âm thanh CÂU (`audio/sentences/...`) | Văn bản đọc (Câu ví dụ) |
|---|---|---|---|---|---|
| 1 | `t01_hello` | `audio/words/t01_hello.mp3` | Hello! | `audio/sentences/t01_hello_s.mp3` | Hello! Nice to meet you! |
| 2 | `t01_goodbye` | `audio/words/t01_goodbye.mp3` | Goodbye! | `audio/sentences/t01_goodbye_s.mp3` | Goodbye! See you soon! |
| 3 | `t01_boy` | `audio/words/t01_boy.mp3` | Boy. | `audio/sentences/t01_boy_s.mp3` | I am a happy boy! |
| 4 | `t01_girl` | `audio/words/t01_girl.mp3` | Girl. | `audio/sentences/t01_girl_s.mp3` | I am a happy girl! |
| 5 | `t01_mommy` | `audio/words/t01_mommy.mp3` | Mommy. | `audio/sentences/t01_mommy_s.mp3` | I love my mommy! |
| 6 | `t01_daddy` | `audio/words/t01_daddy.mp3` | Daddy. | `audio/sentences/t01_daddy_s.mp3` | I love my daddy! |
| 7 | `t01_baby` | `audio/words/t01_baby.mp3` | Baby. | `audio/sentences/t01_baby_s.mp3` | Look at the cute baby! |
| 8 | `t01_friend` | `audio/words/t01_friend.mp3` | Friend. | `audio/sentences/t01_friend_s.mp3` | You are my good friend! |

#### Chủ đề 2: Colors (`t02_colors`)
| # | `word_id` | File âm thanh TỪ | Văn bản đọc (Từ) | File âm thanh CÂU | Văn bản đọc (Câu ví dụ) |
|---|---|---|---|---|---|
| 9 | `t02_red` | `audio/words/t02_red.mp3` | Red. | `audio/sentences/t02_red_s.mp3` | It's red! A red apple. |
| 10 | `t02_blue` | `audio/words/t02_blue.mp3` | Blue. | `audio/sentences/t02_blue_s.mp3` | It's blue! The sky is blue. |
| 11 | `t02_yellow` | `audio/words/t02_yellow.mp3` | Yellow. | `audio/sentences/t02_yellow_s.mp3` | It's yellow! A yellow sun. |
| 12 | `t02_green` | `audio/words/t02_green.mp3` | Green. | `audio/sentences/t02_green_s.mp3` | It's green! A green leaf. |
| 13 | `t02_orange` | `audio/words/t02_orange.mp3` | Orange. | `audio/sentences/t02_orange_s.mp3` | It's orange! I like orange. |
| 14 | `t02_pink` | `audio/words/t02_pink.mp3` | Pink. | `audio/sentences/t02_pink_s.mp3` | It's pink! A pink flower. |
| 15 | `t02_purple` | `audio/words/t02_purple.mp3` | Purple. | `audio/sentences/t02_purple_s.mp3` | It's purple! Purple grapes. |
| 16 | `t02_black` | `audio/words/t02_black.mp3` | Black. | `audio/sentences/t02_black_s.mp3` | It's black! A black hat. |
| 17 | `t02_white` | `audio/words/t02_white.mp3` | White. | `audio/sentences/t02_white_s.mp3` | It's white! A white cloud. |
| 18 | `t02_brown` | `audio/words/t02_brown.mp3` | Brown. | `audio/sentences/t02_brown_s.mp3` | It's brown! Momo is brown. |

#### Chủ đề 3: Numbers 1–10 (`t03_numbers`)
| # | `word_id` | File âm thanh TỪ | Văn bản đọc (Từ) | File âm thanh CÂU | Văn bản đọc (Câu ví dụ) |
|---|---|---|---|---|---|
| 19 | `t03_one` | `audio/words/t03_one.mp3` | One. | `audio/sentences/t03_one_s.mp3` | One! One little star. |
| 20 | `t03_two` | `audio/words/t03_two.mp3` | Two. | `audio/sentences/t03_two_s.mp3` | Two! One, two strawberries. |
| 21 | `t03_three` | `audio/words/t03_three.mp3` | Three. | `audio/sentences/t03_three_s.mp3` | Three! Three yellow ducks. |
| 22 | `t03_four` | `audio/words/t03_four.mp3` | Four. | `audio/sentences/t03_four_s.mp3` | Four! I am four years old! |
| 23 | `t03_five` | `audio/words/t03_five.mp3` | Five. | `audio/sentences/t03_five_s.mp3` | Five! Give me high five! |
| 24 | `t03_six` | `audio/words/t03_six.mp3` | Six. | `audio/sentences/t03_six_s.mp3` | Six! Six big balloons. |
| 25 | `t03_seven` | `audio/words/t03_seven.mp3` | Seven. | `audio/sentences/t03_seven_s.mp3` | Seven! Seven rainbow stars. |
| 26 | `t03_eight` | `audio/words/t03_eight.mp3` | Eight. | `audio/sentences/t03_eight_s.mp3` | Eight! Eight yummy carrots. |
| 27 | `t03_nine` | `audio/words/t03_nine.mp3` | Nine. | `audio/sentences/t03_nine_s.mp3` | Nine! Nine blue butterflies. |
| 28 | `t03_ten` | `audio/words/t03_ten.mp3` | Ten. | `audio/sentences/t03_ten_s.mp3` | Ten! Ten little fingers! |

#### Chủ đề 4: Animals (`t04_animals`)
| # | `word_id` | File âm thanh TỪ | Văn bản đọc (Từ) | File âm thanh CÂU | Văn bản đọc (Câu ví dụ) |
|---|---|---|---|---|---|
| 29 | `t04_dog` | `audio/words/t04_dog.mp3` | Dog. | `audio/sentences/t04_dog_s.mp3` | It's a dog! Woof, woof! |
| 30 | `t04_cat` | `audio/words/t04_cat.mp3` | Cat. | `audio/sentences/t04_cat_s.mp3` | It's a cat! Meow, meow! |
| 31 | `t04_bird` | `audio/words/t04_bird.mp3` | Bird. | `audio/sentences/t04_bird_s.mp3` | It's a bird! Tweet, tweet! |
| 32 | `t04_fish` | `audio/words/t04_fish.mp3` | Fish. | `audio/sentences/t04_fish_s.mp3` | Look! The fish can swim! |
| 33 | `t04_duck` | `audio/words/t04_duck.mp3` | Duck. | `audio/sentences/t04_duck_s.mp3` | It's a duck! Quack, quack! |
| 34 | `t04_chicken` | `audio/words/t04_chicken.mp3` | Chicken. | `audio/sentences/t04_chicken_s.mp3` | It's a chicken! Cluck, cluck! |
| 35 | `t04_cow` | `audio/words/t04_cow.mp3` | Cow. | `audio/sentences/t04_cow_s.mp3` | It's a cow! Moo, moo! |
| 36 | `t04_pig` | `audio/words/t04_pig.mp3` | Pig. | `audio/sentences/t04_pig_s.mp3` | It's a cute pink pig! Oink, oink! |
| 37 | `t04_horse` | `audio/words/t04_horse.mp3` | Horse. | `audio/sentences/t04_horse_s.mp3` | The horse runs fast! Neigh! |
| 38 | `t04_rabbit` | `audio/words/t04_rabbit.mp3` | Rabbit. | `audio/sentences/t04_rabbit_s.mp3` | Hop, hop like a rabbit! |
| 39 | `t04_mouse` | `audio/words/t04_mouse.mp3` | Mouse. | `audio/sentences/t04_mouse_s.mp3` | A little mouse! Squeak, squeak! |
| 40 | `t04_sheep` | `audio/words/t04_sheep.mp3` | Sheep. | `audio/sentences/t04_sheep_s.mp3` | A white sheep! Baa, baa! |

#### Chủ đề 5: My Body (`t05_body`)
| # | `word_id` | File âm thanh TỪ | Văn bản đọc (Từ) | File âm thanh CÂU | Văn bản đọc (Câu ví dụ) |
|---|---|---|---|---|---|
| 41 | `t05_head` | `audio/words/t05_head.mp3` | Head. | `audio/sentences/t05_head_s.mp3` | Touch your head! |
| 42 | `t05_eyes` | `audio/words/t05_eyes.mp3` | Eyes. | `audio/sentences/t05_eyes_s.mp3` | Close your eyes. Open your eyes! |
| 43 | `t05_ears` | `audio/words/t05_ears.mp3` | Ears. | `audio/sentences/t05_ears_s.mp3` | These are my ears. |
| 44 | `t05_nose` | `audio/words/t05_nose.mp3` | Nose. | `audio/sentences/t05_nose_s.mp3` | This is my little nose! |
| 45 | `t05_mouth` | `audio/words/t05_mouth.mp3` | Mouth. | `audio/sentences/t05_mouth_s.mp3` | Open your mouth! Ah! |
| 46 | `t05_hair` | `audio/words/t05_hair.mp3` | Hair. | `audio/sentences/t05_hair_s.mp3` | Brush your nice hair. |
| 47 | `t05_hands` | `audio/words/t05_hands.mp3` | Hands. | `audio/sentences/t05_hands_s.mp3` | Clap your hands! |
| 48 | `t05_fingers` | `audio/words/t05_fingers.mp3` | Fingers. | `audio/sentences/t05_fingers_s.mp3` | Wiggle your ten fingers! |
| 49 | `t05_arms` | `audio/words/t05_arms.mp3` | Arms. | `audio/sentences/t05_arms_s.mp3` | Stretch your arms up high! |
| 50 | `t05_legs` | `audio/words/t05_legs.mp3` | Legs. | `audio/sentences/t05_legs_s.mp3` | Look at my two legs! |
| 51 | `t05_feet` | `audio/words/t05_feet.mp3` | Feet. | `audio/sentences/t05_feet_s.mp3` | Stamp your feet! |
| 52 | `t05_tummy` | `audio/words/t05_tummy.mp3` | Tummy. | `audio/sentences/t05_tummy_s.mp3` | Pat your round tummy! |

---

### B2. Giọng đọc Mẫu câu giao tiếp & Hướng dẫn Phụ huynh (15 file)
*Dùng cả trong bài học của bé và nút 🔊 trong thẻ "Học cùng con" của Khu Phụ huynh.*

| # | `sentence_id` | Đường dẫn file | Văn bản đọc (en-US) | Nghĩa Tiếng Việt (lưu trong JSON) | Phiên âm dễ đọc cho Phụ huynh |
|---|---|---|---|---|---|
| 1 | `p_hello_name` | `audio/sentences/p_hello_name.mp3` | Hello! What's your name? | Xin chào! Tên con là gì? | Hê-lâu! Quát-xơ gio nêm? |
| 2 | `p_my_name` | `audio/sentences/p_my_name.mp3` | My name is Momo! | Tên tớ là Momo! | Mai nêm i-zơ Mô-mô! |
| 3 | `p_how_are_you` | `audio/sentences/p_how_are_you.mp3` | How are you? I'm happy! | Con có khỏe không? Con rất vui! | Hao a diu? Ai-mơ hép-pi! |
| 4 | `p_what_color` | `audio/sentences/p_what_color.mp3` | What color is it? It's red! | Đây là màu gì? Màu đỏ đấy! | Quát có-lờ i-zít? Ít-xơ rét! |
| 5 | `p_i_like_color` | `audio/sentences/p_i_like_color.mp3` | I like blue! | Con thích màu xanh dương! | Ai lai-kơ b-lu! |
| 6 | `p_lets_count` | `audio/sentences/p_lets_count.mp3` | Let's count! One, two, three! | Cùng đếm nào! Một, hai, ba! | Lét-xơ cao-tờ! Oăn, tu, th-ri! |
| 7 | `p_how_many` | `audio/sentences/p_how_many.mp3` | How many? Five! | Có bao nhiêu nhỉ? Năm! | Hao me-ni? Fai-vờ! |
| 8 | `p_how_old` | `audio/sentences/p_how_old.mp3` | I'm four years old! | Con lên bốn tuổi! | Ai-mơ fo gia-zơ âu! |
| 9 | `p_whats_this` | `audio/sentences/p_whats_this.mp3` | What's this? It's a dog! | Đây là con gì? Là con chó đấy! | Quát-xơ đít? Ít-xơ ờ đóc! |
| 10 | `p_animal_says` | `audio/sentences/p_animal_says.mp3` | The cat says meow, meow! | Con mèo kêu meo meo! | Đờ két xây-zơ mi-ao, mi-ao! |
| 11 | `p_i_like_animal` | `audio/sentences/p_i_like_animal.mp3` | I like rabbits! | Con thích những chú thỏ! | Ai lai-kơ rép-bịt-xơ! |
| 12 | `p_touch_your` | `audio/sentences/p_touch_your.mp3` | Touch your nose! | Hãy chạm vào mũi của con nào! | Tắt-chơ gio nâu-zơ! |
| 13 | `p_clap_hands` | `audio/sentences/p_clap_hands.mp3` | Clap your hands! | Vỗ tay nào! | C-lép gio hen-zơ! |
| 14 | `p_this_is_my` | `audio/sentences/p_this_is_my.mp3` | This is my tummy! | Đây là cái bụng của con! | Đít i-zơ mai tăm-mi! |
| 15 | `p_magic_words` | `audio/sentences/p_magic_words.mp3` | Please! Thank you! Good job! | Làm ơn! Cảm ơn! Con giỏi lắm! | P-li-zơ! Thanh kiu! Gút chóp! |

---

### B3. Giọng Mascot Momo hướng dẫn, khen ngợi & TPR (28 file)

| # | Đường dẫn file | Ngữ cảnh | Văn bản đọc (Giọng Momo vui tươi, en-US) |
|---|---|---|---|
| 1 | `audio/instructions/welcome_map.mp3` | Vào bản đồ | Hi friend! Let's play and learn English together! Tap an island! |
| 2 | `audio/instructions/warmup_start.mp3` | Bước 1: Warm-up | Hello! Are you ready? Let's start! |
| 3 | `audio/instructions/discover_intro.mp3` | Bước 2: Discover | Look and listen! Tap the picture to hear it again! |
| 4 | `audio/instructions/tap_find_intro.mp3` | Game Tap & Find | Listen and tap the right picture! |
| 5 | `audio/instructions/where_is.mp3` | Tiền tố câu hỏi tìm hình | Where is... |
| 6 | `audio/instructions/drag_drop_intro.mp3` | Game Drag & Drop | Drag the picture to the magic box! |
| 7 | `audio/instructions/memory_intro.mp3` | Game Memory Match | Find two matching cards! Tap a card! |
| 8 | `audio/instructions/repeat_intro.mp3` | Bước 4: Ghi âm | Your turn! Listen to me, then tap the microphone and say it! |
| 9 | `audio/instructions/repeat_listening.mp3` | Khi nhắc bé nói | Say it out loud! I'm listening! |
| 10 | `audio/instructions/simon_intro.mp3` | Bước 4: Simon Says | Stand up! Let's move our body together! Do what I do! |
| 11 | `audio/instructions/cmd_wave_hello.mp3` | TPR 1 | Wave your hands! Say hello! |
| 12 | `audio/instructions/cmd_clap_hands.mp3` | TPR 2 | Clap your hands! Clap, clap, clap! |
| 13 | `audio/instructions/cmd_touch_nose.mp3` | TPR 3 | Touch your nose! Boop! |
| 14 | `audio/instructions/cmd_touch_head.mp3` | TPR 4 | Touch your head! |
| 15 | `audio/instructions/cmd_stamp_feet.mp3` | TPR 5 | Stamp your feet! Stamp, stamp! |
| 16 | `audio/instructions/cmd_jump_high.mp3` | TPR 6 | Jump up high! One, two, three, jump! |
| 17 | `audio/instructions/cmd_fly_bird.mp3` | TPR 7 | Fly like a little bird! Flap your wings! |
| 18 | `audio/instructions/cmd_swim_fish.mp3` | TPR 8 | Swim like a happy fish! |
| 19 | `audio/instructions/praise_1.mp3` | Khen đúng (ngẫu nhiên 1) | Yay! Good job! |
| 20 | `audio/instructions/praise_2.mp3` | Khen đúng (ngẫu nhiên 2) | Awesome! You did it! |
| 21 | `audio/instructions/praise_3.mp3` | Khen đúng (ngẫu nhiên 3) | Wonderful! High five! |
| 22 | `audio/instructions/praise_4.mp3` | Khen đúng (ngẫu nhiên 4) | Super star! That's right! |
| 23 | `audio/instructions/try_again_1.mp3` | Khi bé chạm chưa đúng 1 | Oops! Let's try again! |
| 24 | `audio/instructions/try_again_2.mp3` | Khi bé chạm chưa đúng 2 | Almost! Look closely and try again! |
| 25 | `audio/instructions/celebrate_sticker.mp3` | Bước 5: Nhận sticker | Hooray! You finished the lesson! Here is a new sticker for you! |
| 26 | `audio/instructions/time_warning_2min.mp3` | Còn 2 phút hết giờ | We have two more minutes to play today! |
| 27 | `audio/instructions/time_up_sleep.mp3` | Hết giờ – Momo đi ngủ | Yawn! I'm sleepy now. Time to rest your eyes and play outside! Bye-bye! See you tomorrow! |
| 28 | `audio/instructions/sticker_book.mp3` | Mở album sticker | Look at all your awesome stickers! Tap one! |

---

### B4. Gợi ý Tiếng Việt (khi bật chế độ hỗ trợ Tiếng Việt) (15 file)
*Chỉ phát khi Phụ huynh bật công tắc "Gợi ý tiếng Việt cho bé" trong Cài đặt.*

| # | Đường dẫn file | Tương ứng với sự kiện | Văn bản đọc (Giọng cô giáo mầm non nhẹ nhàng) |
|---|---|---|---|
| 1 | `audio/vi/welcome_map_vi.mp3` | Vào bản đồ | Chào bé yêu! Bé hãy chạm vào một hòn đảo để bắt đầu chơi nhé! |
| 2 | `audio/vi/discover_intro_vi.mp3` | Bước Discover | Bé hãy nhìn hình, lắng nghe và chạm vào hình để nghe lại nhé! |
| 3 | `audio/vi/tap_find_intro_vi.mp3` | Game Tap & Find | Bé hãy lắng nghe xem Momo gọi tên hình nào và chạm vào hình đó nhé! |
| 4 | `audio/vi/drag_drop_intro_vi.mp3` | Game Drag & Drop | Bé hãy dùng ngón tay kéo hình đúng thả vào chiếc hộp nhé! |
| 5 | `audio/vi/memory_intro_vi.mp3` | Game Memory Match | Bé hãy lật các thẻ để tìm hai hình giống nhau nhé! |
| 6 | `audio/vi/repeat_intro_vi.mp3` | Bước Ghi âm | Đến lượt bé rồi! Bé chạm vào nút micro và đọc to theo Momo nhé! |
| 7 | `audio/vi/simon_intro_vi.mp3` | Bước Simon Says | Bé hãy đứng dậy và tập làm động tác giống bạn khỉ Momo nào! |
| 8 | `audio/vi/try_again_vi.mp3` | Khi chọn chưa đúng | Chưa đúng rồi, bé nhìn hình nhấp nháy và thử lại nhé! |
| 9 | `audio/vi/celebrate_vi.mp3` | Hoàn thành bài | Giỏi quá! Bé được tặng một hình dán mới này! |
| 10 | `audio/vi/time_up_vi.mp3` | Hết giờ | Bạn Momo buồn ngủ rồi. Mình cất máy và ra ngoài chơi cùng bố mẹ nhé! Hẹn gặp bé ngày mai! |
| 11 | `audio/vi/topic_t01_vi.mp3` | Giới thiệu chủ đề 1 | Chủ đề: Chào hỏi và Gia đình |
| 12 | `audio/vi/topic_t02_vi.mp3` | Giới thiệu chủ đề 2 | Chủ đề: Màu sắc quanh bé |
| 13 | `audio/vi/topic_t03_vi.mp3` | Giới thiệu chủ đề 3 | Chủ đề: Bé tập đếm từ 1 đến 10 |
| 14 | `audio/vi/topic_t04_vi.mp3` | Giới thiệu chủ đề 4 | Chủ đề: Những con vật đáng yêu |
| 15 | `audio/vi/topic_t05_vi.mp3` | Giới thiệu chủ đề 5 | Chủ đề: Cơ thể của bé |

---

### B5. Bài hát chủ đề – 5 bài Public Domain (5 file nhạc + mốc lời)
*Tất cả đều dựa trên giai điệu thiếu nhi truyền thống (Public Domain) để **không vi phạm bản quyền**, lời rút gọn 60–75 giây phù hợp từ vựng trong chủ đề. Bạn có thể đưa Prompt + Lyrics dưới đây vào **Suno / Udio** hoặc giao cho nhạc công.*

#### 1. `audio/songs/s01_hello_song.mp3` (Chủ đề 1: Hello!)
- **Music Prompt:** `Happy upbeat preschool children's song, acoustic ukulele, marimba, handclaps, warm clear female American vocal, slow tempo 100 BPM, easy to sing along for 4-year-olds`
- **Lyrics (kèm mốc thời gian gợi ý cho Karaoke JSON):**
  ```text
  [00:00 - 00:04] (Intro music)
  [00:04 - 00:08] Hello, hello! How are you?
  [00:08 - 00:12] Hello, hello! How are you?
  [00:12 - 00:16] I'm fine, I'm happy, thank you!
  [00:16 - 00:20] Hello Mommy! Hello Daddy!
  [00:20 - 00:24] Hello little baby, too!
  [00:24 - 00:28] Wave your hands and say hello!
  [00:28 - 00:32] Wave your hands: Goodbye, bye-bye!
  [00:32 - 00:36] See you soon, my friend!
  ```

#### 2. `audio/songs/s02_rainbow_colors.mp3` (Chủ đề 2: Colors)
- **Music Prompt:** `Cheerful preschool nursery rhyme, bright piano, xylophone, gentle acoustic guitar, clear friendly female vocal en-US, 100 BPM`
- **Lyrics:**
  ```text
  [00:00 - 00:04] (Intro music)
  [00:04 - 00:08] Red and yellow, green and blue,
  [00:08 - 00:12] Orange, pink, and purple too!
  [00:12 - 00:16] Black and white and chocolate brown,
  [00:16 - 00:20] Pretty colors all around!
  [00:20 - 00:24] What color is it? Look and see!
  [00:24 - 00:28] Sing the rainbow song with me!
  [00:28 - 00:32] Red, blue, yellow, green! Hooray!
  ```

#### 3. `audio/songs/s03_ten_little_fingers.mp3` (Chủ đề 3: Numbers 1–10)
- **Music Prompt:** `Playful counting song for toddlers, bouncy pizzicato strings, glockenspiel, warm clear female vocal en-US, slow clear counting 98 BPM`
- **Lyrics:**
  ```text
  [00:00 - 00:04] (Intro music)
  [00:04 - 00:08] One and two, and three bright stars,
  [00:08 - 00:12] Four and five, and six so far!
  [00:12 - 00:16] Seven, eight, and nine, and ten,
  [00:16 - 00:20] Let's all count them once again!
  [00:20 - 00:24] Show your fingers, ready, go!
  [00:24 - 00:28] One, two, three, four, five in a row!
  [00:28 - 00:32] Six, seven, eight, nine, ten up high!
  [00:32 - 00:36] Clap your hands and touch the sky!
  ```

#### 4. `audio/songs/s04_old_macdonald.mp3` (Chủ đề 4: Animals)
- **Music Prompt:** `Cheerful country farm nursery rhyme, acoustic guitar, bouncy banjo, fun farm animal sound effects, clear female vocal en-US, 102 BPM`
- **Lyrics:**
  ```text
  [00:00 - 00:04] (Intro music)
  [00:04 - 00:08] Welcome to Momo's happy farm!
  [00:08 - 00:12] Little puppy dog says woof, woof, woof!
  [00:12 - 00:16] Fluffy kitty cat says meow, meow, meow!
  [00:16 - 00:20] Yellow baby duck says quack, quack, quack!
  [00:20 - 00:24] Happy farm cow says moo, moo, moo!
  [00:24 - 00:28] Little pink pig says oink, oink, oink!
  [00:28 - 00:32] Bird in the sky and fish in the pond,
  [00:32 - 00:36] Sing with the animals all day long!
  ```

#### 5. `audio/songs/s05_head_shoulders.mp3` (Chủ đề 5: My Body)
- **Music Prompt:** `Classic Head Shoulders Knees and Toes action song for preschoolers, upbeat marimba, acoustic drums, handclaps, clear slow female vocal en-US, 100 BPM`
- **Lyrics:**
  ```text
  [00:00 - 00:04] (Intro music)
  [00:04 - 00:08] Head and tummy, arms and legs, arms and legs!
  [00:08 - 00:12] Head and tummy, arms and legs, arms and legs!
  [00:12 - 00:16] And eyes, and ears, and mouth, and nose!
  [00:16 - 00:20] Clap your hands and stamp your feet, stamp your feet!
  [00:20 - 00:24] Touch your hair and wiggle your fingers, too!
  [00:24 - 00:28] Eyes, and ears, and mouth, and nose! Hooray!
  ```

---

### B6. Hiệu ứng âm thanh – SFX & Nhạc nền (12 file)
*Có thể tải miễn phí bản quyền CC0 từ **Kenney.nl (UI Audio / Interface Sounds)** hoặc **Freesound.org (CC0)** hoặc tạo bằng ElevenLabs Sound Effects.*

| # | Đường dẫn file | Độ dài | Mô tả âm thanh (Prompt cho AI SFX) |
|---|---|---|---|
| 1 | `audio/sfx/tap_pop.mp3` | 0.15s | Soft wooden bubble pop sound when tapping a button, warm and pleasant |
| 2 | `audio/sfx/card_flip.mp3` | 0.25s | Gentle paper whoosh sound when flipping a flashcard |
| 3 | `audio/sfx/correct_ding.mp3` | 0.6s | Bright cheerful marimba two-note chime (C5 to G5), positive correct answer feedback |
| 4 | `audio/sfx/wrong_boing.mp3` | 0.4s | Gentle soft cartoon woodblock tap (NOT a harsh buzzer), friendly "try again" sound |
| 5 | `audio/sfx/star_sparkle.mp3` | 0.8s | Magical twinkling glockenspiel sparkle when earning a star |
| 6 | `audio/sfx/celebrate_fanfare.mp3` | 2.5s | Short happy kids victory fanfare with xylophone, light applause, and cheering |
| 7 | `audio/sfx/sticker_peel.mp3` | 0.5s | Cute sticker peeling and sticking sound followed by a tiny chime |
| 8 | `audio/sfx/record_start.mp3` | 0.3s | Soft ascending double-beep indicating microphone recording started |
| 9 | `audio/sfx/record_stop.mp3` | 0.3s | Soft descending double-beep indicating microphone recording stopped |
| 10 | `audio/sfx/island_unlock.mp3` | 1.2s | Magical harp glissando sound when unlocking a new lesson or island |
| 11 | `audio/sfx/momo_yawn.mp3` | 1.5s | Cute cartoon baby monkey sleepy yawn and gentle lullaby chime |
| 12 | `audio/sfx/bgm_map_loop.mp3` | 30–45s | Seamless loopable background music: very soft, gentle acoustic kalimba and warm marimba melody, low volume, peaceful and playful, 90 BPM |

---

## 6. Tổng kết số lượng tài nguyên MVP

| Nhóm | Số lượng file | Ghi chú khi chưa có file thật |
|---|---|---|
| **Hình ảnh (`.png`)** | **109 file** (8 Momo + 21 UI/Bản đồ/Bìa + 52 Từ vựng + 20 Sticker + 8 TPR) | App tự vẽ thẻ màu + icon/emoji chuẩn theo `word_id` nếu chưa tìm thấy file PNG |
| **Âm thanh giọng đọc (`.mp3`)** | **162 file** (52 từ + 52 câu ví dụ + 15 mẫu câu phụ huynh + 28 giọng Momo + 15 gợi ý Tiếng Việt) | `AudioService` tự động chuyển sang `flutter_tts` đọc đúng văn bản trong JSON nếu chưa có file `.mp3` |
| **Bài hát & SFX (`.mp3`)** | **17 file** (5 bài hát + 12 SFX/nhạc nền) | `AudioService` dùng `SystemSound` / giai điệu sintetizer nhẹ hoặc bỏ qua không báo lỗi khi thiếu file |
| **TỔNG CỘNG** | **288 file** | Có thể thay thế từng phần bất kỳ lúc nào mà **không cần sửa code** |
