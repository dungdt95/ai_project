# ĐẶC TẢ TÀI NGUYÊN MỞ RỘNG (ASSET SPECIFICATION V2) – 20 Chủ Đề Mới (`t06` → `t25`)
## Ứng dụng "Bé Vui Tiếng Anh" (Level 2 → Level 5)

> **Mục đích của tài liệu:** Tài liệu này đặc tả toàn bộ hình ảnh, âm thanh từ vựng, câu ví dụ, câu giao tiếp phụ huynh và bài hát Karaoke (Suno AI) cho **20 chủ đề mở rộng (`t06` → `t25`)**. Tài liệu được thiết kế độc lập để có thể dùng trực tiếp cho các Agent tạo ảnh/âm thanh hoặc đóng gói thành các file `.bvpack` đẩy lên Google Drive (`10d5w1ZMGNRy4OmdX6_6nnhpaIu1H6hHm`).
>
> **Tài liệu liên quan:**
> - Đặc tả 5 chủ đề gốc (`t01` → `t05`): [ASSET_SPEC.md](file:///c:/workspace/ai_project/kids_english_app/docs/ASSET_SPEC.md)
> - Kế hoạch mở rộng 20 chủ đề: [KE_HOACH_MO_RONG_20_CHU_DE.md](file:///c:/workspace/ai_project/kids_english_app/docs/KE_HOACH_MO_RONG_20_CHU_DE.md)
> - Kế hoạch nạp chủ đề từ Google Drive: [KE_HOACH_NAP_CHU_DE_GOOGLE_DRIVE.md](file:///c:/workspace/ai_project/kids_english_app/docs/KE_HOACH_NAP_CHU_DE_GOOGLE_DRIVE.md)

---

## MỤC LỤC
1. [Style Guide & Master Prompt Chuẩn](#1-style-guide--master-prompt-chuẩn)
2. [Quy chuẩn Kỹ thuật & Đóng gói `.bvpack`](#2-quy-chuẩn-kỹ-thuật--đóng-gói-bvpack)
3. [PHẦN A – DANH SÁCH HÌNH ẢNH (IMAGES) CHO 20 CHỦ ĐỀ MỚI](#3-phần-a--danh-sách-hình-ảnh-images-cho-20-chủ-đề-mới)
   - [A1. Icon 20 Đảo Bản Đồ 2.5D & 20 Bìa Bài Hát (40 file)](#a1-icon-20-đảo-bản-đồ-25d--20-bìa-bài-hát-40-file)
   - [A2. Chủ đề 6: My Big Family (`t06_family`) (14 file)](#a2-chủ-đề-6-my-big-family-t06_family-14-file)
   - [A3. Chủ đề 7: Zoo Animals (`t07_wild_animals`) (16 file)](#a3-chủ-đề-7-zoo-animals-t07_wild_animals-16-file)
   - [A4. Chủ đề 8: Ocean & Bugs (`t08_sea_bugs`) (14 file)](#a4-chủ-đề-8-ocean--bugs-t08_sea_bugs-14-file)
   - [A5. Chủ đề 9: Fun Shapes (`t09_shapes`) (14 file)](#a5-chủ-đề-9-fun-shapes-t09_shapes-14-file)
   - [A6. Chủ đề 10: Numbers & Sizes (`t10_numbers_sizes`) (14 file)](#a6-chủ-đề-10-numbers--sizes-t10_numbers_sizes-14-file)
   - [A7. Chủ đề 11: Yummy Fruits (`t11_fruits`) (14 file)](#a7-chủ-đề-11-yummy-fruits-t11_fruits-14-file)
   - [A8. Chủ đề 12: Food & Drinks (`t12_food_drinks`) (16 file)](#a8-chủ-đề-12-food--drinks-t12_food_drinks-16-file)
   - [A9. Chủ đề 13: My Toys (`t13_toys`) (14 file)](#a9-chủ-đề-13-my-toys-t13_toys-14-file)
   - [A10. Chủ đề 14: My Clothes (`t14_clothes`) (14 file)](#a10-chủ-đề-14-my-clothes-t14_clothes-14-file)
   - [A11. Chủ đề 15: My Cozy House (`t15_my_house`) (16 file)](#a11-chủ-đề-15-my-cozy-house-t15_my_house-16-file)
   - [A12. Chủ đề 16: My Feelings (`t16_feelings`) (14 file)](#a12-chủ-đề-16-my-feelings-t16_feelings-14-file)
   - [A13. Chủ đề 17: Let's Move! (`t17_actions`) (16 file)](#a13-chủ-đề-17-lets-move-t17_actions-16-file)
   - [A14. Chủ đề 18: Daily Routines (`t18_routines`) (14 file)](#a14-chủ-đề-18-daily-routines-t18_routines-14-file)
   - [A15. Chủ đề 19: Mealtime Tools (`t19_tableware`) (14 file)](#a15-chủ-đề-19-mealtime-tools-t19_tableware-14-file)
   - [A16. Chủ đề 20: Fun Opposites (`t20_opposites`) (14 file)](#a16-chủ-đề-20-fun-opposites-t20_opposites-14-file)
   - [A17. Chủ đề 21: Beep! Vehicles (`t21_vehicles`) (16 file)](#a17-chủ-đề-21-beep-vehicles-t21_vehicles-16-file)
   - [A18. Chủ đề 22: Weather & Nature (`t22_weather_nature`) (16 file)](#a18-chủ-đề-22-weather--nature-t22_weather_nature-16-file)
   - [A19. Chủ đề 23: My Preschool (`t23_school`) (14 file)](#a19-chủ-đề-23-my-preschool-t23_school-14-file)
   - [A20. Chủ đề 24: Cool Jobs (`t24_jobs`) (14 file)](#a20-chủ-đề-24-cool-jobs-t24_jobs-14-file)
   - [A21. Chủ đề 25: Party & Holidays (`t25_party_holidays`) (14 file)](#a21-chủ-đề-25-party--holidays-t25_party_holidays-14-file)
   - [A22. Hình minh họa động tác TPR mở rộng – Simon Says (12 file)](#a22-hình-minh-họa-động-tác-tpr-mở-rộng--simon-says-12-file)
4. [PHẦN B – DANH SÁCH ÂM THANH (AUDIO) CHO 20 CHỦ ĐỀ MỚI](#4-phần-b--danh-sách-âm-thanh-audio-cho-20-chủ-đề-mới)
   - [B1. Giọng đọc Từ vựng & Câu ví dụ – 20 Chủ đề (424 file)](#b1-giọng-đọc-từ-vựng--câu-ví-dụ--20-chủ-đề-424-file)
   - [B2. Giọng đọc Mẫu câu giao tiếp Phụ huynh – 20 Chủ đề (45 file)](#b2-giọng-đọc-mẫu-câu-giao-tiếp-phụ-huynh--20-chủ-đề-45-file)
   - [B3. Giọng Mascot Momo cho 12 lệnh TPR mở rộng (12 file)](#b3-giọng-mascot-momo-cho-12-lệnh-tpr-mở-rộng-12-file)
   - [B4. Bài hát chủ đề – 20 bài Original Suno AI Lyrics (`s06` → `s25`) (20 file)](#b4-bài-hát-chủ-đề--20-bài-original-suno-ai-lyrics-s06--s25-20-file)
5. [Tổng kết số lượng tài nguyên 20 chủ đề mới](#5-tổng-kết-số-lượng-tài-nguyên-20-chủ-đề-mới)

---

## 1. Style Guide & Master Prompt Chuẩn

Mọi hình ảnh của 20 chủ đề mới (`t06` → `t25`) **bắt buộc** giữ nguyên 100% phong cách đồ họa với 5 chủ đề đầu tiên:

### 1.1. Master Style Prompt (Gắn vào cuối mọi prompt tạo hình từ vựng/đảo)
```text
children's book flat vector illustration for 4-year-old preschoolers, cute rounded friendly shapes, thick clean dark-brown outlines (#3D2C2E), warm soft pastel color palette, minimal details, single clear subject centered, isolated on a pure transparent background (or solid white #FFFFFF for easy background removal), no text, no watermark, no complex shadows, Duolingo ABC and Khan Academy Kids art style
```

### 1.2. Character Sheet – Chú khỉ MOMO
```text
CHARACTER MOMO: A cute happy baby monkey mascot, 4 years old look, warm cinnamon brown fur (#C67D3B), cream beige face and round tummy (#FFF1D6), big expressive dark brown eyes, round ears, wearing a bright turquoise T-shirt (#2EC4B6) with a small yellow star (#FFD23F) on the chest, short tail curled up. Flat vector illustration style, thick clean dark-brown outlines (#3D2C2E), consistent proportions (big head, small chubby body, 2.5 heads tall).
```

---

## 2. Quy chuẩn Kỹ thuật & Đóng gói `.bvpack`

* **Đường dẫn file:** Toàn bộ đường dẫn trong bảng dưới đây tính tương đối từ gốc thư mục tài nguyên (tức là `app/assets/` nếu tích hợp built-in, hoặc thư mục gốc bên trong file nén `<topic_id>.bvpack` nếu nạp qua Google Drive).
* **Thông số Hình ảnh:**
  * Từ vựng (`images/topics/<topic_id>/<word>.png`): `512 × 512 px`, PNG nền trong suốt (RGBA).
  * Sticker (`images/stickers/stk_tXX_1..4.png`): `512 × 512 px`, PNG nền trong suốt, có viền trắng dày kiểu die-cut sticker.
  * Đảo bản đồ (`images/map/island_<topic_id>.png`): `512 × 512 px`, PNG nền trong suốt, đảo nổi 2.5D.
  * Bìa bài hát (`images/songs/cover_sXX_<slug>.png`): `600 × 600 px`, PNG/JPG kín khung.
* **Thông số Âm thanh:**
  * Từ vựng & Câu (`audio/words/`, `audio/sentences/`): `.mp3`, `44.1kHz`, Mono, `64–128kbps`, giọng **Anh – Mỹ (en-US)** rõ ràng, tốc độ chậm hơn bình thường ~15%.
  * Bài hát (`audio/songs/sXX_*.mp3`): `.mp3`, `44.1kHz`, Stereo, `128kbps`, tempo `96–108 BPM`, độ dài `35–75 giây`.

---

## 3. PHẦN A – DANH SÁCH HÌNH ẢNH (IMAGES) CHO 20 CHỦ ĐỀ MỚI

### A1. Icon 20 Đảo Bản Đồ 2.5D & 20 Bìa Bài Hát (40 file)

#### 1. Icon 20 Đảo Bản Đồ (`images/map/island_t06..t25.png` – 512×512, nền trong suốt)
| # | Chủ đề | Đường dẫn file | Prompt chi tiết (+ `[Master Style Prompt]`) |
|---|---|---|---|
| 1 | `t06_family` | `images/map/island_t06_family.png` | Cute 2.5D floating cartoon island with a warm big family tree, a cozy wooden house, and glowing pink heart balloons |
| 2 | `t07_wild_animals` | `images/map/island_t07_wild_animals.png` | Cute 2.5D floating cartoon safari zoo island with lush jungle palm trees, a wooden zoo gate, a friendly baby giraffe and lion |
| 3 | `t08_sea_bugs` | `images/map/island_t08_sea_bugs.png` | Cute 2.5D floating cartoon coral reef lagoon island with colorful corals, a jumping dolphin, starfish, and blooming flowers with butterflies |
| 4 | `t09_shapes` | `images/map/island_t09_shapes.png` | Cute 2.5D floating cartoon island built from giant colorful geometric shapes: a yellow star arch, red circle, blue square, and green triangle |
| 5 | `t10_numbers_sizes` | `images/map/island_t10_numbers_sizes.png` | Cute 2.5D floating cartoon island with giant wooden numbers 10 and 20, a playful seesaw comparing a big block and a small block |
| 6 | `t11_fruits` | `images/map/island_t11_fruits.png` | Cute 2.5D floating cartoon orchard island with a red apple tree, giant sliced watermelon house, yellow bananas, and strawberries |
| 7 | `t12_food_drinks` | `images/map/island_t12_food_drinks.png` | Cute 2.5D floating cartoon picnic island with a checkered blanket, giant bowl of rice, milk carton, warm bread, and ice cream cone |
| 8 | `t13_toys` | `images/map/island_t13_toys.png` | Cute 2.5D floating cartoon toyland island with an open magical wooden toy box, teddy bear, colorful ball, building blocks, and a flying kite |
| 9 | `t14_clothes` | `images/map/island_t14_clothes.png` | Cute 2.5D floating cartoon wardrobe island with a cheerful clothesline holding a colorful T-shirt, yellow dress, cute hat, and little shoes |
| 10 | `t15_my_house` | `images/map/island_t15_my_house.png` | Cute 2.5D floating cartoon home island with a cozy red-roof cottage, warm glowing windows, front door, flower garden, and white picket fence |
| 11 | `t16_feelings` | `images/map/island_t16_feelings.png` | Cute 2.5D floating cartoon cloud island with a bright rainbow and three cute expressive smiling, surprised, and sleepy cloud characters |
| 12 | `t17_actions` | `images/map/island_t17_actions.png` | Cute 2.5D floating cartoon sports park island with a bouncy trampoline, running track, climbing ladder, and musical notes |
| 13 | `t18_routines` | `images/map/island_t18_routines.png` | Cute 2.5D floating cartoon day-and-night island: left side has a morning sun and toothbrush, right side has a crescent moon and cozy bed |
| 14 | `t19_tableware` | `images/map/island_t19_tableware.png` | Cute 2.5D floating cartoon dining island with a round wooden table, colorful bowl, plate, spoon, fork, and a cute yellow mug |
| 15 | `t20_opposites` | `images/map/island_t20_opposites.png` | Cute 2.5D floating cartoon split island: half warm sunny beach with a hot sun, half snowy hill with a cold snowman, plus a fast rabbit and slow turtle |
| 16 | `t21_vehicles` | `images/map/island_t21_vehicles.png` | Cute 2.5D floating cartoon transport island with a winding road, red car, yellow bus, train on tracks, little boat in water, and airplane above |
| 17 | `t22_weather_nature` | `images/map/island_t22_weather_nature.png` | Cute 2.5D floating cartoon nature island with a smiling yellow sun, fluffy cloud with gentle rain, green pine tree, rainbow, and flowers |
| 18 | `t23_school` | `images/map/island_t23_school.png` | Cute 2.5D floating cartoon preschool island with a friendly school building, giant colorful crayons, open storybook, and a small slide |
| 19 | `t24_jobs` | `images/map/island_t24_jobs.png` | Cute 2.5D floating cartoon town island with a mini fire station, doctor's cross badge, chef hat sign, and a small space rocket |
| 20 | `t25_party_holidays` | `images/map/island_t25_party_holidays.png` | Cute 2.5D floating cartoon celebration island with a giant birthday cake with lit candles, wrapped gift boxes, party banners, and red lanterns |

#### 2. Bìa 20 Bài Hát (`images/songs/cover_s06..s25.png` – 600×600, kín khung)
| # | Bài hát | Đường dẫn file | Prompt chi tiết (+ `[Master Style Prompt]`) |
|---|---|---|---|
| 21 | `s06_family_song` | `images/songs/cover_s06_family.png` | Song cover art: `[CHARACTER MOMO]` hugging his loving monkey family (Grandma, Grandpa, Mommy, Daddy, Brother, Sister) in front of a cozy home |
| 22 | `s07_zoo_song` | `images/songs/cover_s07_zoo.png` | Song cover art: `[CHARACTER MOMO]` wearing a safari explorer hat singing with a cute baby lion, elephant, giraffe, and panda at the zoo |
| 23 | `s08_ocean_song` | `images/songs/cover_s08_ocean.png` | Song cover art: `[CHARACTER MOMO]` wearing diving goggles waving to a friendly dolphin, sea turtle, red crab, and yellow bee near a sunny beach |
| 24 | `s09_shapes_song` | `images/songs/cover_s09_shapes.png` | Song cover art: `[CHARACTER MOMO]` juggling glowing colorful shapes: a red circle, blue square, green triangle, yellow star, and pink heart |
| 25 | `s10_sizes_song` | `images/songs/cover_s10_sizes.png` | Song cover art: `[CHARACTER MOMO]` standing happily between a big friendly elephant and a tiny cute mouse with colorful numbers 11 to 20 floating |
| 26 | `s11_fruits_song` | `images/songs/cover_s11_fruits.png` | Song cover art: `[CHARACTER MOMO]` holding a big basket of fresh colorful fruits: red apples, yellow bananas, watermelon slice, and grapes |
| 27 | `s12_food_song` | `images/songs/cover_s12_food.png` | Song cover art: `[CHARACTER MOMO]` sitting at a picnic table with a bowl of rice, warm bread, glass of milk, orange juice, and a cupcake |
| 28 | `s13_toys_song` | `images/songs/cover_s13_toys.png` | Song cover art: `[CHARACTER MOMO]` playing happily in a room with a teddy bear, colorful ball, toy car, robot, and floating balloons |
| 29 | `s14_clothes_song` | `images/songs/cover_s14_clothes.png` | Song cover art: `[CHARACTER MOMO]` trying on a cool sun hat, bright jacket, and shiny red shoes in front of a colorful closet |
| 30 | `s15_house_song` | `images/songs/cover_s15_house.png` | Song cover art: `[CHARACTER MOMO]` welcoming friends at the open door of a cute sunny cottage with a sofa, lamp, and bed visible through windows |
| 31 | `s16_feelings_song` | `images/songs/cover_s16_feelings.png` | Song cover art: `[CHARACTER MOMO]` surrounded by four cute expression bubbles showing happy, surprised, sleepy, and excited monkey faces |
| 32 | `s17_actions_song` | `images/songs/cover_s17_actions.png` | Song cover art: `[CHARACTER MOMO]` jumping and dancing energetically on a sunny park stage with music notes and stars |
| 33 | `s18_routines_song` | `images/songs/cover_s18_routines.png` | Song cover art: `[CHARACTER MOMO]` holding a toothbrush with sparkly clean teeth under a cheerful morning sun |
| 34 | `s19_tableware_song` | `images/songs/cover_s19_tableware.png` | Song cover art: `[CHARACTER MOMO]` wearing a cute bib setting a tidy dinner table with a plate, bowl, spoon, fork, and yellow cup |
| 35 | `s20_opposites_song` | `images/songs/cover_s20_opposites.png` | Song cover art: `[CHARACTER MOMO]` holding a cold ice cream in one hand and pointing to a warm sunny sky, with a fast bunny and slow turtle |
| 36 | `s21_vehicles_song` | `images/songs/cover_s21_vehicles.png` | Song cover art: `[CHARACTER MOMO]` driving a cute red convertible car while a yellow bus, choo-choo train, and airplane travel around him |
| 37 | `s22_weather_song` | `images/songs/cover_s22_weather.png` | Song cover art: `[CHARACTER MOMO]` holding a colorful umbrella under a half-sunny, half-rainy sky with a bright rainbow arch |
| 38 | `s23_school_song` | `images/songs/cover_s23_school.png` | Song cover art: `[CHARACTER MOMO]` wearing a cute school backpack holding a picture book and giant crayons in front of a preschool |
| 39 | `s24_jobs_song` | `images/songs/cover_s24_jobs.png` | Song cover art: `[CHARACTER MOMO]` dressed as a friendly little doctor with a toy stethoscope alongside a firefighter helmet and chef hat |
| 40 | `s25_party_song` | `images/songs/cover_s25_party.png` | Song cover art: `[CHARACTER MOMO]` wearing a golden birthday crown blowing out candles on a birthday cake with gifts and fireworks |

---

### A2. Chủ đề 6: My Big Family (`t06_family`) (14 file)

| # | `word_id` | Nghĩa TV (`vi`) | Đường dẫn file | Prompt chi tiết (+ `[Master Style Prompt]`) |
|---|---|---|---|---|
| 1 | `t06_family` | Gia đình | `images/topics/t06_family/family.png` | A warm happy family portrait: Mommy, Daddy, Grandma, Grandpa, a little boy, and a little girl smiling together inside a soft heart frame |
| 2 | `t06_grandma` | Bà | `images/topics/t06_family/grandma.png` | A kind smiling grandmother with silver hair in a bun, wearing round glasses and a cozy lavender cardigan, open warm arms |
| 3 | `t06_grandpa` | Ông | `images/topics/t06_family/grandpa.png` | A gentle cheerful grandfather with silver hair and a warm smile, wearing a comfortable green sweater vest, waving kindly |
| 4 | `t06_brother` | Anh / Em trai | `images/topics/t06_family/brother.png` | A cheerful 6-year-old big brother in a striped orange T-shirt giving a friendly thumbs-up and big smile |
| 5 | `t06_sister` | Chị / Em gái | `images/topics/t06_family/sister.png` | A sweet 6-year-old big sister with a headband andmint-green dress, smiling and waving warmly |
| 6 | `t06_uncle` | Chú / Bác trai | `images/topics/t06_family/uncle.png` | A friendly young uncle wearing a yellow collared shirt, smiling brightly and waving |
| 7 | `t06_aunt` | Cô / Dì | `images/topics/t06_family/aunt.png` | A kind cheerful young aunt with shoulder-length hair wearing a soft pink blouse, smiling warmly |
| 8 | `t06_cousin` | Anh chị em họ | `images/topics/t06_family/cousin.png` | Two happy young cousins (a boy and a girl) standing side by side with arms around each other's shoulders |
| 9 | `t06_home` | Tổ ấm / Nhà | `images/topics/t06_family/home.png` | A cozy little cream-colored house with a red roof, a glowing heart on the front door, and warm light in the windows |
| 10 | `t06_love` | Yêu thương | `images/topics/t06_family/love.png` | A big glowing rosy-pink heart character being hugged by two cute little hands, radiating warmth and sparkles |
| 11 | *(sticker 1)* | — | `images/stickers/stk_t06_1.png` | Die-cut sticker with thick white border: Grandma and Grandpa smiling inside a golden heart badge |
| 12 | *(sticker 2)* | — | `images/stickers/stk_t06_2.png` | Die-cut sticker with thick white border: Brother and Sister giving a joyful high-five |
| 13 | *(sticker 3)* | — | `images/stickers/stk_t06_3.png` | Die-cut sticker with thick white border: A cute red-roof home with a rainbow heart above the chimney |
| 14 | *(sticker 4)* | — | `images/stickers/stk_t06_4.png` | Die-cut sticker with thick white border: `[CHARACTER MOMO]` holding a big pink heart that says nothing, surrounded by stars |

---

### A3. Chủ đề 7: Zoo Animals (`t07_wild_animals`) (16 file)

| # | `word_id` | Nghĩa TV (`vi`) | Đường dẫn file | Prompt chi tiết (+ `[Master Style Prompt]`) |
|---|---|---|---|---|
| 1 | `t07_lion` | Sư tử | `images/topics/t07_wild_animals/lion.png` | A cute friendly baby lion cub with a fluffy brown mane, sitting and smiling with a playful little roar pose |
| 2 | `t07_tiger` | Con hổ | `images/topics/t07_wild_animals/tiger.png` | A cute chubby orange tiger cub with dark-brown stripes, round ears, sitting and smiling warmly |
| 3 | `t07_elephant` | Con voi | `images/topics/t07_wild_animals/elephant.png` | A cute round pastel-blue baby elephant with big floppy ears and trunk curled up happily spraying a tiny water drop |
| 4 | `t07_monkey` | Con khỉ | `images/topics/t07_wild_animals/monkey.png` | A cute playful brown monkey holding a yellow banana and smiling with a curled tail |
| 5 | `t07_bear` | Con gấu | `images/topics/t07_wild_animals/bear.png` | A cute chubby brown bear cub sitting and holding a little yellow honey pot, smiling sweetly |
| 6 | `t07_giraffe` | Hươu cao cổ | `images/topics/t07_wild_animals/giraffe.png` | A cute yellow baby giraffe with brown spots and a long neck, munching on a green leaf with a gentle smile |
| 7 | `t07_zebra` | Ngựa vằn | `images/topics/t07_wild_animals/zebra.png` | A cute friendly baby zebra with clean black-and-white stripes, fuzzy mane, trotting happily |
| 8 | `t07_hippo` | Hà mã | `images/topics/t07_wild_animals/hippo.png` | A cute chubby lavender-gray baby hippo smiling wide showing two little round teeth |
| 9 | `t07_crocodile` | Cá sấu | `images/topics/t07_wild_animals/crocodile.png` | A cute friendly bright-green baby crocodile with big kind eyes and a happy grin, non-scary toddler style |
| 10 | `t07_snake` | Con rắn | `images/topics/t07_wild_animals/snake.png` | A cute friendly lime-green baby snake coiled neatly with big sparkling eyes and a happy smile |
| 11 | `t07_panda` | Gấu trúc | `images/topics/t07_wild_animals/panda.png` | A cute chubby black-and-white baby panda sitting and holding a green bamboo stalk |
| 12 | `t07_kangaroo` | Chuột túi | `images/topics/t07_wild_animals/kangaroo.png` | A cute light-brown kangaroo hopping happily with a tiny baby joey peeking out of its pouch |
| 13 | *(sticker 1)* | — | `images/stickers/stk_t07_1.png` | Die-cut sticker with thick white border: Cute baby lion wearing a little golden king crown |
| 14 | *(sticker 2)* | — | `images/stickers/stk_t07_2.png` | Die-cut sticker with thick white border: Cute baby elephant and giraffe smiling together |
| 15 | *(sticker 3)* | — | `images/stickers/stk_t07_3.png` | Die-cut sticker with thick white border: Cute panda munching bamboo with star sparkles |
| 16 | *(sticker 4)* | — | `images/stickers/stk_t07_4.png` | Die-cut sticker with thick white border: `[CHARACTER MOMO]` wearing a safari hat with binoculars |

---

### A4. Chủ đề 8: Ocean & Bugs (`t08_sea_bugs`) (14 file)

| # | `word_id` | Nghĩa TV (`vi`) | Đường dẫn file | Prompt chi tiết (+ `[Master Style Prompt]`) |
|---|---|---|---|---|
| 1 | `t08_shark` | Cá mập | `images/topics/t08_sea_bugs/shark.png` | A cute friendly baby blue shark with a round snout and big cheerful smile, non-scary preschool style |
| 2 | `t08_whale` | Cá voi | `images/topics/t08_sea_bugs/whale.png` | A cute chubby blue whale spouting a small cheerful water fountain from the top, smiling happily |
| 3 | `t08_dolphin` | Cá heo | `images/topics/t08_sea_bugs/dolphin.png` | A cute sky-blue dolphin leaping joyfully in an arc with a friendly smile |
| 4 | `t08_turtle` | Rùa biển | `images/topics/t08_sea_bugs/turtle.png` | A cute green sea turtle with a patterned shell swimming gently with a warm smile |
| 5 | `t08_crab` | Con cua | `images/topics/t08_sea_bugs/crab.png` | A cute bright-red crab holding up two round claws like a happy cheer, big smiling eyes |
| 6 | `t08_octopus` | Bạch tuộc | `images/topics/t08_sea_bugs/octopus.png` | A cute pink-purple octopus with a round head and eight curly tentacles waving happily |
| 7 | `t08_starfish` | Sao biển | `images/topics/t08_sea_bugs/starfish.png` | A cute five-pointed coral-orange starfish character with a happy smiling face in the center |
| 8 | `t08_bee` | Con ong | `images/topics/t08_sea_bugs/bee.png` | A cute chubby yellow-and-brown bumblebee with tiny translucent wings flying happily |
| 9 | `t08_butterfly` | Con bướm | `images/topics/t08_sea_bugs/butterfly.png` | A cute symmetrical butterfly with bright pink, orange, and yellow wings and a smiling face |
| 10 | `t08_ladybug` | Bọ rùa | `images/topics/t08_sea_bugs/ladybug.png` | A cute round red ladybug with black polka dots and big friendly eyes |
| 11 | *(sticker 1)* | — | `images/stickers/stk_t08_1.png` | Die-cut sticker with thick white border: Cute dolphin jumping over a sparkly wave |
| 12 | *(sticker 2)* | — | `images/stickers/stk_t08_2.png` | Die-cut sticker with thick white border: Happy pink octopus and red crab high-fiving |
| 13 | *(sticker 3)* | — | `images/stickers/stk_t08_3.png` | Die-cut sticker with thick white border: Cute bee, butterfly, and ladybug on a daisy flower |
| 14 | *(sticker 4)* | — | `images/stickers/stk_t08_4.png` | Die-cut sticker with thick white border: `[CHARACTER MOMO]` riding on a friendly sea turtle |

---

### A5. Chủ đề 9: Fun Shapes (`t09_shapes`) (14 file)

| # | `word_id` | Nghĩa TV (`vi`) | Đường dẫn file | Prompt chi tiết (+ `[Master Style Prompt]`) |
|---|---|---|---|---|
| 1 | `t09_circle` | Hình tròn | `images/topics/t09_shapes/circle.png` | A big bright coral-red (`#EF476F`) geometric CIRCLE character with cute smiling eyes in the center, pure clean round shape |
| 2 | `t09_square` | Hình vuông | `images/topics/t09_shapes/square.png` | A big bright sky-blue (`#118AB2`) geometric SQUARE character with four equal sides and cute smiling eyes |
| 3 | `t09_triangle` | Hình tam giác | `images/topics/t09_shapes/triangle.png` | A big bright leaf-green (`#06D6A0`) equilateral TRIANGLE character with three clear corners and cute smiling eyes |
| 4 | `t09_star` | Hình ngôi sao | `images/topics/t09_shapes/star.png` | A big bright golden-yellow (`#FFD166`) five-pointed STAR character with a cheerful smiling face |
| 5 | `t09_heart` | Hình trái tim | `images/topics/t09_shapes/heart.png` | A big bright bubblegum-pink (`#FF70A6`) symmetrical HEART shape character with cute smiling eyes |
| 6 | `t09_rectangle` | Hình chữ nhật | `images/topics/t09_shapes/rectangle.png` | A big bright orange (`#FF9F1C`) horizontal RECTANGLE shape character with four corners and cute smiling eyes |
| 7 | `t09_oval` | Hình bầu dục | `images/topics/t09_shapes/oval.png` | A big bright lavender-purple (`#9B5DE5`) vertical egg-like OVAL shape character with cute smiling eyes |
| 8 | `t09_diamond` | Hình thoi | `images/topics/t09_shapes/diamond.png` | A big bright turquoise (`#2EC4B6`) rhombus DIAMOND shape character standing on one point with cute smiling eyes |
| 9 | `t09_rainbow` | Cầu vồng | `images/topics/t09_shapes/rainbow.png` | A bright 7-color arched rainbow with two fluffy white clouds at the ends |
| 10 | `t09_line` | Đường thẳng | `images/topics/t09_shapes/line.png` | A cute pencil drawing a thick bold straight colorful horizontal LINE across the center |
| 11 | *(sticker 1)* | — | `images/stickers/stk_t09_1.png` | Die-cut sticker with thick white border: Circle, Square, and Triangle characters holding hands |
| 12 | *(sticker 2)* | — | `images/stickers/stk_t09_2.png` | Die-cut sticker with thick white border: A glowing yellow star and pink heart hugging |
| 13 | *(sticker 3)* | — | `images/stickers/stk_t09_3.png` | Die-cut sticker with thick white border: A cute rocket ship built out of a triangle, square, and circles |
| 14 | *(sticker 4)* | — | `images/stickers/stk_t09_4.png` | Die-cut sticker with thick white border: `[CHARACTER MOMO]` holding a giant golden star shape |

---

### A6. Chủ đề 10: Numbers & Sizes (`t10_numbers_sizes`) (14 file)

| # | `word_id` | Nghĩa TV (`vi`) | Đường dẫn file | Prompt chi tiết (+ `[Master Style Prompt]`) |
|---|---|---|---|---|
| 1 | `t10_eleven` | Số mười một (11) | `images/topics/t10_numbers_sizes/eleven.png` | Big chunky rounded number "11" in bright coral red with eleven small yellow stars arranged in two neat rows |
| 2 | `t10_twelve` | Số mười hai (12) | `images/topics/t10_numbers_sizes/twelve.png` | Big chunky rounded number "12" in bright blue next to an egg carton holding twelve cute colorful eggs |
| 3 | `t10_fifteen` | Số mười lăm (15) | `images/topics/t10_numbers_sizes/fifteen.png` | Big chunky rounded number "15" in bright green surrounded by three neat groups of five red apples |
| 4 | `t10_twenty` | Số hai mươi (20) | `images/topics/t10_numbers_sizes/twenty.png` | Big chunky rounded number "20" in shiny gold with colorful confetti dots arranged in two rows of ten |
| 5 | `t10_big` | To / Lớn | `images/topics/t10_numbers_sizes/big.png` | A HUGE friendly blue elephant filling most of the frame next to a tiny flower to emphasize BIG size |
| 6 | `t10_small` | Nhỏ / Bé | `images/topics/t10_numbers_sizes/small.png` | A TINY cute gray mouse sitting next to a large magnifying glass pointing at it to emphasize SMALL size |
| 7 | `t10_tall` | Cao | `images/topics/t10_numbers_sizes/tall.png` | A very TALL giraffe stretching its neck high up next to a vertical height ruler |
| 8 | `t10_short` | Thấp / Ngắn | `images/topics/t10_numbers_sizes/short.png` | A cute SHORT little dachshund puppy standing low next to a height ruler |
| 9 | `t10_long` | Dài | `images/topics/t10_numbers_sizes/long.png` | A very LONG colorful toy train stretching horizontally across the frame |
| 10 | `t10_heavy` | Nặng | `images/topics/t10_numbers_sizes/heavy.png` | `[CHARACTER MOMO]` puffing his cheeks while lifting a large HEAVY wooden treasure box with both hands |
| 11 | *(sticker 1)* | — | `images/stickers/stk_t10_1.png` | Die-cut sticker with thick white border: Golden number "20" trophy badge with stars |
| 12 | *(sticker 2)* | — | `images/stickers/stk_t10_2.png` | Die-cut sticker with thick white border: Big elephant and small mouse high-fiving |
| 13 | *(sticker 3)* | — | `images/stickers/stk_t10_3.png` | Die-cut sticker with thick white border: Tall giraffe wearing a party hat |
| 14 | *(sticker 4)* | — | `images/stickers/stk_t10_4.png` | Die-cut sticker with thick white border: `[CHARACTER MOMO]` flexing strong muscles next to a big weight |

---

### A7. Chủ đề 11: Yummy Fruits (`t11_fruits`) (14 file)

| # | `word_id` | Nghĩa TV (`vi`) | Đường dẫn file | Prompt chi tiết (+ `[Master Style Prompt]`) |
|---|---|---|---|---|
| 1 | `t11_apple` | Quả táo | `images/topics/t11_fruits/apple.png` | A shiny plump bright-red apple with a small green leaf on the stem |
| 2 | `t11_banana` | Quả chuối | `images/topics/t11_fruits/banana.png` | A bright sunny-yellow ripe banana slightly peeled at the top showing cream fruit inside |
| 3 | `t11_orange` | Quả cam | `images/topics/t11_fruits/orange.png` | A round bright-orange citrus fruit with a green leaf and a juicy half-slice beside it |
| 4 | `t11_mango` | Quả xoài | `images/topics/t11_fruits/mango.png` | A plump golden-yellow ripe mango with a small green leaf on top |
| 5 | `t11_watermelon` | Quả dưa hấu | `images/topics/t11_fruits/watermelon.png` | A big round green-striped watermelon with a triangular bright-red juicy slice in front |
| 6 | `t11_grapes` | Chùm nho | `images/topics/t11_fruits/grapes.png` | A plump bunch of glossy purple grapes with a curly green vine and leaf |
| 7 | `t11_strawberry` | Quả dâu tây | `images/topics/t11_fruits/strawberry.png` | A bright-red strawberry with tiny yellow seeds and a fresh green leafy cap |
| 8 | `t11_pineapple` | Quả dứa (thơm) | `images/topics/t11_fruits/pineapple.png` | A cheerful golden-yellow pineapple with diamond criss-cross pattern and a crown of green leaves |
| 9 | `t11_peach` | Quả đào | `images/topics/t11_fruits/peach.png` | A cute round rosy-pink peach with a soft gradient and two green leaves |
| 10 | `t11_coconut` | Quả dừa | `images/topics/t11_fruits/coconut.png` | A fresh green drinking coconut opened at the top with a colorful striped straw sticking out |
| 11 | *(sticker 1)* | — | `images/stickers/stk_t11_1.png` | Die-cut sticker with thick white border: Smiling red apple and yellow banana dancing together |
| 12 | *(sticker 2)* | — | `images/stickers/stk_t11_2.png` | Die-cut sticker with thick white border: A happy watermelon slice wearing cool sunglasses |
| 13 | *(sticker 3)* | — | `images/stickers/stk_t11_3.png` | Die-cut sticker with thick white border: A woven fruit basket overflowing with colorful fruits |
| 14 | *(sticker 4)* | — | `images/stickers/stk_t11_4.png` | Die-cut sticker with thick white border: `[CHARACTER MOMO]` hugging a giant yellow banana |

---

### A8. Chủ đề 12: Food & Drinks (`t12_food_drinks`) (16 file)

| # | `word_id` | Nghĩa TV (`vi`) | Đường dẫn file | Prompt chi tiết (+ `[Master Style Prompt]`) |
|---|---|---|---|---|
| 1 | `t12_rice` | Cơm | `images/topics/t12_food_drinks/rice.png` | A cute blue ceramic bowl filled with fluffy white steamed rice |
| 2 | `t12_bread` | Bánh mì | `images/topics/t12_food_drinks/bread.png` | A warm golden-brown loaf of sliced bread with two soft toast slices |
| 3 | `t12_egg` | Quả trứng | `images/topics/t12_food_drinks/egg.png` | A sunny-side-up fried egg with a bright yellow yolk next to a whole cream egg |
| 4 | `t12_soup` | Canh / Súp | `images/topics/t12_food_drinks/soup.png` | A warm yellow bowl of vegetable soup with gentle steam curls rising above |
| 5 | `t12_noodles` | Mì / Phở | `images/topics/t12_food_drinks/noodles.png` | A warm bowl of delicious golden noodles with a spoon and chopsticks lifting a strand |
| 6 | `t12_pizza` | Bánh pizza | `images/topics/t12_food_drinks/pizza.png` | A triangular slice of cheesy pizza with red tomato circles |
| 7 | `t12_cake` | Bánh kem | `images/topics/t12_food_drinks/cake.png` | A cute strawberry cream sponge cake topped with a red strawberry |
| 8 | `t12_ice_cream` | Kem | `images/topics/t12_food_drinks/ice_cream.png` | A crispy waffle cone with two scoops of pink and vanilla ice cream |
| 9 | `t12_milk` | Sữa | `images/topics/t12_food_drinks/milk.png` | A blue-and-white milk carton next to a clear glass full of white milk |
| 10 | `t12_water` | Nước lọc | `images/topics/t12_food_drinks/water.png` | A clear drinking glass filled with pure light-blue water and a water droplet splash |
| 11 | `t12_juice` | Nước ép | `images/topics/t12_food_drinks/juice.png` | A tall glass of bright orange juice with a straw and an orange slice on the rim |
| 12 | `t12_cookie` | Bánh quy | `images/topics/t12_food_drinks/cookie.png` | A round golden-brown chocolate chip cookie with a tiny bite taken out |
| 13 | *(sticker 1)* | — | `images/stickers/stk_t12_1.png` | Die-cut sticker with thick white border: Cute smiling milk glass and chocolate chip cookie |
| 14 | *(sticker 2)* | — | `images/stickers/stk_t12_2.png` | Die-cut sticker with thick white border: A cheerful double-scoop ice cream cone with sparkles |
| 15 | *(sticker 3)* | — | `images/stickers/stk_t12_3.png` | Die-cut sticker with thick white border: A happy steaming bowl of noodles |
| 16 | *(sticker 4)* | — | `images/stickers/stk_t12_4.png` | Die-cut sticker with thick white border: `[CHARACTER MOMO]` wearing a chef apron holding a yummy cake |

---

### A9. Chủ đề 13: My Toys (`t13_toys`) (14 file)

| # | `word_id` | Nghĩa TV (`vi`) | Đường dẫn file | Prompt chi tiết (+ `[Master Style Prompt]`) |
|---|---|---|---|---|
| 1 | `t13_ball` | Quả bóng | `images/topics/t13_toys/ball.png` | A round bouncy beach ball with bright red, blue, yellow, and white panels |
| 2 | `t13_doll` | Búp bê | `images/topics/t13_toys/doll.png` | A cute rag doll with yarn pigtails, button eyes, and a pink polka-dot dress |
| 3 | `t13_teddy_bear` | Gấu bông | `images/topics/t13_toys/teddy_bear.png` | A soft plush cinnamon-brown teddy bear sitting with a red bow ribbon around its neck |
| 4 | `t13_toy_car` | Xe đồ chơi | `images/topics/t13_toys/toy_car.png` | A chunky bright-red wooden wind-up toy car with big round black wheels |
| 5 | `t13_blocks` | Khối xếp hình | `images/topics/t13_toys/blocks.png` | Four colorful wooden building blocks (red, blue, yellow, green) stacked into a small castle tower |
| 6 | `t13_kite` | Cánh diều | `images/topics/t13_toys/kite.png` | A colorful diamond-shaped kite in red, yellow, and blue with a ribbon bow tail |
| 7 | `t13_robot` | Người máy | `images/topics/t13_toys/robot.png` | A cute friendly retro turquoise toy robot with a glowing heart on its chest and an antenna on top |
| 8 | `t13_balloon` | Bóng bay | `images/topics/t13_toys/balloon.png` | A shiny bright-pink floating party balloon tied with a curly white string |
| 9 | `t13_puzzle` | Tranh ghép hình | `images/topics/t13_toys/puzzle.png` | Four colorful interlocking jigsaw puzzle pieces fitting together |
| 10 | `t13_drum` | Cái trống | `images/topics/t13_toys/drum.png` | A cute red-and-white toy march drum with two wooden drumsticks crossed on top |
| 11 | *(sticker 1)* | — | `images/stickers/stk_t13_1.png` | Die-cut sticker with thick white border: Cute plush teddy bear hugging a red heart |
| 12 | *(sticker 2)* | — | `images/stickers/stk_t13_2.png` | Die-cut sticker with thick white border: Friendly toy robot waving with star sparkles |
| 13 | *(sticker 3)* | — | `images/stickers/stk_t13_3.png` | Die-cut sticker with thick white border: Colorful kite soaring among fluffy clouds |
| 14 | *(sticker 4)* | — | `images/stickers/stk_t13_4.png` | Die-cut sticker with thick white border: `[CHARACTER MOMO]` playing a cute red toy drum |

---

### A10. Chủ đề 14: My Clothes (`t14_clothes`) (14 file)

| # | `word_id` | Nghĩa TV (`vi`) | Đường dẫn file | Prompt chi tiết (+ `[Master Style Prompt]`) |
|---|---|---|---|---|
| 1 | `t14_shirt` | Áo sơ mi | `images/topics/t14_clothes/shirt.png` | A neat light-blue collared button-up child's shirt with round white buttons |
| 2 | `t14_t_shirt` | Áo thun | `images/topics/t14_clothes/t_shirt.png` | A bright orange short-sleeve T-shirt with a cute yellow star printed on the front |
| 3 | `t14_pants` | Quần dài | `images/topics/t14_clothes/pants.png` | A pair of comfortable soft denim-blue child's long pants with front pockets |
| 4 | `t14_shorts` | Quần đùi | `images/topics/t14_clothes/shorts.png` | A pair of cheerful leaf-green summer shorts with a yellow drawstring |
| 5 | `t14_dress` | Váy liền | `images/topics/t14_clothes/dress.png` | A cute pink child's dress with a flared skirt and a small white bow at the waist |
| 6 | `t14_skirt` | Chân váy | `images/topics/t14_clothes/skirt.png` | A cheerful pleated sunny-yellow child's skirt |
| 7 | `t14_shoes` | Đôi giày | `images/topics/t14_clothes/shoes.png` | A pair of cute red-and-white toddler sneakers with velcro straps side by side |
| 8 | `t14_socks` | Đôi tất (vớ) | `images/topics/t14_clothes/socks.png` | A pair of cozy striped colorful ankle socks (blue and yellow stripes) |
| 9 | `t14_hat` | Cái mũ (nón) | `images/topics/t14_clothes/hat.png` | A cute straw sun hat with a bright turquoise ribbon band around it |
| 10 | `t14_jacket` | Áo khoác | `images/topics/t14_clothes/jacket.png` | A cozy hooded zip-up winter jacket in bright teal and yellow |
| 11 | *(sticker 1)* | — | `images/stickers/stk_t14_1.png` | Die-cut sticker with thick white border: A pair of shiny red super-sneakers with wings |
| 12 | *(sticker 2)* | — | `images/stickers/stk_t14_2.png` | Die-cut sticker with thick white border: A cute sun hat and sunglasses ready for summer |
| 13 | *(sticker 3)* | — | `images/stickers/stk_t14_3.png` | Die-cut sticker with thick white border: A colorful star T-shirt and striped socks |
| 14 | *(sticker 4)* | — | `images/stickers/stk_t14_4.png` | Die-cut sticker with thick white border: `[CHARACTER MOMO]` looking cool in a yellow rain jacket and hat |

---

### A11. Chủ đề 15: My Cozy House (`t15_my_house`) (16 file)

| # | `word_id` | Nghĩa TV (`vi`) | Đường dẫn file | Prompt chi tiết (+ `[Master Style Prompt]`) |
|---|---|---|---|---|
| 1 | `t15_house` | Ngôi nhà | `images/topics/t15_my_house/house.png` | A cute cream two-story family house with a red tiled roof, chimney, and green bushes |
| 2 | `t15_door` | Cánh cửa | `images/topics/t15_my_house/door.png` | A warm wooden front door slightly open with a round brass doorknob and a welcome mat |
| 3 | `t15_window` | Cửa sổ | `images/topics/t15_my_house/window.png` | A square white-framed window with sky-blue curtains tied back and a flower pot on the sill |
| 4 | `t15_bedroom` | Phòng ngủ | `images/topics/t15_my_house/bedroom.png` | A cozy miniature child's bedroom vignette with a small bed, star pillow, and night lamp |
| 5 | `t15_kitchen` | Phòng bếp | `images/topics/t15_my_house/kitchen.png` | A cute miniature kitchen counter vignette with a stove, cooking pot, and fridge |
| 6 | `t15_bathroom` | Phòng tắm | `images/topics/t15_my_house/bathroom.png` | A clean miniature bathroom vignette with a white bathtub, bubbles, and a yellow rubber duck |
| 7 | `t15_bed` | Cái giường | `images/topics/t15_my_house/bed.png` | A cozy wooden child's bed with a fluffy white pillow and a pastel blue blanket |
| 8 | `t15_table` | Cái bàn | `images/topics/t15_my_house/table.png` | A sturdy round light-wood dining table with four legs |
| 9 | `t15_chair` | Cái ghế | `images/topics/t15_my_house/chair.png` | A cute wooden child's chair with a soft orange seat cushion |
| 10 | `t15_sofa` | Ghế sô-pha | `images/topics/t15_my_house/sofa.png` | A plush rounded turquoise living-room sofa with two yellow throw pillows |
| 11 | `t15_lamp` | Đèn bàn | `images/topics/t15_my_house/lamp.png` | A cute bedside table lamp with a warm yellow lampshade glowing softly |
| 12 | `t15_clock` | Đồng hồ | `images/topics/t15_my_house/clock.png` | A round colorful wall clock showing numbers 1 to 12 and two clear clock hands |
| 13 | *(sticker 1)* | — | `images/stickers/stk_t15_1.png` | Die-cut sticker with thick white border: A cozy house with a heart chimney puff |
| 14 | *(sticker 2)* | — | `images/stickers/stk_t15_2.png` | Die-cut sticker with thick white border: A cute smiling alarm clock ringing |
| 15 | *(sticker 3)* | — | `images/stickers/stk_t15_3.png` | Die-cut sticker with thick white border: A bubble bathtub with a yellow rubber duck |
| 16 | *(sticker 4)* | — | `images/stickers/stk_t15_4.png` | Die-cut sticker with thick white border: `[CHARACTER MOMO]` reading a book on a comfy sofa |

---

### A12. Chủ đề 16: My Feelings (`t16_feelings`) (14 file)

| # | `word_id` | Nghĩa TV (`vi`) | Đường dẫn file | Prompt chi tiết (+ `[Master Style Prompt]`) |
|---|---|---|---|---|
| 1 | `t16_happy` | Vui vẻ | `images/topics/t16_feelings/happy.png` | Close-up of `[CHARACTER MOMO]` with a huge beaming HAPPY smile, rosy cheeks, and sparkling eyes |
| 2 | `t16_sad` | Buồn | `images/topics/t16_feelings/sad.png` | Close-up of `[CHARACTER MOMO]` looking gently SAD with drooping ears, a small pout, and one tiny teardrop |
| 3 | `t16_angry` | Tức giận | `images/topics/t16_feelings/angry.png` | Close-up of `[CHARACTER MOMO]` with puffed red cheeks, furrowed eyebrows, and arms crossed in a cute ANGRY pout |
| 4 | `t16_scared` | Sợ hãi | `images/topics/t16_feelings/scared.png` | Close-up of `[CHARACTER MOMO]` looking mildly SCARED, holding hands to cheeks with wide round eyes |
| 5 | `t16_sleepy` | Buồn ngủ | `images/topics/t16_feelings/sleepy.png` | Close-up of `[CHARACTER MOMO]` yawning with half-closed SLEEPY eyes and small "Zzz" bubbles floating |
| 6 | `t16_tired` | Mệt | `images/topics/t16_feelings/tired.png` | `[CHARACTER MOMO]` sitting down wiping a tiny sweat drop from his forehead, looking TIRED after running |
| 7 | `t16_hungry` | Đói bụng | `images/topics/t16_feelings/hungry.png` | `[CHARACTER MOMO]` rubbing his tummy while thinking of a banana in a small thought bubble, looking HUNGRY |
| 8 | `t16_thirsty` | Khát nước | `images/topics/t16_feelings/thirsty.png` | `[CHARACTER MOMO]` holding an empty cup and thinking of a cool water drop, looking THIRSTY |
| 9 | `t16_surprised` | Ngạc nhiên | `images/topics/t16_feelings/surprised.png` | Close-up of `[CHARACTER MOMO]` with an "O" shaped mouth and wide sparkling eyes looking SURPRISED at a gift |
| 10 | `t16_excited` | Hào hứng | `images/topics/t16_feelings/excited.png` | `[CHARACTER MOMO]` jumping with starry eyes and fists pumped in the air, looking super EXCITED |
| 11 | *(sticker 1)* | — | `images/stickers/stk_t16_1.png` | Die-cut sticker with thick white border: A big sunny yellow smiley face badge with stars |
| 12 | *(sticker 2)* | — | `images/stickers/stk_t16_2.png` | Die-cut sticker with thick white border: `[CHARACTER MOMO]` sending a big warm comforting hug |
| 13 | *(sticker 3)* | — | `images/stickers/stk_t16_3.png` | Die-cut sticker with thick white border: Four colorful emotion stars (happy, sleepy, surprised, excited) |
| 14 | *(sticker 4)* | — | `images/stickers/stk_t16_4.png` | Die-cut sticker with thick white border: `[CHARACTER MOMO]` with starry excited eyes and a rainbow |

---

### A13. Chủ đề 17: Let's Move! (`t17_actions`) (16 file)

| # | `word_id` | Nghĩa TV (`vi`) | Đường dẫn file | Prompt chi tiết (+ `[Master Style Prompt]`) |
|---|---|---|---|---|
| 1 | `t17_run` | Chạy | `images/topics/t17_actions/run.png` | A cute 4-year-old child RUNNING happily forward in sneakers with motion lines behind |
| 2 | `t17_jump` | Nhảy bật lên | `images/topics/t17_actions/jump.png` | A cute child JUMPING high into the air with both arms raised joyfully |
| 3 | `t17_walk` | Đi bộ | `images/topics/t17_actions/walk.png` | A cute child WALKING calmly with a cheerful smile, one foot stepping forward |
| 4 | `t17_dance` | Nhảy múa | `images/topics/t17_actions/dance.png` | A cute child DANCING happily with musical notes floating around |
| 5 | `t17_sing` | Ca hát | `images/topics/t17_actions/sing.png` | A cute child holding a toy microphone and SINGING with floating music notes |
| 6 | `t17_swim` | Bơi | `images/topics/t17_actions/swim.png` | A cute child wearing swim goggles SWIMMING happily in light-blue water waves |
| 7 | `t17_fly` | Bay | `images/topics/t17_actions/fly.png` | A cute bluebird FLYING high in the air with wings spread wide |
| 8 | `t17_climb` | Leo trèo | `images/topics/t17_actions/climb.png` | `[CHARACTER MOMO]` CLIMBING up a safe wooden playground ladder happily |
| 9 | `t17_sit` | Ngồi | `images/topics/t17_actions/sit.png` | A cute child SITTING neatly on a colorful floor cushion with hands on knees |
| 10 | `t17_stand` | Đứng | `images/topics/t17_actions/stand.png` | A cute child STANDING up straight and tall with a proud happy smile |
| 11 | `t17_laugh` | Cười vang | `images/topics/t17_actions/laugh.png` | A cute child holding their tummy and LAUGHING out loud joyfully |
| 12 | `t17_hug` | Ôm | `images/topics/t17_actions/hug.png` | `[CHARACTER MOMO]` and a cute child giving each other a warm HUG with a small pink heart above |
| 13 | *(sticker 1)* | — | `images/stickers/stk_t17_1.png` | Die-cut sticker with thick white border: `[CHARACTER MOMO]` dancing with headphones and music notes |
| 14 | *(sticker 2)* | — | `images/stickers/stk_t17_2.png` | Die-cut sticker with thick white border: Golden winged sneaker medal for running and jumping |
| 15 | *(sticker 3)* | — | `images/stickers/stk_t17_3.png` | Die-cut sticker with thick white border: Two cute friends giving a big warm hug |
| 16 | *(sticker 4)* | — | `images/stickers/stk_t17_4.png` | Die-cut sticker with thick white border: `[CHARACTER MOMO]` doing a superhero jump in the air |

---

### A14. Chủ đề 18: Daily Routines (`t18_routines`) (14 file)

| # | `word_id` | Nghĩa TV (`vi`) | Đường dẫn file | Prompt chi tiết (+ `[Master Style Prompt]`) |
|---|---|---|---|---|
| 1 | `t18_wake_up` | Thức dậy | `images/topics/t18_routines/wake_up.png` | A cute child sitting up in bed stretching arms wide as a cheerful morning sun shines outside |
| 2 | `t18_brush_teeth` | Đánh răng | `images/topics/t18_routines/brush_teeth.png` | A cute child holding a blue toothbrush and BRUSHING TEETH with foamy white bubbles |
| 3 | `t18_wash_face` | Rửa mặt | `images/topics/t18_routines/wash_face.png` | A cute child splashing clean water drops on their cheeks to WASH FACE with a towel nearby |
| 4 | `t18_wash_hands` | Rửa tay | `images/topics/t18_routines/wash_hands.png` | Two child hands rubbing white soap bubbles together under clean water drops |
| 5 | `t18_comb_hair` | Chải tóc | `images/topics/t18_routines/comb_hair.png` | A cute child using a yellow comb to neatly COMB HAIR with a happy smile |
| 6 | `t18_take_a_bath` | Đi tắm | `images/topics/t18_routines/take_a_bath.png` | `[CHARACTER MOMO]` sitting in a white bathtub full of fluffy soap bubbles with a yellow rubber duck |
| 7 | `t18_eat_breakfast` | Ăn sáng | `images/topics/t18_routines/eat_breakfast.png` | A cute child sitting at a table eating a healthy breakfast of bread, egg, and milk |
| 8 | `t18_read_a_book` | Đọc sách | `images/topics/t18_routines/read_a_book.png` | A cute child holding an open colorful picture storybook and reading happily |
| 9 | `t18_go_to_bed` | Đi ngủ | `images/topics/t18_routines/go_to_bed.png` | A cute child in starry pajamas tucked into a cozy bed pulling up a soft blanket |
| 10 | `t18_good_night` | Chúc ngủ ngon | `images/topics/t18_routines/good_night.png` | A smiling yellow crescent moon wearing a nightcap surrounded by twinkling stars in a dark-blue circle |
| 11 | *(sticker 1)* | — | `images/stickers/stk_t18_1.png` | Die-cut sticker with thick white border: A sparkling clean tooth and a smiling toothbrush |
| 12 | *(sticker 2)* | — | `images/stickers/stk_t18_2.png` | Die-cut sticker with thick white border: Clean hands with soap bubbles and stars |
| 13 | *(sticker 3)* | — | `images/stickers/stk_t18_3.png` | Die-cut sticker with thick white border: Smiling crescent moon and sleepy star |
| 14 | *(sticker 4)* | — | `images/stickers/stk_t18_4.png` | Die-cut sticker with thick white border: `[CHARACTER MOMO]` in cute pajamas hugging a star pillow |

---

### A15. Chủ đề 19: Mealtime Tools (`t19_tableware`) (14 file)

| # | `word_id` | Nghĩa TV (`vi`) | Đường dẫn file | Prompt chi tiết (+ `[Master Style Prompt]`) |
|---|---|---|---|---|
| 1 | `t19_spoon` | Cái thìa (muỗng) | `images/topics/t19_tableware/spoon.png` | A cute rounded silver-and-orange child's SPOON angled diagonally |
| 2 | `t19_fork` | Cái nĩa | `images/topics/t19_tableware/fork.png` | A cute safe rounded child's FORK with a turquoise handle |
| 3 | `t19_bowl` | Cái bát (chén) | `images/topics/t19_tableware/bowl.png` | A cute round sunny-yellow ceramic soup BOWL with a small star pattern on the side |
| 4 | `t19_plate` | Cái đĩa | `images/topics/t19_tableware/plate.png` | A clean round white dinner PLATE with a colorful pastel blue rim |
| 5 | `t19_cup` | Cái cốc có quai | `images/topics/t19_tableware/cup.png` | A cute coral-pink ceramic mug CUP with a round handle |
| 6 | `t19_glass` | Ly thủy tinh | `images/topics/t19_tableware/glass.png` | A clear transparent drinking GLASS half-filled with light-blue water |
| 7 | `t19_bottle` | Bình nước | `images/topics/t19_tableware/bottle.png` | A cute reusable kids water BOTTLE in mint green with a flip-top straw lid |
| 8 | `t19_napkin` | Khăn ăn | `images/topics/t19_tableware/napkin.png` | A neatly folded soft cream cloth NAPKIN with a pastel orange border |
| 9 | `t19_chopsticks` | Đôi đũa | `images/topics/t19_tableware/chopsticks.png` | A pair of smooth warm-brown wooden CHOPSTICKS resting on a little ceramic holder |
| 10 | `t19_pot` | Cái nồi | `images/topics/t19_tableware/pot.png` | A cute bright-red cooking POT with two side handles and a lid |
| 11 | *(sticker 1)* | — | `images/stickers/stk_t19_1.png` | Die-cut sticker with thick white border: Cute smiling spoon and fork high-fiving |
| 12 | *(sticker 2)* | — | `images/stickers/stk_t19_2.png` | Die-cut sticker with thick white border: A happy yellow bowl and pink cup |
| 13 | *(sticker 3)* | — | `images/stickers/stk_t19_3.png` | Die-cut sticker with thick white border: A red cooking pot with heart-shaped steam |
| 14 | *(sticker 4)* | — | `images/stickers/stk_t19_4.png` | Die-cut sticker with thick white border: `[CHARACTER MOMO]` holding a spoon and bowl ready to eat |

---

### A16. Chủ đề 20: Fun Opposites (`t20_opposites`) (14 file)

| # | `word_id` | Nghĩa TV (`vi`) | Đường dẫn file | Prompt chi tiết (+ `[Master Style Prompt]`) |
|---|---|---|---|---|
| 1 | `t20_hot` | Nóng | `images/topics/t20_opposites/hot.png` | A steaming mug of cocoa next to a glowing red-orange thermometer icon showing HOT |
| 2 | `t20_cold` | Lạnh | `images/topics/t20_opposites/cold.png` | A cute shivering blue ice cube with snowflakes and a blue thermometer icon showing COLD |
| 3 | `t20_fast` | Nhanh | `images/topics/t20_opposites/fast.png` | A cute white rabbit zooming forward at super FAST speed with wind streaks behind |
| 4 | `t20_slow` | Chậm | `images/topics/t20_opposites/slow.png` | A cute green tortoise walking very SLOW with a tiny snail on its shell |
| 5 | `t20_up` | Lên trên | `images/topics/t20_opposites/up.png` | `[CHARACTER MOMO]` climbing UP a step with a big bright green arrow pointing UP |
| 6 | `t20_down` | Xuống dưới | `images/topics/t20_opposites/down.png` | `[CHARACTER MOMO]` sliding DOWN a yellow playground slide with a big orange arrow pointing DOWN |
| 7 | `t20_open` | Mở ra | `images/topics/t20_opposites/open.png` | A colorful gift treasure box with its lid wide OPEN and stars popping out |
| 8 | `t20_close` | Đóng lại | `images/topics/t20_opposites/close.png` | The same colorful gift treasure box with its lid CLOSED tightly and tied with a ribbon |
| 9 | `t20_clean` | Sạch sẽ | `images/topics/t20_opposites/clean.png` | A pair of white sneakers that are sparkling CLEAN with twinkling star sparkles around them |
| 10 | `t20_dirty` | Bẩn / Lấm lem | `images/topics/t20_opposites/dirty.png` | A pair of sneakers covered in brown mud splashes looking DIRTY |
| 11 | *(sticker 1)* | — | `images/stickers/stk_t20_1.png` | Die-cut sticker with thick white border: Fast bunny and slow turtle crossing a finish line together |
| 12 | *(sticker 2)* | — | `images/stickers/stk_t20_2.png` | Die-cut sticker with thick white border: Cute hot sun and cold snowflake smiling side by side |
| 13 | *(sticker 3)* | — | `images/stickers/stk_t20_3.png` | Die-cut sticker with thick white border: Open treasure chest overflowing with golden stars |
| 14 | *(sticker 4)* | — | `images/stickers/stk_t20_4.png` | Die-cut sticker with thick white border: `[CHARACTER MOMO]` sliding happily down a rainbow slide |

---

### A17. Chủ đề 21: Beep! Vehicles (`t21_vehicles`) (16 file)

| # | `word_id` | Nghĩa TV (`vi`) | Đường dẫn file | Prompt chi tiết (+ `[Master Style Prompt]`) |
|---|---|---|---|---|
| 1 | `t21_car` | Xe ô tô | `images/topics/t21_vehicles/car.png` | A cute rounded bright-red family CAR with big friendly headlights and smooth wheels |
| 2 | `t21_bus` | Xe buýt | `images/topics/t21_vehicles/bus.png` | A cheerful sunny-yellow school BUS with big windows |
| 3 | `t21_bike` | Xe đạp | `images/topics/t21_vehicles/bike.png` | A cute sky-blue child's BICYCLE with a front basket and bell |
| 4 | `t21_motorbike` | Xe máy | `images/topics/t21_vehicles/motorbike.png` | A cute pastel-mint scooter MOTORBIKE with a matching safety helmet on the seat |
| 5 | `t21_train` | Tàu hỏa | `images/topics/t21_vehicles/train.png` | A colorful steam TRAIN locomotive in blue and red puffing a fluffy white cloud |
| 6 | `t21_airplane` | Máy bay | `images/topics/t21_vehicles/airplane.png` | A cute chubby white-and-blue passenger AIRPLANE soaring with two small clouds |
| 7 | `t21_helicopter` | Trực thăng | `images/topics/t21_vehicles/helicopter.png` | A cute round orange-and-teal HELICOPTER with spinning rotor blades on top |
| 8 | `t21_boat` | Thuyền nhỏ | `images/topics/t21_vehicles/boat.png` | A cute wooden sailboat with a white-and-red striped sail floating on a small blue wave |
| 9 | `t21_ship` | Tàu thủy lớn | `images/topics/t21_vehicles/ship.png` | A big friendly ocean cruise SHIP in white, blue, and red with two smokestacks |
| 10 | `t21_truck` | Xe tải | `images/topics/t21_vehicles/truck.png` | A sturdy green-and-yellow dump TRUCK carrying colorful blocks |
| 11 | `t21_fire_truck` | Xe cứu hỏa | `images/topics/t21_vehicles/fire_truck.png` | A bright-red FIRE TRUCK with a white ladder on top and a blue flashing siren light |
| 12 | `t21_police_car` | Xe cảnh sát | `images/topics/t21_vehicles/police_car.png` | A cute blue-and-white POLICE CAR with a star badge on the door and a top light |
| 13 | *(sticker 1)* | — | `images/stickers/stk_t21_1.png` | Die-cut sticker with thick white border: Cute red fire truck and blue police car team |
| 14 | *(sticker 2)* | — | `images/stickers/stk_t21_2.png` | Die-cut sticker with thick white border: Colorful choo-choo train puffing star clouds |
| 15 | *(sticker 3)* | — | `images/stickers/stk_t21_3.png` | Die-cut sticker with thick white border: Cute airplane flying over a rainbow |
| 16 | *(sticker 4)* | — | `images/stickers/stk_t21_4.png` | Die-cut sticker with thick white border: `[CHARACTER MOMO]` wearing pilot goggles flying an airplane |

---

### A18. Chủ đề 22: Weather & Nature (`t22_weather_nature`) (16 file)

| # | `word_id` | Nghĩa TV (`vi`) | Đường dẫn file | Prompt chi tiết (+ `[Master Style Prompt]`) |
|---|---|---|---|---|
| 1 | `t22_sun` | Mặt trời | `images/topics/t22_weather_nature/sun.png` | A bright warm golden-yellow SUN with rounded rays and a gentle happy smile |
| 2 | `t22_moon` | Mặt trăng | `images/topics/t22_weather_nature/moon.png` | A glowing soft-yellow crescent MOON with a peaceful smile and two tiny stars |
| 3 | `t22_cloud` | Đám mây | `images/topics/t22_weather_nature/cloud.png` | A big fluffy soft white CLOUD with a light-blue shadow contour |
| 4 | `t22_rain` | Cơn mưa | `images/topics/t22_weather_nature/rain.png` | A soft blue-gray cloud with cute sky-blue RAIN droplets falling gently |
| 5 | `t22_wind` | Cơn gió | `images/topics/t22_weather_nature/wind.png` | A cute cloud blowing gentle swirling turquoise WIND breeze lines and two floating leaves |
| 6 | `t22_snow` | Tuyết | `images/topics/t22_weather_nature/snow.png` | A cute white snowman wearing a red scarf surrounded by clear six-pointed SNOWFLAKES |
| 7 | `t22_tree` | Cái cây | `images/topics/t22_weather_nature/tree.png` | A lush round green TREE with a warm brown trunk |
| 8 | `t22_flower` | Bông hoa | `images/topics/t22_weather_nature/flower.png` | A cheerful pink-and-yellow daisy FLOWER with two green leaves on the stem |
| 9 | `t22_grass` | Thảm cỏ | `images/topics/t22_weather_nature/grass.png` | A fresh tuft of vibrant green GRASS blades with tiny yellow wildflowers |
| 10 | `t22_sunny` | Trời nắng | `images/topics/t22_weather_nature/sunny.png` | A circular weather window showing a bright SUNNY blue sky with a smiling sun |
| 11 | `t22_rainy` | Trời mưa | `images/topics/t22_weather_nature/rainy.png` | A cute yellow umbrella opened under falling blue raindrops on a RAINY day |
| 12 | `t22_windy` | Trời gió | `images/topics/t22_weather_nature/windy.png` | A small green tree bending gently in a WINDY breeze with swirling wind lines |
| 13 | *(sticker 1)* | — | `images/stickers/stk_t22_1.png` | Die-cut sticker with thick white border: Smiling sun wearing cool sunglasses |
| 14 | *(sticker 2)* | — | `images/stickers/stk_t22_2.png` | Die-cut sticker with thick white border: Cute cloud with a rainbow waterfall |
| 15 | *(sticker 3)* | — | `images/stickers/stk_t22_3.png` | Die-cut sticker with thick white border: Happy pink flower and green tree |
| 16 | *(sticker 4)* | — | `images/stickers/stk_t22_4.png` | Die-cut sticker with thick white border: `[CHARACTER MOMO]` jumping in rain puddles with yellow boots and an umbrella |

---

### A19. Chủ đề 23: My Preschool (`t23_school`) (14 file)

| # | `word_id` | Nghĩa TV (`vi`) | Đường dẫn file | Prompt chi tiết (+ `[Master Style Prompt]`) |
|---|---|---|---|---|
| 1 | `t23_school` | Trường học | `images/topics/t23_school/school.png` | A cheerful pastel-yellow preschool building with a red roof, clock tower, and welcoming double doors |
| 2 | `t23_teacher` | Cô giáo | `images/topics/t23_school/teacher.png` | A kind young female preschool TEACHER smiling warmly while holding an open picture book |
| 3 | `t23_classroom` | Lớp học | `images/topics/t23_school/classroom.png` | A bright preschool CLASSROOM scene with a green board, colorful rug, and small kids table |
| 4 | `t23_book` | Quyển sách | `images/topics/t23_school/book.png` | A thick colorful picture STORYBOOK with a star on the cover, slightly open |
| 5 | `t23_crayon` | Bút sáp màu | `images/topics/t23_school/crayon.png` | Three chunky preschool wax CRAYONS in red, yellow, and blue side by side |
| 6 | `t23_pencil` | Bút chì | `images/topics/t23_school/pencil.png` | A cute chunky yellow wooden PENCIL with a pink eraser tip |
| 7 | `t23_paper` | Tờ giấy | `images/topics/t23_school/paper.png` | A clean white sheet of drawing PAPER with a small colorful sun and flower sketch on it |
| 8 | `t23_bag` | Cặp sách (Ba lô) | `images/topics/t23_school/bag.png` | A cute rounded turquoise-and-orange kids backpack school BAG with a front pocket |
| 9 | `t23_scissors` | Cái kéo | `images/topics/t23_school/scissors.png` | A pair of safe rounded-tip plastic craft SCISSORS with bright orange handles |
| 10 | `t23_playground` | Sân chơi | `images/topics/t23_school/playground.png` | A colorful kids PLAYGROUND set with a yellow slide and red swing |
| 11 | *(sticker 1)* | — | `images/stickers/stk_t23_1.png` | Die-cut sticker with thick white border: A cute backpack and open storybook with stars |
| 12 | *(sticker 2)* | — | `images/stickers/stk_t23_2.png` | Die-cut sticker with thick white border: Three smiling colorful crayons |
| 13 | *(sticker 3)* | — | `images/stickers/stk_t23_3.png` | Die-cut sticker with thick white border: A golden "Super Student" star medal |
| 14 | *(sticker 4)* | — | `images/stickers/stk_t23_4.png` | Die-cut sticker with thick white border: `[CHARACTER MOMO]` wearing a backpack waving on the way to school |

---

### A20. Chủ đề 24: Cool Jobs (`t24_jobs`) (14 file)

| # | `word_id` | Nghĩa TV (`vi`) | Đường dẫn file | Prompt chi tiết (+ `[Master Style Prompt]`) |
|---|---|---|---|---|
| 1 | `t24_doctor` | Bác sĩ | `images/topics/t24_jobs/doctor.png` | A friendly young DOCTOR wearing a white coat and a stethoscope around the neck, smiling kindly |
| 2 | `t24_nurse` | Y tá | `images/topics/t24_jobs/nurse.png` | A caring young NURSE in light-teal scrubs holding a little heart band-aid with a warm smile |
| 3 | `t24_firefighter` | Lính cứu hỏa | `images/topics/t24_jobs/firefighter.png` | A brave friendly FIREFIGHTER wearing a red helmet and yellow coat holding a water hose |
| 4 | `t24_police_officer` | Cảnh sát | `images/topics/t24_jobs/police_officer.png` | A friendly POLICE OFFICER in a blue uniform and cap waving with a warm reassuring smile |
| 5 | `t24_chef` | Đầu bếp | `images/topics/t24_jobs/chef.png` | A cheerful CHEF wearing a tall white chef hat and apron holding a wooden spoon |
| 6 | `t24_farmer` | Nông dân | `images/topics/t24_jobs/farmer.png` | A happy FARMER wearing a straw hat and blue overalls holding a basket of red apples |
| 7 | `t24_driver` | Tài xế | `images/topics/t24_jobs/driver.png` | A cheerful bus DRIVER wearing a blue cap holding a steering wheel and waving |
| 8 | `t24_builder` | Thợ xây | `images/topics/t24_jobs/builder.png` | A friendly BUILDER wearing a yellow safety hard hat and tool belt holding a toy hammer |
| 9 | `t24_singer` | Ca sĩ | `images/topics/t24_jobs/singer.png` | A joyful SINGER holding a golden microphone on stage with musical notes around |
| 10 | `t24_astronaut` | Phi hành gia | `images/topics/t24_jobs/astronaut.png` | A cute ASTRONAUT in a white spacesuit with the helmet visor open showing a big smile and floating stars |
| 11 | *(sticker 1)* | — | `images/stickers/stk_t24_1.png` | Die-cut sticker with thick white border: Cute doctor stethoscope and heart badge |
| 12 | *(sticker 2)* | — | `images/stickers/stk_t24_2.png` | Die-cut sticker with thick white border: Shiny red firefighter helmet with stars |
| 13 | *(sticker 3)* | — | `images/stickers/stk_t24_3.png` | Die-cut sticker with thick white border: Cute white space rocket blasting off to the stars |
| 14 | *(sticker 4)* | — | `images/stickers/stk_t24_4.png` | Die-cut sticker with thick white border: `[CHARACTER MOMO]` dressed as a cute astronaut floating with stars |

---

### A21. Chủ đề 25: Party & Holidays (`t25_party_holidays`) (14 file)

| # | `word_id` | Nghĩa TV (`vi`) | Đường dẫn file | Prompt chi tiết (+ `[Master Style Prompt]`) |
|---|---|---|---|---|
| 1 | `t25_birthday` | Sinh nhật | `images/topics/t25_party_holidays/birthday.png` | A two-tier pink-and-cream BIRTHDAY cake decorated with sprinkles and four lit candles |
| 2 | `t25_gift` | Hộp quà | `images/topics/t25_party_holidays/gift.png` | A square bright-yellow GIFT box wrapped with a big red satin ribbon bow on top |
| 3 | `t25_candle` | Ngọn nến | `images/topics/t25_party_holidays/candle.png` | A cute striped pink-and-white birthday CANDLE with a warm glowing yellow flame |
| 4 | `t25_party_hat` | Mũ sinh nhật | `images/topics/t25_party_holidays/party_hat.png` | A cone-shaped colorful polka-dot PARTY HAT topped with a fluffy yellow pom-pom |
| 5 | `t25_crown` | Vương miện | `images/topics/t25_party_holidays/crown.png` | A shiny golden CROWN decorated with colorful red, blue, and green gem circles |
| 6 | `t25_music` | Âm nhạc | `images/topics/t25_party_holidays/music.png` | Colorful floating 3D MUSIC notes (eighth notes and treble clef) in orange, teal, and pink with sparkles |
| 7 | `t25_fireworks` | Pháo hoa | `images/topics/t25_party_holidays/fireworks.png` | Bright colorful FIREWORKS bursting into star patterns in pink, gold, and turquoise |
| 8 | `t25_lantern` | Đèn lồng | `images/topics/t25_party_holidays/lantern.png` | A traditional festive glowing red-and-gold paper LANTERN with a yellow tassel |
| 9 | `t25_wish` | Điều ước | `images/topics/t25_party_holidays/wish.png` | A glowing golden shooting star with a sparkly rainbow trail representing a magic WISH |
| 10 | `t25_celebrate` | Ăn mừng | `images/topics/t25_party_holidays/celebrate.png` | A party popper bursting out colorful confetti ribbons and stars to CELEBRATE |
| 11 | *(sticker 1)* | — | `images/stickers/stk_t25_1.png` | Die-cut sticker with thick white border: A festive birthday cake with glowing candles |
| 12 | *(sticker 2)* | — | `images/stickers/stk_t25_2.png` | Die-cut sticker with thick white border: A golden crown with a big number star |
| 13 | *(sticker 3)* | — | `images/stickers/stk_t25_3.png` | Die-cut sticker with thick white border: Glowing red festival lantern and fireworks |
| 14 | *(sticker 4)* | — | `images/stickers/stk_t25_4.png` | Die-cut sticker with thick white border: `[CHARACTER MOMO]` wearing a party hat holding a gift box with confetti |

---

### A22. Hình minh họa động tác TPR mở rộng – Simon Says (12 file)

| # | `command_id` | Đường dẫn file | Prompt chi tiết (+ `[Master Style Prompt]`) |
|---|---|---|---|
| 1 | `cmd_give_hug` | `images/tpr/cmd_give_hug.png` | `[CHARACTER MOMO]` wrapping both arms around himself in a warm self-hug with a floating pink heart |
| 2 | `cmd_roar_lion` | `images/tpr/cmd_roar_lion.png` | `[CHARACTER MOMO]` holding both paws up like a cute baby lion and making a playful roar face |
| 3 | `cmd_draw_circle` | `images/tpr/cmd_draw_circle.png` | `[CHARACTER MOMO]` drawing a big glowing circle in the air with one finger |
| 4 | `cmd_reach_tall` | `images/tpr/cmd_reach_tall.png` | `[CHARACTER MOMO]` standing on tiptoes stretching both hands high up to the sky like a tall giraffe |
| 5 | `cmd_rub_tummy` | `images/tpr/cmd_rub_tummy.png` | `[CHARACTER MOMO]` rubbing his round tummy in a circular motion with a yummy smile |
| 6 | `cmd_walk_robot` | `images/tpr/cmd_walk_robot.png` | `[CHARACTER MOMO]` bending arms at 90 degrees and marching stiffly like a cute funny robot |
| 7 | `cmd_put_on_hat` | `images/tpr/cmd_put_on_hat.png` | `[CHARACTER MOMO]` using both hands to place an imaginary hat on top of his head |
| 8 | `cmd_knock_door` | `images/tpr/cmd_knock_door.png` | `[CHARACTER MOMO]` knocking forward in the air with one fist ("knock, knock") |
| 9 | `cmd_smile_happy` | `images/tpr/cmd_smile_happy.png` | `[CHARACTER MOMO]` pointing both index fingers to his smiling cheeks with a big happy grin |
| 10 | `cmd_dance_spin` | `images/tpr/cmd_dance_spin.png` | `[CHARACTER MOMO]` spinning around happily in a dance pose with curved motion lines |
| 11 | `cmd_brush_teeth` | `images/tpr/cmd_brush_teeth.png` | `[CHARACTER MOMO]` mimicking brushing his teeth with an index finger moving left and right |
| 12 | `cmd_drive_car` | `images/tpr/cmd_drive_car.png` | `[CHARACTER MOMO]` holding an imaginary steering wheel with both hands and turning it ("beep, beep!") |

---

## 4. PHẦN B – DANH SÁCH ÂM THANH (AUDIO) CHO 20 CHỦ ĐỀ MỚI

> Tất cả đường dẫn tính từ gốc thư mục tài nguyên (`app/assets/` hoặc thư mục gốc của gói `.bvpack`).
> Giọng đọc tiếng Anh: **Anh – Mỹ (en-US)**, phát âm rõ, chậm rãi (~85% tốc độ thường), tươi vui.

### B1. Giọng đọc Từ vựng & Câu ví dụ – 20 Chủ đề (`t06` → `t25`) (424 file: 212 từ + 212 câu)

#### Chủ đề 6: My Big Family (`t06_family`)
| # | `word_id` | Nghĩa TV (`vi`) | File âm thanh TỪ (`audio/words/...`) | Văn bản đọc (Từ) | File âm thanh CÂU (`audio/sentences/...`) | Văn bản đọc (Câu ví dụ) |
|---|---|---|---|---|---|---|
| 1 | `t06_family` | Gia đình | `audio/words/t06_family.mp3` | Family. | `audio/sentences/t06_family_s.mp3` | I love my big family! |
| 2 | `t06_grandma` | Bà | `audio/words/t06_grandma.mp3` | Grandma. | `audio/sentences/t06_grandma_s.mp3` | My grandma makes yummy cookies! |
| 3 | `t06_grandpa` | Ông | `audio/words/t06_grandpa.mp3` | Grandpa. | `audio/sentences/t06_grandpa_s.mp3` | My grandpa tells funny stories! |
| 4 | `t06_brother` | Anh / Em trai | `audio/words/t06_brother.mp3` | Brother. | `audio/sentences/t06_brother_s.mp3` | I play ball with my brother! |
| 5 | `t06_sister` | Chị / Em gái | `audio/words/t06_sister.mp3` | Sister. | `audio/sentences/t06_sister_s.mp3` | My sister sings with me! |
| 6 | `t06_uncle` | Chú / Bác trai | `audio/words/t06_uncle.mp3` | Uncle. | `audio/sentences/t06_uncle_s.mp3` | My uncle is tall and kind! |
| 7 | `t06_aunt` | Cô / Dì | `audio/words/t06_aunt.mp3` | Aunt. | `audio/sentences/t06_aunt_s.mp3` | My aunt gives me a warm hug! |
| 8 | `t06_cousin` | Anh chị em họ | `audio/words/t06_cousin.mp3` | Cousin. | `audio/sentences/t06_cousin_s.mp3` | My cousin is my good friend! |
| 9 | `t06_home` | Tổ ấm / Nhà | `audio/words/t06_home.mp3` | Home. | `audio/sentences/t06_home_s.mp3` | Welcome to my happy home! |
| 10 | `t06_love` | Yêu thương | `audio/words/t06_love.mp3` | Love. | `audio/sentences/t06_love_s.mp3` | I love you so much! |

#### Chủ đề 7: Zoo Animals (`t07_wild_animals`)
| # | `word_id` | Nghĩa TV (`vi`) | File âm thanh TỪ | Văn bản đọc (Từ) | File âm thanh CÂU | Văn bản đọc (Câu ví dụ) |
|---|---|---|---|---|---|---|
| 11 | `t07_lion` | Sư tử | `audio/words/t07_lion.mp3` | Lion. | `audio/sentences/t07_lion_s.mp3` | The lion is the king! Roar! |
| 12 | `t07_tiger` | Con hổ | `audio/words/t07_tiger.mp3` | Tiger. | `audio/sentences/t07_tiger_s.mp3` | The tiger has orange and black stripes! |
| 13 | `t07_elephant` | Con voi | `audio/words/t07_elephant.mp3` | Elephant. | `audio/sentences/t07_elephant_s.mp3` | The elephant has a long nose! |
| 14 | `t07_monkey` | Con khỉ | `audio/words/t07_monkey.mp3` | Monkey. | `audio/sentences/t07_monkey_s.mp3` | Momo is a happy little monkey! |
| 15 | `t07_bear` | Con gấu | `audio/words/t07_bear.mp3` | Bear. | `audio/sentences/t07_bear_s.mp3` | The big brown bear loves honey! |
| 16 | `t07_giraffe` | Hươu cao cổ | `audio/words/t07_giraffe.mp3` | Giraffe. | `audio/sentences/t07_giraffe_s.mp3` | The giraffe has a very long neck! |
| 17 | `t07_zebra` | Ngựa vằn | `audio/words/t07_zebra.mp3` | Zebra. | `audio/sentences/t07_zebra_s.mp3` | The zebra is black and white! |
| 18 | `t07_hippo` | Hà mã | `audio/words/t07_hippo.mp3` | Hippo. | `audio/sentences/t07_hippo_s.mp3` | The hippo has a big wide mouth! |
| 19 | `t07_crocodile` | Cá sấu | `audio/words/t07_crocodile.mp3` | Crocodile. | `audio/sentences/t07_crocodile_s.mp3` | Snap, snap goes the green crocodile! |
| 20 | `t07_snake` | Con rắn | `audio/words/t07_snake.mp3` | Snake. | `audio/sentences/t07_snake_s.mp3` | Hiss, hiss goes the long snake! |
| 21 | `t07_panda` | Gấu trúc | `audio/words/t07_panda.mp3` | Panda. | `audio/sentences/t07_panda_s.mp3` | The cute panda eats green bamboo! |
| 22 | `t07_kangaroo` | Chuột túi | `audio/words/t07_kangaroo.mp3` | Kangaroo. | `audio/sentences/t07_kangaroo_s.mp3` | Jump, jump like a kangaroo! |

#### Chủ đề 8: Ocean & Bugs (`t08_sea_bugs`)
| # | `word_id` | Nghĩa TV (`vi`) | File âm thanh TỪ | Văn bản đọc (Từ) | File âm thanh CÂU | Văn bản đọc (Câu ví dụ) |
|---|---|---|---|---|---|---|
| 23 | `t08_shark` | Cá mập | `audio/words/t08_shark.mp3` | Shark. | `audio/sentences/t08_shark_s.mp3` | The baby shark swims fast in the sea! |
| 24 | `t08_whale` | Cá voi | `audio/words/t08_whale.mp3` | Whale. | `audio/sentences/t08_whale_s.mp3` | The blue whale is super big! |
| 25 | `t08_dolphin` | Cá heo | `audio/words/t08_dolphin.mp3` | Dolphin. | `audio/sentences/t08_dolphin_s.mp3` | The clever dolphin jumps over the waves! |
| 26 | `t08_turtle` | Rùa biển | `audio/words/t08_turtle.mp3` | Turtle. | `audio/sentences/t08_turtle_s.mp3` | The sea turtle swims nice and slow! |
| 27 | `t08_crab` | Con cua | `audio/words/t08_crab.mp3` | Crab. | `audio/sentences/t08_crab_s.mp3` | The red crab walks sideways! Click, click! |
| 28 | `t08_octopus` | Bạch tuộc | `audio/words/t08_octopus.mp3` | Octopus. | `audio/sentences/t08_octopus_s.mp3` | The octopus has eight funny arms! |
| 29 | `t08_starfish` | Sao biển | `audio/words/t08_starfish.mp3` | Starfish. | `audio/sentences/t08_starfish_s.mp3` | Look at the pretty star under the sea! |
| 30 | `t08_bee` | Con ong | `audio/words/t08_bee.mp3` | Bee. | `audio/sentences/t08_bee_s.mp3` | Buzz, buzz goes the yellow bee! |
| 31 | `t08_butterfly` | Con bướm | `audio/words/t08_butterfly.mp3` | Butterfly. | `audio/sentences/t08_butterfly_s.mp3` | The colorful butterfly flies over the flowers! |
| 32 | `t08_ladybug` | Bọ rùa | `audio/words/t08_ladybug.mp3` | Ladybug. | `audio/sentences/t08_ladybug_s.mp3` | The little red ladybug has black spots! |

#### Chủ đề 9: Fun Shapes (`t09_shapes`)
| # | `word_id` | Nghĩa TV (`vi`) | File âm thanh TỪ | Văn bản đọc (Từ) | File âm thanh CÂU | Văn bản đọc (Câu ví dụ) |
|---|---|---|---|---|---|---|
| 33 | `t09_circle` | Hình tròn | `audio/words/t09_circle.mp3` | Circle. | `audio/sentences/t09_circle_s.mp3` | A round circle, like a ball! |
| 34 | `t09_square` | Hình vuông | `audio/words/t09_square.mp3` | Square. | `audio/sentences/t09_square_s.mp3` | A square has four equal sides! |
| 35 | `t09_triangle` | Hình tam giác | `audio/words/t09_triangle.mp3` | Triangle. | `audio/sentences/t09_triangle_s.mp3` | A triangle has three corners! |
| 36 | `t09_star` | Hình ngôi sao | `audio/words/t09_star.mp3` | Star. | `audio/sentences/t09_star_s.mp3` | A bright yellow star in the sky! |
| 37 | `t09_heart` | Hình trái tim | `audio/words/t09_heart.mp3` | Heart. | `audio/sentences/t09_heart_s.mp3` | A pink heart full of love! |
| 38 | `t09_rectangle` | Hình chữ nhật | `audio/words/t09_rectangle.mp3` | Rectangle. | `audio/sentences/t09_rectangle_s.mp3` | The door is a big rectangle! |
| 39 | `t09_oval` | Hình bầu dục | `audio/words/t09_oval.mp3` | Oval. | `audio/sentences/t09_oval_s.mp3` | An egg has an oval shape! |
| 40 | `t09_diamond` | Hình thoi | `audio/words/t09_diamond.mp3` | Diamond. | `audio/sentences/t09_diamond_s.mp3` | The kite is a flying diamond! |
| 41 | `t09_rainbow` | Cầu vồng | `audio/words/t09_rainbow.mp3` | Rainbow. | `audio/sentences/t09_rainbow_s.mp3` | Look at the seven-color rainbow! |
| 42 | `t09_line` | Đường thẳng | `audio/words/t09_line.mp3` | Line. | `audio/sentences/t09_line_s.mp3` | Draw a straight line with me! |

#### Chủ đề 10: Numbers & Sizes (`t10_numbers_sizes`)
| # | `word_id` | Nghĩa TV (`vi`) | File âm thanh TỪ | Văn bản đọc (Từ) | File âm thanh CÂU | Văn bản đọc (Câu ví dụ) |
|---|---|---|---|---|---|---|
| 43 | `t10_eleven` | Số mười một (11) | `audio/words/t10_eleven.mp3` | Eleven. | `audio/sentences/t10_eleven_s.mp3` | Eleven! Eleven shiny stars! |
| 44 | `t10_twelve` | Số mười hai (12) | `audio/words/t10_twelve.mp3` | Twelve. | `audio/sentences/t10_twelve_s.mp3` | Twelve! Twelve yummy cookies! |
| 45 | `t10_fifteen` | Số mười lăm (15) | `audio/words/t10_fifteen.mp3` | Fifteen. | `audio/sentences/t10_fifteen_s.mp3` | Fifteen! Let's count to fifteen! |
| 46 | `t10_twenty` | Số hai mươi (20) | `audio/words/t10_twenty.mp3` | Twenty. | `audio/sentences/t10_twenty_s.mp3` | Twenty! Ten fingers and ten toes make twenty! |
| 47 | `t10_big` | To / Lớn | `audio/words/t10_big.mp3` | Big. | `audio/sentences/t10_big_s.mp3` | The elephant is very big! |
| 48 | `t10_small` | Nhỏ / Bé | `audio/words/t10_small.mp3` | Small. | `audio/sentences/t10_small_s.mp3` | The little mouse is so small! |
| 49 | `t10_tall` | Cao | `audio/words/t10_tall.mp3` | Tall. | `audio/sentences/t10_tall_s.mp3` | The giraffe is super tall! |
| 50 | `t10_short` | Thấp / Ngắn | `audio/words/t10_short.mp3` | Short. | `audio/sentences/t10_short_s.mp3` | The little puppy is short! |
| 51 | `t10_long` | Dài | `audio/words/t10_long.mp3` | Long. | `audio/sentences/t10_long_s.mp3` | The train is very long! |
| 52 | `t10_heavy` | Nặng | `audio/words/t10_heavy.mp3` | Heavy. | `audio/sentences/t10_heavy_s.mp3` | This big box is heavy! |

#### Chủ đề 11: Yummy Fruits (`t11_fruits`)
| # | `word_id` | Nghĩa TV (`vi`) | File âm thanh TỪ | Văn bản đọc (Từ) | File âm thanh CÂU | Văn bản đọc (Câu ví dụ) |
|---|---|---|---|---|---|---|
| 53 | `t11_apple` | Quả táo | `audio/words/t11_apple.mp3` | Apple. | `audio/sentences/t11_apple_s.mp3` | Crunch! A sweet red apple! |
| 54 | `t11_banana` | Quả chuối | `audio/words/t11_banana.mp3` | Banana. | `audio/sentences/t11_banana_s.mp3` | Momo loves yellow bananas! |
| 55 | `t11_orange` | Quả cam | `audio/words/t11_orange.mp3` | Orange. | `audio/sentences/t11_orange_s.mp3` | A juicy round orange! |
| 56 | `t11_mango` | Quả xoài | `audio/words/t11_mango.mp3` | Mango. | `audio/sentences/t11_mango_s.mp3` | Sweet yellow mango, yummy! |
| 57 | `t11_watermelon` | Quả dưa hấu | `audio/words/t11_watermelon.mp3` | Watermelon. | `audio/sentences/t11_watermelon_s.mp3` | Big green watermelon, red inside! |
| 58 | `t11_grapes` | Chùm nho | `audio/words/t11_grapes.mp3` | Grapes. | `audio/sentences/t11_grapes_s.mp3` | Purple grapes, one by one! |
| 59 | `t11_strawberry` | Quả dâu tây | `audio/words/t11_strawberry.mp3` | Strawberry. | `audio/sentences/t11_strawberry_s.mp3` | A cute little red strawberry! |
| 60 | `t11_pineapple` | Quả dứa (thơm) | `audio/words/t11_pineapple.mp3` | Pineapple. | `audio/sentences/t11_pineapple_s.mp3` | A pineapple wears a green crown! |
| 61 | `t11_peach` | Quả đào | `audio/words/t11_peach.mp3` | Peach. | `audio/sentences/t11_peach_s.mp3` | A soft pink peach! |
| 62 | `t11_coconut` | Quả dừa | `audio/words/t11_coconut.mp3` | Coconut. | `audio/sentences/t11_coconut_s.mp3` | Cool coconut water on a sunny day! |

#### Chủ đề 12: Food & Drinks (`t12_food_drinks`)
| # | `word_id` | Nghĩa TV (`vi`) | File âm thanh TỪ | Văn bản đọc (Từ) | File âm thanh CÂU | Văn bản đọc (Câu ví dụ) |
|---|---|---|---|---|---|---|
| 63 | `t12_rice` | Cơm | `audio/words/t12_rice.mp3` | Rice. | `audio/sentences/t12_rice_s.mp3` | White rice in my little bowl! |
| 64 | `t12_bread` | Bánh mì | `audio/words/t12_bread.mp3` | Bread. | `audio/sentences/t12_bread_s.mp3` | Warm bread for breakfast! |
| 65 | `t12_egg` | Quả trứng | `audio/words/t12_egg.mp3` | Egg. | `audio/sentences/t12_egg_s.mp3` | One yummy egg for you! |
| 66 | `t12_soup` | Canh / Súp | `audio/words/t12_soup.mp3` | Soup. | `audio/sentences/t12_soup_s.mp3` | Blow on the warm soup! |
| 67 | `t12_noodles` | Mì / Phở | `audio/words/t12_noodles.mp3` | Noodles. | `audio/sentences/t12_noodles_s.mp3` | Slurp, slurp! Yummy noodles! |
| 68 | `t12_pizza` | Bánh pizza | `audio/words/t12_pizza.mp3` | Pizza. | `audio/sentences/t12_pizza_s.mp3` | Let's share a slice of pizza! |
| 69 | `t12_cake` | Bánh kem | `audio/words/t12_cake.mp3` | Cake. | `audio/sentences/t12_cake_s.mp3` | A sweet strawberry cake! |
| 70 | `t12_ice_cream` | Kem | `audio/words/t12_ice_cream.mp3` | Ice cream. | `audio/sentences/t12_ice_cream_s.mp3` | Cold and sweet ice cream! |
| 71 | `t12_milk` | Sữa | `audio/words/t12_milk.mp3` | Milk. | `audio/sentences/t12_milk_s.mp3` | Drink your milk to grow tall! |
| 72 | `t12_water` | Nước lọc | `audio/words/t12_water.mp3` | Water. | `audio/sentences/t12_water_s.mp3` | Drink clean water every day! |
| 73 | `t12_juice` | Nước ép | `audio/words/t12_juice.mp3` | Juice. | `audio/sentences/t12_juice_s.mp3` | Fresh orange juice, please! |
| 74 | `t12_cookie` | Bánh quy | `audio/words/t12_cookie.mp3` | Cookie. | `audio/sentences/t12_cookie_s.mp3` | Crunchy chocolate chip cookie! |

#### Chủ đề 13: My Toys (`t13_toys`)
| # | `word_id` | Nghĩa TV (`vi`) | File âm thanh TỪ | Văn bản đọc (Từ) | File âm thanh CÂU | Văn bản đọc (Câu ví dụ) |
|---|---|---|---|---|---|---|
| 75 | `t13_ball` | Quả bóng | `audio/words/t13_ball.mp3` | Ball. | `audio/sentences/t13_ball_s.mp3` | Bounce, bounce the colorful ball! |
| 76 | `t13_doll` | Búp bê | `audio/words/t13_doll.mp3` | Doll. | `audio/sentences/t13_doll_s.mp3` | A cute little doll in a pink dress! |
| 77 | `t13_teddy_bear` | Gấu bông | `audio/words/t13_teddy_bear.mp3` | Teddy bear. | `audio/sentences/t13_teddy_bear_s.mp3` | Hug my soft brown teddy bear! |
| 78 | `t13_toy_car` | Xe đồ chơi | `audio/words/t13_toy_car.mp3` | Toy car. | `audio/sentences/t13_toy_car_s.mp3` | Zoom, zoom goes the red toy car! |
| 79 | `t13_blocks` | Khối xếp hình | `audio/words/t13_blocks.mp3` | Blocks. | `audio/sentences/t13_blocks_s.mp3` | Build a tall tower with blocks! |
| 80 | `t13_kite` | Cánh diều | `audio/words/t13_kite.mp3` | Kite. | `audio/sentences/t13_kite_s.mp3` | Fly the kite high in the sky! |
| 81 | `t13_robot` | Người máy | `audio/words/t13_robot.mp3` | Robot. | `audio/sentences/t13_robot_s.mp3` | Beep, boop! Walk like a robot! |
| 82 | `t13_balloon` | Bóng bay | `audio/words/t13_balloon.mp3` | Balloon. | `audio/sentences/t13_balloon_s.mp3` | Hold the shiny floating balloon! |
| 83 | `t13_puzzle` | Tranh ghép hình | `audio/words/t13_puzzle.mp3` | Puzzle. | `audio/sentences/t13_puzzle_s.mp3` | Put the puzzle pieces together! |
| 84 | `t13_drum` | Cái trống | `audio/words/t13_drum.mp3` | Drum. | `audio/sentences/t13_drum_s.mp3` | Boom, boom, play the little drum! |

#### Chủ đề 14: My Clothes (`t14_clothes`)
| # | `word_id` | Nghĩa TV (`vi`) | File âm thanh TỪ | Văn bản đọc (Từ) | File âm thanh CÂU | Văn bản đọc (Câu ví dụ) |
|---|---|---|---|---|---|---|
| 85 | `t14_shirt` | Áo sơ mi | `audio/words/t14_shirt.mp3` | Shirt. | `audio/sentences/t14_shirt_s.mp3` | Button up your clean shirt! |
| 86 | `t14_t_shirt` | Áo thun | `audio/words/t14_t_shirt.mp3` | T-shirt. | `audio/sentences/t14_t_shirt_s.mp3` | Momo wears a blue T-shirt! |
| 87 | `t14_pants` | Quần dài | `audio/words/t14_pants.mp3` | Pants. | `audio/sentences/t14_pants_s.mp3` | Put on your comfy pants! |
| 88 | `t14_shorts` | Quần đùi | `audio/words/t14_shorts.mp3` | Shorts. | `audio/sentences/t14_shorts_s.mp3` | Cool shorts for a sunny day! |
| 89 | `t14_dress` | Váy liền | `audio/words/t14_dress.mp3` | Dress. | `audio/sentences/t14_dress_s.mp3` | A pretty yellow dress! |
| 90 | `t14_skirt` | Chân váy | `audio/words/t14_skirt.mp3` | Skirt. | `audio/sentences/t14_skirt_s.mp3` | Spin around in a cute skirt! |
| 91 | `t14_shoes` | Đôi giày | `audio/words/t14_shoes.mp3` | Shoes. | `audio/sentences/t14_shoes_s.mp3` | Put on your shoes to go outside! |
| 92 | `t14_socks` | Đôi tất (vớ) | `audio/words/t14_socks.mp3` | Socks. | `audio/sentences/t14_socks_s.mp3` | Two warm socks for my two feet! |
| 93 | `t14_hat` | Cái mũ (nón) | `audio/words/t14_hat.mp3` | Hat. | `audio/sentences/t14_hat_s.mp3` | Wear a sun hat on your head! |
| 94 | `t14_jacket` | Áo khoác | `audio/words/t14_jacket.mp3` | Jacket. | `audio/sentences/t14_jacket_s.mp3` | Zip up your warm jacket! |

#### Chủ đề 15: My Cozy House (`t15_my_house`)
| # | `word_id` | Nghĩa TV (`vi`) | File âm thanh TỪ | Văn bản đọc (Từ) | File âm thanh CÂU | Văn bản đọc (Câu ví dụ) |
|---|---|---|---|---|---|---|
| 95 | `t15_house` | Ngôi nhà | `audio/words/t15_house.mp3` | House. | `audio/sentences/t15_house_s.mp3` | This is my cozy little house! |
| 96 | `t15_door` | Cánh cửa | `audio/words/t15_door.mp3` | Door. | `audio/sentences/t15_door_s.mp3` | Knock, knock! Open the door! |
| 97 | `t15_window` | Cửa sổ | `audio/words/t15_window.mp3` | Window. | `audio/sentences/t15_window_s.mp3` | Look out the sunny window! |
| 98 | `t15_bedroom` | Phòng ngủ | `audio/words/t15_bedroom.mp3` | Bedroom. | `audio/sentences/t15_bedroom_s.mp3` | I sleep in my quiet bedroom! |
| 99 | `t15_kitchen` | Phòng bếp | `audio/words/t15_kitchen.mp3` | Kitchen. | `audio/sentences/t15_kitchen_s.mp3` | Daddy cooks in the kitchen! |
| 100 | `t15_bathroom` | Phòng tắm | `audio/words/t15_bathroom.mp3` | Bathroom. | `audio/sentences/t15_bathroom_s.mp3` | Wash hands in the bathroom! |
| 101 | `t15_bed` | Cái giường | `audio/words/t15_bed.mp3` | Bed. | `audio/sentences/t15_bed_s.mp3` | A soft pillow on my bed! |
| 102 | `t15_table` | Cái bàn | `audio/words/t15_table.mp3` | Table. | `audio/sentences/t15_table_s.mp3` | Put the book on the table! |
| 103 | `t15_chair` | Cái ghế | `audio/words/t15_chair.mp3` | Chair. | `audio/sentences/t15_chair_s.mp3` | Sit down nicely on the chair! |
| 104 | `t15_sofa` | Ghế sô-pha | `audio/words/t15_sofa.mp3` | Sofa. | `audio/sentences/t15_sofa_s.mp3` | We read stories on the sofa! |
| 105 | `t15_lamp` | Đèn bàn | `audio/words/t15_lamp.mp3` | Lamp. | `audio/sentences/t15_lamp_s.mp3` | Turn on the bright little lamp! |
| 106 | `t15_clock` | Đồng hồ | `audio/words/t15_clock.mp3` | Clock. | `audio/sentences/t15_clock_s.mp3` | Tick-tock goes the wall clock! |

#### Chủ đề 16: My Feelings (`t16_feelings`)
| # | `word_id` | Nghĩa TV (`vi`) | File âm thanh TỪ | Văn bản đọc (Từ) | File âm thanh CÂU | Văn bản đọc (Câu ví dụ) |
|---|---|---|---|---|---|---|
| 107 | `t16_happy` | Vui vẻ | `audio/words/t16_happy.mp3` | Happy. | `audio/sentences/t16_happy_s.mp3` | I am happy! Smile big! |
| 108 | `t16_sad` | Buồn | `audio/words/t16_sad.mp3` | Sad. | `audio/sentences/t16_sad_s.mp3` | When I feel sad, I need a hug. |
| 109 | `t16_angry` | Tức giận | `audio/words/t16_angry.mp3` | Angry. | `audio/sentences/t16_angry_s.mp3` | Take a deep breath when you're angry. |
| 110 | `t16_scared` | Sợ hãi | `audio/words/t16_scared.mp3` | Scared. | `audio/sentences/t16_scared_s.mp3` | Don't be scared, Mommy is here! |
| 111 | `t16_sleepy` | Buồn ngủ | `audio/words/t16_sleepy.mp3` | Sleepy. | `audio/sentences/t16_sleepy_s.mp3` | Yawn! I am so sleepy now! |
| 112 | `t16_tired` | Mệt | `audio/words/t16_tired.mp3` | Tired. | `audio/sentences/t16_tired_s.mp3` | Let's sit and rest when we're tired. |
| 113 | `t16_hungry` | Đói bụng | `audio/words/t16_hungry.mp3` | Hungry. | `audio/sentences/t16_hungry_s.mp3` | My tummy says I'm hungry! |
| 114 | `t16_thirsty` | Khát nước | `audio/words/t16_thirsty.mp3` | Thirsty. | `audio/sentences/t16_thirsty_s.mp3` | I'm thirsty, I want some water! |
| 115 | `t16_surprised` | Ngạc nhiên | `audio/words/t16_surprised.mp3` | Surprised. | `audio/sentences/t16_surprised_s.mp3` | Wow! What a big surprise! |
| 116 | `t16_excited` | Hào hứng | `audio/words/t16_excited.mp3` | Excited. | `audio/sentences/t16_excited_s.mp3` | Hooray! I am super excited! |

#### Chủ đề 17: Let's Move! (`t17_actions`)
| # | `word_id` | Nghĩa TV (`vi`) | File âm thanh TỪ | Văn bản đọc (Từ) | File âm thanh CÂU | Văn bản đọc (Câu ví dụ) |
|---|---|---|---|---|---|---|
| 117 | `t17_run` | Chạy | `audio/words/t17_run.mp3` | Run. | `audio/sentences/t17_run_s.mp3` | Run, run fast in the park! |
| 118 | `t17_jump` | Nhảy bật lên | `audio/words/t17_jump.mp3` | Jump. | `audio/sentences/t17_jump_s.mp3` | Jump up high into the air! |
| 119 | `t17_walk` | Đi bộ | `audio/words/t17_walk.mp3` | Walk. | `audio/sentences/t17_walk_s.mp3` | Walk, walk, one step at a time! |
| 120 | `t17_dance` | Nhảy múa | `audio/words/t17_dance.mp3` | Dance. | `audio/sentences/t17_dance_s.mp3` | Dance to the happy music! |
| 121 | `t17_sing` | Ca hát | `audio/words/t17_sing.mp3` | Sing. | `audio/sentences/t17_sing_s.mp3` | La-la-la! Sing a joyful song! |
| 122 | `t17_swim` | Bơi | `audio/words/t17_swim.mp3` | Swim. | `audio/sentences/t17_swim_s.mp3` | Swim like a little fish! |
| 123 | `t17_fly` | Bay | `audio/words/t17_fly.mp3` | Fly. | `audio/sentences/t17_fly_s.mp3` | Spread your arms and fly like a bird! |
| 124 | `t17_climb` | Leo trèo | `audio/words/t17_climb.mp3` | Climb. | `audio/sentences/t17_climb_s.mp3` | Momo likes to climb the tree! |
| 125 | `t17_sit` | Ngồi | `audio/words/t17_sit.mp3` | Sit. | `audio/sentences/t17_sit_s.mp3` | Sit down gently on the mat! |
| 126 | `t17_stand` | Đứng | `audio/words/t17_stand.mp3` | Stand. | `audio/sentences/t17_stand_s.mp3` | Stand up tall and straight! |
| 127 | `t17_laugh` | Cười vang | `audio/words/t17_laugh.mp3` | Laugh. | `audio/sentences/t17_laugh_s.mp3` | Ha-ha-ha! Laugh out loud! |
| 128 | `t17_hug` | Ôm | `audio/words/t17_hug.mp3` | Hug. | `audio/sentences/t17_hug_s.mp3` | Give your friend a warm hug! |

#### Chủ đề 18: Daily Routines (`t18_routines`)
| # | `word_id` | Nghĩa TV (`vi`) | File âm thanh TỪ | Văn bản đọc (Từ) | File âm thanh CÂU | Văn bản đọc (Câu ví dụ) |
|---|---|---|---|---|---|---|
| 129 | `t18_wake_up` | Thức dậy | `audio/words/t18_wake_up.mp3` | Wake up. | `audio/sentences/t18_wake_up_s.mp3` | Good morning! Time to wake up! |
| 130 | `t18_brush_teeth` | Đánh răng | `audio/words/t18_brush_teeth.mp3` | Brush teeth. | `audio/sentences/t18_brush_teeth_s.mp3` | Brush your teeth up and down! |
| 131 | `t18_wash_face` | Rửa mặt | `audio/words/t18_wash_face.mp3` | Wash face. | `audio/sentences/t18_wash_face_s.mp3` | Splash! Wash your cute face! |
| 132 | `t18_wash_hands` | Rửa tay | `audio/words/t18_wash_hands.mp3` | Wash hands. | `audio/sentences/t18_wash_hands_s.mp3` | Wash your hands with soap and water! |
| 133 | `t18_comb_hair` | Chải tóc | `audio/words/t18_comb_hair.mp3` | Comb hair. | `audio/sentences/t18_comb_hair_s.mp3` | Comb your hair nice and neat! |
| 134 | `t18_take_a_bath` | Đi tắm | `audio/words/t18_take_a_bath.mp3` | Take a bath. | `audio/sentences/t18_take_a_bath_s.mp3` | Rub-a-dub! Take a warm bubble bath! |
| 135 | `t18_eat_breakfast` | Ăn sáng | `audio/words/t18_eat_breakfast.mp3` | Eat breakfast. | `audio/sentences/t18_eat_breakfast_s.mp3` | Eat a healthy breakfast every morning! |
| 136 | `t18_read_a_book` | Đọc sách | `audio/words/t18_read_a_book.mp3` | Read a book. | `audio/sentences/t18_read_a_book_s.mp3` | Read a storybook before bedtime! |
| 137 | `t18_go_to_bed` | Đi ngủ | `audio/words/t18_go_to_bed.mp3` | Go to bed. | `audio/sentences/t18_go_to_bed_s.mp3` | Put on pajamas and go to bed! |
| 138 | `t18_good_night` | Chúc ngủ ngon | `audio/words/t18_good_night.mp3` | Good night. | `audio/sentences/t18_good_night_s.mp3` | Good night, sweet dreams! |

#### Chủ đề 19: Mealtime Tools (`t19_tableware`)
| # | `word_id` | Nghĩa TV (`vi`) | File âm thanh TỪ | Văn bản đọc (Từ) | File âm thanh CÂU | Văn bản đọc (Câu ví dụ) |
|---|---|---|---|---|---|---|
| 139 | `t19_spoon` | Cái thìa (muỗng) | `audio/words/t19_spoon.mp3` | Spoon. | `audio/sentences/t19_spoon_s.mp3` | Eat your soup with a spoon! |
| 140 | `t19_fork` | Cái nĩa | `audio/words/t19_fork.mp3` | Fork. | `audio/sentences/t19_fork_s.mp3` | Use a fork for your fruit! |
| 141 | `t19_bowl` | Cái bát (chén) | `audio/words/t19_bowl.mp3` | Bowl. | `audio/sentences/t19_bowl_s.mp3` | A full bowl of warm rice! |
| 142 | `t19_plate` | Cái đĩa | `audio/words/t19_plate.mp3` | Plate. | `audio/sentences/t19_plate_s.mp3` | Put the sandwich on the plate! |
| 143 | `t19_cup` | Cái cốc có quai | `audio/words/t19_cup.mp3` | Cup. | `audio/sentences/t19_cup_s.mp3` | A cute yellow cup for my milk! |
| 144 | `t19_glass` | Ly thủy tinh | `audio/words/t19_glass.mp3` | Glass. | `audio/sentences/t19_glass_s.mp3` | A glass of cool water! |
| 145 | `t19_bottle` | Bình nước | `audio/words/t19_bottle.mp3` | Bottle. | `audio/sentences/t19_bottle_s.mp3` | Bring your water bottle to the park! |
| 146 | `t19_napkin` | Khăn ăn | `audio/words/t19_napkin.mp3` | Napkin. | `audio/sentences/t19_napkin_s.mp3` | Wipe your mouth with a napkin! |
| 147 | `t19_chopsticks` | Đôi đũa | `audio/words/t19_chopsticks.mp3` | Chopsticks. | `audio/sentences/t19_chopsticks_s.mp3` | Mommy and Daddy use chopsticks! |
| 148 | `t19_pot` | Cái nồi | `audio/words/t19_pot.mp3` | Pot. | `audio/sentences/t19_pot_s.mp3` | Yummy soup is cooking in the pot! |

#### Chủ đề 20: Fun Opposites (`t20_opposites`)
| # | `word_id` | Nghĩa TV (`vi`) | File âm thanh TỪ | Văn bản đọc (Từ) | File âm thanh CÂU | Văn bản đọc (Câu ví dụ) |
|---|---|---|---|---|---|---|
| 149 | `t20_hot` | Nóng | `audio/words/t20_hot.mp3` | Hot. | `audio/sentences/t20_hot_s.mp3` | The sun is hot! The soup is hot! |
| 150 | `t20_cold` | Lạnh | `audio/words/t20_cold.mp3` | Cold. | `audio/sentences/t20_cold_s.mp3` | The ice cream is cold! Brrr! |
| 151 | `t20_fast` | Nhanh | `audio/words/t20_fast.mp3` | Fast. | `audio/sentences/t20_fast_s.mp3` | The rabbit runs super fast! |
| 152 | `t20_slow` | Chậm | `audio/words/t20_slow.mp3` | Slow. | `audio/sentences/t20_slow_s.mp3` | The little turtle walks very slow! |
| 153 | `t20_up` | Lên trên | `audio/words/t20_up.mp3` | Up. | `audio/sentences/t20_up_s.mp3` | Hands up high in the sky! |
| 154 | `t20_down` | Xuống dưới | `audio/words/t20_down.mp3` | Down. | `audio/sentences/t20_down_s.mp3` | Sit down low on the floor! |
| 155 | `t20_open` | Mở ra | `audio/words/t20_open.mp3` | Open. | `audio/sentences/t20_open_s.mp3` | Open the surprise gift box! |
| 156 | `t20_close` | Đóng lại | `audio/words/t20_close.mp3` | Close. | `audio/sentences/t20_close_s.mp3` | Close your eyes and count to three! |
| 157 | `t20_clean` | Sạch sẽ | `audio/words/t20_clean.mp3` | Clean. | `audio/sentences/t20_clean_s.mp3` | My hands are shiny and clean! |
| 158 | `t20_dirty` | Bẩn / Lấm lem | `audio/words/t20_dirty.mp3` | Dirty. | `audio/sentences/t20_dirty_s.mp3` | Muddy shoes are dirty! Let's wash them! |

#### Chủ đề 21: Beep! Vehicles (`t21_vehicles`)
| # | `word_id` | Nghĩa TV (`vi`) | File âm thanh TỪ | Văn bản đọc (Từ) | File âm thanh CÂU | Văn bản đọc (Câu ví dụ) |
|---|---|---|---|---|---|---|
| 159 | `t21_car` | Xe ô tô | `audio/words/t21_car.mp3` | Car. | `audio/sentences/t21_car_s.mp3` | Beep, beep! Drive the little car! |
| 160 | `t21_bus` | Xe buýt | `audio/words/t21_bus.mp3` | Bus. | `audio/sentences/t21_bus_s.mp3` | The yellow school bus goes round and round! |
| 161 | `t21_bike` | Xe đạp | `audio/words/t21_bike.mp3` | Bike. | `audio/sentences/t21_bike_s.mp3` | Ring, ring! Ride a blue bike! |
| 162 | `t21_motorbike` | Xe máy | `audio/words/t21_motorbike.mp3` | Motorbike. | `audio/sentences/t21_motorbike_s.mp3` | Wear a helmet on the motorbike! |
| 163 | `t21_train` | Tàu hỏa | `audio/words/t21_train.mp3` | Train. | `audio/sentences/t21_train_s.mp3` | Choo, choo! Here comes the long train! |
| 164 | `t21_airplane` | Máy bay | `audio/words/t21_airplane.mp3` | Airplane. | `audio/sentences/t21_airplane_s.mp3` | Whoosh! The airplane flies above the clouds! |
| 165 | `t21_helicopter` | Trực thăng | `audio/words/t21_helicopter.mp3` | Helicopter. | `audio/sentences/t21_helicopter_s.mp3` | The helicopter spins up in the sky! |
| 166 | `t21_boat` | Thuyền nhỏ | `audio/words/t21_boat.mp3` | Boat. | `audio/sentences/t21_boat_s.mp3` | Row, row the little wooden boat! |
| 167 | `t21_ship` | Tàu thủy lớn | `audio/words/t21_ship.mp3` | Ship. | `audio/sentences/t21_ship_s.mp3` | The big ship sails across the ocean! |
| 168 | `t21_truck` | Xe tải | `audio/words/t21_truck.mp3` | Truck. | `audio/sentences/t21_truck_s.mp3` | The strong truck carries big boxes! |
| 169 | `t21_fire_truck` | Xe cứu hỏa | `audio/words/t21_fire_truck.mp3` | Fire truck. | `audio/sentences/t21_fire_truck_s.mp3` | Wee-oo! The red fire truck is coming! |
| 170 | `t21_police_car` | Xe cảnh sát | `audio/words/t21_police_car.mp3` | Police car. | `audio/sentences/t21_police_car_s.mp3` | The police car helps keep us safe! |

#### Chủ đề 22: Weather & Nature (`t22_weather_nature`)
| # | `word_id` | Nghĩa TV (`vi`) | File âm thanh TỪ | Văn bản đọc (Từ) | File âm thanh CÂU | Văn bản đọc (Câu ví dụ) |
|---|---|---|---|---|---|---|
| 171 | `t22_sun` | Mặt trời | `audio/words/t22_sun.mp3` | Sun. | `audio/sentences/t22_sun_s.mp3` | The bright yellow sun shines in the sky! |
| 172 | `t22_moon` | Mặt trăng | `audio/words/t22_moon.mp3` | Moon. | `audio/sentences/t22_moon_s.mp3` | The gentle moon glows at night! |
| 173 | `t22_cloud` | Đám mây | `audio/words/t22_cloud.mp3` | Cloud. | `audio/sentences/t22_cloud_s.mp3` | Fluffy white clouds float by! |
| 174 | `t22_rain` | Cơn mưa | `audio/words/t22_rain.mp3` | Rain. | `audio/sentences/t22_rain_s.mp3` | Pitter-patter falls the rain! |
| 175 | `t22_wind` | Cơn gió | `audio/words/t22_wind.mp3` | Wind. | `audio/sentences/t22_wind_s.mp3` | Whoosh! The wind blows the leaves! |
| 176 | `t22_snow` | Tuyết | `audio/words/t22_snow.mp3` | Snow. | `audio/sentences/t22_snow_s.mp3` | Soft white snow falls down! |
| 177 | `t22_tree` | Cái cây | `audio/words/t22_tree.mp3` | Tree. | `audio/sentences/t22_tree_s.mp3` | A tall green tree with many leaves! |
| 178 | `t22_flower` | Bông hoa | `audio/words/t22_flower.mp3` | Flower. | `audio/sentences/t22_flower_s.mp3` | Smell the pretty blooming flower! |
| 179 | `t22_grass` | Thảm cỏ | `audio/words/t22_grass.mp3` | Grass. | `audio/sentences/t22_grass_s.mp3` | Soft green grass under my feet! |
| 180 | `t22_sunny` | Trời nắng | `audio/words/t22_sunny.mp3` | Sunny. | `audio/sentences/t22_sunny_s.mp3` | It's a sunny day! Let's play outside! |
| 181 | `t22_rainy` | Trời mưa | `audio/words/t22_rainy.mp3` | Rainy. | `audio/sentences/t22_rainy_s.mp3` | It's rainy! Open your umbrella! |
| 182 | `t22_windy` | Trời gió | `audio/words/t22_windy.mp3` | Windy. | `audio/sentences/t22_windy_s.mp3` | It's windy! Great for flying a kite! |

#### Chủ đề 23: My Preschool (`t23_school`)
| # | `word_id` | Nghĩa TV (`vi`) | File âm thanh TỪ | Văn bản đọc (Từ) | File âm thanh CÂU | Văn bản đọc (Câu ví dụ) |
|---|---|---|---|---|---|---|
| 183 | `t23_school` | Trường học | `audio/words/t23_school.mp3` | School. | `audio/sentences/t23_school_s.mp3` | I love going to my happy school! |
| 184 | `t23_teacher` | Cô giáo | `audio/words/t23_teacher.mp3` | Teacher. | `audio/sentences/t23_teacher_s.mp3` | My teacher is kind and sweet! |
| 185 | `t23_classroom` | Lớp học | `audio/words/t23_classroom.mp3` | Classroom. | `audio/sentences/t23_classroom_s.mp3` | We sing and play in our classroom! |
| 186 | `t23_book` | Quyển sách | `audio/words/t23_book.mp3` | Book. | `audio/sentences/t23_book_s.mp3` | Open the picture book and read! |
| 187 | `t23_crayon` | Bút sáp màu | `audio/words/t23_crayon.mp3` | Crayon. | `audio/sentences/t23_crayon_s.mp3` | Color the picture with a red crayon! |
| 188 | `t23_pencil` | Bút chì | `audio/words/t23_pencil.mp3` | Pencil. | `audio/sentences/t23_pencil_s.mp3` | Draw a circle with a pencil! |
| 189 | `t23_paper` | Tờ giấy | `audio/words/t23_paper.mp3` | Paper. | `audio/sentences/t23_paper_s.mp3` | A clean sheet of white paper! |
| 190 | `t23_bag` | Cặp sách (Ba lô) | `audio/words/t23_bag.mp3` | Bag. | `audio/sentences/t23_bag_s.mp3` | Put your book inside your school bag! |
| 191 | `t23_scissors` | Cái kéo | `audio/words/t23_scissors.mp3` | Scissors. | `audio/sentences/t23_scissors_s.mp3` | Cut the paper carefully with safety scissors! |
| 192 | `t23_playground` | Sân chơi | `audio/words/t23_playground.mp3` | Playground. | `audio/sentences/t23_playground_s.mp3` | Slide and swing at the playground! |

#### Chủ đề 24: Cool Jobs (`t24_jobs`)
| # | `word_id` | Nghĩa TV (`vi`) | File âm thanh TỪ | Văn bản đọc (Từ) | File âm thanh CÂU | Văn bản đọc (Câu ví dụ) |
|---|---|---|---|---|---|---|
| 193 | `t24_doctor` | Bác sĩ | `audio/words/t24_doctor.mp3` | Doctor. | `audio/sentences/t24_doctor_s.mp3` | The kind doctor helps me feel better! |
| 194 | `t24_nurse` | Y tá | `audio/words/t24_nurse.mp3` | Nurse. | `audio/sentences/t24_nurse_s.mp3` | The caring nurse gives me a sticker! |
| 195 | `t24_firefighter` | Lính cứu hỏa | `audio/words/t24_firefighter.mp3` | Firefighter. | `audio/sentences/t24_firefighter_s.mp3` | The brave firefighter puts out the fire! |
| 196 | `t24_police_officer` | Cảnh sát | `audio/words/t24_police_officer.mp3` | Police officer. | `audio/sentences/t24_police_officer_s.mp3` | The police officer helps people on the street! |
| 197 | `t24_chef` | Đầu bếp | `audio/words/t24_chef.mp3` | Chef. | `audio/sentences/t24_chef_s.mp3` | The chef wears a tall white hat and cooks yummy food! |
| 198 | `t24_farmer` | Nông dân | `audio/words/t24_farmer.mp3` | Farmer. | `audio/sentences/t24_farmer_s.mp3` | The farmer grows fresh fruit and vegetables! |
| 199 | `t24_driver` | Tài xế | `audio/words/t24_driver.mp3` | Driver. | `audio/sentences/t24_driver_s.mp3` | The bus driver drives us safely! |
| 200 | `t24_builder` | Thợ xây | `audio/words/t24_builder.mp3` | Builder. | `audio/sentences/t24_builder_s.mp3` | The builder wears a yellow helmet and builds houses! |
| 201 | `t24_singer` | Ca sĩ | `audio/words/t24_singer.mp3` | Singer. | `audio/sentences/t24_singer_s.mp3` | The singer holds a mic and sings on stage! |
| 202 | `t24_astronaut` | Phi hành gia | `audio/words/t24_astronaut.mp3` | Astronaut. | `audio/sentences/t24_astronaut_s.mp3` | The astronaut flies a rocket to the stars! |

#### Chủ đề 25: Party & Holidays (`t25_party_holidays`)
| # | `word_id` | Nghĩa TV (`vi`) | File âm thanh TỪ | Văn bản đọc (Từ) | File âm thanh CÂU | Văn bản đọc (Câu ví dụ) |
|---|---|---|---|---|---|---|
| 203 | `t25_birthday` | Sinh nhật | `audio/words/t25_birthday.mp3` | Birthday. | `audio/sentences/t25_birthday_s.mp3` | Happy birthday to you! |
| 204 | `t25_gift` | Hộp quà | `audio/words/t25_gift.mp3` | Gift. | `audio/sentences/t25_gift_s.mp3` | A colorful gift with a big ribbon! |
| 205 | `t25_candle` | Ngọn nến | `audio/words/t25_candle.mp3` | Candle. | `audio/sentences/t25_candle_s.mp3` | Blow out the birthday candles! Whoosh! |
| 206 | `t25_party_hat` | Mũ sinh nhật | `audio/words/t25_party_hat.mp3` | Party hat. | `audio/sentences/t25_party_hat_s.mp3` | Wear a sparkly party hat! |
| 207 | `t25_crown` | Vương miện | `audio/words/t25_crown.mp3` | Crown. | `audio/sentences/t25_crown_s.mp3` | A shiny golden crown for the birthday star! |
| 208 | `t25_music` | Âm nhạc | `audio/words/t25_music.mp3` | Music. | `audio/sentences/t25_music_s.mp3` | Clap and dance to the party music! |
| 209 | `t25_fireworks` | Pháo hoa | `audio/words/t25_fireworks.mp3` | Fireworks. | `audio/sentences/t25_fireworks_s.mp3` | Boom, sparkle! Bright fireworks in the night sky! |
| 210 | `t25_lantern` | Đèn lồng | `audio/words/t25_lantern.mp3` | Lantern. | `audio/sentences/t25_lantern_s.mp3` | A glowing red lantern for the festival! |
| 211 | `t25_wish` | Điều ước | `audio/words/t25_wish.mp3` | Wish. | `audio/sentences/t25_wish_s.mp3` | Close your eyes and make a happy wish! |
| 212 | `t25_celebrate` | Ăn mừng | `audio/words/t25_celebrate.mp3` | Celebrate. | `audio/sentences/t25_celebrate_s.mp3` | Hooray! Let's celebrate together! |

---

### B2. Giọng đọc Mẫu câu giao tiếp Phụ huynh – 20 Chủ đề (`t06` → `t25`) (40 file)

| # | Chủ đề | `sentence_id` | Đường dẫn file | Văn bản đọc (en-US) | Nghĩa Tiếng Việt (`vi`) | Phiên âm Phụ huynh (`pron_vi`) |
|---|---|---|---|---|---|---|
| 1 | `t06` | `p_who_is_this` | `audio/sentences/p_who_is_this.mp3` | Who is this? This is my grandma! | Ai đây nhỉ? Đây là bà của con! | Hu i-zơ đít? Đít i-zơ mai gờ-ren-ma! |
| 2 | `t06` | `p_love_family` | `audio/sentences/p_love_family.mp3` | I love my family very much! | Con yêu gia đình mình nhiều lắm! | Ai lấp mai pha-mi-li ve-ri mắt-chờ! |
| 3 | `t07` | `p_go_to_zoo` | `audio/sentences/p_go_to_zoo.mp3` | Let's go to the zoo! | Mình cùng đi sở thú nào! | Lét-xơ gâu tu đờ du! |
| 4 | `t07` | `p_big_elephant` | `audio/sentences/p_big_elephant.mp3` | Look at the big elephant! | Nhìn chú voi to chưa kìa! | Lúc ét đờ bíc e-li-phần! |
| 5 | `t08` | `p_in_the_ocean` | `audio/sentences/p_in_the_ocean.mp3` | What lives in the ocean? | Con gì sống ở dưới biển nhỉ? | Quát líp-xơ in đờ âu-sần? |
| 6 | `t08` | `p_pretty_butterfly` | `audio/sentences/p_pretty_butterfly.mp3` | Look! A pretty butterfly! | Nhìn kìa! Một chú bướm xinh đẹp! | Lúc! Ờ pờ-rít-ti bắt-tơ-phờ-lai! |
| 7 | `t09` | `p_what_shape` | `audio/sentences/p_what_shape.mp3` | What shape is it? It's a circle! | Hình gì đây con? Hình tròn đấy! | Quát sếp i-zơ ít? Ít-xơ ờ xơ-cồ! |
| 8 | `t09` | `p_yellow_star` | `audio/sentences/p_yellow_star.mp3` | Look at the bright yellow star! | Nhìn ngôi sao màu vàng sáng kìa! | Lúc ét đờ bờ-rai die-lâu xờ-ta! |
| 9 | `t10` | `p_big_or_small` | `audio/sentences/p_big_or_small.mp3` | Is it big or small? It's big! | Nó to hay nhỏ nhỉ? Nó to lắm! | I-zơ ít bíc o xờ-mô? Ít-xơ bíc! |
| 10 | `t10` | `p_count_twenty` | `audio/sentences/p_count_twenty.mp3` | Let's count to twenty together! | Cùng đếm đến hai mươi nào! | Lét-xơ cao-tờ tu troen-ti tu-ge-đờ! |
| 11 | `t11` | `p_like_apples` | `audio/sentences/p_like_apples.mp3` | Do you like apples? Yes, I do! | Con có thích táo không? Dạ có ạ! | Đu diu lai áp-pồ-xơ? Diét, ai đu! |
| 12 | `t11` | `p_eat_fruit` | `audio/sentences/p_eat_fruit.mp3` | Eat your fruit! It's yummy! | Ăn hoa quả nào con! Ngon lắm đấy! | Ít gio phờ-rút! Ít-xơ dăm-mi! |
| 13 | `t12` | `p_hungry_thirsty` | `audio/sentences/p_hungry_thirsty.mp3` | I'm hungry! I'm thirsty! | Con đói bụng! Con khát nước! | Ai-mơ hăng-gờ-ri! Ai-mơ thơ-xờ-ti! |
| 14 | `t12` | `p_have_some_milk` | `audio/sentences/p_have_some_milk.mp3` | Can I have some milk, please? | Cho con xin một ít sữa ạ! | Ken ai hép xăm miu-kờ, pờ-li-zơ? |
| 15 | `t13` | `p_play_with_ball` | `audio/sentences/p_play_with_ball.mp3` | Let's play with the ball! | Mình cùng chơi bóng nhé! | Lét-xơ pờ-lây quít đờ bô! |
| 16 | `t13` | `p_share_toys` | `audio/sentences/p_share_toys.mp3` | Let's share our toys! Clean up, please! | Mình cùng chia sẻ và dọn đồ chơi nhé! | Lét-xơ se ao-ờ toi-zơ! Cờ-lin ắp, pờ-li-zơ! |
| 17 | `t14` | `p_put_on_shoes` | `audio/sentences/p_put_on_shoes.mp3` | Put on your shoes, please! | Con đi giày vào nhé! | Pút on gio su-zơ, pờ-li-zơ! |
| 18 | `t14` | `p_take_off_hat` | `audio/sentences/p_take_off_hat.mp3` | Take off your hat and jacket! | Cởi mũ và áo khoác ra nào con! | Tếch óp gio hét en chéc-kịt! |
| 19 | `t15` | `p_open_door` | `audio/sentences/p_open_door.mp3` | Open the door, please! Close the door! | Mở cửa giúp mẹ nhé! Đóng cửa lại nào! | Âu-pần đờ đo, pờ-li-zơ! Cờ-lâu-zơ đờ đo! |
| 20 | `t15` | `p_where_is_cat` | `audio/sentences/p_where_is_cat.mp3` | Where is the cat? Under the table! | Con mèo đâu rồi? Ở dưới gầm bàn kìa! | Que i-zơ đờ két? Ăn-đờ đờ tây-bồ! |
| 21 | `t16` | `p_how_do_you_feel` | `audio/sentences/p_how_do_you_feel.mp3` | How do you feel today? I'm happy! | Hôm nay con thấy thế nào? Con rất vui! | Hao đu diu phiu tu-đây? Ai-mơ hép-pi! |
| 22 | `t16` | `p_dont_be_scared` | `audio/sentences/p_dont_be_scared.mp3` | Don't be scared! Mommy is here! | Đừng sợ nhé! Có mẹ ở đây rồi! | Đôn-tờ bi xờ-ke-đờ! Măm-mi i-zơ hia! |
| 23 | `t17` | `p_can_you_jump` | `audio/sentences/p_can_you_jump.mp3` | Can you jump high? Yes, I can! | Con nhảy cao được không? Dạ được ạ! | Ken diu chăm-pờ hai? Diét, ai ken! |
| 24 | `t17` | `p_stand_and_sit` | `audio/sentences/p_stand_and_sit.mp3` | Stand up, please! Sit down, please! | Đứng lên nào! Ngồi xuống nào! | Xờ-ten ắp, pờ-li-zơ! Xít đao, pờ-li-zơ! |
| 25 | `t18` | `p_time_to_brush` | `audio/sentences/p_time_to_brush.mp3` | Good morning! Time to brush your teeth! | Chào buổi sáng! Đến giờ đánh răng rồi! | Gút mo-ninh! Tham tu bơ-rắt-sờ gio tít! |
| 26 | `t18` | `p_good_night_sleep` | `audio/sentences/p_good_night_sleep.mp3` | Time to go to bed! Good night! | Đến giờ đi ngủ rồi! Chúc con ngủ ngon! | Tham tu gâu tu bét! Gút nai! |
| 27 | `t19` | `p_pass_the_spoon` | `audio/sentences/p_pass_the_spoon.mp3` | Pass me the spoon, please! | Đưa giúp mẹ cái thìa nhé con! | Pát-xơ mi đờ xờ-pun, pờ-li-zơ! |
| 28 | `t19` | `p_hold_your_cup` | `audio/sentences/p_hold_your_cup.mp3` | Hold your cup with two hands! | Con cầm cốc bằng cả hai tay nhé! | Hâu gio cắp quít tu hen-zơ! |
| 29 | `t20` | `p_careful_hot` | `audio/sentences/p_careful_hot.mp3` | Be careful! The soup is hot! | Cẩn thận nhé con! Canh còn nóng đấy! | Bi ke-phồ! Đờ xúp i-zơ hót! |
| 30 | `t20` | `p_fast_and_slow` | `audio/sentences/p_fast_and_slow.mp3` | Go fast! Now go slow! | Đi nhanh nào! Giờ đi chậm thôi! | Gâu phát-xờ! Nao gâu xờ-lâu! |
| 31 | `t21` | `p_look_fire_truck` | `audio/sentences/p_look_fire_truck.mp3` | Look! A big red fire truck! | Nhìn kìa! Xe cứu hỏa màu đỏ to chưa! | Lúc! Ờ bíc rét phai-ờ trắc! |
| 32 | `t21` | `p_red_light_stop` | `audio/sentences/p_red_light_stop.mp3` | Red light, stop! Green light, go! | Đèn đỏ dừng lại! Đèn xanh đi thôi! | Rét lai, xờ-tóp! Gờ-rin lai, gâu! |
| 33 | `t22` | `p_hows_weather` | `audio/sentences/p_hows_weather.mp3` | How's the weather today? It's sunny! | Thời tiết hôm nay thế nào? Trời nắng đẹp! | Hao-zơ đờ que-đờ tu-đây? Ít-xơ xăn-ni! |
| 34 | `t22` | `p_its_raining` | `audio/sentences/p_its_raining.mp3` | It's rainy today! Bring an umbrella! | Hôm nay trời mưa! Nhớ mang ô nhé! | Ít-xơ rên-ni tu-đây! Bờ-rinh ần ăm-bờ-re-la! |
| 35 | `t23` | `p_ready_for_school` | `audio/sentences/p_ready_for_school.mp3` | Are you ready for school? Pack your bag! | Con sẵn sàng đi học chưa? Cất đồ vào cặp nào! | A diu re-đi pho xờ-cun? Péc gio béc! |
| 36 | `t23` | `p_listen_teacher` | `audio/sentences/p_listen_teacher.mp3` | Listen to your teacher at school! | Ở trường con nhớ nghe lời cô giáo nhé! | Lít-sần tu gio tít-chờ ét xờ-cun! |
| 37 | `t24` | `p_want_to_be` | `audio/sentences/p_want_to_be.mp3` | What do you want to be? A doctor! | Lớn lên con muốn làm nghề gì? Bác sĩ ạ! | Quát đu diu quăn tu bi? Ờ đóc-tơ! |
| 38 | `t24` | `p_brave_firefighter` | `audio/sentences/p_brave_firefighter.mp3` | The firefighter is very brave! | Chú lính cứu hỏa thật dũng cảm! | Đờ phai-ờ-phai-tơ i-zơ ve-ri bờ-rây-vờ! |
| 39 | `t25` | `p_happy_birthday` | `audio/sentences/p_happy_birthday.mp3` | Happy birthday! Make a wish! | Chúc mừng sinh nhật! Ước một điều ước nào! | Hép-pi bớt-đây! Mếch ờ quýt-sờ! |
| 40 | `t25` | `p_thank_for_gift` | `audio/sentences/p_thank_for_gift.mp3` | Thank you for the lovely gift! | Con cảm ơn vì món quà đáng yêu ạ! | Thanh kiu pho đờ lấp-li gíp-tờ! |

---

### B3. Giọng Mascot Momo cho 12 lệnh TPR mở rộng (`audio/instructions/cmd_*.mp3`)

| # | `command_id` | Đường dẫn file | Văn bản đọc (en-US) | Nghĩa Tiếng Việt (`viText`) |
|---|---|---|---|---|
| 1 | `cmd_give_hug` | `audio/instructions/cmd_give_hug.mp3` | Give yourself a big warm hug! | Hãy tự ôm mình một cái thật ấm áp nào! |
| 2 | `cmd_roar_lion` | `audio/instructions/cmd_roar_lion.mp3` | Roar like a brave little lion! Roar! | Hãy gầm vang như chú sư tử dũng cảm nào! |
| 3 | `cmd_draw_circle` | `audio/instructions/cmd_draw_circle.mp3` | Draw a big round circle in the air! | Hãy vẽ một vòng tròn thật to trong không trung nào! |
| 4 | `cmd_reach_tall` | `audio/instructions/cmd_reach_tall.mp3` | Stretch up tall like a giraffe! | Hãy vươn người cao lên như chú hươu cao cổ nào! |
| 5 | `cmd_rub_tummy` | `audio/instructions/cmd_rub_tummy.mp3` | Rub your yummy tummy! Yummy, yummy! | Hãy xoa bụng ngon miệng nào! |
| 6 | `cmd_walk_robot` | `audio/instructions/cmd_walk_robot.mp3` | Walk like a funny robot! Beep, boop! | Hãy đi như một chú người máy vui nhộn nào! |
| 7 | `cmd_put_on_hat` | `audio/instructions/cmd_put_on_hat.mp3` | Put a cool hat on your head! | Hãy làm động tác đội mũ lên đầu nào! |
| 8 | `cmd_knock_door` | `audio/instructions/cmd_knock_door.mp3` | Knock on the door! Knock, knock, knock! | Hãy gõ cửa nào! Cốc, cốc, cốc! |
| 9 | `cmd_smile_happy` | `audio/instructions/cmd_smile_happy.mp3` | Show me your biggest happy smile! | Hãy cười thật tươi cho Momo xem nào! |
| 10 | `cmd_dance_spin` | `audio/instructions/cmd_dance_spin.mp3` | Spin around and dance with me! | Hãy xoay một vòng và nhảy múa cùng Momo nào! |
| 11 | `cmd_brush_teeth` | `audio/instructions/cmd_brush_teeth.mp3` | Brush your teeth! Up and down! | Hãy làm động tác đánh răng lên xuống nào! |
| 12 | `cmd_drive_car` | `audio/instructions/cmd_drive_car.mp3` | Drive your little car! Beep, beep! | Hãy cầm vô lăng lái xe ô tô nào! Bim, bim! |

---

### B4. Bài hát chủ đề – 20 bài Original Suno AI Lyrics (`s06` → `s25`) (20 file)
> **Lưu ý chống bản quyền Suno AI:** Toàn bộ 20 bài hát dưới đây đều được **sáng tác lời mới 100% (Original Lyrics)** gắn với nhân vật Momo và từ vựng của từng bài, hoàn toàn không chứa bất kỳ câu hát thương mại có bản quyền nào. Bạn chỉ cần copy `Music Prompt` vào ô **Style of Music** và `Lyrics` vào ô **Lyrics** trên **Suno AI**, sau đó dùng skill `integrate-song` để tích hợp file MP3 vào ứng dụng.

#### 6. `audio/songs/s06_family_song.mp3` (Chủ đề 6: My Big Family)
- **Title:** `Momo's Happy Family Tree`
- **Music Prompt:** `Warm cheerful preschool family song, acoustic guitar, ukulele, glockenspiel, gentle handclaps, loving female American vocal, 100 BPM`
- **Lyrics:**
  ```text
  Welcome to my happy home,
  Full of love wherever we roam!
  Grandma, Grandpa smile so bright,
  Mommy, Daddy hold me tight!
  Brother, Sister, play with me,
  Uncle, Aunt, and Cousin, see!
  One big family under the sun,
  I love you all, everyone!
  ```

#### 7. `audio/songs/s07_zoo_song.mp3` (Chủ đề 7: Zoo Animals)
- **Title:** `Welcome to Momo's Jungle Zoo`
- **Music Prompt:** `Playful safari adventure kids song, bouncy marimba, wooden percussion, upbeat acoustic guitar, cheerful female vocal en-US, 104 BPM`
- **Lyrics:**
  ```text
  Let's go walking to the zoo,
  Momo wants to go with you!
  Lion roars and Tiger leaps,
  Big gray Elephant stomps his feet!
  Tall Giraffe and Zebra run,
  Bear and Panda having fun!
  Hippo, Crocodile, Kangaroo,
  We love animals at the zoo!
  ```

#### 8. `audio/songs/s08_ocean_song.mp3` (Chủ đề 8: Ocean & Bugs)
- **Title:** `Deep Down in the Sparkly Sea`
- **Music Prompt:** `Breezy tropical children's song, steel drum, ukulele, xylophone, playful splashes, clear warm female vocal en-US, 100 BPM`
- **Lyrics:**
  ```text
  Deep down in the sparkly sea,
  Who is swimming next to me?
  Dolphin jumps and blue Whale sings,
  Shark and Turtle flap their fins!
  Octopus waves eight arms high,
  Crab and Starfish say hi-hi!
  Up above, the Bee goes buzz,
  Butterfly and Ladybug dance with us!
  ```

#### 9. `audio/songs/s09_shapes_song.mp3` (Chủ đề 9: Fun Shapes)
- **Title:** `Shapes All Around Us`
- **Music Prompt:** `Bouncy educational preschool song, bright piano, pizzicato strings, glockenspiel, clear rhythmic female vocal en-US, 100 BPM`
- **Lyrics:**
  ```text
  Circle, Square, and Triangle too,
  Shapes are waiting here for you!
  Round like a ball is a Circle bright,
  Four even sides make a Square just right!
  Star in the sky and a pink Heart sweet,
  Rectangle, Oval, and Diamond meet!
  Draw a straight Line and a Rainbow high,
  Shapes all around under the sky!
  ```

#### 10. `audio/songs/s10_sizes_song.mp3` (Chủ đề 10: Numbers & Sizes)
- **Title:** `Big and Small, Count Them All`
- **Music Prompt:** `Fun counting and opposites song for toddlers, playful tuba, xylophone, ukulele, handclaps, clear slow female vocal en-US, 98 BPM`
- **Lyrics:**
  ```text
  Eleven, twelve, and fifteen stars,
  Count to twenty, near and far!
  Some are big and some are small,
  Some are short and some are tall!
  Elephant is big and heavy too,
  Little mouse is small and new!
  Long choo-choo train rolls down the track,
  Count to twenty forward and back!
  ```

#### 11. `audio/songs/s11_fruits_song.mp3` (Chủ đề 11: Yummy Fruits)
- **Title:** `Yummy Fruit Salad Dance`
- **Music Prompt:** `Upbeat tropical kids dance song, acoustic ukulele, marimba, shaker, cheerful female American vocal, 104 BPM`
- **Lyrics:**
  ```text
  Red sweet Apple, crunch, crunch, crunch!
  Yellow Banana for our lunch!
  Juicy Orange and Mango sweet,
  Big Watermelon is a treat!
  Purple Grapes and Strawberry red,
  Pineapple wears a crown on its head!
  Soft pink Peach and Coconut cool,
  Yummy fruit makes us strong for school!
  ```

#### 12. `audio/songs/s12_food_song.mp3` (Chủ đề 12: Food & Drinks)
- **Title:** `Hungry Tummy, Yummy Food`
- **Music Prompt:** `Happy mealtime nursery song, bouncy piano, acoustic bass, woodblocks, warm friendly female vocal en-US, 100 BPM`
- **Lyrics:**
  ```text
  Rub your tummy, it's time to eat,
  Healthy food is such a treat!
  White warm Rice and golden Bread,
  Egg and Soup just like Mom said!
  Yummy Noodles, Pizza slice,
  Milk and Water, cool and nice!
  Orange Juice and Cake and Cookie too,
  Thank you for the food we chew!
  ```

#### 13. `audio/songs/s13_toys_song.mp3` (Chủ đề 13: My Toys)
- **Title:** `The Magic Toy Box`
- **Music Prompt:** `Magical playful toyroom song for kids, music box glockenspiel, bouncy ukulele, toy drum beats, clear female vocal en-US, 102 BPM`
- **Lyrics:**
  ```text
  Open up the magic toy box wide,
  Look at all the fun inside!
  Bounce the Ball and hug the Doll,
  Soft Teddy Bear and Blocks so tall!
  Red Toy Car goes zoom, zoom, zoom,
  Robot marches across the room!
  Kite, Balloon, Puzzle, and Drum,
  Let's share our toys, everyone!
  ```

#### 14. `audio/songs/s14_clothes_song.mp3` (Chủ đề 14: My Clothes)
- **Title:** `Get Dressed with Momo`
- **Music Prompt:** `Morning upbeat preschool action song, acoustic guitar, whistling, handclaps, bright piano, clear female vocal en-US, 102 BPM`
- **Lyrics:**
  ```text
  Good morning, friend! Let's get dressed today,
  Put on our clothes and go out to play!
  Put on your T-shirt, Shirt, and Pants,
  Dress, Skirt, or Shorts for a happy dance!
  Two warm Socks and two fast Shoes,
  Which bright color will you choose?
  Zip your Jacket, wear your Hat,
  We are ready just like that!
  ```

#### 15. `audio/songs/s15_house_song.mp3` (Chủ đề 15: My Cozy House)
- **Title:** `Welcome to My Cozy House`
- **Music Prompt:** `Cozy warm children's sing-along song, gentle acoustic guitar, celesta, upright bass, friendly female vocal en-US, 98 BPM`
- **Lyrics:**
  ```text
  Knock, knock, knock on the wooden Door,
  Step inside on the cozy floor!
  Look out the Window, sunny and bright,
  Turn on the Lamp for a warm soft light!
  Table and Chair in the Kitchen neat,
  Sofa to rest our little feet!
  Clean in the Bathroom, Clock on the wall,
  Soft Bed in the Bedroom, good night all!
  ```

#### 16. `audio/songs/s16_feelings_song.mp3` (Chủ đề 16: My Feelings)
- **Title:** `Happy Faces, Many Feelings`
- **Music Prompt:** `Expressive gentle preschool song, warm piano, ukulele, soft strings, caring female American vocal, 98 BPM`
- **Lyrics:**
  ```text
  How do you feel inside today?
  Every feeling is okay!
  When I am Happy, I smile wide,
  When I am Sad, Mom's by my side!
  Angry or Scared, take a breath so deep,
  Tired and Sleepy, ready to sleep!
  Hungry or Thirsty, Surprised, Excited too,
  Momo is always here with you!
  ```

#### 17. `audio/songs/s17_actions_song.mp3` (Chủ đề 17: Let's Move!)
- **Title:** `Move and Freeze with Momo`
- **Music Prompt:** `Energetic preschool TPR action dance song, funky acoustic guitar, upbeat drums, xylophone, handclaps, excited female vocal en-US, 108 BPM`
- **Lyrics:**
  ```text
  Stand up tall and walk with me,
  Run and jump, one, two, three!
  Dance to the music, sing out loud,
  Laugh together, happy and proud!
  Swim like a fish in the water blue,
  Fly like a bird and climb up too!
  Give a warm hug, then sit right down,
  We are the happiest kids in town!
  ```

#### 18. `audio/songs/s18_routines_song.mp3` (Chủ đề 18: Daily Routines)
- **Title:** `Every Morning, Every Night`
- **Music Prompt:** `Cheerful daily routine nursery song, bright marimba, acoustic guitar, gentle bells, clear female vocal en-US, 100 BPM`
- **Lyrics:**
  ```text
  Wake up smiling with the morning sun,
  A brand new day has just begun!
  Brush your teeth and wash your face,
  Comb your hair neatly in place!
  Wash your hands before we eat,
  Healthy breakfast, warm and sweet!
  Take a bath and read a book,
  Go to bed, good night, sweet dreams!
  ```

#### 19. `audio/songs/s19_tableware_song.mp3` (Chủ đề 19: Mealtime Tools)
- **Title:** `Set the Table, One Two Three`
- **Music Prompt:** `Playful rhythmic kitchen song for toddlers, wooden percussion, pizzicato strings, piano, clear female vocal en-US, 100 BPM`
- **Lyrics:**
  ```text
  Let's set the table, one, two, three,
  Dinner is ready for you and me!
  Put down the Plate and the little Bowl,
  Spoon and Fork on the table roll!
  Chopsticks ready, Napkin neat,
  Yummy soup in the Pot so sweet!
  Water in the Bottle, Glass, and Cup,
  Sit down nicely and eat it up!
  ```

#### 20. `audio/songs/s20_opposites_song.mp3` (Chủ đề 20: Fun Opposites)
- **Title:** `Hot and Cold, Up and Down`
- **Music Prompt:** `Bouncy playful contrasts song for preschoolers, accordion, ukulele, xylophone, slide whistle, clear female vocal en-US, 102 BPM`
- **Lyrics:**
  ```text
  Soup is hot and ice cream is cold,
  Fun little opposites to behold!
  Rabbit is fast and turtle is slow,
  Ready, steady, off they go!
  Reach up high and bend down low,
  Open the box and close it so!
  Wash dirty hands till they're shiny clean,
  Best little helpers you have ever seen!
  ```

#### 21. `audio/songs/s21_vehicles_song.mp3` (Chủ đề 21: Beep! Vehicles)
- **Title:** `Zoom, Beep, Choo-Choo Go!`
- **Music Prompt:** `Upbeat transportation song for kids, acoustic guitar, brass horn accents, train whistle, cheerful female vocal en-US, 105 BPM`
- **Lyrics:**
  ```text
  Beep goes the Car and the yellow Bus,
  Ring goes the Bike as it rides with us!
  Motorbike rolls and the big Truck hauls,
  Fire Truck and Police Car answer the calls!
  Choo-choo Train on the long steel track,
  Boat and big Ship sail out and back!
  Airplane and Helicopter high in the sky,
  Wave to Momo as we fly by!
  ```

#### 22. `audio/songs/s22_weather_song.mp3` (Chủ đề 22: Weather & Nature)
- **Title:** `Sunny Sky or Rainy Day`
- **Music Prompt:** `Fresh acoustic nature song for preschoolers, ukulele, kalimba, flute, gentle rain stick, clear female vocal en-US, 98 BPM`
- **Lyrics:**
  ```text
  Look out the window, what do you see?
  Bright yellow Sun and a tall green Tree!
  Fluffy white Cloud in the Sunny sky,
  Cool Windy breeze blows gently by!
  Pitter-patter Rain on a Rainy day,
  Flower and Grass drink water and sway!
  Soft white Snow and the glowing Moon,
  Nature sings a happy tune!
  ```

#### 23. `audio/songs/s23_school_song.mp3` (Chủ đề 23: My Preschool)
- **Title:** `Off to Preschool We Go`
- **Music Prompt:** `Joyful back-to-school preschool song, upbeat piano, acoustic guitar, glockenspiel, handclaps, friendly female vocal en-US, 102 BPM`
- **Lyrics:**
  ```text
  Pack your school Bag, ready, set, go,
  Off to our happy School we go!
  Kind sweet Teacher smiles at the door,
  Friends in the Classroom on the floor!
  Open a Book and read a rhyme,
  Pencil, Crayon, and Paper time!
  Safe little Scissors, cut with care,
  Out to the Playground in the fresh air!
  ```

#### 24. `audio/songs/s24_jobs_song.mp3` (Chủ đề 24: Cool Jobs)
- **Title:** `When I Grow Up`
- **Music Prompt:** `Inspiring cheerful kids song about community helpers, bright brass, acoustic guitar, marimba, warm female vocal en-US, 102 BPM`
- **Lyrics:**
  ```text
  Doctor and Nurse help us feel fine,
  Firefighter, Police Officer shine!
  Chef in the kitchen cooks a treat,
  Farmer grows healthy food to eat!
  Driver on the road and Builder strong,
  Singer on the stage sings a happy song!
  Astronaut flies where the bright stars glow,
  What will you be as you learn and grow?
  ```

#### 25. `audio/songs/s25_party_song.mp3` (Chủ đề 25: Party & Holidays)
- **Title:** `Momo's Big Celebration Party`
- **Music Prompt:** `Festive celebration party song for preschoolers, upbeat ukulele, brass fanfare, xylophone, handclaps, joyful female vocal en-US, 106 BPM`
- **Lyrics:**
  ```text
  Put on your Party Hat, wear your gold Crown,
  It's the biggest Birthday party in town!
  Light up the Candle, close your eyes tight,
  Make a sweet Wish in the warm candlelight!
  Open the Gift with a big red bow,
  Dance to the Music and watch Lanterns glow!
  Fireworks sparkle high up above,
  Let's Celebrate with joy and love!
  ```

---

## 5. Tổng Kết Số Lượng Tài Nguyên 20 Chủ Đề Mới (`t06` → `t25`)

| Nhóm Tài Nguyên | Số lượng File mới | Chi tiết |
|---|---|---|
| **Hình ảnh Đảo & Bìa nhạc (`.png`)** | **40 file** | 20 Đảo nổi 2.5D (`512×512`) + 20 Bìa bài hát (`600×600`) |
| **Hình ảnh Từ vựng (`.png`)** | **212 file** | 212 hình minh họa từ vựng nền trong suốt (`512×512`) cho `t06` → `t25` |
| **Hình ảnh Sticker & TPR (`.png`)** | **92 file** | 80 Sticker thưởng (4 sticker/chủ đề) + 12 hình động tác TPR mới |
| **Âm thanh Từ vựng & Câu ví dụ (`.mp3`)** | **424 file** | 212 file đọc từ đơn (`audio/words/`) + 212 file đọc câu ví dụ (`audio/sentences/`) |
| **Âm thanh Mẫu câu Phụ huynh & TPR (`.mp3`)** | **52 file** | 40 file mẫu câu Học cùng con + 12 file hướng dẫn động tác TPR |
| **Bài hát Chủ đề Karaoke (`.mp3`)** | **20 file** | 20 bài hát thiếu nhi sáng tác gốc (`s06` → `s25`) kèm timestamp Karaoke |
| **File Cấu hình Chủ đề & Gói (`.json` / `.bvpack`)** | **41 file** | 20 file `t06..t25.json` + 20 gói nén `.bvpack` + 1 file `index.json` trên Google Drive |
| **TỔNG CỘNG (20 Chủ đề mới)** | **881 file** | Kết hợp với 288 file của 5 chủ đề MVP $\rightarrow$ Toàn bộ hệ sinh thái đạt **1,169 file tài nguyên** |
