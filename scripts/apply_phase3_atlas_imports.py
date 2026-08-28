#!/usr/bin/env python3
"""Apply Phase 3 quality values to the approved boss and robot atlas imports."""

from __future__ import annotations

import json
import re
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
GAME = REPO / "game"
MANIFEST = REPO / "docs" / "manifests" / "asset_optimization_phase3_atlases.json"


def main() -> None:
    document = json.loads(MANIFEST.read_text(encoding="utf-8"))
    changed = 0
    for asset in document["assets"]:
        import_path = GAME / asset["before"]["import_metadata_path"].removeprefix(
            "res://"
        )
        text = import_path.read_text(encoding="utf-8")
        if "compress/mode=1" not in text:
            raise AssertionError(f"Atlas is not lossy: {import_path}")
        prior_quality = asset["before"]["lossy_quality"]
        target_quality = asset["target_quality"]
        expected = f"compress/lossy_quality={prior_quality}"
        replacement = f"compress/lossy_quality={target_quality}"
        if expected not in text:
            raise AssertionError(f"Unexpected quality for {import_path}")
        updated = text.replace(expected, replacement, 1)
        if len(re.findall(r"^compress/lossy_quality=", updated, re.MULTILINE)) != 1:
            raise AssertionError(f"Duplicate quality field in {import_path}")
        import_path.write_text(updated, encoding="utf-8")
        changed += 1
    if changed != document["candidate_count"]:
        raise AssertionError(
            f"Changed {changed} imports; expected {document['candidate_count']}"
        )
    print(f"phase3_imports_changed={changed}")


if __name__ == "__main__":
    main()
