#!/usr/bin/env bash
set -euo pipefail

export PATH="$HOME/bin:$HOME/.local/bin:$PATH"
export GODOT_SILENCE_ROOT_WARNING=1
GODOT="${GODOT:-$(command -v godot || command -v godot4 || true)}"
test -n "$GODOT"
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
mkdir -p \
	  artifacts/charge_attack \
	  artifacts/title_screen \
  artifacts/city_slice \
	  artifacts/endless_terrain \
	  artifacts/enemy_variety \
	  artifacts/street_volatility \
	  artifacts/directives \
	  artifacts/upgrades \
	  artifacts/weapon_drones
: > artifacts/.gdignore
START_EPOCH="$(date +%s)"
ENGINE_TIMEOUT_SECONDS=120
EXPORT_TIMEOUT_SECONDS=300
PCK_BUDGET_BYTES=$((16 * 1024 * 1024))

run_engine() {
	timeout --preserve-status --signal=TERM --kill-after=5s \
		"${ENGINE_TIMEOUT_SECONDS}s" "$@"
}

run_export() {
	timeout --preserve-status --signal=TERM --kill-after=5s \
		"${EXPORT_TIMEOUT_SECONDS}s" "$@"
}

printf '%s\n' '[L3] import'
run_engine "$GODOT" --headless --path . --import

printf '%s\n' '[L1] parse and lint'
"$GODOT" --version | grep -Fq '4.7.2'
grep -Fq 'config/features=PackedStringArray("4.7", "GL Compatibility")' project.godot
grep -Fq 'window/size/viewport_width=1280' project.godot
grep -Fq 'window/size/viewport_height=720' project.godot
grep -Fq 'window/stretch/mode="canvas_items"' project.godot
grep -Fq 'window/stretch/aspect="keep"' project.godot
grep -Fq 'renderer/rendering_method="gl_compatibility"' project.godot
grep -Fq 'variant/extensions_support=false' export_presets.cfg
grep -Fq 'variant/thread_support=false' export_presets.cfg
CITY_SLICE_LINES="$(wc -l < scripts/gameplay/city_slice.gd)"
test "$CITY_SLICE_LINES" -le 650
printf 'city_slice_lines=%s\n' "$CITY_SLICE_LINES"
test -z "$(find art audio -type f \( -iname '*candidate*' -o -iname '*carrier*' -o -iname '*original*' \) -print -quit)"
for cue in \
  audio/sfx/rampage/overdrive_activation.wav \
  audio/sfx/rampage/combo_break.wav \
	  audio/sfx/upgrades/upgrade_confirm.wav \
	  audio/sfx/robot/robot_footstep.wav \
	  audio/sfx/robot/robot_servo.wav \
	  audio/sfx/robot/robot_dash_warp_drive.wav \
	  audio/sfx/robot/dodge_energy_recharged.wav \
	  audio/sfx/robot/ground_slam_impact.wav \
	  audio/sfx/robot/double_punch_impact.wav \
	  audio/voice/air_target_acquired.wav \
	  audio/voice/target_lost.wav \
	  audio/voice/target_destroyed.wav \
	  audio/sfx/debris/debris_enemy_thud.wav; do
  test "$(ffprobe -v error -select_streams a:0 -show_entries stream=sample_rate -of csv=p=0 "$cue")" = 48000
		test "$(ffprobe -v error -select_streams a:0 -show_entries stream=codec_name -of csv=p=0 "$cue")" = pcm_s16le
done
DASH_WARP_DURATION="$(
	ffprobe -v error -show_entries format=duration -of csv=p=0 \
		audio/sfx/robot/robot_dash_warp_drive.wav
)"
awk -v duration="$DASH_WARP_DURATION" 'BEGIN {
	exit !(duration >= 1.0 && duration <= 3.0)
}'
PARSE_LOG="artifacts/parse-lint.log"
: > "$PARSE_LOG"
while IFS= read -r -d '' script; do
	  gdlint "$script"
	  run_engine "$GODOT" --headless --path . --check-only -s "$script" 2>&1 \
	    | tee -a "$PARSE_LOG"
done < <(find scripts selftest test -type f -name '*.gd' -print0 | sort -z)
if grep -Eq 'SCRIPT ERROR|Parse Error|ERROR:|FATAL|CRASH' "$PARSE_LOG"; then
	printf '%s\n' '[PARSE-FAIL] Godot logged a script or resource diagnostic' >&2
	exit 1
fi

printf '%s\n' '[L2] GUT unit suite'
run_engine "$GODOT" --headless -d -s addons/gut/gut_cmdln.gd -gdir=res://test -gexit \
  | tee artifacts/gut.log
test -s artifacts/unit-tests-ran.txt
UNIT_TESTS="$(cat artifacts/unit-tests-ran.txt)"
test "$UNIT_TESTS" -ge 2
printf 'unit_tests=%s\n' "$UNIT_TESTS"

printf '%s\n' '[L3] launch boot'
run_engine "$GODOT" --headless --path . -s selftest/boot_smoke_scenario.gd

printf '%s\n' '[L3] bounded direct launch shutdown'
run_engine "$GODOT" --headless --audio-driver Dummy --fixed-fps 60 --path . \
  --quit-after 120 2>&1 | tee artifacts/direct-boot.log
if grep -Eq \
  'ObjectDB instances were leaked|resources still in use at exit|AudioStreamPlaybackOggVorbis|Resource still in use:.*city_pressure_loop' \
  artifacts/direct-boot.log; then
  printf '%s\n' '[DIRECT-BOOT-FAIL] retained Ogg playback during shutdown' >&2
  exit 1
fi

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

printf '%s\n' '[L4] charged-smash headless scenario'
run_engine "$GODOT" --headless --fixed-fps 60 --path . \
	-s selftest/charge_attack_scenario.gd
jq -e '.done == true and .result == "PASS" and .shot.status == "SKIP"' \
	artifacts/charge_attack/report.json >/dev/null

printf '%s\n' '[L4] directive-card headless lifecycle scenario'
run_engine "$GODOT" --headless --fixed-fps 60 --path . \
	-s selftest/directive_card_visual_scenario.gd

printf '%s\n' '[L4] district-building gallery headless scenario'
run_engine "$GODOT" --headless --fixed-fps 60 --path . \
  -s selftest/district_building_gallery_scenario.gd
jq -e '.done == true and .result == "PASS" and (.districts | length) == 5' \
  artifacts/district_gallery/report.json >/dev/null

printf '%s\n' '[L4] enemy-variety headless scenario'
run_engine "$GODOT" --headless --fixed-fps 60 --path . \
  -s selftest/enemy_variety_scenario.gd
jq -e '.done == true and .result == "PASS" and .shot.status == "SKIP"' \
  artifacts/enemy_variety/report.json >/dev/null

printf '%s\n' '[L4] street-volatility headless scenario'
run_engine "$GODOT" --headless --fixed-fps 60 --path . \
  -s selftest/street_volatility_scenario.gd
jq -e '.done == true and .result == "PASS" and .shot.status == "SKIP"' \
  artifacts/street_volatility/report.json >/dev/null

printf '%s\n' '[L4] endless-terrain headless scenario'
run_engine "$GODOT" --headless --fixed-fps 60 --path . \
  -s selftest/endless_terrain_scenario.gd
jq -e '.done == true and .result == "PASS" and .shot.status == "SKIP"' \
  artifacts/endless_terrain/report.json >/dev/null

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
  cp artifacts/title_screen/title-screen.png \
    artifacts/title_screen/title-screen-landscape.png
  SHOT_HASH="$(sha256sum artifacts/title_screen/title-screen.png | cut -d' ' -f1)"
  printf 'shot_sha256=%s\n' "$SHOT_HASH"

  printf '%s\n' '[L5] portrait title render scenario'
  PROTO_SCROLLER_PORTRAIT=1 run_engine xvfb-run -a "$GODOT" --path . \
    --resolution 720x1280 -s selftest/title_screen_scenario.gd
  jq -e '.done == true and .result == "PASS" and .shot.status == "PASS"' \
    artifacts/title_screen/report.json >/dev/null
  PORTRAIT_TITLE_DIMENSIONS="$(file artifacts/title_screen/title-screen.png)"
  grep -Fq '720 x 1280' <<< "$PORTRAIT_TITLE_DIMENSIONS"
  mv artifacts/title_screen/title-screen.png \
    artifacts/title_screen/title-screen-portrait.png
  cp artifacts/title_screen/title-screen-landscape.png \
    artifacts/title_screen/title-screen.png

  printf '%s\n' '[L5] windowed city-slice render scenario'
  run_engine xvfb-run -a "$GODOT" --path . --resolution 1280x720 \
    -s selftest/city_slice_scenario.gd
  jq -e '.done == true and .result == "PASS" and .shot.status == "PASS"' \
    artifacts/city_slice/report.json >/dev/null
	  test -s artifacts/city_slice/city-slice.png
	  CITY_DIMENSIONS="$(file artifacts/city_slice/city-slice.png)"
	  grep -Fq '1280 x 720' <<< "$CITY_DIMENSIONS"
	  test -s artifacts/city_slice/city-slice-wrecked.png
	  test -s artifacts/city_slice/city-slice-rubble.png
	  grep -Fq '1280 x 720' <<< "$(file artifacts/city_slice/city-slice-wrecked.png)"
	  grep -Fq '1280 x 720' <<< "$(file artifacts/city_slice/city-slice-rubble.png)"
	  cp artifacts/city_slice/city-slice.png \
	    artifacts/city_slice/city-slice-landscape.png
	  mv artifacts/city_slice/city-slice-wrecked.png \
	    artifacts/city_slice/city-slice-wrecked-landscape.png
	  mv artifacts/city_slice/city-slice-rubble.png \
	    artifacts/city_slice/city-slice-rubble-landscape.png

	  printf '%s\n' '[L5] portrait city-slice wreck and rubble render scenario'
	  PROTO_SCROLLER_PORTRAIT=1 run_engine xvfb-run -a "$GODOT" --path . \
	    --resolution 720x1280 -s selftest/city_slice_scenario.gd
	  jq -e '.done == true and .result == "PASS" and .shot.status == "PASS"' \
	    artifacts/city_slice/report.json >/dev/null
	  test -s artifacts/city_slice/city-slice.png
	  test -s artifacts/city_slice/city-slice-wrecked.png
	  test -s artifacts/city_slice/city-slice-rubble.png
	  grep -Fq '720 x 1280' <<< "$(file artifacts/city_slice/city-slice.png)"
	  grep -Fq '720 x 1280' <<< "$(file artifacts/city_slice/city-slice-wrecked.png)"
	  grep -Fq '720 x 1280' <<< "$(file artifacts/city_slice/city-slice-rubble.png)"
	  mv artifacts/city_slice/city-slice.png \
	    artifacts/city_slice/city-slice-portrait.png
	  mv artifacts/city_slice/city-slice-wrecked.png \
	    artifacts/city_slice/city-slice-wrecked-portrait.png
	  mv artifacts/city_slice/city-slice-rubble.png \
	    artifacts/city_slice/city-slice-rubble-portrait.png
	  cp artifacts/city_slice/city-slice-landscape.png \
	    artifacts/city_slice/city-slice.png
	  cp artifacts/city_slice/city-slice-wrecked-landscape.png \
	    artifacts/city_slice/city-slice-wrecked.png
		  cp artifacts/city_slice/city-slice-rubble-landscape.png \
		    artifacts/city_slice/city-slice-rubble.png

		  printf '%s\n' '[L5] landscape charged-smash visual scenario'
		  run_engine xvfb-run -a "$GODOT" --path . --resolution 1280x720 \
		    -s selftest/charge_attack_scenario.gd
		  jq -e '.done == true and .result == "PASS" and .shot.status == "PASS"' \
		    artifacts/charge_attack/report.json >/dev/null
		  grep -Fq '1280 x 720' <<< "$(file artifacts/charge_attack/charge-attack.png)"
		  mv artifacts/charge_attack/charge-attack.png \
		    artifacts/charge_attack/charge-attack-landscape.png

		  printf '%s\n' '[L5] portrait charged-smash visual scenario'
		  PROTO_SCROLLER_PORTRAIT=1 run_engine xvfb-run -a "$GODOT" --path . \
		    --resolution 720x1280 -s selftest/charge_attack_scenario.gd
		  jq -e '.done == true and .result == "PASS" and .shot.status == "PASS"' \
		    artifacts/charge_attack/report.json >/dev/null
		  grep -Fq '720 x 1280' <<< "$(file artifacts/charge_attack/charge-attack.png)"
		  mv artifacts/charge_attack/charge-attack.png \
		    artifacts/charge_attack/charge-attack-portrait.png
		  cp artifacts/charge_attack/charge-attack-landscape.png \
		    artifacts/charge_attack/charge-attack.png

		  printf '%s\n' '[L5] landscape district-building gallery scenario'
	  run_engine xvfb-run -a "$GODOT" --path . --resolution 1280x720 \
	    -s selftest/district_building_gallery_scenario.gd
	  jq -e '.done == true and .result == "PASS" and (.districts | length) == 5' \
	    artifacts/district_gallery/report.json >/dev/null
	  test "$(find artifacts/district_gallery -maxdepth 1 -type f \
	    -name '*-landscape.png' -size +0c | wc -l)" -eq 5
	  while IFS= read -r gallery_shot; do
	    grep -Fq '1280 x 720' <<< "$(file "$gallery_shot")"
	  done < <(find artifacts/district_gallery -maxdepth 1 -type f \
	    -name '*-landscape.png' | LC_ALL=C sort)

	  printf '%s\n' '[L5] portrait district-building gallery scenario'
	  PROTO_SCROLLER_PORTRAIT=1 run_engine xvfb-run -a "$GODOT" --path . \
	    --resolution 720x1280 -s selftest/district_building_gallery_scenario.gd
	  jq -e '.done == true and .result == "PASS" and (.districts | length) == 5' \
	    artifacts/district_gallery/report.json >/dev/null
	  test "$(find artifacts/district_gallery -maxdepth 1 -type f \
	    -name '*-portrait.png' -size +0c | wc -l)" -eq 5
	  while IFS= read -r gallery_shot; do
	    grep -Fq '720 x 1280' <<< "$(file "$gallery_shot")"
	  done < <(find artifacts/district_gallery -maxdepth 1 -type f \
	    -name '*-portrait.png' | LC_ALL=C sort)

	  printf '%s\n' '[L5] windowed enemy-variety render scenario'
  run_engine xvfb-run -a "$GODOT" --path . --resolution 1280x720 \
    -s selftest/enemy_variety_scenario.gd
  jq -e '.done == true and .result == "PASS" and .shot.status == "PASS"' \
    artifacts/enemy_variety/report.json >/dev/null
  test -s artifacts/enemy_variety/enemy-variety.png
  ENEMY_VARIETY_DIMENSIONS="$(file artifacts/enemy_variety/enemy-variety.png)"
  grep -Fq '1280 x 720' <<< "$ENEMY_VARIETY_DIMENSIONS"

  printf '%s\n' '[L5] windowed street-volatility render scenario'
  run_engine xvfb-run -a "$GODOT" --path . --resolution 1280x720 \
    -s selftest/street_volatility_scenario.gd
  jq -e '.done == true and .result == "PASS" and .shot.status == "PASS"' \
    artifacts/street_volatility/report.json >/dev/null
  test -s artifacts/street_volatility/street-volatility.png
  STREET_VOLATILITY_DIMENSIONS="$(file artifacts/street_volatility/street-volatility.png)"
  grep -Fq '1280 x 720' <<< "$STREET_VOLATILITY_DIMENSIONS"

  printf '%s\n' '[L5] windowed endless-terrain render scenario'
  run_engine xvfb-run -a "$GODOT" --path . --resolution 1280x720 \
    -s selftest/endless_terrain_scenario.gd
  jq -e '.done == true and .result == "PASS" and .shot.status == "PASS"' \
    artifacts/endless_terrain/report.json >/dev/null
	  test -s artifacts/endless_terrain/endless-terrain.png
	  grep -Fq '1280 x 720' <<< "$(file artifacts/endless_terrain/endless-terrain.png)"
	  cp artifacts/endless_terrain/endless-terrain.png \
	    artifacts/endless_terrain/endless-terrain-landscape.png

	  printf '%s\n' '[L5] portrait endless-terrain district scenario'
	  PROTO_SCROLLER_PORTRAIT=1 run_engine xvfb-run -a "$GODOT" --path . \
	    --resolution 720x1280 -s selftest/endless_terrain_scenario.gd
	  jq -e '.done == true and .result == "PASS" and .shot.status == "PASS"' \
	    artifacts/endless_terrain/report.json >/dev/null
	  grep -Fq '720 x 1280' <<< "$(file artifacts/endless_terrain/endless-terrain.png)"
	  mv artifacts/endless_terrain/endless-terrain.png \
	    artifacts/endless_terrain/endless-terrain-portrait.png
	  cp artifacts/endless_terrain/endless-terrain-landscape.png \
	    artifacts/endless_terrain/endless-terrain.png

	  printf '%s\n' '[L5] initial city-slice visual scenario'
  run_engine xvfb-run -a "$GODOT" --path . --resolution 1280x720 \
    -s selftest/city_slice_visual_scenario.gd
  test -s artifacts/city_slice/city-slice-initial.png
  INITIAL_CITY_DIMENSIONS="$(file artifacts/city_slice/city-slice-initial.png)"
  grep -Fq '1280 x 720' <<< "$INITIAL_CITY_DIMENSIONS"
  cp artifacts/city_slice/city-slice-initial.png \
    artifacts/city_slice/city-slice-initial-landscape.png

  printf '%s\n' '[L5] portrait initial city-slice visual scenario'
  PROTO_SCROLLER_PORTRAIT=1 run_engine xvfb-run -a "$GODOT" --path . \
    --resolution 720x1280 -s selftest/city_slice_visual_scenario.gd
  PORTRAIT_CITY_DIMENSIONS="$(file artifacts/city_slice/city-slice-initial.png)"
  grep -Fq '720 x 1280' <<< "$PORTRAIT_CITY_DIMENSIONS"
	  mv artifacts/city_slice/city-slice-initial.png \
	    artifacts/city_slice/city-slice-initial-portrait.png
		  cp artifacts/city_slice/city-slice-initial-landscape.png \
		    artifacts/city_slice/city-slice-initial.png

	  printf '%s\n' '[L5] portrait mobile-controls visual scenario'
	  run_engine xvfb-run -a "$GODOT" --path . --resolution 720x1280 \
	    -s selftest/mobile_controls_visual_scenario.gd
	  test -s artifacts/mobile_controls/mobile-controls-portrait.png
	  grep -Fq '720 x 1280' <<< "$(
	    file artifacts/mobile_controls/mobile-controls-portrait.png
	  )"

		  printf '%s\n' '[L5] landscape upgrade overlay visual scenario'
	  run_engine xvfb-run -a "$GODOT" --path . --resolution 1280x720 \
	    -s selftest/upgrade_overlay_visual_scenario.gd
	  test -s artifacts/upgrades/upgrade-choice.png
	  grep -Fq '1280 x 720' <<< "$(file artifacts/upgrades/upgrade-choice.png)"
	  mv artifacts/upgrades/upgrade-choice.png \
	    artifacts/upgrades/upgrade-choice-landscape.png

	  printf '%s\n' '[L5] portrait upgrade overlay visual scenario'
	  PROTO_SCROLLER_PORTRAIT=1 run_engine xvfb-run -a "$GODOT" --path . \
	    --resolution 720x1280 -s selftest/upgrade_overlay_visual_scenario.gd
	  test -s artifacts/upgrades/upgrade-choice.png
	  grep -Fq '720 x 1280' <<< "$(file artifacts/upgrades/upgrade-choice.png)"
	  mv artifacts/upgrades/upgrade-choice.png \
	    artifacts/upgrades/upgrade-choice-portrait.png

	  printf '%s\n' '[L5] landscape failed-directive card scenario'
	  run_engine xvfb-run -a "$GODOT" --path . --resolution 1280x720 \
	    -s selftest/directive_card_visual_scenario.gd
	  test -s artifacts/directives/directive-failed.png
	  grep -Fq '1280 x 720' <<< "$(file artifacts/directives/directive-failed.png)"
	  mv artifacts/directives/directive-failed.png \
	    artifacts/directives/directive-failed-landscape.png

	  printf '%s\n' '[L5] portrait failed-directive card scenario'
	  PROTO_SCROLLER_PORTRAIT=1 run_engine xvfb-run -a "$GODOT" --path . \
	    --resolution 720x1280 -s selftest/directive_card_visual_scenario.gd
	  test -s artifacts/directives/directive-failed.png
	  grep -Fq '720 x 1280' <<< "$(file artifacts/directives/directive-failed.png)"
	  mv artifacts/directives/directive-failed.png \
	    artifacts/directives/directive-failed-portrait.png

	  printf '%s\n' '[L5] landscape weapon-drone visual scenario'
	  run_engine xvfb-run -a "$GODOT" --path . --resolution 1280x720 \
	    -s selftest/weapon_drone_visual_scenario.gd
	  test -s artifacts/weapon_drones/weapon-drones-rank-one.png
	  test -s artifacts/weapon_drones/weapon-drones-max-rank.png
	  grep -Fq '1280 x 720' <<< "$(file artifacts/weapon_drones/weapon-drones-rank-one.png)"
	  grep -Fq '1280 x 720' <<< "$(file artifacts/weapon_drones/weapon-drones-max-rank.png)"
	  mv artifacts/weapon_drones/weapon-drones-rank-one.png \
	    artifacts/weapon_drones/weapon-drones-rank-one-landscape.png
	  mv artifacts/weapon_drones/weapon-drones-max-rank.png \
	    artifacts/weapon_drones/weapon-drones-max-rank-landscape.png

	  printf '%s\n' '[L5] portrait weapon-drone visual scenario'
	  PROTO_SCROLLER_PORTRAIT=1 run_engine xvfb-run -a "$GODOT" --path . \
	    --resolution 720x1280 -s selftest/weapon_drone_visual_scenario.gd
	  test -s artifacts/weapon_drones/weapon-drones-rank-one.png
	  test -s artifacts/weapon_drones/weapon-drones-max-rank.png
	  grep -Fq '720 x 1280' <<< "$(file artifacts/weapon_drones/weapon-drones-rank-one.png)"
	  grep -Fq '720 x 1280' <<< "$(file artifacts/weapon_drones/weapon-drones-max-rank.png)"
	  mv artifacts/weapon_drones/weapon-drones-rank-one.png \
	    artifacts/weapon_drones/weapon-drones-rank-one-portrait.png
	  mv artifacts/weapon_drones/weapon-drones-max-rank.png \
	    artifacts/weapon_drones/weapon-drones-max-rank-portrait.png

	  printf '%s\n' '[WEB] cache-bypassed release export'
  rm -rf ../client/public/game
  mkdir -p ../client/public/game
	  run_export "$GODOT" --headless --quiet --path . --export-release Web \
	    ../client/public/game/game.html
  test -s ../client/public/game/game.html
  test "$(find ../client/public/game -maxdepth 1 -type f -name '*.wasm' -size +0c -printf '.' | wc -c)" -ge 1
  test "$(find ../client/public/game -maxdepth 1 -type f -name '*.pck' -size +0c -printf '.' | wc -c)" -ge 1
	  test "$(find ../client/public/game -maxdepth 1 -type f -name '*.js' -size +0c -printf '.' | wc -c)" -ge 1
	  PCK_BYTES="$(stat -c %s ../client/public/game/game.pck)"
	  test "$PCK_BYTES" -le "$PCK_BUDGET_BYTES"
	  printf 'pck_bytes=%s pck_budget_bytes=%s\n' "$PCK_BYTES" "$PCK_BUDGET_BYTES"
  (
    cd ../client/public/game
    find . -maxdepth 1 -type f -print0 | LC_ALL=C sort -z | xargs -0 sha256sum
	  ) > artifacts/web-export.sha256
	  printf 'web_files=%s\n' "$(wc -l < artifacts/web-export.sha256)"

	  printf '%s\n' '[WEB] automated browser upgrade-transition smoke'
	  (
	    cd ..
	    timeout --preserve-status --signal=TERM --kill-after=5s 180s pnpm smoke:web
	  )
	  jq -e '
	    .status == "PASS"
		    and (.phases | map(.status)) == [
		      "ready",
		      "charge_started",
		      "charge_progress",
		      "charge_released",
		      "attack_started",
	      "upgrade_visible",
	      "upgrade_resolved",
	      "east_walk_ok",
	      "pass"
	    ]
	  ' artifacts/browser/upgrade-transition.json >/dev/null
	  test -s artifacts/browser/upgrade-transition.png
	  grep -Fq '1280 x 720' <<< "$(file artifacts/browser/upgrade-transition.png)"
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
