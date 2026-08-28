#!/usr/bin/env python3
"""Finalize Phase 4 PCK and audibility evidence after both candidates pass."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
MANIFEST = REPO / "docs" / "manifests" / "asset_optimization_phase4_audio.json"
VERIFICATION = REPO / "docs" / "manifests" / "asset_optimization_phase4_audio_verification.json"
REPORTS = {
    "baseline": Path("/tmp/proto-scroller-phase4-baseline-audio.json"),
    "candidate_a": Path("/tmp/proto-scroller-phase4-candidate-a-audio.json"),
    "candidate_b": Path("/tmp/proto-scroller-phase4-candidate-b-audio.json"),
    "browser": Path("/tmp/proto-scroller-phase4-browser-audio.json"),
}
EXPORTS = {
    "baseline": Path("/tmp/proto-scroller-phase4-baseline"),
    "candidate_a": Path("/tmp/proto-scroller-phase4-candidate-a"),
    "candidate_b": Path("/tmp/proto-scroller-phase4-candidate-b"),
}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def artifact_set(root: Path) -> dict:
    result = {}
    for extension in ("html", "js", "wasm", "pck"):
        path = root / f"game.{extension}"
        if not path.is_file() or path.stat().st_size <= 0:
            raise AssertionError(f"Missing export artifact: {path}")
        result[extension] = {
            "bytes": path.stat().st_size,
            "sha256": sha256(path),
        }
    return result


def main() -> None:
    manifest = load(MANIFEST)
    reports = {key: load(path) for key, path in REPORTS.items()}
    for stage in ("baseline", "candidate_a", "candidate_b"):
        report = reports[stage]
        if report["status"] != "PASS" or report["errors"]:
            raise AssertionError(f"Headless audio verification failed: {stage}")
        if report["candidate_count"] != 49:
            raise AssertionError(f"Unexpected stream count: {stage}")
    browser = reports["browser"]
    if browser["status"] != "PASS" or browser["probe"]["errors"]:
        raise AssertionError("Browser audio verification failed")
    if browser["probe"]["stream_count"] != 49 or browser["nonemptyBufferStartCount"] < 49:
        raise AssertionError("Browser did not start every Phase 4 stream")
    if "running" not in browser["audioContextStates"]:
        raise AssertionError("Browser Web Audio context is not running")
    if len([item for item in browser["worklets"] if item["state"] == "fulfilled"]) != 2:
        raise AssertionError("Both browser audio worklets did not fulfill")

    exports = {key: artifact_set(path) for key, path in EXPORTS.items()}
    baseline_pck = exports["baseline"]["pck"]["bytes"]
    candidate_a_pck = exports["candidate_a"]["pck"]["bytes"]
    candidate_b_pck = exports["candidate_b"]["pck"]["bytes"]
    if not baseline_pck > candidate_a_pck > candidate_b_pck:
        raise AssertionError("Phase 4 candidate PCK sizes are not strictly decreasing")

    baseline_by_path = {item["source_path"]: item for item in reports["baseline"]["results"]}
    candidate_by_path = {item["source_path"]: item for item in reports["candidate_b"]["results"]}
    comparisons = []
    for source_path in sorted(baseline_by_path):
        before = baseline_by_path[source_path]
        after = candidate_by_path[source_path]
        peak_ratio = after["decoded_peak"] / before["decoded_peak"]
        rms_ratio = after["decoded_rms"] / before["decoded_rms"]
        duration_delta = after["length_seconds"] - before["length_seconds"]
        if not after["player_started"] or after["bus_muted"]:
            raise AssertionError(f"Playback or bus failure: {source_path}")
        if after["mix_rate_hz"] != 24000 or after["format"] != 3:
            raise AssertionError(f"Unexpected final import contract: {source_path}")
        if not 0.50 <= peak_ratio <= 1.50:
            raise AssertionError(f"Peak changed excessively: {source_path} {peak_ratio}")
        if not 0.70 <= rms_ratio <= 1.30:
            raise AssertionError(f"RMS changed excessively: {source_path} {rms_ratio}")
        if abs(duration_delta) > 0.001:
            raise AssertionError(f"Duration changed excessively: {source_path} {duration_delta}")
        comparisons.append(
            {
                "source_path": source_path,
                "baseline_mix_rate_hz": before["mix_rate_hz"],
                "candidate_mix_rate_hz": after["mix_rate_hz"],
                "peak_ratio": round(peak_ratio, 8),
                "rms_ratio": round(rms_ratio, 8),
                "duration_delta_seconds": round(duration_delta, 8),
                "candidate_peak": after["decoded_peak"],
                "candidate_rms": after["decoded_rms"],
                "candidate_nonzero_samples": after["nonzero_samples"],
                "player_started": after["player_started"],
                "bus_muted": after["bus_muted"],
            }
        )

    pck_results = {
        "baseline": exports["baseline"],
        "candidate_a": exports["candidate_a"],
        "candidate_b": exports["candidate_b"],
        "candidate_a_reduction_bytes": baseline_pck - candidate_a_pck,
        "candidate_b_incremental_reduction_bytes": candidate_a_pck - candidate_b_pck,
        "candidate_b_total_reduction_bytes": baseline_pck - candidate_b_pck,
        "candidate_b_total_reduction_percent": round(
            (baseline_pck - candidate_b_pck) * 100.0 / baseline_pck, 6
        ),
    }
    signal_summary = {
        "stream_count": len(comparisons),
        "minimum_candidate_peak": min(item["candidate_peak"] for item in comparisons),
        "minimum_candidate_rms": min(item["candidate_rms"] for item in comparisons),
        "minimum_peak_ratio": min(item["peak_ratio"] for item in comparisons),
        "maximum_peak_ratio": max(item["peak_ratio"] for item in comparisons),
        "minimum_rms_ratio": min(item["rms_ratio"] for item in comparisons),
        "maximum_rms_ratio": max(item["rms_ratio"] for item in comparisons),
        "maximum_absolute_duration_delta_seconds": max(
            abs(item["duration_delta_seconds"]) for item in comparisons
        ),
        "all_players_started": all(item["player_started"] for item in comparisons),
        "all_buses_unmuted": all(not item["bus_muted"] for item in comparisons),
    }
    browser_summary = {
        "status": browser["status"],
        "stream_count": browser["probe"]["stream_count"],
        "voice_count": browser["probe"]["voice_count"],
        "sfx_count": browser["probe"]["sfx_count"],
        "nonempty_buffer_start_count": browser["nonemptyBufferStartCount"],
        "audio_context_states": browser["audioContextStates"],
        "fulfilled_worklet_urls": [
            item["url"] for item in browser["worklets"] if item["state"] == "fulfilled"
        ],
        "request_failures": browser["requestFailures"],
        "material_browser_errors": browser["materialBrowserErrors"],
    }
    manifest["pck_results"] = pck_results
    manifest["verification_summary"] = {
        "headless_decode_and_playback": signal_summary,
        "browser_audio": browser_summary,
    }
    MANIFEST.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    VERIFICATION.write_text(
        json.dumps(
            {
                "phase": 4,
                "status": "PASS",
                "pck_results": pck_results,
                "signal_summary": signal_summary,
                "browser_summary": browser_summary,
                "stream_comparisons": comparisons,
            },
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )
    print(json.dumps({
        "status": "PASS",
        "pck_results": pck_results,
        "signal_summary": signal_summary,
        "browser_summary": browser_summary,
    }, indent=2))


if __name__ == "__main__":
    main()
