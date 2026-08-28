#!/usr/bin/env python3
"""Apply Phase 2 lossy import policy to the frozen manifest candidate set."""

from __future__ import annotations

import json
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
GAME = REPO / "game"
MANIFEST = REPO / "docs" / "manifests" / "asset_optimization_phase2_textures.json"


def main() -> None:
    document = json.loads(MANIFEST.read_text(encoding="utf-8"))
    changed = 0
    for asset in document["assets"]:
        import_path = GAME / asset["before"]["import_metadata_path"].removeprefix(
            "res://"
        )
        text = import_path.read_text(encoding="utf-8")
        if "compress/lossy_quality=0.7" not in text:
            raise AssertionError(f"Unexpected quality for {import_path}")
        if "compress/mode=0" not in text:
            raise AssertionError(f"Candidate is no longer lossless: {import_path}")
        updated = text.replace("compress/mode=0", "compress/mode=1", 1)
        import_path.write_text(updated, encoding="utf-8")
        changed += 1
    if changed != document["candidate_count"]:
        raise AssertionError(
            f"Changed {changed} imports; expected {document['candidate_count']}"
        )
    print(f"phase2_imports_changed={changed}")


if __name__ == "__main__":
    main()
