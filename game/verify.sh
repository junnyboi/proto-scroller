#!/usr/bin/env bash
set -euo pipefail

export PATH="$HOME/bin:$HOME/.local/bin:$PATH"
export GODOT_SILENCE_ROOT_WARNING=1
GODOT="${GODOT:-$HOME/bin/godot}"
MODE="standard"
if [[ "${1:-}" == "--full" ]]; then
  MODE="full"
elif [[ -n "${1:-}" ]]; then
  echo "Usage: ./verify.sh [--full]" >&2
  exit 2
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"
rm -rf artifacts
mkdir -p artifacts/title_screen artifacts/city_slice
START_EPOCH="$(date +%s)"

run_engine() {
  timeout --preserve-status --signal=TERM --kill-after=5s 35s "$@"
}

printf '%s\n' '[L3] import'
run_engine "$GODOT" --headless --path . --import

printf '%s\n' '[L1] parse and lint'
"$GODOT" --version | grep -Fq '4.7.1'
grep -Fq 'config/features=PackedStringArray("4.7", "GL Compatibility")' project.godot
grep -Fq 'window/size/viewport_width=1280' project.godot
grep -Fq 'window/size/viewport_height=720' project.godot
grep -Fq 'renderer/rendering_method="gl_compatibility"' project.godot
grep -Fq 'variant/extensions_support=false' export_presets.cfg
grep -Fq 'variant/thread_support=false' export_presets.cfg
CITY_SLICE_LINES="$(wc -l < scripts/gameplay/city_slice.gd)"
test "$CITY_SLICE_LINES" -le 1000
test "$CITY_SLICE_LINES" -lt 650
printf 'city_slice_lines=%s\n' "$CITY_SLICE_LINES"
test -z "$(find art audio -type f \( -iname '*candidate*' -o -iname '*carrier*' -o -iname '*original*' \) -print -quit)"
for cue in audio/sfx/rampage/overdrive_activation.wav audio/sfx/rampage/combo_break.wav; do
  test "$(ffprobe -v error -select_streams a:0 -show_entries stream=sample_rate -of csv=p=0 "$cue")" = 48000
  test "$(ffprobe -v error -select_streams a:0 -show_entries stream=codec_name -of csv=p=0 "$cue")" = pcm_s16le
done
while IFS= read -r -d '' script; do
  gdlint "$script"
  run_engine "$GODOT" --headless --path . --check-only -s "$script"
done < <(find scripts selftest test -type f -name '*.gd' -print0 | sort -z)

printf '%s\n' '[L2] GUT unit suite'
run_engine "$GODOT" --headless -d -s addons/gut/gut_cmdln.gd -gdir=res://test -gexit \
  | tee artifacts/gut.log
test -s artifacts/unit-tests-ran.txt
UNIT_TESTS="$(cat artifacts/unit-tests-ran.txt)"
test "$UNIT_TESTS" -ge 2
printf 'unit_tests=%s\n' "$UNIT_TESTS"

printf '%s\n' '[L3] launch boot'
run_engine "$GODOT" --headless --path . --quit-after 2

printf '%s\n' '[L4] headless injected-input scenario'
run_engine "$GODOT" --headless --fixed-fps 60 --path . \
  -s selftest/title_screen_scenario.gd
jq -e '.done == true and .result == "PASS" and .shot.status == "SKIP"' \
  artifacts/title_screen/report.json >/dev/null

printf '%s\n' '[L4] city-slice headless scenario'
run_engine "$GODOT" --headless --fixed-fps 60 --path . \
  -s selftest/city_slice_scenario.gd
jq -e '.done == true and .result == "PASS" and .shot.status == "SKIP"' \
  artifacts/city_slice/report.json >/dev/null

SHOT_HASH=""
if [[ "$MODE" == "full" ]]; then
  printf '%s\n' '[L5] windowed render scenario'
  run_engine xvfb-run -a "$GODOT" --path . --resolution 1280x720 \
    -s selftest/title_screen_scenario.gd
  jq -e '.done == true and .result == "PASS" and .shot.status == "PASS"' \
    artifacts/title_screen/report.json >/dev/null
  test -s artifacts/title_screen/title-screen.png
  DIMENSIONS="$(file artifacts/title_screen/title-screen.png)"
  grep -Fq '1280 x 720' <<< "$DIMENSIONS"
  SHOT_HASH="$(sha256sum artifacts/title_screen/title-screen.png | cut -d' ' -f1)"
  printf 'shot_sha256=%s\n' "$SHOT_HASH"

  printf '%s\n' '[L5] windowed city-slice render scenario'
  run_engine xvfb-run -a "$GODOT" --path . --resolution 1280x720 \
    -s selftest/city_slice_scenario.gd
  jq -e '.done == true and .result == "PASS" and .shot.status == "PASS"' \
    artifacts/city_slice/report.json >/dev/null
  test -s artifacts/city_slice/city-slice.png
  CITY_DIMENSIONS="$(file artifacts/city_slice/city-slice.png)"
  grep -Fq '1280 x 720' <<< "$CITY_DIMENSIONS"

  printf '%s\n' '[L5] initial city-slice visual scenario'
  run_engine xvfb-run -a "$GODOT" --path . --resolution 1280x720 \
    -s selftest/city_slice_visual_scenario.gd
  test -s artifacts/city_slice/city-slice-initial.png
  INITIAL_CITY_DIMENSIONS="$(file artifacts/city_slice/city-slice-initial.png)"
  grep -Fq '1280 x 720' <<< "$INITIAL_CITY_DIMENSIONS"

  printf '%s\n' '[WEB] cache-bypassed release export'
  rm -rf ../client/public/game
  mkdir -p ../client/public/game
  run_engine "$GODOT" --headless --path . --export-release Web \
    ../client/public/game/game.html
  test -s ../client/public/game/game.html
  test "$(find ../client/public/game -maxdepth 1 -type f -name '*.wasm' -size +0c -printf '.' | wc -c)" -ge 1
  test "$(find ../client/public/game -maxdepth 1 -type f -name '*.pck' -size +0c -printf '.' | wc -c)" -ge 1
  test "$(find ../client/public/game -maxdepth 1 -type f -name '*.js' -size +0c -printf '.' | wc -c)" -ge 1
  PCK_BYTES="$(stat -c %s ../client/public/game/game.pck)"
  test "$PCK_BYTES" -le 8388608
  printf 'pck_bytes=%s\n' "$PCK_BYTES"
  (
    cd ../client/public/game
    find . -maxdepth 1 -type f -print0 | LC_ALL=C sort -z | xargs -0 sha256sum
  ) > artifacts/web-export.sha256
  printf 'web_files=%s\n' "$(wc -l < artifacts/web-export.sha256)"
fi

END_EPOCH="$(date +%s)"
jq -n \
  --arg mode "$MODE" \
  --arg status 'PASS' \
  --argjson unit_tests "$UNIT_TESTS" \
  --arg shot_sha256 "$SHOT_HASH" \
  --argjson seconds "$((END_EPOCH - START_EPOCH))" \
  '{mode:$mode,status:$status,unit_tests:$unit_tests,shot_sha256:$shot_sha256,seconds:$seconds}' \
  > artifacts/verify.json
printf '[VERIFY-PASS] mode=%s seconds=%s\n' "$MODE" "$((END_EPOCH - START_EPOCH))"
