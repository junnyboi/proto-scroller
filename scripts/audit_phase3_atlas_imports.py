#!/usr/bin/env python3
"""Generate before/after evidence for Phase 3 atlas import compression."""

from __future__ import annotations

import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path
from typing import Any

from PIL import Image

REPO = Path(__file__).resolve().parents[1]
GAME = REPO / "game"
OUTPUT = REPO / "docs" / "manifests" / "asset_optimization_phase3_atlases.json"
TARGETS = [
    {
        "group": "boss_atlas",
        "source": "res://art/bosses/animated/cantor-31-atlas.webp",
        "columns": 8,
        "rows": 4,
        "target_quality": 0.55,
    },
    {
        "group": "boss_atlas",
        "source": "res://art/bosses/animated/choir-prime-atlas.webp",
        "columns": 8,
        "rows": 4,
        "target_quality": 0.55,
    },
    {
        "group": "boss_atlas",
        "source": "res://art/bosses/animated/mimesis-04-atlas.webp",
        "columns": 8,
        "rows": 4,
        "target_quality": 0.55,
    },
    {
        "group": "boss_atlas",
        "source": "res://art/bosses/animated/samaritan-15-atlas.webp",
        "columns": 8,
        "rows": 4,
        "target_quality": 0.55,
    },
    {
        "group": "boss_atlas",
        "source": "res://art/bosses/animated/settlement-engine-s04-atlas.webp",
        "columns": 8,
        "rows": 4,
        "target_quality": 0.55,
    },
    {
        "group": "robot_atlas",
        "source": "res://art/robot/grunt/grunt_horizontal_atlas.png",
        "columns": 25,
        "rows": 7,
        "target_quality": 0.60,
    },
]


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def read_value(text: str, key: str) -> str:
    match = re.search(rf"^{re.escape(key)}=(.+)$", text, re.MULTILINE)
    if not match:
        raise ValueError(f"Missing {key}")
    return match.group(1).strip().strip('"')


def git_head() -> str:
    return subprocess.check_output(
        ["git", "-C", str(REPO), "rev-parse", "HEAD"], text=True
    ).strip()


def inspect(target: dict[str, Any]) -> dict[str, Any]:
    source = GAME / target["source"].removeprefix("res://")
    import_file = Path(str(source) + ".import")
    text = import_file.read_text(encoding="utf-8")
    imported_res = read_value(text, "path")
    imported = GAME / imported_res.removeprefix("res://")
    with Image.open(source) as image:
        rgba = image.convert("RGBA")
        alpha = rgba.getchannel("A")
        histogram = alpha.histogram()
        pixels = rgba.width * rgba.height
        non_opaque = sum(histogram[:255])
        width, height = rgba.size
    columns = target["columns"]
    rows = target["rows"]
    if width % columns != 0 or height % rows != 0:
        raise AssertionError(f"Atlas grid mismatch for {target['source']}")
    return {
        "source_path": target["source"],
        "import_metadata_path": target["source"] + ".import",
        "group": target["group"],
        "uid": read_value(text, "uid"),
        "source_bytes": source.stat().st_size,
        "source_sha256": sha256(source),
        "width": width,
        "height": height,
        "columns": columns,
        "rows": rows,
        "cell_width": width // columns,
        "cell_height": height // rows,
        "non_opaque_pixel_fraction": round(non_opaque / pixels, 8),
        "import_mode": int(read_value(text, "compress/mode")),
        "lossy_quality": float(read_value(text, "compress/lossy_quality")),
        "high_quality": read_value(text, "compress/high_quality") == "true",
        "size_limit": int(read_value(text, "process/size_limit")),
        "imported_path": imported_res,
        "imported_bytes": imported.stat().st_size,
        "imported_sha256": sha256(imported),
    }


def before() -> None:
    assets = []
    for target in TARGETS:
        state = inspect(target)
        assets.append(
            {
                "source_path": target["source"],
                "group": target["group"],
                "target_quality": target["target_quality"],
                "before": state,
                "after": None,
            }
        )
    document = {
        "phase": 3,
        "title": "Boss and robot atlas import quality tuning",
        "baseline_source_revision": git_head(),
        "candidate_count": len(assets),
        "assets": assets,
        "summary": {
            "before_imported_bytes": sum(
                asset["before"]["imported_bytes"] for asset in assets
            ),
            "after_imported_bytes": None,
            "imported_payload_reduction_bytes": None,
        },
    }
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(document, indent=2) + "\n", encoding="utf-8")


def after() -> None:
    document = json.loads(OUTPUT.read_text(encoding="utf-8"))
    targets = {target["source"]: target for target in TARGETS}
    for asset in document["assets"]:
        current = inspect(targets[asset["source_path"]])
        prior = asset["before"]
        for key in (
            "source_bytes",
            "source_sha256",
            "width",
            "height",
            "columns",
            "rows",
            "cell_width",
            "cell_height",
            "uid",
            "size_limit",
        ):
            if current[key] != prior[key]:
                raise AssertionError(
                    f"Atlas contract changed for {asset['source_path']}: {key}"
                )
        if current["import_mode"] != 1:
            raise AssertionError(f"Lossy mode missing for {asset['source_path']}")
        if current["lossy_quality"] != asset["target_quality"]:
            raise AssertionError(f"Target quality missing for {asset['source_path']}")
        asset["after"] = current
    before_bytes = sum(asset["before"]["imported_bytes"] for asset in document["assets"])
    after_bytes = sum(asset["after"]["imported_bytes"] for asset in document["assets"])
    document["candidate_source_revision"] = git_head()
    document["summary"] = {
        "before_imported_bytes": before_bytes,
        "after_imported_bytes": after_bytes,
        "imported_payload_reduction_bytes": before_bytes - after_bytes,
    }
    OUTPUT.write_text(json.dumps(document, indent=2) + "\n", encoding="utf-8")


def main() -> None:
    if len(sys.argv) != 2 or sys.argv[1] not in {"before", "after"}:
        raise SystemExit("Usage: audit_phase3_atlas_imports.py before|after")
    if sys.argv[1] == "before":
        before()
    else:
        after()
    print(OUTPUT)


if __name__ == "__main__":
    main()
