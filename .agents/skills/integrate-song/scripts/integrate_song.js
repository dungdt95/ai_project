#!/usr/bin/env node
/**
 * Upgraded Song Integrator & DSP Vocal Phrase / Bar-Grid Analyzer + Clip Slicer (v2.2)
 *
 * Modes:
 *   1. Copy & Analyze single topic:
 *      node integrate_song.js <topic_id_or_number> [source_mp3_path]
 *   2. Analyze existing song(s) without copying:
 *      node integrate_song.js --analyze <topic1> [topic2 ...]
 *   3. Slice 8 verification clips at candidate (or custom) timestamps:
 *      node integrate_song.js --slice <topic> [t1,t2,t3,t4,t5,t6,t7,t8]
 *   4. Apply verified timestamps to topic JSON:
 *      node integrate_song.js --apply <topic> <t1,t2,t3,t4,t5,t6,t7,t8>
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const WORKSPACE_ROOT = 'c:\\workspace\\ai_project';
const APP_ROOT = path.join(WORKSPACE_ROOT, 'kids_english_app', 'app');
const TOPICS_DIR = path.join(APP_ROOT, 'assets', 'content', 'topics');
const SCRATCH_MODULES = 'C:\\Users\\User\\.gemini\\antigravity\\brain\\16ff3194-5821-40cd-ae00-c9944920f977\\scratch\\node_modules';

function resolveTopicFile(topicArg) {
  const files = fs.readdirSync(TOPICS_DIR).filter(f => f.endsWith('.json')).sort();
  const clean = String(topicArg).toLowerCase().trim();

  const exact = files.find(f => f.toLowerCase() === clean || f.toLowerCase() === `${clean}.json`);
  if (exact) return path.join(TOPICS_DIR, exact);

  const numMatch = clean.match(/(\d+)/);
  if (numMatch) {
    const padded = numMatch[1].padStart(2, '0');
    const found = files.find(f => f.startsWith(`t${padded}_`));
    if (found) return path.join(TOPICS_DIR, found);
  }

  const found = files.find(f => f.toLowerCase().includes(clean));
  if (found) return path.join(TOPICS_DIR, found);

  throw new Error(`Could not resolve topic "${topicArg}". Available topics: ${files.join(', ')}`);
}

function analyzeSongMp3(mp3Path, topicId, lyrics) {
  const ffmpegPath = require(path.join(SCRATCH_MODULES, 'ffmpeg-static'));
  const { WaveFile } = require(path.join(SCRATCH_MODULES, 'wavefile'));
  const tempDir = process.env.TEMP || 'C:\\Users\\User\\AppData\\Local\\Temp';
  const tempVocWav = path.join(tempDir, `vocal_band_${topicId}.wav`);

  execSync(
    `"${ffmpegPath}" -y -i "${mp3Path}" -af "highpass=f=320,lowpass=f=3400" -ar 16000 -ac 2 -c:a pcm_s16le "${tempVocWav}"`,
    { stdio: 'pipe' }
  );

  const wav = new WaveFile(fs.readFileSync(tempVocWav));
  try { fs.unlinkSync(tempVocWav); } catch (_) {}
  wav.toBitDepth('32f');
  const samples = wav.getSamples();
  const left = samples[0];
  const right = samples[1] || samples[0];
  const sr = 16000;
  const duration = left.length / sr;

  const dt = 0.1;
  const hop = Math.floor(sr * dt);
  const frames = [];
  let maxVocal = 0.0001;

  for (let i = 0; i < left.length; i += hop) {
    const end = Math.min(left.length, i + hop);
    let sumMid = 0;
    let sumSide = 0;
    for (let j = i; j < end; j++) {
      const mid = 0.5 * (left[j] + right[j]);
      const side = 0.5 * (left[j] - right[j]);
      sumMid += mid * mid;
      sumSide += side * side;
    }
    const n = end - i;
    const rmsMid = Math.sqrt(sumMid / n);
    const rmsSide = Math.sqrt(sumSide / n);
    const vocalRaw = Math.max(0, rmsMid - 0.85 * rmsSide);
    frames.push({
      t: Number((i / sr).toFixed(1)),
      rmsMid,
      rmsSide,
      vocalRaw,
    });
  }

  for (let i = 0; i < frames.length; i++) {
    let s = 0, c = 0;
    for (let k = Math.max(0, i - 1); k <= Math.min(frames.length - 1, i + 1); k++) {
      s += frames[k].vocalRaw;
      c++;
    }
    frames[i].vocal = s / c;
    if (frames[i].vocal > maxVocal) maxVocal = frames[i].vocal;
  }

  for (let i = 0; i < frames.length; i++) {
    frames[i].norm = frames[i].vocal / maxVocal;
    const prev = i > 0 ? frames[i - 1].norm : 0;
    frames[i].onset = Math.max(0, frames[i].norm - prev);
  }

  let firstVocalSec = 2.0;
  for (let i = 4; i < frames.length - 12; i++) {
    let sum12 = 0;
    let max12 = 0;
    for (let k = 0; k < 12; k++) {
      const v = frames[i + k].norm;
      sum12 += v;
      if (v > max12) max12 = v;
    }
    const avg12 = sum12 / 12;
    if (frames[i].norm >= 0.45 && max12 >= 0.58 && avg12 >= 0.46) {
      let startIdx = i;
      while (
        startIdx > 1 &&
        frames[startIdx - 1].norm >= 0.25 &&
        frames[startIdx].norm >= frames[startIdx - 1].norm &&
        i - startIdx < 3
      ) {
        startIdx--;
      }
      firstVocalSec = frames[startIdx].t;
      break;
    }
  }

  let lastVocalSec = duration - 1.2;
  for (let i = frames.length - 4; i > 15; i--) {
    let sum8 = 0;
    let max8 = 0;
    for (let k = 0; k < 8 && i - k >= 0; k++) {
      const v = frames[i - k].norm;
      sum8 += v;
      if (v > max8) max8 = v;
    }
    if (frames[i].norm >= 0.30 && max8 >= 0.50 && sum8 / 8 >= 0.36) {
      lastVocalSec = frames[i].t;
      break;
    }
  }

  const startFrame = Math.max(0, Math.round(firstVocalSec / dt));
  const endFrame = Math.min(frames.length - 1, Math.round(lastVocalSec / dt));

  for (let i = 0; i < frames.length; i++) {
    const prevMin = Math.min(
      frames[Math.max(0, i - 1)].norm,
      frames[Math.max(0, i - 2)].norm,
      frames[Math.max(0, i - 3)].norm
    );
    let futSum = 0;
    let futMax = 0;
    const futLen = 10;
    for (let k = 0; k < futLen; k++) {
      const v = frames[Math.min(frames.length - 1, i + k)].norm;
      futSum += v;
      if (v > futMax) futMax = v;
    }
    const futAvg = futSum / futLen;
    const dipJump = Math.max(0, futAvg - prevMin);
    frames[i].phraseScore = (futMax >= 0.45 ? 1 : 0.25) * (1.5 * dipJump + 1.2 * frames[i].onset + 0.5 * futAvg);
  }

  // Search best bar duration in [2.1s .. 2.7s] (88 - 114 BPM, the range specified in all Suno prompts)
  let bestLag = 24;
  let bestCorr = -1;
  for (let lag = 22; lag <= 27; lag++) {
    let corr = 0;
    for (let i = startFrame; i + lag <= endFrame; i++) {
      corr += frames[i].phraseScore * frames[i + lag].phraseScore;
      if (i + 2 * lag <= endFrame) {
        corr += 0.6 * frames[i].phraseScore * frames[i + 2 * lag].phraseScore;
      }
    }
    if (corr > bestCorr) {
      bestCorr = corr;
      bestLag = lag;
    }
  }
  const estBarSec = bestLag * dt;
  const estBpm = Math.round((60 * 4) / estBarSec);

  const numLines = lyrics.length || 8;
  const suggestedTimestamps = computeBarGridLineStarts(frames, startFrame, endFrame, numLines, bestLag, dt);

  const phrasePeaks = [];
  for (let i = Math.max(2, startFrame - 5); i <= endFrame; i++) {
    if (
      frames[i].phraseScore >= 0.42 &&
      frames[i].phraseScore >= frames[i - 1].phraseScore &&
      frames[i].phraseScore >= frames[Math.min(frames.length - 1, i + 1)].phraseScore
    ) {
      if (phrasePeaks.length === 0 || frames[i].t - phrasePeaks[phrasePeaks.length - 1].t >= 1.7) {
        phrasePeaks.push({ t: frames[i].t, score: Number(frames[i].phraseScore.toFixed(2)) });
      } else if (frames[i].phraseScore > phrasePeaks[phrasePeaks.length - 1].score) {
        phrasePeaks[phrasePeaks.length - 1] = { t: frames[i].t, score: Number(frames[i].phraseScore.toFixed(2)) };
      }
    }
  }

  const totalVocalSpan = Math.max(numLines * 2.0, lastVocalSec - firstVocalSec);
  const approxBarsTotal = Math.round(totalVocalSpan / estBarSec);

  return {
    duration: Number(duration.toFixed(2)),
    firstVocalSec: Number(firstVocalSec.toFixed(1)),
    lastVocalSec: Number(lastVocalSec.toFixed(1)),
    totalVocalSpan: Number(totalVocalSpan.toFixed(1)),
    estBarSec: Number(estBarSec.toFixed(2)),
    estBpm,
    approxBarsTotal,
    phrasePeaks,
    suggestedTimestamps,
    frames,
  };
}

/**
 * Dynamic programming over musical bar grid (1 bar, 1.5 bars, 2 bars, or 4 bars for interlude)
 * anchored to breath-dip + vocal onset scores.
 */
function computeBarGridLineStarts(frames, startFrame, endFrame, numLines, barLag, dt) {
  let bestGlobalScore = -1e9;
  let bestPath = null;

  // Test bar lengths around barLag (from 21 to 27 frames = 2.1s to 2.7s)
  for (let B = 22; B <= 26; B++) {
    const dp = Array.from({ length: numLines }, () => new Float64Array(frames.length).fill(-1e9));
    const parent = Array.from({ length: numLines }, () => new Int32Array(frames.length).fill(-1));

    const l0Min = Math.max(2, startFrame - 3);
    const l0Max = Math.min(frames.length - numLines * 18, startFrame + 35);
    for (let f = l0Min; f <= l0Max; f++) {
      const dist = Math.abs(f - startFrame) * dt;
      dp[0][f] = frames[f].phraseScore * 2.4 - 0.35 * dist;
    }

    // Allowed musical line steps: 1 bar (B), 1.5 bars (1.5*B), 2 bars (2*B), 3 bars (3*B), 4 bars (4*B interlude)
    const mults = [
      { m: 1.0, pen: 0.0 },
      { m: 1.5, pen: 0.35 },
      { m: 2.0, pen: 0.15 },
      { m: 3.0, pen: 0.65 },
      { m: 4.0, pen: 0.85 },
    ];

    for (let k = 1; k < numLines; k++) {
      for (let p = l0Min; p <= endFrame; p++) {
        if (dp[k - 1][p] <= -1e8) continue;
        for (const { m, pen } of mults) {
          const target = Math.round(p + m * B);
          // Allow +-2 frames (0.2s) micro-timing jitter around the exact bar multiple
          for (let jitter = -2; jitter <= 2; jitter++) {
            const f = target + jitter;
            if (f <= p + 15 || f > endFrame) continue;
            const jitterPen = Math.abs(jitter) * 0.12;
            const val = dp[k - 1][p] + frames[f].phraseScore * 2.0 - pen - jitterPen;
            if (val > dp[k][f]) {
              dp[k][f] = val;
              parent[k][f] = p;
            }
          }
        }
      }
    }

    for (let f = l0Min; f <= endFrame; f++) {
      if (dp[numLines - 1][f] <= -1e8) continue;
      const remSec = (endFrame - f) * dt;
      if (remSec < 1.5 || remSec > 9.0) continue;
      const tailPen = Math.abs(remSec - B * dt) * 0.25;
      const score = dp[numLines - 1][f] - tailPen;
      if (score > bestGlobalScore) {
        bestGlobalScore = score;
        const path = new Array(numLines);
        let cur = f;
        for (let k = numLines - 1; k >= 0; k--) {
          path[k] = Number(frames[cur].t.toFixed(1));
          cur = parent[k][cur];
        }
        bestPath = path;
      }
    }
  }

  if (!bestPath) {
    const step = (endFrame - startFrame) / numLines;
    return Array.from({ length: numLines }, (_, idx) => Number(((startFrame + idx * step) * dt).toFixed(1)));
  }
  return bestPath;
}

function sliceCandidateClips(mp3Path, topicId, timestamps, duration) {
  const ffmpegPath = require(path.join(SCRATCH_MODULES, 'ffmpeg-static'));
  const clipsDir = path.join(
    'C:\\Users\\User\\.gemini\\antigravity\\brain\\16ff3194-5821-40cd-ae00-c9944920f977\\scratch\\clips_verify',
    topicId
  );
  fs.mkdirSync(clipsDir, { recursive: true });
  // Clean old clips in this topic dir
  for (const old of fs.readdirSync(clipsDir)) {
    try { fs.unlinkSync(path.join(clipsDir, old)); } catch (_) {}
  }
  const outFiles = [];
  for (let i = 0; i < timestamps.length; i++) {
    const start = timestamps[i];
    const next = i + 1 < timestamps.length ? timestamps[i + 1] : Math.min(duration, start + 3.5);
    const clipDur = Math.max(1.5, Number((next - start).toFixed(2)));
    const outPath = path.join(clipsDir, `L${i + 1}_${start.toFixed(1)}s.mp3`);
    execSync(
      `"${ffmpegPath}" -y -ss ${start} -t ${clipDur} -i "${mp3Path}" -c:a libmp3lame -q:a 5 "${outPath}"`,
      { stdio: 'pipe' }
    );
    outFiles.push({ line: i + 1, start, end: Number((start + clipDur).toFixed(1)), path: outPath });
  }
  return outFiles;
}

function printAnalysisReport(topicData, topicJsonPath, targetMp3Path, analysis) {
  console.log(`\n==================================================================`);
  console.log(`TOPIC : ${topicData.id} (${topicData.title_en} / ${topicData.title_vi})`);
  console.log(`MP3   : ${targetMp3Path}`);
  console.log(`JSON  : ${topicJsonPath}`);
  console.log(`------------------------------------------------------------------`);
  console.log(`Total Duration     : ${analysis.duration}s`);
  console.log(`First Vocal Entry  : ~${analysis.firstVocalSec}s  (Intro: 0.0s -> ${analysis.firstVocalSec}s)`);
  console.log(`Last Vocal Exit    : ~${analysis.lastVocalSec}s  (Vocal Span: ${analysis.totalVocalSpan}s)`);
  console.log(`Estimated Tempo    : ~${analysis.estBpm} BPM (1 bar ≈ ${analysis.estBarSec}s, ~${analysis.approxBarsTotal} bars sung)`);
  console.log(`Detected Phrase Onsets (${analysis.phrasePeaks.length}): ${analysis.phrasePeaks.map(p => `${p.t.toFixed(1)}s`).join(', ')}`);
  console.log(`Suggested 8-Line Timestamps (Bar-Grid DSP): [${analysis.suggestedTimestamps.join(', ')}]`);
  console.log(`------------------------------------------------------------------`);
  console.log(`Proposed Lyric Alignment Preview:`);
  topicData.song.lyrics.forEach((l, idx) => {
    const sugT = analysis.suggestedTimestamps[idx] ?? l.t;
    console.log(`  Line ${idx + 1}: old=${String(l.t).padStart(4, ' ')}s -> DSP=${String(sugT).padStart(4, ' ')}s | "${l.text}"`);
  });
  console.log(`------------------------------------------------------------------`);
  console.log(`0.2s Stereo Center-Vocal Envelope (V >= 0.50 indicates active singing):`);

  for (let i = 0; i < analysis.frames.length; i += 2) {
    const f0 = analysis.frames[i];
    const f1 = analysis.frames[i + 1] || f0;
    const norm = Math.max(f0.norm, f1.norm);
    const pScore = Math.max(f0.phraseScore, f1.phraseScore);
    const bar = '#'.repeat(Math.round(norm * 28));
    const isSuggested = analysis.suggestedTimestamps.some(st => Math.abs(st - f0.t) < 0.11);
    const marker = isSuggested
      ? ' <== [SUGGESTED LINE START]'
      : (pScore >= 0.48 && norm >= 0.45 ? ' <-- onset' : (norm < 0.22 ? ' (pause/inst)' : ''));
    console.log(`${f0.t.toFixed(1).padStart(5, ' ')}s | V:${norm.toFixed(2)} | ${bar}${marker}`);
  }
}

function main() {
  const args = process.argv.slice(2);
  if (args.length === 0) {
    console.error(
      'Usage:\n' +
      '  node integrate_song.js <topic> [source_mp3_path]\n' +
      '  node integrate_song.js --analyze <topic1> [topic2 ...]\n' +
      '  node integrate_song.js --slice <topic> [t1,t2,t3,t4,t5,t6,t7,t8]\n' +
      '  node integrate_song.js --apply <topic> <t1,t2,t3,t4,t5,t6,t7,t8>'
    );
    process.exit(1);
  }

  if (args[0] === '--apply') {
    const topicJsonPath = resolveTopicFile(args[1]);
    const topicData = JSON.parse(fs.readFileSync(topicJsonPath, 'utf8'));
    const ts = args[2].split(',').map(s => Number(Number(s.trim()).toFixed(1)));
    if (ts.length !== topicData.song.lyrics.length) {
      throw new Error(`Expected ${topicData.song.lyrics.length} timestamps, got ${ts.length}`);
    }
    topicData.song.lyrics.forEach((l, idx) => {
      l.t = ts[idx];
    });
    fs.writeFileSync(topicJsonPath, JSON.stringify(topicData, null, 2) + '\n', 'utf8');
    console.log(`Updated ${topicData.id} (${topicJsonPath}) with timestamps: [${ts.join(', ')}]`);
    return;
  }

  if (args[0] === '--slice') {
    const topicJsonPath = resolveTopicFile(args[1]);
    const topicData = JSON.parse(fs.readFileSync(topicJsonPath, 'utf8'));
    const targetMp3Path = path.join(APP_ROOT, 'assets', ...topicData.song.audio.split('/'));
    const analysis = analyzeSongMp3(targetMp3Path, topicData.id, topicData.song.lyrics);
    const ts = args[2]
      ? args[2].split(',').map(Number)
      : analysis.suggestedTimestamps;
    const clips = sliceCandidateClips(targetMp3Path, topicData.id, ts, analysis.duration);
    console.log(`Sliced ${clips.length} verification clips for ${topicData.id} (Duration: ${analysis.duration}s):`);
    clips.forEach((c, idx) => {
      const txt = topicData.song.lyrics[idx] ? topicData.song.lyrics[idx].text : '';
      console.log(`  Line ${c.line} [${c.start.toFixed(1)}s -> ${c.end.toFixed(1)}s]: ${c.path} | Expected: "${txt}"`);
    });
    return;
  }

  if (args[0] === '--analyze') {
    const targets = args.slice(1);
    for (const t of targets) {
      const topicJsonPath = resolveTopicFile(t);
      const topicData = JSON.parse(fs.readFileSync(topicJsonPath, 'utf8'));
      const targetMp3Path = path.join(APP_ROOT, 'assets', ...topicData.song.audio.split('/'));
      const analysis = analyzeSongMp3(targetMp3Path, topicData.id, topicData.song.lyrics);
      printAnalysisReport(topicData, topicJsonPath, targetMp3Path, analysis);
    }
    return;
  }

  const [topicArg, sourceMp3] = args;
  const topicJsonPath = resolveTopicFile(topicArg);
  const topicData = JSON.parse(fs.readFileSync(topicJsonPath, 'utf8'));
  const targetRelAudio = topicData.song.audio;
  const targetMp3Path = path.join(APP_ROOT, 'assets', ...targetRelAudio.split('/'));

  if (sourceMp3) {
    if (!fs.existsSync(sourceMp3)) {
      throw new Error(`Source MP3 file not found: ${sourceMp3}`);
    }
    fs.mkdirSync(path.dirname(targetMp3Path), { recursive: true });
    fs.copyFileSync(sourceMp3, targetMp3Path);
    const stat = fs.statSync(targetMp3Path);
    console.log(`[Copied] ${sourceMp3} (${stat.size} bytes) -> ${targetMp3Path}`);
  }

  const analysis = analyzeSongMp3(targetMp3Path, topicData.id, topicData.song.lyrics);
  printAnalysisReport(topicData, topicJsonPath, targetMp3Path, analysis);
}

main();
