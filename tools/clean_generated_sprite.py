from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image


def is_magenta_key(red: int, green: int, blue: int) -> bool:
    dominant = min(red, blue)
    return (
        dominant >= 35
        and green <= 105
        and dominant >= max(1, green) * 1.55
        and abs(red - blue) <= 100
    )


def clean(source: Path, destination: Path, padding: int) -> None:
    image = Image.open(source).convert("RGBA")
    pixels = image.load()
    removed = 0
    for y in range(image.height):
        for x in range(image.width):
            red, green, blue, alpha = pixels[x, y]
            if alpha > 0 and is_magenta_key(red, green, blue):
                pixels[x, y] = (red, green, blue, 0)
                removed += 1

    alpha = image.getchannel("A")
    bbox = alpha.point(lambda value: 255 if value >= 8 else 0).getbbox()
    if bbox is None:
        raise RuntimeError(f"No opaque subject remains after cleanup: {source}")
    left = max(0, bbox[0] - padding)
    top = max(0, bbox[1] - padding)
    right = min(image.width, bbox[2] + padding)
    bottom = min(image.height, bbox[3] + padding)
    result = image.crop((left, top, right, bottom))
    destination.parent.mkdir(parents=True, exist_ok=True)
    result.save(destination, optimize=True)
    print(
        f"cleaned={source.name} output={destination.name} "
        f"removed_pixels={removed} size={result.width}x{result.height}"
    )


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("destination", type=Path)
    parser.add_argument("--padding", type=int, default=24)
    arguments = parser.parse_args()
    clean(arguments.source, arguments.destination, arguments.padding)
