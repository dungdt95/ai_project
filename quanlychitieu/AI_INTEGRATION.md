# Phân tích: Tích hợp AI vào app Quản lý Thu Chi

> Tài liệu phân tích khả năng, các phương án và lộ trình tích hợp AI vào ứng dụng quản lý thu chi cá nhân (hiện đang chạy local hoàn toàn).

---

## 1. Câu trả lời ngắn

**Có thể**, và có nhiều cách triển khai khác nhau. Vấn đề chính là **mâu thuẫn giữa yêu cầu "offline hoàn toàn"** và **khả năng/độ chính xác của AI**:

- AI thật sự mạnh (LLM như GPT-4, Claude, Gemini) → cần gọi API qua mạng
- AI on-device (chạy local trên máy) → giới hạn năng lực, app nặng (1-4GB), cần thiết bị mạnh
- "Pseudo-AI" (regex + dictionary + rules) → chạy offline tuyệt đối, đáp ứng 70-80% use case nhập liệu nhanh

→ **Đề xuất**: Bắt đầu với **rule-based parser + voice input**, sau đó **cho phép user opt-in** dùng cloud AI nếu muốn nâng cao.

---

## 2. Các use case AI có thể hỗ trợ

| # | Use case | Mức độ hữu ích | Độ phức tạp AI cần |
|---|----------|-----------------|---------------------|
| 1 | **Nhập giao dịch bằng văn bản tự nhiên**: "Ăn phở 50k trưa nay" → auto-fill form | ⭐⭐⭐⭐⭐ | Thấp (parser) hoặc cao (LLM) |
| 2 | **Nhập bằng giọng nói**: nói tiếng Việt → text → giao dịch | ⭐⭐⭐⭐⭐ | Speech-to-text + parser |
| 3 | **Quét hóa đơn (OCR)**: chụp ảnh bill → trích xuất số tiền, ngày, item | ⭐⭐⭐⭐ | Cao (Vision model) |
| 4 | **Gợi ý danh mục thông minh**: gõ "Grab" → tự chọn "Đi lại" | ⭐⭐⭐⭐ | Thấp (keyword matching) |
| 5 | **Phân tích & insight**: "Tháng này bạn chi cho ăn uống cao hơn 30%" | ⭐⭐⭐ | Trung (template + data) |
| 6 | **Tư vấn ngân sách**: "Nên giảm chi giải trí xuống 500k/tháng" | ⭐⭐⭐ | Cao (LLM) |
| 7 | **Tìm kiếm bằng ngôn ngữ tự nhiên**: "Các khoản chi ăn uống tuần trước" | ⭐⭐⭐ | Trung (semantic search) |
| 8 | **Dự đoán chi tiêu**: "Cuối tháng dự kiến chi ~5tr" | ⭐⭐ | Thấp (math) |

---

## 3. Bốn phương án kỹ thuật

### Phương án A: **Rule-based parser** (offline tuyệt đối)

Không dùng AI thực, chỉ dùng **regex + dictionary từ khóa**.

**Ví dụ pipeline:**
```
Input: "ăn phở 50k trưa nay"
  ↓
1. Regex extract số tiền: "50k" → 50000
2. Match từ khóa: "phở" → danh mục "Ăn uống"
3. Match thời gian: "trưa nay" → DateTime.now()
  ↓
Output: Transaction(amount=50000, category="Ăn uống", date=today)
```

**Dictionary từ khóa cho danh mục (gợi ý):**
```dart
{
  'Ăn uống': ['ăn', 'uống', 'phở', 'cơm', 'cafe', 'trà sữa', 'bún', 'lẩu', 'nướng'],
  'Đi lại': ['grab', 'taxi', 'xăng', 'xe ôm', 'vé xe', 'vé tàu', 'bay'],
  'Mua sắm': ['mua', 'shopee', 'lazada', 'tiki', 'siêu thị'],
  'Hóa đơn': ['điện', 'nước', 'internet', 'điện thoại', 'wifi'],
  'Giải trí': ['phim', 'rạp', 'game', 'karaoke', 'bar'],
  // ...
}
```

**Regex số tiền:**
```regex
(\d+(?:[.,]\d+)?)\s*(k|nghìn|ngàn|tr|triệu|m|đ|d|vnd)?
```
- "50k" → 50.000
- "1tr5" → 1.500.000  
- "500.000đ" → 500.000

| ✅ Ưu điểm | ❌ Nhược điểm |
|-----------|----------------|
| Offline 100% | Cần maintain dictionary |
| Nhanh, gọn (~50KB code) | Không hiểu ngữ cảnh phức tạp |
| Không cần thiết bị mạnh | Chỉ đáp ứng câu đơn giản |
| Không tốn chi phí | Mở rộng khó (cần code thêm) |
| Không vấn đề bảo mật | |

### Phương án B: **On-device LLM** (offline, nhưng nặng)

Chạy mô hình AI ngay trên máy user (không gọi API).

**Lựa chọn model:**
| Model | Kích thước | Phù hợp |
|-------|-----------|---------|
| Gemma 2B (Google) | ~1.5GB | Phổ biến, có Flutter plugin `flutter_gemma` |
| Phi-3 mini (Microsoft) | ~2GB | Chất lượng cao |
| Llama 3.2 1B | ~1GB | Nhẹ nhất hiện tại |
| Qwen2.5 0.5B | ~500MB | Siêu nhẹ, chất lượng vừa |

**Plugin Flutter:**
- [`flutter_gemma`](https://pub.dev/packages/flutter_gemma) — Google chính thức
- [`fllama`](https://pub.dev/packages/fllama) — llama.cpp cho Flutter
- [`tflite_flutter`](https://pub.dev/packages/tflite_flutter) — TensorFlow Lite

| ✅ Ưu điểm | ❌ Nhược điểm |
|-----------|----------------|
| Offline 100% | App size tăng **1-4GB** |
| AI thực sự, hiểu ngữ cảnh | Cần thiết bị RAM ≥6GB |
| Không tốn chi phí runtime | Inference chậm (3-15s/câu) |
| Bảo mật tuyệt đối | Pin tụt nhanh |
| | Khó test trên emulator |
| | Chưa hỗ trợ tốt tiếng Việt với model nhỏ |

> Khuyến cáo: **Chưa nên dùng** ở giai đoạn MVP. Phù hợp khi user là power-user và có thiết bị mạnh.

### Phương án C: **Cloud AI API** (mạnh nhất, cần mạng)

Gọi API của các nhà cung cấp lớn:

| Provider | Model | Giá/1M tokens | Hỗ trợ Vision |
|----------|-------|---------------|-----------------|
| **Anthropic** | Claude Haiku 4.5 | $1 in / $5 out | ✅ |
| **OpenAI** | GPT-4o-mini | $0.15 in / $0.6 out | ✅ |
| **Google** | Gemini 2.0 Flash | $0.075 in / $0.3 out | ✅ |
| **Groq** | Llama 3.3 70B | $0.59 in / $0.79 out | ❌ |

**Chi phí ước lượng** cho 1 user trung bình (50 giao dịch/tháng, mỗi câu ~100 tokens):
- Gemini Flash: ~$0.001/tháng (~25 đồng) → **gần như miễn phí**
- Claude Haiku: ~$0.005/tháng (~125 đồng)

→ Chi phí không phải vấn đề. **Vấn đề là cần internet và quản lý API key**.

**Cách quản lý API key:**
1. **User tự cung cấp** (recommended): tạo màn hình Settings → "AI", user paste API key của họ vào
2. **Bạn cung cấp**: build server proxy nhỏ → quản lý quota → app gọi server (cần backend)

| ✅ Ưu điểm | ❌ Nhược điểm |
|-----------|----------------|
| AI mạnh nhất (hiểu ngữ cảnh, đa ngôn ngữ) | Cần internet |
| Hỗ trợ vision (OCR hóa đơn) | Cần API key |
| App vẫn nhẹ | Bảo mật: data → cloud |
| Triển khai nhanh | Vi phạm "offline hoàn toàn" |

### Phương án D: **Hybrid** (đề xuất chính) ⭐

Kết hợp ưu điểm các phương án:

```
┌──────────────────────────────────────────┐
│   Voice input (speech_to_text plugin)    │  ← Android on-device speech (Android 13+)
└──────────────────────────────────────────┘
                  ↓ text
┌──────────────────────────────────────────┐
│   Rule-based parser (offline)            │  ← Mặc định, miễn phí, nhanh
└──────────────────────────────────────────┘
                  ↓
        Parse thành công?
       /            \
     Yes              No / "Phân tích AI"
      ↓                 ↓
   Tạo TX        ┌──────────────────────┐
                 │ Cloud AI (opt-in)    │  ← User bật trong Settings
                 │ Gemini/Claude API    │
                 └──────────────────────┘
                          ↓
                       Tạo TX
```

**Flow nhập nhanh đề xuất:**
1. Tap **icon mic** trên FAB → nói: *"Ăn phở 50k trưa nay"*
2. Speech → text "ăn phở 50k trưa nay"
3. Parser cố gắng extract → form thêm giao dịch tự fill số tiền + danh mục + ngày
4. User confirm hoặc chỉnh sửa → lưu

**Cho user advanced:**
1. Vào Settings → "AI" → bật "Phân tích bằng AI"
2. Chọn provider: Gemini (free tier 1M token/ngày) / OpenAI / Claude
3. Paste API key
4. Khi parser local fail → tự động fallback sang AI

**Tính năng bổ sung khi bật AI:**
- OCR hóa đơn: chụp ảnh → trích xuất giao dịch
- Insights tháng: "Tháng này bạn chi cho ăn uống cao hơn 30%..."
- Tư vấn ngân sách dựa trên lịch sử

---

## 4. So sánh tổng quan

| Tiêu chí | A. Rules | B. On-device LLM | C. Cloud API | D. Hybrid |
|----------|----------|------------------|--------------|-----------|
| Offline 100% | ✅ | ✅ | ❌ | ⚠️ Phần cốt lõi |
| Độ chính xác | 70-80% | 75-85% | 95% | 90%+ |
| App size | ~50KB code | +1-4GB | ~100KB | ~200KB |
| Tốc độ nhập 1 TX | <100ms | 3-15s | 1-3s | 100ms-3s |
| Chi phí | 0 | 0 | ~$0.001/user/tháng | ~$0/user (rule first) |
| Cần thiết bị mạnh | ❌ | ✅ RAM 6GB+ | ❌ | ❌ |
| Bảo mật | ✅ Tuyệt đối | ✅ Tuyệt đối | ⚠️ Data → cloud | ⚠️ Tùy bật |
| Triển khai | 2-3 ngày | 1-2 tuần | 3-5 ngày | 1-2 tuần |
| Maintain | Cần update từ điển | Update model | Theo dõi API | Cả hai |

---

## 5. Đề xuất triển khai (Phương án D - Hybrid)

### Giai đoạn 1 — Voice + Rule-based (1 tuần)

**Mục tiêu**: User có thể nhập giao dịch bằng giọng nói hoặc gõ tự nhiên, hoàn toàn offline.

**Files mới cần tạo:**
```
lib/services/
├── voice_input_service.dart        # Wrap speech_to_text
└── ai_parser/
    ├── ai_parser.dart              # Interface chung
    ├── rule_parser.dart            # Parser regex + dictionary
    ├── amount_extractor.dart       # Tách số tiền
    ├── date_extractor.dart         # Tách thời gian (hôm nay, hôm qua, ...)
    └── category_matcher.dart       # Match từ khóa → danh mục
lib/features/transactions/
├── presentation/
│   └── voice_input_screen.dart     # UI ghi âm + preview
└── application/
    └── ai_assistant_controller.dart
```

**Dependencies thêm:**
```yaml
speech_to_text: ^7.0.0    # Voice → text
permission_handler: ^11.x  # Quyền microphone (đã có)
```

**Permissions cần thêm vào AndroidManifest.xml:**
```xml
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
<uses-permission android:name="android.permission.INTERNET"/> 
<!-- INTERNET cần cho Google Speech, có thể bỏ nếu dùng on-device -->
```

**UI thay đổi:**
- Trên màn hình Giao dịch, thêm nút **mic** cạnh FAB hoặc đè lên FAB (giữ để nói)
- Sau khi nói → hiện preview text + form thêm tự fill → user confirm

### Giai đoạn 2 — Cloud AI opt-in (1 tuần)

**Mục tiêu**: User có thể bật cloud AI để nhập câu phức tạp + OCR hóa đơn + insights.

**Files mới:**
```
lib/services/ai_parser/
├── cloud_parser.dart               # Implement AIParser, gọi API
└── prompt_templates.dart           # Prompt cho từng task
lib/features/settings/
└── ai_settings_screen.dart         # Quản lý API key, chọn provider
lib/features/reports/
└── ai_insights_card.dart           # Card hiển thị insight
```

**Settings UI mới:**
- Toggle "Bật trợ lý AI"
- Dropdown chọn provider: Gemini / OpenAI / Claude
- TextField paste API key (lưu trong SQLite settings, mã hóa bằng `flutter_secure_storage`)
- Toggle "Cho phép gửi dữ liệu giao dịch để phân tích"

**Prompt mẫu cho parser:**
```
Bạn là trợ lý nhập liệu cho app quản lý chi tiêu cá nhân.
Phân tích câu sau và trả về JSON:

Câu: "{user_input}"

Danh mục có sẵn: {categories_list}

Trả về JSON với format:
{
  "type": "expense" | "income",
  "amount": <số nguyên VND>,
  "category": "<tên danh mục khớp nhất>",
  "date": "<YYYY-MM-DD>",
  "note": "<ghi chú nếu có>"
}

Chỉ trả JSON, không giải thích.
```

### Giai đoạn 3 — OCR hóa đơn + Insights (2 tuần)

- Nút "Quét hóa đơn" trong tab Giao dịch
- `image_picker` → chụp/chọn ảnh → gửi lên cloud AI vision API → trả JSON
- Trong tab Báo cáo, thêm card "Phân tích bằng AI" → tóm tắt tháng + đề xuất

---

## 6. Mockup luồng người dùng

### Flow 1: Nhập bằng giọng nói (offline)
```
[Tab Giao dịch] → Tap & giữ nút Mic
                       ↓
               🎤 "Đang nghe..."
                       ↓
        User nói: "Ăn phở năm chục nghìn trưa nay"
                       ↓
              📝 Hiển thị text đã nhận diện
                       ↓
       Tap [Phân tích] → Form thêm giao dịch
                       ↓
              ┌───────────────────────┐
              │ Số tiền: 50.000 đ     │  ← auto fill
              │ Danh mục: Ăn uống     │  ← auto fill
              │ Ngày: 10/05/2026      │  ← auto fill
              │ Ghi chú: ăn phở       │  ← auto fill
              └───────────────────────┘
                       ↓
                [Lưu]
```

### Flow 2: OCR hóa đơn (cloud AI)
```
[Tab Giao dịch] → Tap nút Camera
                       ↓
              📷 Mở camera, chụp bill
                       ↓
              "Đang phân tích..."
                       ↓
              Cloud AI Vision → JSON
                       ↓
        ┌─────────────────────────┐
        │ Tổng: 285.000 đ         │
        │ Ngày: 10/05/2026        │
        │ Items:                  │
        │  - Phở bò × 2           │
        │  - Trà sữa × 1          │
        │ Danh mục gợi ý: Ăn uống │
        └─────────────────────────┘
                       ↓
              [Lưu] hoặc [Sửa]
```

### Flow 3: Insight tháng (cloud AI)
```
[Tab Báo cáo] → Card "💡 Phân tích AI"
        ↓
"Tháng 5/2026 của bạn:
 • Chi tiêu tăng 18% so với tháng trước
 • 'Ăn uống' chiếm 45% tổng chi (cao bất thường)
 • Đã chi vượt mức trung bình 6 tháng gần nhất 
   ở các ngày: 03, 08, 14
 
 Gợi ý: Cân nhắc đặt hạn mức ăn uống 2.5tr/tháng
        để giữ tỷ lệ tiết kiệm 30%."
```

---

## 7. Lưu ý quan trọng

### Bảo mật
- API key **bắt buộc** lưu bằng `flutter_secure_storage` (Android Keystore), không lưu plain text trong SQLite
- Cảnh báo rõ ràng: "Khi bật AI cloud, dữ liệu giao dịch sẽ được gửi đến nhà cung cấp AI"
- Cho phép user **xóa toàn bộ dữ liệu AI cache** trong Settings

### Quyền (Permissions)
- `RECORD_AUDIO` cho voice input
- `CAMERA` cho OCR
- `INTERNET` chỉ cần khi bật cloud AI

### Performance
- Voice recognition trên Android 13+ có on-device mode → không cần mạng
- Parser local phải chạy <100ms
- Cloud API gọi async, có loading state, có cancel

### Fallback
- Nếu parser fail → vẫn cho user mở form thủ công
- Nếu API timeout/lỗi → hiện thông báo, không crash
- Nếu mất mạng giữa chừng → cache câu đã nhập, retry sau

### UX
- AI là **công cụ hỗ trợ**, không bắt buộc → form thủ công luôn truy cập được
- Mọi kết quả AI **phải confirm** trước khi lưu
- Có nút **"Học lại"** cho từng giao dịch (training data cho model sau)

### Pháp lý / chính sách
- Khi gửi data lên cloud, cần thông báo rõ trong **chính sách bảo mật**
- Lưu ý quy định bảo mật dữ liệu cá nhân (Việt Nam: Nghị định 13/2023)

---

## 8. Roadmap đề xuất

| Giai đoạn | Thời gian | Phạm vi |
|-----------|-----------|---------|
| **MVP+** | 1 tuần | Voice input + Rule-based parser cho text → giao dịch |
| **AI v1** | 1 tuần | Settings AI, cloud parser opt-in (Gemini), fallback chain |
| **AI v2** | 2 tuần | OCR hóa đơn (Vision API), AI insights trong Báo cáo |
| **AI v3** | 1 tuần | Smart search, dự đoán chi tiêu, gợi ý ngân sách |

---

## 9. Kết luận

### Khuyến nghị

✅ **Nên thêm**, theo cách:
1. **Bắt đầu nhỏ**: Voice + rule-based parser (giữ offline-first)
2. **Cho user lựa chọn**: cloud AI là tùy chọn opt-in, user tự bring own API key
3. **Không thay thế UI thủ công**: AI hỗ trợ, không thay thế

❌ **Không nên**:
- Đưa on-device LLM ngay (app sẽ nặng 2GB+, RAM yêu cầu cao)
- Gọi cloud AI mặc định không có sự đồng ý của user
- Bắt buộc dùng AI cho mọi giao dịch (giảm UX)

### Giá trị mang lại

- ⏱️ **Tiết kiệm thời gian**: nhập 1 giao dịch từ 30s → 5s (voice) hoặc 10s (text natural)
- 📸 **OCR hóa đơn**: thay vì nhập tay từng món
- 💡 **Insights**: phát hiện thói quen chi tiêu bất thường, đưa ra gợi ý
- 🎯 **Đúng phong cách**: offline-first vẫn đảm bảo, AI chỉ là layer bổ sung

### Bước tiếp theo đề xuất

1. Approve hoặc chỉnh sửa scope
2. Implement Giai đoạn 1 (voice + rule parser) → 1 tuần
3. User test → đo độ chính xác parser
4. Quyết định có triển khai Giai đoạn 2 (cloud AI) hay không

---

## 10. Bonus: On-device LLM **dùng chung cho nhiều app** (mở rộng từ Phương án B)

> Ý tưởng: Thay vì mỗi app nhúng model riêng (mất 1-4GB × số app), **chỉ host 1 model duy nhất** trên máy → nhiều app cùng gọi tới. Câu hỏi: làm được không, làm như thế nào?

**Câu trả lời ngắn**: ✅ **Có**, có 5 cách triển khai khác nhau, mỗi cách phù hợp với một mục đích.

### 10.1. Năm kiến trúc khả thi

#### Cách 1: **Chia sẻ file model** (đơn giản nhất, không tiết kiệm RAM)

```
┌──────────────────┐     ┌──────────────────┐
│ App A (1.5GB RAM)│     │ App B (1.5GB RAM)│
│  + inference     │     │  + inference     │
└────────┬─────────┘     └────────┬─────────┘
         │ load                    │ load
         ↓                         ↓
    ┌────────────────────────────────────┐
    │  /sdcard/Models/gemma-2b.gguf      │  ← file vật lý 1 lần
    └────────────────────────────────────┘
```

- Mỗi app vẫn load model vào RAM của mình → **không tiết kiệm RAM**, chỉ tiết kiệm storage
- Mỗi app cần inference engine riêng (llama.cpp/MLC)
- Android 11+ có Scoped Storage → không phải app nào cũng đọc được /sdcard tự do
- **Đánh giá**: Không khuyến khích vì lợi ích rất ít.

#### Cách 2: **AI Hub app + Bound Service** (recommended cho ecosystem riêng) ⭐

```
┌─────────────┐       AIDL/HTTP localhost      ┌──────────────────┐
│  App quản   │ ──────────────────────────► │   AI Hub App     │
│  lý chi tiêu│ ◄────────────────────────── │  (Foreground svc)│
└─────────────┘                              │  + Model 1.5GB   │
                                             │  + llama.cpp     │
┌─────────────┐                              └──────────────────┘
│  App khác   │ ────────────────────────────────────► │
│  (notes,    │ ◄──────────────────────────────────── │
│  todo, ...) │
└─────────────┘
```

**Cách hoạt động:**
1. Build 1 app riêng tên "AI Hub" (hoặc tên gì cũng được), publish lên Play Store hoặc cài tay
2. AI Hub:
   - Chạy `ForegroundService` để giữ model trong RAM
   - Expose API qua **Android Bound Service (AIDL)** hoặc **HTTP localhost**
3. App quản lý chi tiêu thêm dependency, gọi service:
   ```dart
   final result = await AIHubClient.complete("Ăn phở 50k trưa nay");
   ```
4. AI Hub xử lý → trả JSON về

**Ưu điểm:**
- ✅ **Chỉ 1 instance model trong RAM** (1.5GB cho cả N app)
- ✅ User cài 1 lần, dùng cho nhiều app của bạn
- ✅ Update model độc lập (chỉ update AI Hub)
- ✅ Cấu hình tập trung: chọn model, thiết bị (CPU/GPU/NPU)

**Nhược điểm:**
- ❌ Cần build và maintain thêm 1 app
- ❌ User phải cài AI Hub trước (chuỗi phụ thuộc)
- ❌ Foreground service chạy thường trực → tốn pin (giải pháp: stop service khi không dùng > 5 phút)
- ❌ Android battery optimizer có thể kill service → cần handle

**Implementation overview (AIDL):**

`IAIHubService.aidl`:
```aidl
package com.aihub.service;

interface IAIHubService {
    String complete(String prompt, int maxTokens);
    void completeStream(String prompt, int maxTokens, IAIHubCallback callback);
    boolean isModelLoaded();
}
```

App client gọi:
```dart
// Flutter có package android_intent_plus + platform channels
// Hoặc dùng package method_channel để gọi AIDL từ Kotlin native
final aiHub = AIHubClient();
await aiHub.connect();
final json = await aiHub.complete(
  prompt: 'Phân tích: "Ăn phở 50k"',
  maxTokens: 200,
);
```

#### Cách 3: **Android AICore + Gemini Nano** (chuẩn Google, nhưng giới hạn)

Đây là **cách "chính chủ"** Google đang đẩy mạnh từ Android 14+.

```
┌─────────────┐    ML Kit GenAI APIs    ┌──────────────────────┐
│  App của    │ ──────────────────────► │  Google Play Services│
│  bạn        │ ◄────────────────────── │  + AICore            │
└─────────────┘                          │  + Gemini Nano (sẵn) │
                                         └──────────────────────┘
                                            ↑ pre-installed trên
                                              Pixel 8+, Samsung S24+
```

**Đặc điểm:**
- Gemini Nano đã **được nhúng sẵn** trong hệ điều hành (chỉ ~3GB ROM)
- Apps dùng [**ML Kit GenAI APIs**](https://developers.google.com/ml-kit/genai) (Beta từ 2024)
- API có sẵn:
  - **Summarization** — tóm tắt văn bản
  - **Rewriting** — viết lại theo style khác
  - **Proofreading** — sửa lỗi chính tả/ngữ pháp
  - **Image description** — mô tả ảnh
  - Sắp có: **Custom prompts** (general LLM)

**Hỗ trợ thiết bị (tính đến 2026-05):**
- ✅ Pixel 8 Pro, Pixel 9, Pixel 9 Pro, Pixel 10
- ✅ Samsung Galaxy S24/S25 series
- ✅ Một số Xiaomi 14+, OnePlus 12+
- ❌ Phần lớn thiết bị tầm trung & cũ

**Ưu điểm:**
- ✅ **Không cần build hub**, không tốn RAM thêm (đã sẵn trong OS)
- ✅ API chuẩn, bảo mật được Google đảm bảo
- ✅ Inference cực nhanh (NPU dedicated)
- ✅ Pin tiết kiệm (chip AI riêng)

**Nhược điểm:**
- ❌ Chỉ chạy trên thiết bị cao cấp (~10-15% thị phần Việt Nam)
- ❌ Hiện chưa có general "complete()" API — chỉ task cụ thể
- ❌ Không tùy biến model (Google quyết)

**Code mẫu (Kotlin):**
```kotlin
val client = SummarizationClient.create(SummarizationOptions.Builder().build())
val response = client.summarize("văn bản dài...").await()
println(response.summary)
```

→ Flutter chưa có wrapper chính thức, cần viết platform channel.

#### Cách 4: **Local HTTP server** (Termux + Ollama) (linh hoạt nhất, dev-friendly)

```
┌─────────────┐    HTTP localhost:11434    ┌──────────────────┐
│  App quản   │ ──────────────────────► │  Termux + Ollama │
│  lý chi tiêu│ ◄────────────────────── │  + Model         │
└─────────────┘                          └──────────────────┘
                  ↑ Apps khác cũng gọi
                    HTTP localhost
```

**Cách hoạt động:**
1. User cài [Termux](https://f-droid.org/packages/com.termux/) (terminal Android)
2. Trong Termux, cài [Ollama](https://ollama.com) hoặc [llama.cpp server](https://github.com/ggerganov/llama.cpp)
3. Chạy: `ollama serve` → server lắng nghe localhost:11434
4. App Flutter gọi qua `http` package:
   ```dart
   final response = await http.post(
     Uri.parse('http://localhost:11434/api/generate'),
     body: jsonEncode({
       'model': 'gemma2:2b',
       'prompt': 'Phân tích: "Ăn phở 50k"',
     }),
   );
   ```

**Ưu điểm:**
- ✅ **Cực kỳ linh hoạt** — đổi model, prompt, settings dễ
- ✅ **Streaming** OOTB
- ✅ Cùng 1 server phục vụ **vô số app**
- ✅ Open-source toàn bộ
- ✅ Dùng API chuẩn OpenAI-compatible → đổi sang cloud dễ

**Nhược điểm:**
- ❌ User phải cài Termux + chạy lệnh terminal → **không phù hợp end-user phổ thông**
- ❌ Server chiếm RAM 1-2GB liên tục
- ❌ Cần maintain (start lại server sau reboot)

→ **Phù hợp cho dev test hoặc power user.** Không phù hợp app commercial cho user phổ thông.

#### Cách 5: **App AI hub có sẵn** (tận dụng app đã có)

Một số app trên Play Store đã host model + expose API:

| App | API | Ghi chú |
|-----|-----|---------|
| [PocketPal AI](https://github.com/a-ghorbani/pocketpal-ai) | Có HTTP API local | Open-source |
| [MLC Chat](https://llm.mlc.ai/) | Hỗ trợ nhiều model | MLC team |
| [Maid](https://github.com/Mobile-Artificial-Intelligence/maid) | Front-end cho llama.cpp | F-Droid |
| [Layla](https://www.layla-network.ai/) | Trả phí, có API | Polished UX |

→ User cài app đó, app của bạn gọi API. **Phụ thuộc bên thứ 3**, ít kiểm soát.

### 10.2. So sánh 5 cách

| Tiêu chí | 1. Shared file | 2. AI Hub + Service ⭐ | 3. Android AICore | 4. Termux+Ollama | 5. App hub bên 3 |
|----------|---------------|------------------------|--------------------|-------------------|--------------------|
| Tiết kiệm RAM | ❌ | ✅ | ✅ | ✅ | ✅ |
| Tiết kiệm storage | ✅ | ✅ | ✅ | ✅ | ✅ |
| Cần dev thêm app | ❌ | ✅ Cần | ❌ | ❌ | ❌ |
| Dễ cho user | ⚠️ | ⚠️ Cài 1 app | ✅ Sẵn OS | ❌ Phải cài Termux | ⚠️ Cài app bên 3 |
| Kiểm soát model | ✅ | ✅ Toàn quyền | ❌ Google | ✅ | ❌ Bên thứ 3 |
| Phạm vi thiết bị | Mọi máy | Mọi máy | Chỉ flagship | Mọi máy | Mọi máy |
| Có thể custom prompt | ✅ | ✅ | ⚠️ Limited | ✅ | ✅ |
| Streaming | Tùy | ✅ | ✅ | ✅ | ✅ |
| Pin tiêu thụ | Cao | Trung | Thấp (NPU) | Cao | Trung |
| Khả thi production | Thấp | **Cao** | Cao (nếu thiết bị OK) | Thấp | Trung |

### 10.3. Đề xuất cụ thể cho hệ sinh thái app cá nhân

**Nếu mục tiêu là**: bạn có/sẽ có **nhiều app cá nhân** muốn dùng chung 1 LLM trên máy → **Cách 2 (AI Hub + Bound Service)** là phù hợp nhất.

**Kiến trúc đề xuất:**

```
                  ┌─────────────────────────────────┐
                  │         AI Hub App              │
                  │  ┌───────────────────────────┐  │
                  │  │ ForegroundService         │  │
                  │  │  ├─ llama.cpp engine      │  │
                  │  │  ├─ Model loaded (1.5GB)  │  │
                  │  │  └─ Request queue         │  │
                  │  └───────────┬───────────────┘  │
                  │              │ AIDL              │
                  │  ┌───────────┴───────────────┐  │
                  │  │ IAIHubService             │  │
                  │  │  ├─ complete()            │  │
                  │  │  ├─ completeStream()      │  │
                  │  │  ├─ embed()               │  │
                  │  │  ├─ getModelInfo()        │  │
                  │  │  └─ setSystemPrompt()     │  │
                  │  └───────────────────────────┘  │
                  │                                 │
                  │  UI:                            │
                  │   - Quản lý model (download)    │
                  │   - Cấu hình thread/temperature │
                  │   - Lịch sử request             │
                  │   - Quota/rate limit cho app    │
                  │   - Tắt/bật service             │
                  └────────────┬────────────────────┘
                               │
        ┌──────────────────────┼──────────────────────┐
        │                      │                      │
   ┌────┴────┐            ┌────┴────┐            ┌────┴────┐
   │ Quản lý │            │  Notes  │            │  Todo   │
   │ chi tiêu│            │   App   │            │   App   │
   └─────────┘            └─────────┘            └─────────┘
```

**Stack đề xuất cho AI Hub:**
- Ngôn ngữ: **Kotlin + JNI** (gọi llama.cpp native)
- Inference engine: **llama.cpp** (compile cho Android arm64-v8a)
- Model: **Gemma 2 2B Q4** (~1.5GB) hoặc **Qwen 2.5 0.5B Q4** (~400MB)
- IPC: **AIDL** (chính thức, an toàn) hoặc **HTTP localhost** (đơn giản hơn cho Flutter)

**Lựa chọn IPC:**

| | AIDL (Bound Service) | HTTP localhost |
|---|----------------------|----------------|
| Hiệu năng | ✅ Tốt nhất (Binder IPC) | ⚠️ HTTP overhead |
| Setup Flutter | ❌ Cần platform channel | ✅ Dùng `http` package |
| Streaming | ⚠️ Cần callback AIDL | ✅ SSE/chunked dễ |
| Bảo mật | ✅ Chỉ apps có signature/permission | ⚠️ Cần auth token |
| Cross-platform | ❌ Android only | ✅ |

→ **Khuyến nghị**: dùng **HTTP localhost** với token authentication. Gọn cho Flutter, dễ debug.

**API spec mẫu (HTTP-based):**

```http
POST http://127.0.0.1:8080/v1/complete
Authorization: Bearer <client_token>
Content-Type: application/json

{
  "prompt": "Phân tích: \"Ăn phở 50k trưa nay\"",
  "system": "Bạn là parser nhập liệu thu chi. Trả JSON.",
  "max_tokens": 200,
  "temperature": 0.1,
  "stream": false
}

→ Response:
{
  "text": "{\"type\":\"expense\",\"amount\":50000,...}",
  "tokens_in": 42,
  "tokens_out": 38,
  "duration_ms": 850
}
```

**Quản lý quota cho từng app:**
AI Hub lưu danh sách `client_token` → app name → daily limit, để tránh 1 app spam làm app khác bị nghẽn.

### 10.4. So sánh chi phí

Giả sử user có 3 app cùng dùng AI:

| Phương án | RAM | Storage | Pin | Effort dev |
|-----------|-----|---------|-----|------------|
| Mỗi app nhúng riêng (cũ) | 4.5GB (3×1.5) | 4.5GB | 3× | Thấp |
| Cách 2 (AI Hub) | 1.5GB | 1.5GB | 1× | Cao (build hub) |
| Cách 3 (Gemini Nano) | 0 thêm | 0 thêm | thấp nhất | Thấp |
| Cách 4 (Termux) | 1.5GB | ~3GB | 1× | Thấp (user setup) |

→ Cách 2 và 3 là **thực tế nhất**. Cách 2 control mọi thứ, Cách 3 dùng được ngay nếu thiết bị hỗ trợ.

### 10.5. Kết luận phần Bonus

**Câu hỏi gốc**: *"Có thể tạo riêng 1 model trên máy, dùng cho nhiều app không?"*

**Trả lời**: ✅ **Hoàn toàn được**. Có 3 cách thực tế:

1. **Cho hệ sinh thái app riêng của bạn** → Build **AI Hub app** (Cách 2). Effort cao nhưng kiểm soát toàn bộ.

2. **Tận dụng nền tảng** → Dùng **Android AICore + Gemini Nano** (Cách 3). Dễ nhất nhưng giới hạn thiết bị + tính năng.

3. **Cho dev/power-user** → Dùng **Termux + Ollama** (Cách 4). Cực mạnh nhưng end-user khó dùng.

**Khuyến nghị cho project quanlychitieu hiện tại:**
- Trước mắt **không khuyến khích đầu tư AI Hub** vì:
  - Chỉ có 1 app, lợi ích share chưa rõ rệt
  - Effort xây hub > effort tích hợp Cloud AI nhiều
- Khi nào có **≥3 app cá nhân** muốn AI offline → tính đến Cách 2
- Hoặc theo dõi **AICore Custom Prompts API** (Google sắp ra) → dùng Cách 3 không tốn công

**Kế hoạch thực tế:**

| Số lượng app dùng AI | Chiến lược nên dùng |
|---------------------|---------------------|
| 1 app | Cloud AI opt-in (Phương án D) |
| 2-3 app | Cloud AI hoặc AICore (nếu thiết bị hỗ trợ) |
| 4+ app | Tự build AI Hub (Cách 2) |
| User là dev | Termux + Ollama (Cách 4) |
