from __future__ import annotations

import sys
from collections import deque
from pathlib import Path

from PIL import Image

MIN_COMPONENT_SIZE = 300


def is_magenta(red: int, green: int, blue: int) -> bool:
    dominant = min(red, blue)
    return (
        dominant >= 35
        and green <= 130
        and dominant >= max(1, green) * 1.35
        and abs(red - blue) <= 125
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

    visited: set[tuple[int, int]] = set()
    removed = 0
    removed_components = 0
    for start in candidate:
        if start in visited:
            continue
        queue: deque[tuple[int, int]] = deque([start])
        component: list[tuple[int, int]] = []
        visited.add(start)
        while queue:
            x, y = queue.popleft()
            component.append((x, y))
            for neighbor_x in range(max(0, x - 1), min(width, x + 2)):
                for neighbor_y in range(max(0, y - 1), min(height, y + 2)):
                    position = (neighbor_x, neighbor_y)
                    if position in candidate and position not in visited:
                        visited.add(position)
                        queue.append(position)
        if len(component) < MIN_COMPONENT_SIZE:
            continue
        xs = [position[0] for position in component]
        ys = [position[1] for position in component]
        component_width = max(xs) - min(xs) + 1
        component_height = max(ys) - min(ys) + 1
        aspect = max(
            component_width / max(1, component_height),
            component_height / max(1, component_width),
        )
        fill_ratio = len(component) / (component_width * component_height)
        if aspect < 10.0 and fill_ratio > 0.08:
            continue
        removed_components += 1
        removed += len(component)
        for x, y in component:
            red, green, blue, _alpha = pixels[x, y]
            pixels[x, y] = (red, green, blue, 0)

    image.save(path, optimize=True)
    print(
        f"cleaned={path.name} removed_components={removed_components} "
        f"removed_pixels={removed}"
    )


if __name__ == "__main__":
    for argument in sys.argv[1:]:
        clean(Path(argument))
