# Project CHOIR Asset Provenance

All Project CHOIR visual assets were generated with **GPT Image 2** on 2026-08-26. Enemy and boss prompts used the approved Project CHOIR concepts plus existing Proto Scroller production art as style and silhouette references. Sprite generations used a solid `#FF00FF` chroma background and explicitly requested orthographic, complete, gameplay-readable subjects.

| Production asset | GPT Image 2 source | Purpose |
|---|---|---|
| `game/art/city/enemies/archetypes/21-reclaimed-breacher.png` | `docs/story-concepts/production-sources/21-reclaimed-breacher-source.png` | Residential close-range bio-weapon. |
| `game/art/city/enemies/archetypes/22-graft-runner.png` | `docs/story-concepts/production-sources/22-graft-runner-source.png` | Residential/Military pack attacker and carrier payload. |
| `game/art/city/enemies/archetypes/23-choir-siren.png` | `docs/story-concepts/production-sources/23-choir-siren-source.png` | Entertainment support and weapon-disruption unit. |
| `game/art/city/enemies/archetypes/24-ossuary-crawler.png` | `docs/story-concepts/production-sources/24-ossuary-crawler-source.png` | Entertainment containment-release threat. |
| `game/art/city/enemies/archetypes/25-seraph-carrier.png` | `docs/story-concepts/production-sources/25-seraph-carrier-source.png` | Military airborne carrier. |
| `game/art/city/enemies/archetypes/26-pale-engine.png` | `docs/story-concepts/production-sources/26-pale-engine-source.png` | Military/Royal siege organism. |
| `game/art/finale/choir-prime-core.png` | `docs/story-concepts/production-sources/choir-prime-core-source.png` | Royal final boss core. |
| `game/art/finale/choir-pylon.png` | `docs/story-concepts/production-sources/choir-pylon-source.png` | Five color-modulated finale organs. |
| `game/art/narrative/memory-glass-node.png` | `docs/story-concepts/production-sources/memory-glass-node-source.png` | Dossier and evidence-node marker. |
| `game/art/narrative/continuity-cradle.jpg` | Direct GPT Image 2 generation | Title codex and pilot-continuity reveal. |

The reproducible processor at `scripts/process-choir-assets.py` removes the chroma background, rejects isolated debris by retaining the primary connected alpha component, trims transparent margins, downscales to production dimensions, and compresses the continuity panorama. It does not draw or invent visual content. Raw source renders remain outside `game/` so the Godot import and Web export cannot include them accidentally. Destructible facades intentionally own no cross-section background asset or production recipe.

## Localization font subset

The expanded Simplified Chinese narrative and runtime-tuning catalog currently requires 986 unique catalog codepoints after the title, district-shop, 56-parameter tuning, visual-control, and tuned-run debrief vocabulary are synchronized. `scripts/build-cjk-font-subset.py` deterministically rebuilds `game/art/fonts/DroidSansFallbackFull-ProtoScroller.ttf` from the Apache-2.0 system source `/usr/share/fonts/truetype/droid/DroidSansFallbackFull.ttf`, retaining only current `zh-CN.json` characters plus invariant control glyphs. The current subset is 148,408 bytes with SHA-256 `ea7701b158f0cef24cc657892bb7cebd31e3ec2f7774ff76e7eccc77c479a7ec` and passes the repository's full-catalog glyph coverage test.
