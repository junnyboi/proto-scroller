from __future__ import annotations

import sys
from collections import deque
from pathlib import Path

from PIL import Image


def is_magenta(red: int, green: int, blue: int) -> bool:
    dominant = min(red, blue)
    return (
        dominant >= 35
        and green <= 120
        and dominant >= max(1, green) * 1.45
        and abs(red - blue) <= 110
    )


def clean(path: Path) -> None:
    image = Image.open(path).convert("RGBA")
    pixels = image.load()
    width, height = image.size
    candidate: set[tuple[int, int]] = set()
    for y in range(height):
        for x in range(width):
            red, green, blue, alpha = pixels[x, y]
            if alpha > 0 and is_magenta(red, green, blue):
                candidate.add((x, y))

    queue: deque[tuple[int, int]] = deque()
    exterior: set[tuple[int, int]] = set()
    for x, y in candidate:
        for neighbor_x in range(max(0, x - 1), min(width, x + 2)):
            for neighbor_y in range(max(0, y - 1), min(height, y + 2)):
                if pixels[neighbor_x, neighbor_y][3] < 8:
                    queue.append((x, y))
                    exterior.add((x, y))
                    break
            if (x, y) in exterior:
                break

    while queue:
        x, y = queue.popleft()
        for neighbor_x in range(max(0, x - 1), min(width, x + 2)):
            for neighbor_y in range(max(0, y - 1), min(height, y + 2)):
                position = (neighbor_x, neighbor_y)
                if position in candidate and position not in exterior:
                    exterior.add(position)
                    queue.append(position)

    for x, y in exterior:
        red, green, blue, _alpha = pixels[x, y]
        pixels[x, y] = (red, green, blue, 0)
    image.save(path, optimize=True)
    print(f"cleaned={path.name} exterior_magenta_pixels={len(exterior)}")


if __name__ == "__main__":
    for argument in sys.argv[1:]:
        clean(Path(argument))
