from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image


def inspect(path: Path) -> None:
    image = Image.open(path).convert("RGBA")
    alpha = image.getchannel("A")
    width, height = image.size
    total = width * height
    histogram = alpha.histogram()
    transparent = sum(histogram[:8])
    opaque = sum(histogram[248:])
    corners = [
        image.getpixel((0, 0)),
        image.getpixel((width - 1, 0)),
        image.getpixel((0, height - 1)),
        image.getpixel((width - 1, height - 1)),
    ]
    print(
        f"{path.name}: size={width}x{height} "
        f"alpha_extrema={alpha.getextrema()} "
        f"transparent_fraction={transparent / total:.4f} "
        f"opaque_fraction={opaque / total:.4f} corners={corners}"
    )


if __name__ == "__main__":
    for argument in sys.argv[1:]:
        inspect(Path(argument))
