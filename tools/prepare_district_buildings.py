from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
DISTRICT_ROOT = ROOT / "game" / "art" / "city" / "districts"
MANIFEST = DISTRICT_ROOT / "building_asset_manifest.json"
PADDING = 10
ALPHA_THRESHOLD = 8


def is_magenta_key(red: int, green: int, blue: int) -> bool:
    dominant = min(red, blue)
    return (
        dominant >= 35
        and green <= 105
        and dominant >= max(1, green) * 1.55
        and abs(red - blue) <= 100
    )


def is_green_key(red: int, green: int, blue: int) -> bool:
    return (
        green >= 40
        and green >= max(1, red) * 1.45
        and green >= max(1, blue) * 1.45
    )


def remove_key_color(image: Image.Image, preserve_magenta: bool) -> Image.Image:
    result = image.convert("RGBA")
    pixels = result.load()
    for y in range(result.height):
        for x in range(result.width):
            red, green, blue, alpha = pixels[x, y]
            should_remove = (
                is_green_key(red, green, blue)
                if preserve_magenta
                else is_magenta_key(red, green, blue)
            )
            if alpha > 0 and should_remove:
                pixels[x, y] = (red, green, blue, 0)
    return result


def prepare(entry: dict[str, object], cell_pixels: dict[str, int]) -> None:
    relative_path = Path(str(entry["file"]))
    target_path = DISTRICT_ROOT / relative_path
    image = remove_key_color(
        Image.open(target_path),
        preserve_magenta=str(entry["district"]) == "nightlife",
    )
    alpha = image.getchannel("A")
    bbox = alpha.point(lambda value: 255 if value >= ALPHA_THRESHOLD else 0).getbbox()
    if bbox is None:
        raise RuntimeError(f"No opaque subject in {target_path}")
    subject = image.crop(bbox)

    width = int(entry["columns"]) * int(cell_pixels["width"])
    height = int(entry["rows"]) * int(cell_pixels["height"])
    available_width = width - PADDING * 2
    available_height = height - PADDING * 2
    scale = min(available_width / subject.width, available_height / subject.height)
    resized_size = (
        max(1, round(subject.width * scale)),
        max(1, round(subject.height * scale)),
    )
    subject = subject.resize(resized_size, Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    offset = ((width - subject.width) // 2, height - PADDING - subject.height)
    canvas.alpha_composite(subject, offset)
    canvas.save(target_path, optimize=True)
    print(
        f"prepared={entry['id']} grid={entry['columns']}x{entry['rows']} "
        f"canvas={width}x{height} subject={subject.width}x{subject.height}"
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--district", default="")
    arguments = parser.parse_args()
    manifest = json.loads(MANIFEST.read_text())
    cell_pixels = manifest["cell_pixels"]
    buildings = manifest["buildings"]
    if len(buildings) != 30:
        raise RuntimeError(f"Expected 30 buildings, found {len(buildings)}")
    for entry in buildings:
        if arguments.district and entry["district"] != arguments.district:
            continue
        prepare(entry, cell_pixels)


if __name__ == "__main__":
    main()
