#!/usr/bin/env python3
"""Create transparent 512px runtime derivatives from GPT Image 2 combo insignias."""

from __future__ import annotations

import hashlib
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE_DIR = ROOT / "docs" / "combo-feedback-concepts"
OUTPUT_DIR = ROOT / "game" / "art" / "ui" / "combo_herald"
NAMES = (
    "double_kill",
    "triple_kill",
    "overkill",
    "unstoppable",
    "annihilation",
    "extinction_event",
)


def is_chroma(red: int, green: int, blue: int) -> bool:
    """Match temporary pink/magenta pixels while preserving authored red accents."""
    return (
        red >= 90
        and blue >= 75
        and green <= 170
        and (red + blue) >= (green * 2.25)
        and abs(red - blue) <= 135
    )


def process(source: Path, destination: Path) -> tuple[str, int]:
    image = Image.open(source).convert("RGBA")
    pixels = image.load()
    removed = 0
    for y in range(image.height):
        for x in range(image.width):
            red, green, blue, alpha = pixels[x, y]
            if alpha > 0 and is_chroma(red, green, blue):
                pixels[x, y] = (red, green, blue, 0)
                removed += 1

    bbox = image.getbbox()
    if bbox is None:
        raise RuntimeError(f"Chroma cleanup removed the complete image: {source}")
    subject = image.crop(bbox)
    canvas = Image.new("RGBA", (2048, 2048), (0, 0, 0, 0))
    max_subject = 1840
    scale = min(max_subject / subject.width, max_subject / subject.height)
    target = (
        max(1, round(subject.width * scale)),
        max(1, round(subject.height * scale)),
    )
    subject = subject.resize(target, Image.Resampling.LANCZOS)
    offset = ((canvas.width - target[0]) // 2, (canvas.height - target[1]) // 2)
    canvas.alpha_composite(subject, offset)
    runtime = canvas.resize((512, 512), Image.Resampling.LANCZOS)
    destination.parent.mkdir(parents=True, exist_ok=True)
    runtime.save(destination, format="PNG", optimize=True)
    digest = hashlib.sha256(destination.read_bytes()).hexdigest()
    return digest, removed


def main() -> None:
    for name in NAMES:
        source = SOURCE_DIR / f"{name}.png"
        destination = OUTPUT_DIR / f"{name}.png"
        digest, removed = process(source, destination)
        print(f"{name}: removed={removed} sha256={digest}")


if __name__ == "__main__":
    main()
