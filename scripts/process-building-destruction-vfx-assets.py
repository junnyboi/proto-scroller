#!/usr/bin/env python3
"""Build transparent runtime debris/VFX textures from GPT Image 2 sources."""

from __future__ import annotations

from pathlib import Path

import cv2
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE_DIR = ROOT / "docs" / "building-destruction-vfx-concepts"
RUNTIME_DIR = ROOT / "game" / "art" / "city" / "destructibles" / "debris"
SIZE = 128
PADDING_RATIO = 0.10
ASSETS = {
    "concrete-chunk-source.png": "concrete_chunk.png",
    "glass-shard-source.png": "glass_shard.png",
    "steel-fragment-source.png": "steel_fragment.png",
    "dust-puff-source.png": "dust_puff.png",
    "impact-flash-source.png": "impact_flash.png",
}


def process(source: Path, output: Path) -> None:
    rgba = np.asarray(Image.open(source).convert("RGBA"), dtype=np.uint8).copy()
    red = rgba[:, :, 0].astype(np.float32)
    green = rgba[:, :, 1].astype(np.float32)
    blue = rgba[:, :, 2].astype(np.float32)
    alpha = rgba[:, :, 3]

    # GPT Image 2 used magenta only as the removable staging color. Delete its
    # antialiased fringe and glitch-line remnants without touching cyan glass,
    # orange sparks, charcoal concrete, or neutral dust.
    magenta = (
        (red > 46.0)
        & (blue > 40.0)
        & (red > green * 1.30 + 8.0)
        & (blue > green * 1.12 + 6.0)
    )
    alpha[magenta] = 0
    alpha[alpha < 10] = 0

    # Retain the largest authored silhouette. This removes any detached staging
    # residue touching the original canvas edge while preserving internal alpha.
    binary = (alpha > 18).astype(np.uint8)
    count, labels, stats, _ = cv2.connectedComponentsWithStats(binary, connectivity=8)
    if count <= 1:
        raise RuntimeError(f"No visible subject found in {source}")
    areas = stats[1:, cv2.CC_STAT_AREA]
    subject_label = int(np.argmax(areas)) + 1
    subject = (labels == subject_label).astype(np.uint8)
    subject = cv2.dilate(subject, np.ones((5, 5), np.uint8), iterations=1)
    alpha[subject == 0] = 0
    rgba[:, :, 3] = alpha

    visible = np.argwhere(alpha > 0)
    if visible.size == 0:
        raise RuntimeError(f"Cleanup removed the entire subject in {source}")
    y0, x0 = visible.min(axis=0)
    y1, x1 = visible.max(axis=0) + 1
    trimmed = Image.fromarray(rgba, "RGBA").crop((int(x0), int(y0), int(x1), int(y1)))

    side = max(trimmed.size)
    padded_side = int(round(side * (1.0 + PADDING_RATIO * 2.0)))
    canvas = Image.new("RGBA", (padded_side, padded_side), (0, 0, 0, 0))
    offset = ((padded_side - trimmed.width) // 2, (padded_side - trimmed.height) // 2)
    canvas.alpha_composite(trimmed, offset)
    runtime = canvas.resize((SIZE, SIZE), Image.Resampling.LANCZOS)

    # Suppress subpixel colored ghosts introduced by downsampling fully
    # transparent texels.
    runtime_rgba = np.asarray(runtime, dtype=np.uint8).copy()
    runtime_rgba[runtime_rgba[:, :, 3] <= 2] = (0, 0, 0, 0)
    output.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(runtime_rgba, "RGBA").save(output, optimize=True)


if __name__ == "__main__":
    for source_name, output_name in ASSETS.items():
        process(SOURCE_DIR / source_name, RUNTIME_DIR / output_name)
        print(f"built {output_name}")
