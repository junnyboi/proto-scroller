# Proto Scroller Media Asset Audit

**Audit date:** 2026-08-28
**Author:** Manus AI
**Baseline:** `21b15e00c10c4cab11849e6a50f7ebe2900bb163`

## Summary
Six obsolete derivatives and their imports were removed after runtime-path, basename, manifest, processor, export-policy, dynamic-load, hash, and history review. No runtime-referenced media was removed. Source reduction is **1,082,614 bytes** before manifest reduction. There is no additive PCK claim because Phase 1 already excluded these paths; its measured shipping reduction was 832,068 bytes.[1]

## Removed Media
| Path | Bytes | Reason |
|---|---:|---|
| `game/art/city/parallax/sky.png` | 905,354 | Superseded single-sky image. |
| `game/art/city/parallax/living/cloud_bank.webp` | 58,008 | Unloaded derivative; concept retained. |
| `game/art/robot/provisional/robot_draft_idle.png` | 19,615 | Superseded provisional image. |
| `game/art/effects/shockwave_ground_ring.png` | 64,034 | Manifest-only, no consumer. |
| `game/art/presentation/kinetic_impact_halo.png` | 18,414 | Manifest-only, no consumer. |
| `game/art/robot/upgrades/armor_plating_overlay.png` | 11,380 | Manifest-only, no consumer. |
| Six `.import` files | 5,809 | Metadata exclusive to deleted media. |
| **Total** | **1,082,614** | Before manifest reduction. |

## Retained Classes
| Class | Rationale |
|---|---|
| Documentation masters | Preserve GPT Image 2 provenance and stay outside the PCK. |
| GUT media | Supports tests and is export-excluded. |
| Client/title duplicates | Serve separate active packaging paths. |
| Runtime game media | Has direct or approved dynamic consumers. |

## Verification
JSON parsing, processor compilation, deleted-path scans, Godot 4.7.2 import, and focused sky, upgrade-asset, and audio-default regressions passed: **16 tests with 18,683 assertions**. The final source descendant receives a fresh Web export and WebDev synchronization.

## References
[1]: https://github.com/junnyboi/proto-scroller/blob/main/docs/ASSET_OPTIMIZATION_AND_CLEANUP_IMPLEMENTATION_PLAN.md "Proto Scroller asset optimization and cleanup implementation plan"
