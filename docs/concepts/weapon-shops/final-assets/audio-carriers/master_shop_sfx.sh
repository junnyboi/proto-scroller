#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$ROOT/../../../../.." && pwd)"
OUT="$REPO/game/audio/sfx/shop"
mkdir -p "$OUT"

master() {
  local input="$1"
  local start="$2"
  local duration="$3"
  local output="$4"
  local shaping="$5"
  ffmpeg -y -v error -ss "$start" -t "$duration" -i "$input" \
    -vn -ac 1 -ar 48000 \
    -af "highpass=f=45,lowpass=f=17000,${shaping},acompressor=threshold=0.05:ratio=4.0:attack=2:release=75:makeup=3.0,loudnorm=I=-13.0:TP=-1.0:LRA=5.0,afade=t=in:st=0:d=0.012,afade=t=out:st=$(awk -v d="$duration" 'BEGIN { printf "%.3f", d - 0.08 }'):d=0.08" \
    -c:a pcm_s16le "$output"
}

master \
  "$ROOT/upgrade-purchase-raw.wav" \
  0.75 1.35 \
  "$OUT/shop_purchase.wav" \
  "equalizer=f=110:t=q:w=0.9:g=2.5,equalizer=f=2500:t=q:w=1.2:g=1.8"

master \
  "$ROOT/chassis-repair-raw.wav" \
  0.55 1.80 \
  "$OUT/shop_repair.wav" \
  "equalizer=f=95:t=q:w=1.0:g=2.0,equalizer=f=5200:t=q:w=1.0:g=1.4"

for output in "$OUT/shop_purchase.wav" "$OUT/shop_repair.wav"; do
  ffprobe -v error -show_entries format=duration,size -show_entries stream=codec_name,sample_fmt,sample_rate,channels -of json "$output"
  ffmpeg -hide_banner -nostats -i "$output" -filter_complex ebur128=peak=true -f null - 2>&1 | tail -n 16
  sha256sum "$output"
done
