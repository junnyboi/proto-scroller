#!/usr/bin/env python3
"""Create clean concept and bounded runtime derivatives from the GPT Image 2 dossier crest."""

from __future__ import annotations

from pathlib import Path

import cv2
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "docs/match-debrief-concepts/after-action-dossier-crest-source.png"
CONCEPT = ROOT / "docs/match-debrief-concepts/after-action-dossier-crest.png"
RUNTIME = ROOT / "game/art/ui/match_debrief/dossier_crest.png"


def clean_crest(source: Path) -> Image.Image:
    image = Image.open(source).convert("RGBA")
    pixels = np.asarray(image).copy()
    rgb = pixels[:, :, :3].astype(np.float32)
    alpha = pixels[:, :, 3].astype(np.float32)

    # Remove residual neon-green chroma without touching the cyan circuit glow.
    chroma = (
        (rgb[:, :, 1] > 60.0)
        & (rgb[:, :, 1] > rgb[:, :, 0] * 1.22)
        & (rgb[:, :, 1] > rgb[:, :, 2] * 1.40)
    )
    alpha[chroma] = 0.0

    # Retain the largest connected visible object and discard detached generation specks.
    mask = (alpha > 10.0).astype(np.uint8)
    component_count, labels, stats, _centroids = cv2.connectedComponentsWithStats(mask, 8)
    if component_count <= 1:
        raise RuntimeError("Generated crest has no visible connected component")
    largest_label = 1 + int(np.argmax(stats[1:, cv2.CC_STAT_AREA]))
    alpha[labels != largest_label] = 0.0

    ys, xs = np.nonzero(alpha > 4.0)
    if xs.size == 0 or ys.size == 0:
        raise RuntimeError("Generated crest became empty after cleanup")
    left, right = int(xs.min()), int(xs.max()) + 1
    top, bottom = int(ys.min()), int(ys.max()) + 1
    content_width = right - left
    content_height = bottom - top
    padding = max(24, int(max(content_width, content_height) * 0.055))
    side = max(content_width, content_height) + padding * 2

    pixels[:, :, 3] = np.clip(alpha, 0.0, 255.0).astype(np.uint8)
    cleaned = Image.fromarray(pixels, "RGBA").crop((left, top, right, bottom))
    square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    x = (side - content_width) // 2
    y = (side - content_height) // 2
    square.alpha_composite(cleaned, (x, y))
    return square


def save_derivative(image: Image.Image, path: Path, size: int) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    derivative = image.resize((size, size), Image.Resampling.LANCZOS)
    derivative.save(path, format="PNG", optimize=True)


def main() -> None:
    crest = clean_crest(SOURCE)
    save_derivative(crest, CONCEPT, 1024)
    save_derivative(crest, RUNTIME, 256)
    print(f"concept={CONCEPT} size=1024x1024")
    print(f"runtime={RUNTIME} size=256x256")


if __name__ == "__main__":
    main()
