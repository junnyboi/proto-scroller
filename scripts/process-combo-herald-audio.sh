#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_DIR="${ROOT}/docs/combo-feedback-carriers"
OUTPUT_DIR="${ROOT}/game/audio/voice/combo"
mkdir -p "${OUTPUT_DIR}"

names=(double_kill triple_kill overkill unstoppable annihilation extinction_event)
declare -A starts=(
  [double_kill]=1.82
  [triple_kill]=1.28
  [overkill]=1.12
  [unstoppable]=0.08
  [annihilation]=0.92
  [extinction_event]=0.00
)
declare -A ends=(
  [double_kill]=3.00
  [triple_kill]=3.00
  [overkill]=2.48
  [unstoppable]=2.10
  [annihilation]=2.76
  [extinction_event]=2.70
)

for name in "${names[@]}"; do
  input="${SOURCE_DIR}/${name}.mp4"
  output="${OUTPUT_DIR}/${name}.wav"
  [[ -s "${input}" ]] || { printf 'Missing carrier: %s\n' "${input}" >&2; exit 1; }
  ffmpeg -hide_banner -loglevel error -y -i "${input}" -vn \
    -af "atrim=start=${starts[$name]}:end=${ends[$name]},asetpts=N/SR/TB,afade=t=in:st=0:d=0.01,loudnorm=I=-16:TP=-1.5:LRA=7,apad=pad_dur=0.12" \
    -ar 48000 -ac 1 -c:a pcm_s16le "${output}"
  ffprobe -v error -select_streams a:0 \
    -show_entries stream=codec_name,sample_rate,channels:format=duration \
    -of default=noprint_wrappers=1 "${output}"
done
