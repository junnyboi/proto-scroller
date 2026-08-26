#!/usr/bin/env python3
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent
MASTER = ROOT / "masters"

GROUPS = {
    "backplates-contact.jpg": sorted(MASTER.glob("*-shop-backplate.png")),
    "operators-contact.png": sorted(MASTER.glob("*-operator.png")),
    "products-contact.png": sorted(MASTER.glob("*-products.png")),
    "shared-contact.png": [
        MASTER / "confirmation-frame.png",
        MASTER / "stat-preview-frame.png",
        MASTER / "rampage-credit-sigil.png",
        MASTER / "upgrade-success-burst.png",
        MASTER / "repair-success-burst.png",
        MASTER / "new-game-plus-insignia.png",
    ],
}

for output_name, paths in GROUPS.items():
    thumbs = []
    for path in paths:
        image = Image.open(path).convert("RGBA")
        image.thumbnail((480, 270), Image.Resampling.LANCZOS)
        card = Image.new("RGBA", (500, 320), (18, 22, 28, 255))
        x = (500 - image.width) // 2
        y = 12 + (270 - image.height) // 2
        card.alpha_composite(image, (x, y))
        draw = ImageDraw.Draw(card)
        draw.text((12, 292), path.stem, fill=(235, 226, 205, 255))
        thumbs.append(card)
    columns = 2 if len(thumbs) <= 6 else 3
    rows = (len(thumbs) + columns - 1) // columns
    sheet = Image.new("RGB", (columns * 500, rows * 320), (10, 13, 17))
    for index, card in enumerate(thumbs):
        sheet.paste(card.convert("RGB"), ((index % columns) * 500, (index // columns) * 320))
    sheet.save(ROOT / output_name, quality=92)
