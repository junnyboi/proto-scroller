#!/usr/bin/env python3
"""Apply the staged Phase 4 24 kHz import policy to voice or SFX WAVs."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
GAME = REPO / "game"
MANIFEST = REPO / "docs" / "manifests" / "asset_optimization_phase4_audio.json"


def set_parameter(text: str, key: str, value: str) -> str:
    pattern = rf"^{re.escape(key)}=.*$"
    replacement = f"{key}={value}"
    if re.search(pattern, text, re.MULTILINE):
        return re.sub(pattern, replacement, text, count=1, flags=re.MULTILINE)
    anchor = "compress/mode="
    index = text.find(anchor)
    if index < 0:
        raise AssertionError(f"Cannot insert {key}; compression mode missing")
    return text[:index] + replacement + "\n" + text[index:]


def main() -> None:
    if len(sys.argv) != 2 or sys.argv[1] not in {"voice", "sfx"}:
        raise SystemExit("Usage: apply_phase4_audio_imports.py voice|sfx")
    group = sys.argv[1]
    document = json.loads(MANIFEST.read_text(encoding="utf-8"))
    examined = 0
    changed = 0
    for asset in document["assets"]:
        if asset["group"] != group:
            continue
        examined += 1
        import_file = GAME / asset["before"]["import_metadata_path"].removeprefix(
            "res://"
        )
        text = import_file.read_text(encoding="utf-8")
        if "compress/mode=2" not in text:
            raise AssertionError(f"Candidate is not QOA: {import_file}")
        updated = set_parameter(text, "force/max_rate", "true")
        updated = set_parameter(updated, "force/max_rate_hz", "24000")
        if updated != text:
            import_file.write_text(updated, encoding="utf-8")
            changed += 1
    expected_examined = document["group_counts"][group]
    expected_changed = document["policy_change_counts"][group]
    if examined != expected_examined or changed != expected_changed:
        raise AssertionError(
            f"Examined/changed {examined}/{changed} {group} imports; "
            f"expected {expected_examined}/{expected_changed}"
        )
    print(f"phase4_{group}_imports_examined={examined}")
    print(f"phase4_{group}_imports_changed={changed}")


if __name__ == "__main__":
    main()
