#!/usr/bin/env python3
from pathlib import Path
from PIL import Image, ImageEnhance

ROOT = Path(__file__).resolve().parent
MASTERS = ROOT / "masters"
RUNTIME = ROOT.parents[3] / "game" / "art" / "ui" / "weapon_shop"
RUNTIME.mkdir(parents=True, exist_ok=True)

DISTRICTS = ["business", "residential", "entertainment", "military", "royal"]
PRODUCTS = {
    "business": ["foreclosure_slugs", "hostile_leverage", "collateral_refinance"],
    "residential": ["patchwork_nanoweld", "scrapheap_magnetics", "borrowed_shock_coils"],
    "entertainment": ["encore_capacitors", "jackpot_chamber", "backstage_triage"],
    "military": ["siege_breaching_load", "hunter_killer_link", "gantry_overhaul"],
    "royal": ["sovereign_aegis", "crownfire_protocol", "chronoseal_governor"],
}


def save_webp(image: Image.Image, path: Path, quality: int = 80) -> None:
    image.save(path, "WEBP", quality=quality, method=6)


def contain(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    output = Image.new("RGBA", size, (0, 0, 0, 0))
    image = image.copy()
    image.thumbnail(size, Image.Resampling.LANCZOS)
    output.alpha_composite(image, ((size[0] - image.width) // 2, (size[1] - image.height) // 2))
    return output


for district in DISTRICTS:
    with Image.open(MASTERS / f"{district}-shop-backplate.png") as source:
        backplate = source.convert("RGB").resize((1280, 720), Image.Resampling.LANCZOS)
        backplate = ImageEnhance.Brightness(backplate).enhance(0.82)
        save_webp(backplate, RUNTIME / f"{district}_backplate.webp", 62)
    with Image.open(MASTERS / f"{district}-operator.png") as source:
        portrait = contain(source.convert("RGBA"), (512, 512))
        save_webp(portrait, RUNTIME / f"{district}_operator.webp", 82)
    with Image.open(MASTERS / f"{district}-products.png") as source:
        atlas = source.convert("RGBA")
        third = atlas.width / 3.0
        for index, product_id in enumerate(PRODUCTS[district]):
            left = round(index * third)
            right = round((index + 1) * third)
            segment = atlas.crop((left, 0, right, atlas.height))
            alpha_bbox = segment.getchannel("A").getbbox()
            if alpha_bbox is None:
                raise RuntimeError(f"No alpha content in {district} product {index}")
            product = segment.crop(alpha_bbox)
            product = contain(product, (256, 256))
            save_webp(product, RUNTIME / f"{product_id}.webp", 84)

SHARED = {
    "confirmation-frame.png": ("confirmation_frame.webp", (720, 540), 82),
    "stat-preview-frame.png": ("stat_preview_frame.webp", (640, 480), 82),
    "rampage-credit-sigil.png": ("rampage_credit.webp", (192, 192), 84),
    "upgrade-success-burst.png": ("upgrade_success_burst.webp", (256, 256), 86),
    "repair-success-burst.png": ("repair_success_burst.webp", (256, 256), 86),
    "new-game-plus-insignia.png": ("new_game_plus.webp", (256, 256), 86),
}
for source_name, (output_name, size, quality) in SHARED.items():
    with Image.open(MASTERS / source_name) as source:
        save_webp(contain(source.convert("RGBA"), size), RUNTIME / output_name, quality)

for original in MASTERS.glob("*_original.png"):
    original.unlink()

print(f"Wrote {len(list(RUNTIME.glob('*.webp')))} runtime WebP assets to {RUNTIME}")
