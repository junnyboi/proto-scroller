from __future__ import annotations

import hashlib
import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
MASTER_DIR = ROOT / "docs/story-concepts/production-sources/choir-attack-vfx"
CONCEPT_DIR = ROOT / "docs/concepts/choir-attack-vfx"
RUNTIME_DIR = ROOT / "game/art/city/enemies/choir-attacks"

ROSTER = [
    ("01", "covenant-warden"),
    ("02", "mercy-recovery-cart"),
    ("03", "testament-kite"),
    ("04", "receivership-ambulance"),
    ("05", "intake-shepherd"),
    ("06", "evacuation-litter"),
    ("07", "rainvault-pressure-ward"),
    ("08", "balcony-recall-beacon"),
    ("09", "memorial-usher"),
    ("10", "glassback-double"),
    ("11", "recall-lantern"),
    ("12", "marquee-anesthetist"),
    ("13", "suture-marshal"),
    ("14", "mercy-raker"),
    ("15", "revetment-ward"),
    ("16", "triage-kite"),
    ("17", "privy-chirurgeon"),
    ("18", "laureate-courser"),
    ("19", "ninefold-witness"),
    ("20", "regency-conservator"),
]

RANGED = {
    "covenant-warden",
    "mercy-recovery-cart",
    "rainvault-pressure-ward",
    "glassback-double",
    "marquee-anesthetist",
    "mercy-raker",
    "revetment-ward",
    "triage-kite",
    "regency-conservator",
}

PHASES = (
    ("projectile", 0, (170, 120)),
    ("impact", 1, (170, 170)),
    ("attack", 2, (176, 170)),
)
ATLAS_COLUMNS = 5
ATLAS_ROWS = 4
ATLAS_CELL = 192


def trim_alpha(image: Image.Image, padding: int = 10) -> Image.Image:
    rgba = image.convert("RGBA")
    bbox = rgba.getchannel("A").getbbox()
    if bbox is None:
        raise ValueError("Generated phase has no visible alpha content")
    left, top, right, bottom = bbox
    left = max(0, left - padding)
    top = max(0, top - padding)
    right = min(rgba.width, right + padding)
    bottom = min(rgba.height, bottom + padding)
    return rgba.crop((left, top, right, bottom))


def fit(image: Image.Image, bounds: tuple[int, int]) -> Image.Image:
    output = image.copy()
    output.thumbnail(bounds, Image.Resampling.LANCZOS)
    return output


def quantize_alpha(image: Image.Image, colors: int) -> Image.Image:
    rgba = image.convert("RGBA")
    return rgba.quantize(colors=colors, method=Image.Quantize.FASTOCTREE).convert("RGBA")


def save_png(image: Image.Image, path: Path, colors: int) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    optimized = quantize_alpha(image, colors)
    optimized.save(path, format="PNG", optimize=True, compress_level=9)


def save_webp(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.convert("RGBA").save(
        path,
        format="WEBP",
        quality=78,
        method=6,
        exact=True,
    )


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def main() -> None:
    CONCEPT_DIR.mkdir(parents=True, exist_ok=True)
    RUNTIME_DIR.mkdir(parents=True, exist_ok=True)
    manifest: list[dict[str, object]] = []
    atlases = {
        phase: Image.new(
            "RGBA",
            (ATLAS_COLUMNS * ATLAS_CELL, ATLAS_ROWS * ATLAS_CELL),
            (0, 0, 0, 0),
        )
        for phase, _column, _bounds in PHASES
    }
    for old_runtime in RUNTIME_DIR.glob("*.png"):
        old_runtime.unlink()

    for number, slug in ROSTER:
        master_path = MASTER_DIR / f"{number}-{slug}-attack-master.png"
        if not master_path.is_file():
            raise FileNotFoundError(master_path)
        master = Image.open(master_path).convert("RGBA")
        if master.size != (2304, 1536):
            raise ValueError(f"Unexpected master dimensions for {master_path}: {master.size}")

        concept = master.copy()
        concept.thumbnail((1152, 768), Image.Resampling.LANCZOS)
        concept_path = CONCEPT_DIR / f"{number}-{slug}-attack-vfx.png"
        save_png(concept, concept_path, 192)

        column_width = master.width // 3
        regions: dict[str, object] = {}
        roster_index = int(number) - 1
        cell_x = (roster_index % ATLAS_COLUMNS) * ATLAS_CELL
        cell_y = (roster_index // ATLAS_COLUMNS) * ATLAS_CELL
        for phase, column, bounds in PHASES:
            phase_image = master.crop(
                (column * column_width, 0, (column + 1) * column_width, master.height)
            )
            phase_image = trim_alpha(phase_image)
            if phase == "projectile" and slug in RANGED and phase_image.height > phase_image.width:
                phase_image = phase_image.rotate(90, expand=True, resample=Image.Resampling.BICUBIC)
            phase_image = fit(phase_image, bounds)
            paste_x = cell_x + (ATLAS_CELL - phase_image.width) // 2
            paste_y = cell_y + (ATLAS_CELL - phase_image.height) // 2
            atlases[phase].alpha_composite(phase_image, (paste_x, paste_y))
            regions[phase] = {
                "atlas": f"game/art/city/enemies/choir-attacks/district-{phase}-vfx.webp",
                "region": [cell_x, cell_y, ATLAS_CELL, ATLAS_CELL],
                "content_size": list(phase_image.size),
            }

        manifest.append(
            {
                "number": number,
                "id": slug.replace("-", "_"),
                "delivery": "projectile" if slug in RANGED else "actor",
                "master": str(master_path.relative_to(ROOT)),
                "concept": str(concept_path.relative_to(ROOT)),
                "regions": regions,
            }
        )

    atlas_files: dict[str, object] = {}
    for phase, atlas in atlases.items():
        atlas_path = RUNTIME_DIR / f"district-{phase}-vfx.webp"
        save_webp(atlas, atlas_path)
        atlas_files[phase] = {
            "path": str(atlas_path.relative_to(ROOT)),
            "size": list(atlas.size),
            "bytes": atlas_path.stat().st_size,
            "sha256": sha256(atlas_path),
        }

    manifest_path = MASTER_DIR / "manifest.json"
    manifest_path.write_text(
        json.dumps({"atlases": atlas_files, "variants": manifest}, indent=2) + "\n",
        encoding="utf-8",
    )
    runtime_bytes = sum(path.stat().st_size for path in RUNTIME_DIR.glob("*.webp"))
    print(f"processed={len(manifest)} runtime_files={len(list(RUNTIME_DIR.glob('*.webp')))}")
    print(f"runtime_bytes={runtime_bytes}")


if __name__ == "__main__":
    main()
