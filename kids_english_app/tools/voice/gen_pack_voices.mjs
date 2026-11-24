// Sinh các file giọng đọc còn thiếu cho gói chủ đề trong kids_english_app/content_packs/<id>/.
// Văn bản lấy trực tiếp từ topic.json (khớp docs/ASSET_SPEC_20_NEW_TOPICS.md, phần B1–B3):
//   - words[].audio            ← "<Text>."            (giọng đọc từ, chậm ~15%)
//   - words[].sentence_audio   ← words[].sentence     (câu ví dụ)
//   - sentences[].audio        ← sentences[].text     (mẫu câu phụ huynh)
//   - commands[].audio         ← commands[].text      (giọng Momo, lệnh TPR)
// Chỉ tạo file CHƯA có (không ghi đè). Định dạng 24 kHz / 48 kbps mono MP3, giống giọng t01..t05.
//
// Cách dùng (trong thư mục này):
//   npm install
//   node gen_pack_voices.mjs                 # tất cả chủ đề trong content_packs/
//   node gen_pack_voices.mjs t06_family ...  # chỉ một số chủ đề
//   node gen_pack_voices.mjs --dry-run       # chỉ liệt kê file sẽ tạo
// Sau đó đóng gói lại: cd ../../app && dart run tools/pack_topic.dart <id> --out ../docs/packs
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { MsEdgeTTS, OUTPUT_FORMAT } from "msedge-tts";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const PACKS = path.resolve(HERE, "../../content_packs");

// Giọng đọc (Edge neural). Có thể đổi tại đây.
const VOICES = {
  word: { voice: "en-US-JennyNeural", rate: "-15%", pitch: "+0Hz" },
  sentence: { voice: "en-US-JennyNeural", rate: "-15%", pitch: "+0Hz" },
  parent: { voice: "en-US-JennyNeural", rate: "-10%", pitch: "+0Hz" },
  momo: { voice: "en-US-AnaNeural", rate: "-5%", pitch: "+0Hz" },
};

const args = process.argv.slice(2);
const dryRun = args.includes("--dry-run");
const only = args.filter((a) => !a.startsWith("--"));

function jobsFor(topicDir) {
  const t = JSON.parse(fs.readFileSync(path.join(topicDir, "topic.json"), "utf8"));
  const jobs = [];
  const add = (rel, text, kind) => {
    if (!rel || !text) return;
    jobs.push({ rel, text: text.trim(), kind, out: path.join(topicDir, ...rel.split("/")) });
  };
  for (const w of t.words ?? []) {
    add(w.audio, /[.!?]$/.test(w.text.trim()) ? w.text : `${w.text}.`, "word");
    add(w.sentence_audio, w.sentence, "sentence");
  }
  for (const s of t.sentences ?? []) add(s.audio, s.text, "parent");
  for (const c of t.commands ?? []) add(c.audio, c.text, "momo");
  return { id: t.id, jobs };
}

const escapeXml = (s) => s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");

async function synth(tts, current, job) {
  const v = VOICES[job.kind];
  if (current.voice !== v.voice) {
    await tts.setMetadata(v.voice, OUTPUT_FORMAT.AUDIO_24KHZ_48KBITRATE_MONO_MP3);
    current.voice = v.voice;
  }
  const { audioStream } = tts.toStream(escapeXml(job.text), { rate: v.rate, pitch: v.pitch });
  const chunks = [];
  for await (const c of audioStream) chunks.push(c);
  const buf = Buffer.concat(chunks);
  if (buf.length < 1000) throw new Error(`âm thanh quá ngắn (${buf.length} bytes)`);
  return buf;
}

const topics = fs
  .readdirSync(PACKS)
  .filter((d) => fs.existsSync(path.join(PACKS, d, "topic.json")))
  .filter((d) => only.length === 0 || only.includes(d))
  .sort();

const cache = new Map(); // cùng giọng + văn bản → dùng lại (lệnh TPR lặp giữa các chủ đề)
let made = 0, reused = 0, skipped = 0, failed = 0;
const tts = new MsEdgeTTS();
const current = { voice: null };

for (const d of topics) {
  const { id, jobs } = jobsFor(path.join(PACKS, d));
  const todo = jobs.filter((j) => !fs.existsSync(j.out));
  skipped += jobs.length - todo.length;
  console.log(`${id}: ${todo.length} file cần tạo`);
  for (const j of todo) {
    if (dryRun) {
      console.log(`  [${j.kind}] ${j.rel}  "${j.text}"`);
      continue;
    }
    const key = `${VOICES[j.kind].voice}|${VOICES[j.kind].rate}|${j.text}`;
    try {
      let buf = cache.get(key);
      if (buf) reused++;
      else {
        buf = await synth(tts, current, j);
        cache.set(key, buf);
        made++;
      }
      fs.mkdirSync(path.dirname(j.out), { recursive: true });
      fs.writeFileSync(j.out, buf);
    } catch (e) {
      failed++;
      console.error(`  LỖI ${j.rel}: ${e.message ?? e}`);
    }
  }
}
tts.close?.();
console.log(`Xong: tạo mới ${made}, dùng lại ${reused}, đã có ${skipped}, lỗi ${failed}`);
process.exit(failed ? 1 : 0);
