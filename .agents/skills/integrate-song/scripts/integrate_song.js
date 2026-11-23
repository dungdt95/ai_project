#!/usr/bin/env node
/**
 * Song Asset Copier & Acoustic Envelope Analyzer
 * Usage: node integrate_song.js <topic_id_or_number> <source_mp3_path>
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

function main() {
  const args = process.argv.slice(2);
  if (args.length < 2) {
    console.error('Usage: node integrate_song.js <topic> <mp3_path>');
    process.exit(1);
  }

  const [topicArg, sourceMp3] = args;
  if (!fs.existsSync(sourceMp3)) {
    throw new Error(`Source MP3 file not found: ${sourceMp3}`);
  }

  const topicJsonPath = resolveTopicFile(topicArg);
  const topicData = JSON.parse(fs.readFileSync(topicJsonPath, 'utf8'));
  const targetRelAudio = topicData.song.audio;
  const targetMp3Path = path.join(APP_ROOT, 'assets', ...targetRelAudio.split('/'));

  console.log(`=== Song Integrator & Acoustic Analyzer ===`);
  console.log(`Topic       : ${topicData.id} (${topicData.title_en} / ${topicData.title_vi})`);
  console.log(`JSON Path   : ${topicJsonPath}`);
  console.log(`Source MP3  : ${sourceMp3}`);
  console.log(`Target Asset: ${targetMp3Path}`);

  // 1. Copy MP3 to target asset path
  fs.mkdirSync(path.dirname(targetMp3Path), { recursive: true });
  fs.copyFileSync(sourceMp3, targetMp3Path);
  const stat = fs.statSync(targetMp3Path);
  console.log(`[1/2] Copied MP3 (${stat.size} bytes) -> ${targetMp3Path}`);

  // 2. Probe duration & vocal energy profile via ffmpeg-static
  try {
    const ffmpegPath = require(path.join(SCRATCH_MODULES, 'ffmpeg-static'));
    const { WaveFile } = require(path.join(SCRATCH_MODULES, 'wavefile'));
    const tempWav = path.join(process.env.TEMP || 'C:\\Users\\User\\AppData\\Local\\Temp', `vocal_${topicData.id}.wav`);

    execSync(`"${ffmpegPath}" -y -i "${targetMp3Path}" -af "highpass=f=250,lowpass=f=3800" -ar 16000 -ac 2 -c:a pcm_s16le "${tempWav}"`, { stdio: 'pipe' });

    const wav = new WaveFile(fs.readFileSync(tempWav));
    wav.toBitDepth('32f');
    const samples = wav.getSamples();
    const left = samples[0];
    const right = samples[1] || samples[0];
    const sr = 16000;
    const duration = left.length / sr;
    console.log(`[2/2] Audio Duration: ${duration.toFixed(2)}s`);

    // Print 0.2s stereo Mid/Side vocal dominance profile
    const stepSamples = Math.floor(sr * 0.2);
    const rows = [];
    let maxVocal = 0.0001;
    for (let i = 0; i < left.length; i += stepSamples) {
      const end = Math.min(left.length, i + stepSamples);
      let sumMid = 0, sumSide = 0;
      for (let j = i; j < end; j++) {
        const mid = 0.5 * (left[j] + right[j]);
        const side = 0.5 * (left[j] - right[j]);
        sumMid += mid * mid;
        sumSide += side * side;
      }
      const rmsMid = Math.sqrt(sumMid / (end - i));
      const rmsSide = Math.sqrt(sumSide / (end - i));
      const vocalScore = Math.max(0, rmsMid - 0.6 * rmsSide);
      if (vocalScore > maxVocal) maxVocal = vocalScore;
      rows.push({ t: i / sr, rmsMid, rmsSide, vocalScore });
    }

    console.log(`\n0.2s Stereo Center-Vocal Envelope:`);
    for (const r of rows) {
      const norm = r.vocalScore / maxVocal;
      const bar = '#'.repeat(Math.round(norm * 30));
      console.log(`${r.t.toFixed(1).padStart(5, ' ')}s | V:${norm.toFixed(2)} | ${bar}`);
    }

    console.log(`\nCurrent Lyrics in JSON (${topicData.song.lyrics.length} lines):`);
    topicData.song.lyrics.forEach((l, idx) => {
      console.log(`  Line ${idx + 1} [t=${l.t}s]: ${l.text}`);
    });
    console.log(`\nNEXT STEP: Call read_file on "${targetMp3Path}" to listen directly and calibrate exact 0.1s timestamps.`);
  } catch (e) {
    console.log(`[2/2] Note: Could not run ffmpeg probe (${e.message}). Proceed to read_file on "${targetMp3Path}".`);
  }
}

main();
