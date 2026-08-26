#!/usr/bin/env python3
"""Validate title-loop geometry, timing, and end-to-start visual continuity."""

from __future__ import annotations

import argparse
import json
import math
import subprocess
from pathlib import Path

EXPECTED = {
    "title-loop-landscape.mp4": (1280, 720),
    "title-loop-portrait.mp4": (720, 1280),
}
EXPECTED_FPS = 24.0
EXPECTED_FRAMES = 192
EXPECTED_DURATION = 8.0
MAX_SEAM_MAE = 0.004
MIN_SEAM_CORRELATION = 0.998
ANALYSIS_WIDTH = 320


def run(command: list[str]) -> bytes:
    return subprocess.run(command, check=True, stdout=subprocess.PIPE).stdout


def probe(path: Path) -> dict:
    payload = run(
        [
            "ffprobe",
            "-v",
            "error",
            "-select_streams",
            "v:0",
            "-show_entries",
            "stream=codec_name,width,height,r_frame_rate,avg_frame_rate,nb_frames,duration",
            "-show_entries",
            "format=duration",
            "-of",
            "json",
            str(path),
        ]
    )
    return json.loads(payload)


def decode_gray(path: Path, frame_index: int) -> bytes:
    return run(
        [
            "ffmpeg",
            "-hide_banner",
            "-loglevel",
            "error",
            "-i",
            str(path),
            "-vf",
            f"select=eq(n\\,{frame_index}),scale={ANALYSIS_WIDTH}:-2:flags=area,format=gray",
            "-vsync",
            "0",
            "-frames:v",
            "1",
            "-f",
            "rawvideo",
            "-",
        ]
    )


def fraction(value: str) -> float:
    numerator, denominator = value.split("/", 1)
    return float(numerator) / float(denominator)


def similarity(left: bytes, right: bytes) -> tuple[float, float]:
    if not left or len(left) != len(right):
        raise RuntimeError(f"Decoded frame lengths differ: {len(left)} vs {len(right)}")
    count = len(left)
    mean_left = sum(left) / count
    mean_right = sum(right) / count
    absolute_error = 0.0
    covariance = 0.0
    variance_left = 0.0
    variance_right = 0.0
    for left_value, right_value in zip(left, right):
        absolute_error += abs(left_value - right_value)
        centered_left = left_value - mean_left
        centered_right = right_value - mean_right
        covariance += centered_left * centered_right
        variance_left += centered_left * centered_left
        variance_right += centered_right * centered_right
    mae = absolute_error / count / 255.0
    denominator = math.sqrt(variance_left * variance_right)
    correlation = covariance / denominator if denominator else 1.0
    return mae, correlation


def validate(path: Path) -> dict:
    expected_geometry = EXPECTED.get(path.name)
    if expected_geometry is None:
        raise RuntimeError(f"Unsupported title loop: {path.name}")
    metadata = probe(path)
    stream = metadata["streams"][0]
    geometry = (int(stream["width"]), int(stream["height"]))
    fps = fraction(stream["avg_frame_rate"])
    frame_count = int(stream["nb_frames"])
    duration = float(stream["duration"])
    if stream["codec_name"] != "h264":
        raise RuntimeError(f"{path.name}: codec={stream['codec_name']} expected=h264")
    if geometry != expected_geometry:
        raise RuntimeError(f"{path.name}: geometry={geometry} expected={expected_geometry}")
    if abs(fps - EXPECTED_FPS) > 0.001:
        raise RuntimeError(f"{path.name}: fps={fps} expected={EXPECTED_FPS}")
    if frame_count != EXPECTED_FRAMES:
        raise RuntimeError(f"{path.name}: frames={frame_count} expected={EXPECTED_FRAMES}")
    if abs(duration - EXPECTED_DURATION) > 0.001:
        raise RuntimeError(f"{path.name}: duration={duration} expected={EXPECTED_DURATION}")
    first = decode_gray(path, 0)
    last = decode_gray(path, frame_count - 1)
    mae, correlation = similarity(first, last)
    if mae > MAX_SEAM_MAE:
        raise RuntimeError(f"{path.name}: seam_mae={mae:.9f} exceeds {MAX_SEAM_MAE}")
    if correlation < MIN_SEAM_CORRELATION:
        raise RuntimeError(
            f"{path.name}: seam_correlation={correlation:.9f} below {MIN_SEAM_CORRELATION}"
        )
    return {
        "file": path.name,
        "codec": stream["codec_name"],
        "geometry": list(geometry),
        "fps": fps,
        "frames": frame_count,
        "duration": duration,
        "seam_mae": mae,
        "seam_correlation": correlation,
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("videos", nargs="+", type=Path)
    args = parser.parse_args()
    report = [validate(path.resolve()) for path in args.videos]
    print(json.dumps({"status": "PASS", "loops": report}, indent=2))


if __name__ == "__main__":
    main()
