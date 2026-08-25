from __future__ import annotations

import json
from collections import defaultdict
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ASSET_ROOT = ROOT / "game" / "art" / "city" / "districts"
MANIFEST_PATH = ASSET_ROOT / "building_asset_manifest.json"
EXPECTED_DISTRICTS = {
    "residential",
    "business",
    "nightlife",
    "shopping",
    "government",
    "military",
}


def main() -> None:
    manifest = json.loads(MANIFEST_PATH.read_text())
    buildings = manifest["buildings"]
    cell_width = int(manifest["cell_pixels"]["width"])
    cell_height = int(manifest["cell_pixels"]["height"])
    errors: list[str] = []
    ids: set[str] = set()
    counts: dict[str, int] = defaultdict(int)
    weights: dict[str, int] = defaultdict(int)

    if len(buildings) != 30:
        errors.append(f"Expected 30 buildings, found {len(buildings)}")

    for entry in buildings:
        building_id = str(entry["id"])
        district = str(entry["district"])
        if building_id in ids:
            errors.append(f"Duplicate ID: {building_id}")
        ids.add(building_id)
        counts[district] += 1
        weights[district] += int(entry["spawn_weight"])

        path = ASSET_ROOT / str(entry["file"])
        if not path.is_file():
            errors.append(f"Missing asset: {path}")
            continue
        import_path = Path(f"{path}.import")
        if not import_path.is_file():
            errors.append(f"Missing Godot import sidecar: {import_path}")

        image = Image.open(path)
        expected_size = (
            int(entry["columns"]) * cell_width,
            int(entry["rows"]) * cell_height,
        )
        if image.size != expected_size:
            errors.append(
                f"{building_id}: expected {expected_size}, found {image.size}"
            )
        rgba = image.convert("RGBA")
        alpha = rgba.getchannel("A")
        extrema = alpha.getextrema()
        if extrema[0] != 0 or extrema[1] != 255:
            errors.append(f"{building_id}: invalid alpha extrema {extrema}")
        corners = [
            alpha.getpixel((0, 0)),
            alpha.getpixel((image.width - 1, 0)),
            alpha.getpixel((0, image.height - 1)),
            alpha.getpixel((image.width - 1, image.height - 1)),
        ]
        if any(value > 16 for value in corners):
            errors.append(f"{building_id}: nontransparent canvas corner {corners}")

    if set(counts) != EXPECTED_DISTRICTS:
        errors.append(f"District set mismatch: {sorted(counts)}")
    for district in sorted(EXPECTED_DISTRICTS):
        if counts[district] != 5:
            errors.append(f"{district}: expected 5 assets, found {counts[district]}")
        if weights[district] != 100:
            errors.append(f"{district}: weights total {weights[district]}, expected 100")

    raw_duplicates = sorted(ASSET_ROOT.rglob("*_original.png"))
    if raw_duplicates:
        errors.append(f"Raw generation duplicates remain: {raw_duplicates}")

    if errors:
        for error in errors:
            print(f"ERROR: {error}")
        raise SystemExit(1)

    print("DISTRICT_ASSET_PACKAGE=PASS")
    print(f"BUILDINGS={len(buildings)} DISTRICTS={len(counts)}")
    print(f"SOURCE_CELL={cell_width}x{cell_height}")
    for district in sorted(counts):
        print(
            f"{district}: buildings={counts[district]} "
            f"spawn_weight={weights[district]}"
        )


if __name__ == "__main__":
    main()
