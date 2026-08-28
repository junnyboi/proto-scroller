#!/usr/bin/env python3
"""Generate staged evidence for Phase 4 non-music audio resampling."""

from __future__ import annotations

import array
import hashlib
import json
import math
import re
import subprocess
import sys
import wave
from pathlib import Path
from typing import Any

REPO = Path(__file__).resolve().parents[1]
GAME = REPO / "game"
OUTPUT = REPO / "docs" / "manifests" / "asset_optimization_phase4_audio.json"
GROUP_ROOTS = {
    "voice": GAME / "audio" / "voice",
    "sfx": GAME / "audio" / "sfx",
}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def read_optional(text: str, key: str, default: str) -> str:
    match = re.search(rf"^{re.escape(key)}=(.+)$", text, re.MULTILINE)
    return default if not match else match.group(1).strip().strip('"')


def source_signal(path: Path) -> dict[str, Any]:
    with wave.open(str(path), "rb") as handle:
        channels = handle.getnchannels()
        sample_width = handle.getsampwidth()
        sample_rate = handle.getframerate()
        frame_count = handle.getnframes()
        raw = handle.readframes(frame_count)
    if sample_width != 2:
        raise AssertionError(f"Expected 16-bit PCM source WAV: {path}")
    samples = array.array("h")
    samples.frombytes(raw)
    if sys.byteorder != "little":
        samples.byteswap()
    if not samples:
        raise AssertionError(f"Empty source WAV: {path}")
    peak = max(abs(value) for value in samples) / 32768.0
    rms = math.sqrt(sum(float(value) * float(value) for value in samples) / len(samples)) / 32768.0
    return {
        "channels": channels,
        "sample_width_bits": sample_width * 8,
        "sample_rate_hz": sample_rate,
        "frame_count": frame_count,
        "duration_seconds": round(frame_count / sample_rate, 6),
        "source_peak": round(peak, 8),
        "source_rms": round(rms, 8),
    }


def inspect(group: str, source: Path) -> dict[str, Any]:
    import_file = Path(str(source) + ".import")
    text = import_file.read_text(encoding="utf-8")
    source_res = "res://" + source.relative_to(GAME).as_posix()
    imported_res = read_optional(text, "path", "")
    if not imported_res:
        raise AssertionError(f"Missing imported path: {import_file}")
    imported = GAME / imported_res.removeprefix("res://")
    state = {
        "group": group,
        "source_path": source_res,
        "import_metadata_path": source_res + ".import",
        "uid": read_optional(text, "uid", ""),
        "source_bytes": source.stat().st_size,
        "source_sha256": sha256(source),
        **source_signal(source),
        "force_8_bit": read_optional(text, "force/8_bit", "false") == "true",
        "force_mono": read_optional(text, "force/mono", "false") == "true",
        "force_max_rate": read_optional(text, "force/max_rate", "false") == "true",
        "force_max_rate_hz": int(read_optional(text, "force/max_rate_hz", "44100")),
        "trim": read_optional(text, "edit/trim", "false") == "true",
        "normalize": read_optional(text, "edit/normalize", "false") == "true",
        "loop_mode": int(read_optional(text, "edit/loop_mode", "0")),
        "loop_begin": int(read_optional(text, "edit/loop_begin", "0")),
        "loop_end": int(read_optional(text, "edit/loop_end", "-1")),
        "compression_mode": int(read_optional(text, "compress/mode", "0")),
        "resample_mode": int(read_optional(text, "edit/resample/mode", "0")),
        "resample_rate_hz": int(read_optional(text, "edit/resample/rate", "44100")),
        "imported_path": imported_res,
        "imported_bytes": imported.stat().st_size,
        "imported_sha256": sha256(imported),
    }
    if state["source_peak"] <= 0.0 or state["source_rms"] <= 0.0:
        raise AssertionError(f"Silent source WAV: {source_res}")
    return state


def git_head() -> str:
    return subprocess.check_output(
        ["git", "-C", str(REPO), "rev-parse", "HEAD"], text=True
    ).strip()


def candidate_paths() -> list[tuple[str, Path]]:
    result: list[tuple[str, Path]] = []
    for group, root in GROUP_ROOTS.items():
        result.extend((group, path) for path in sorted(root.rglob("*.wav")))
    return result


def stage_summary(assets: list[dict[str, Any]], stage: str) -> dict[str, Any]:
    by_group: dict[str, dict[str, int]] = {}
    before_total = 0
    stage_total = 0
    for group in GROUP_ROOTS:
        group_assets = [asset for asset in assets if asset["group"] == group]
        before_bytes = sum(asset["before"]["imported_bytes"] for asset in group_assets)
        after_bytes = sum(asset[stage]["imported_bytes"] for asset in group_assets)
        by_group[group] = {
            "before_imported_bytes": before_bytes,
            "stage_imported_bytes": after_bytes,
            "imported_reduction_bytes": before_bytes - after_bytes,
        }
        before_total += before_bytes
        stage_total += after_bytes
    return {
        "before_imported_bytes": before_total,
        "stage_imported_bytes": stage_total,
        "imported_reduction_bytes": before_total - stage_total,
        "by_group": by_group,
    }


def before() -> None:
    assets = []
    counts = {group: 0 for group in GROUP_ROOTS}
    for group, source in candidate_paths():
        state = inspect(group, source)
        if state["compression_mode"] != 2:
            raise AssertionError(f"Phase 4 expects QOA mode 2: {state['source_path']}")
        if state["resample_mode"] != 0:
            raise AssertionError(f"Candidate already resampled: {state['source_path']}")
        counts[group] += 1
        assets.append(
            {
                "group": group,
                "source_path": state["source_path"],
                "before": state,
                "candidate_a_voice_24khz": None,
                "candidate_b_all_24khz": None,
            }
        )
    document = {
        "phase": 4,
        "title": "Selective non-music audio sample-rate reduction",
        "baseline_source_revision": git_head(),
        "target_policy": {
            "compression_mode": 2,
            "force_max_rate": True,
            "force_max_rate_hz": 24000,
            "source_masters_modified": False,
        },
        "candidate_count": len(assets),
        "group_counts": counts,
        "policy_change_counts": {
            group: sum(
                1
                for asset in assets
                if asset["group"] == group
                and not (
                    asset["before"]["force_max_rate"]
                    and asset["before"]["force_max_rate_hz"] == 24000
                )
            )
            for group in GROUP_ROOTS
        },
        "assets": assets,
        "stage_summaries": {},
    }
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(document, indent=2) + "\n", encoding="utf-8")


def after_voice() -> None:
    document = json.loads(OUTPUT.read_text(encoding="utf-8"))
    for asset in document["assets"]:
        source = GAME / asset["source_path"].removeprefix("res://")
        current = inspect(asset["group"], source)
        verify_identity(asset["before"], current)
        if asset["group"] == "voice":
            verify_target_policy(current)
        else:
            if (
                current["force_max_rate"] != asset["before"]["force_max_rate"]
                or current["force_max_rate_hz"]
                != asset["before"]["force_max_rate_hz"]
            ):
                raise AssertionError(f"SFX changed during Candidate A: {asset['source_path']}")
        asset["candidate_a_voice_24khz"] = current
    document["candidate_a_base_revision"] = git_head()
    document["stage_summaries"]["candidate_a_voice_24khz"] = stage_summary(
        document["assets"], "candidate_a_voice_24khz"
    )
    OUTPUT.write_text(json.dumps(document, indent=2) + "\n", encoding="utf-8")


def after_all() -> None:
    document = json.loads(OUTPUT.read_text(encoding="utf-8"))
    for asset in document["assets"]:
        source = GAME / asset["source_path"].removeprefix("res://")
        current = inspect(asset["group"], source)
        verify_identity(asset["before"], current)
        verify_target_policy(current)
        asset["candidate_b_all_24khz"] = current
    document["candidate_b_base_revision"] = git_head()
    document["stage_summaries"]["candidate_b_all_24khz"] = stage_summary(
        document["assets"], "candidate_b_all_24khz"
    )
    OUTPUT.write_text(json.dumps(document, indent=2) + "\n", encoding="utf-8")


def verify_identity(before_state: dict[str, Any], current: dict[str, Any]) -> None:
    keys = (
        "uid",
        "source_bytes",
        "source_sha256",
        "channels",
        "sample_width_bits",
        "sample_rate_hz",
        "frame_count",
        "duration_seconds",
        "source_peak",
        "source_rms",
        "force_8_bit",
        "force_mono",
        "resample_mode",
        "resample_rate_hz",
        "trim",
        "normalize",
        "loop_mode",
        "loop_begin",
        "loop_end",
        "compression_mode",
    )
    for key in keys:
        if before_state[key] != current[key]:
            raise AssertionError(f"Audio identity changed for {current['source_path']}: {key}")


def verify_target_policy(state: dict[str, Any]) -> None:
    if state["compression_mode"] != 2:
        raise AssertionError(f"QOA mode changed for {state['source_path']}")
    if not state["force_max_rate"] or state["force_max_rate_hz"] != 24000:
        raise AssertionError(f"24 kHz policy missing for {state['source_path']}")


def main() -> None:
    actions = {"before": before, "after_voice": after_voice, "after_all": after_all}
    if len(sys.argv) != 2 or sys.argv[1] not in actions:
        raise SystemExit("Usage: audit_phase4_audio_imports.py before|after_voice|after_all")
    actions[sys.argv[1]]()
    print(OUTPUT)


if __name__ == "__main__":
    main()
