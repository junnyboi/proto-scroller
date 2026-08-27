from __future__ import annotations

import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
SOURCE_DIR = ROOT / "docs/concepts/living-skies"
RUNTIME_DIR = ROOT / "game/art/city/parallax/living"
RUNTIME_DIR.mkdir(parents=True, exist_ok=True)

ASSETS = (
    {
        "id": "cloud_bank",
        "source": "district-cloud-bank.png",
        "runtime": "cloud_bank.webp",
        "key": "green",
        "width": 1024,
        "quality": 78,
    },
    {
        "id": "courier_shuttle",
        "source": "distant-courier-shuttle.png",
        "runtime": "courier_shuttle.webp",
        "key": "magenta",
        "width": 256,
        "quality": 82,
    },
    {
        "id": "state_carrier",
        "source": "distant-state-carrier.png",
        "runtime": "state_carrier.webp",
        "key": "magenta",
        "width": 384,
        "quality": 82,
    },
)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def clean_key(image: Image.Image, key: str) -> Image.Image:
    rgba = np.asarray(image.convert("RGBA"), dtype=np.uint8).copy()
    rgb = rgba[:, :, :3].astype(np.int16)
    alpha = rgba[:, :, 3].astype(np.float32)
    red = rgb[:, :, 0]
    green = rgb[:, :, 1]
    blue = rgb[:, :, 2]
    if key == "green":
        excess = green - np.maximum(red, blue)
        contamination = (excess > 10) & (green > 56)
        strength = np.clip((excess.astype(np.float32) - 8.0) / 42.0, 0.0, 1.0)
        neutral = ((red + blue) // 2).astype(np.int16)
        rgb[:, :, 1] = np.where(contamination, neutral, green)
    else:
        excess = np.minimum(red, blue) - green
        contamination = (excess > 10) & (red > 64) & (blue > 64)
        strength = np.clip((excess.astype(np.float32) - 8.0) / 46.0, 0.0, 1.0)
        neutral = green.astype(np.int16)
        rgb[:, :, 0] = np.where(contamination, neutral, red)
        rgb[:, :, 2] = np.where(contamination, neutral, blue)
    alpha *= 1.0 - strength
    alpha[contamination & (strength > 0.55)] = 0.0
    rgba[:, :, :3] = np.clip(rgb, 0, 255).astype(np.uint8)
    rgba[:, :, 3] = np.clip(alpha, 0, 255).astype(np.uint8)
    cleaned = Image.fromarray(rgba, mode="RGBA")
    bounds = cleaned.getchannel("A").point(lambda value: 255 if value > 4 else 0).getbbox()
    if bounds is None:
        raise RuntimeError("Key cleanup removed the complete subject")
    pad_x = max(8, round((bounds[2] - bounds[0]) * 0.025))
    pad_y = max(8, round((bounds[3] - bounds[1]) * 0.04))
    crop = (
        max(0, bounds[0] - pad_x),
        max(0, bounds[1] - pad_y),
        min(cleaned.width, bounds[2] + pad_x),
        min(cleaned.height, bounds[3] + pad_y),
    )
    return cleaned.crop(crop)


def prepare(entry: dict[str, object]) -> dict[str, object]:
    source = SOURCE_DIR / str(entry["source"])
    runtime = RUNTIME_DIR / str(entry["runtime"])
    cleaned = clean_key(Image.open(source), str(entry["key"]))
    target_width = int(entry["width"])
    target_height = max(1, round(cleaned.height * target_width / cleaned.width))
    resized = cleaned.resize((target_width, target_height), Image.Resampling.LANCZOS)
    resized.putalpha(resized.getchannel("A").filter(ImageFilter.GaussianBlur(0.35)))
    resized.save(runtime, "WEBP", quality=int(entry["quality"]), method=6)
    return {
        "id": entry["id"],
        "generator": "GPT Image 2",
        "source": source.relative_to(ROOT).as_posix(),
        "source_dimensions": f"{Image.open(source).width}x{Image.open(source).height}",
        "source_sha256": sha256(source),
        "runtime": runtime.relative_to(ROOT).as_posix(),
        "runtime_dimensions": f"{resized.width}x{resized.height}",
        "runtime_bytes": runtime.stat().st_size,
        "runtime_sha256": sha256(runtime),
        "processing": (
            f"existing-alpha key decontamination ({entry['key']}); alpha-aware crop; "
            f"Lanczos resize; 0.35 px alpha soften; WebP quality {entry['quality']}"
        ),
    }


def main() -> None:
    entries = [prepare(entry) for entry in ASSETS]
    manifest = {
        "generator": "GPT Image 2",
        "purpose": "fixed-allocation moving cloud and distant air-traffic parallax",
        "entries": entries,
    }
    path = RUNTIME_DIR / "MANIFEST.json"
    path.write_text(json.dumps(manifest, indent=2) + "\n")
    for entry in entries:
        print(
            f"{entry['id']} {entry['runtime_dimensions']} "
            f"{entry['runtime_bytes']} bytes {entry['runtime_sha256']}"
        )


if __name__ == "__main__":
    main()
