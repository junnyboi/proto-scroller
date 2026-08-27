# Animated Boss Sprites Implementation Plan

**Author:** Manus AI

**Status:** In progress

**Engine:** Godot 4.7.2-stable, GL Compatibility, non-threaded Web export

**Canonical repository:** `https://github.com/junnyboi/proto-scroller`

**Target branch:** Shared `main`, integrated without rewriting history

## Objective

Replace the five campaign bosses’ static presentation sprites with video-derived animated sprites while preserving the existing Project CHOIR identity, fixed combat authority, responsive landscape/portrait behavior, no-post-warm-allocation architecture, and Web package discipline. Every boss receives **east- and west-facing `moving` and `attacking` states**. Animation remains cosmetic: the hidden `TankEnemy`, existing hurt regions, `BossAttackArea2D` footprints, controller clocks, damage events, support pools, wreck policy, and campaign transactions remain authoritative.

The feature uses the project-mandated video-to-sprites workflow. GPT Image 2 creates reference-faithful chroma keyframes; locked-camera, audio-disabled image-conditioned videos supply motion; deterministic processing extracts keyed frames; and Godot consumes compact atlases through the existing prewarmed `BossRig2D`.[1] [2]

## Inspected Baseline

The concept index, runtime manifest, static sprites, shared boss implementation plan, boss rig, and three controller families were inspected before production.[3] [4] [5] Each existing boss is a 512×384 transparent WebP shown by `BossRig2D` as one fitted `Sprite2D`, with a separate weak-point part and fixed sockets/hurt regions. The visible rig currently has no animation clock and does not inherit the hidden host’s facing.

| Boss | Current silhouette | Signature attack selected for the shared attack state | Direction rule |
|---|---|---|---|
| SETTLEMENT ENGINE S-04 | Wide inverted finance-scale gantry on twin crawlers, with unequal coffer and archive payloads | `FORECLOSURE_STAMP` | Generate E and W independently; mirroring would relocate the east archive and unequal payloads. |
| SAMARITAN-15 | Long six-legged municipal clinic crawler with triage cradle, four pods, cisterns, and rescue crane | `BLACKOUT_HARVEST` | Generate E; mirror the entire rig to W. |
| MIMESIS-04 | Low stage crawler with cyan memory coffin, broken crescent, opposed marquee banks, and cable tail | `ARMED_AFTERIMAGE` | Generate E; mirror the entire rig to W. |
| CANTOR-31 / PALE ENGINE | Rail crawler with tall artillery spine, off-center capsule, telemetry drum, and three unequal surgical arms | `COMPRESSION_PSALM` | Generate E; mirror the entire rig to W. |
| CHOIR Prime | Floor-anchored palace engine with five named reliquaries, cyan aperture, spinal conduits, and inverted throne | `CROWN_RADIAL_VERDICT` | Generate E and W independently; mirroring would swap named pylon architecture and finale semantics. |

## Production Matrix

The runtime requires twenty sequences. Fourteen source carriers are generated because only three bosses are safe to mirror as complete composited rigs.

| Boss | Generated carriers | Derived sequences | Runtime total |
|---|---:|---:|---:|
| SETTLEMENT ENGINE S-04 | E/W × moving/attacking = 4 | 0 | 4 |
| SAMARITAN-15 | E × moving/attacking = 2 | W × moving/attacking = 2 | 4 |
| MIMESIS-04 | E × moving/attacking = 2 | W × moving/attacking = 2 | 4 |
| CANTOR-31 / PALE ENGINE | E × moving/attacking = 2 | W × moving/attacking = 2 | 4 |
| CHOIR Prime | E/W × moving/attacking = 4 | 0 | 4 |
| **Total** | **14** | **6** | **20** |

Every carrier uses a flat hot-pink `#FF00FF` background selected by the video-to-sprites contrast tool, one full-body boss, a locked orthographic-style side view, zero camera motion, constant scale, fixed ground origin, no particles, no shadows, no duplicate subject, no text, and no audio. First and last keyframes are identical for loop closure. The gameplay-optimized extraction profile is **eight frames per sequence at a 6 FPS moving-loop rate**, processed within a 384×216 ceiling. The attack state uses the same eight ordered frames but maps them to the authoritative 0.85-second telegraph, 0.55-second active, and 0.75-second recovery intervals rather than running an independent damage clock.

## Boss Motion Briefs

### SETTLEMENT ENGINE S-04

The moving loop cycles crawler belts in place, compresses the two shoes under alternating load, settles the central mast, reciprocates the hydraulic rods, and gives each unequal hanging payload a different restrained lag. The attack cycle raises the central platen through telegraph, snaps it into the existing centered stamp footprint during active time, then rebounds and vents during recovery. East and west carriers preserve the archive on its canonical east side instead of reflecting the architecture.

### SAMARITAN-15

The moving loop uses two alternating tripod steps across six stabilizers, minimal chassis heave, delayed cistern and hose settle, and a gently counter-swinging rescue crane. Captive silhouettes and life lamps remain calm and legible. The attack cycle plants all feet, braces the crane, draws cyan energy from pods toward the clinic battery, emits the Blackout Harvest discharge while retaining a visibly dry lane, then returns to the crawl pose. Glass never reads as the damage source.

### MIMESIS-04

The moving loop rolls the crawler pads, compresses lower stage braces, counter-bobs the cyan capsule and broken proscenium, chases restrained amber/magenta bulbs, and lets the cable tail lag. The attack cycle tightens the crescent and counts amber during telegraph, snaps the capsule and magenta bank during the controller-owned Armed Afterimage active interval, and decays to the moving pose. The recorded magenta footprint remains the only damage truth; cyan history remains harmless.

### CANTOR-31 / PALE ENGINE

The moving loop turns the crawler bogies, pulses the deck under weight, counter-sways the tall artillery spine, articulates three unequal arms in staggered phases, rotates the telemetry drum, and lets clamps and hoses settle late. The attack cycle braces the arms and compresses the spine during telegraph, snaps the spine and collar with one heavy recoil during active time, then vents and damps into the base pose. It never selects a lane, spawns a support, or resolves reclamation.

### CHOIR Prime

The moving state is a floor-anchored breathing-engine loop rather than walking: the cyan aperture inhales, the throne settles, spinal braces flex, cables lag, fog drifts behind reliquary glass, and five towers answer with sequential cyan pulses. The attack cycle draws the throne and braces inward, opens the Crown and aperture, emits the verdict recoil during the existing radial active interval, and drains back into the ambient state. Separate east and west carriers preserve the named pylon map and finale receiver semantics.

## Asset Layout

Generation masters remain outside the source repository at `/home/ubuntu/proto-scroller-art-masters/boss-sprites/`. Each boss folder stores approved chroma anchors, MP4 carriers, extracted transparent frames, per-sequence sheets/manifests, and the lossless consolidated atlas master. The repository stores only runtime atlases, compact runtime metadata, import settings, provenance, and the implementation plan:

```text
game/art/bosses/animated/
  settlement-engine-s04-atlas.webp
  samaritan-15-atlas.webp
  mimesis-04-atlas.webp
  cantor-31-atlas.webp
  choir-prime-atlas.webp
  ANIMATION_ASSET_MANIFEST.md
```

Each atlas contains four contiguous eight-frame sequences in this order: `E_moving`, `W_moving`, `E_attacking`, `W_attacking`. Eight columns produce one row per sequence and four rows per boss. Cells share one bottom-center anchor and include transparent padding, allowing one stable `Sprite2D.region_rect` envelope per boss. Godot imports runtime atlases as filtered lossy Web textures without mipmaps; lossless masters and videos remain outside the PCK.

## Runtime Architecture

### `BossAnimationCatalog`

A new immutable catalog preloads five atlases and records each atlas cell size, column count, frame count, and sequence offsets. It validates all five rig presets, four required sequence keys, and one-page dimensions. Direction is semantic (`E` or `W`), never inferred from negative node scale, so sockets, named pylons, hurt regions, and controller-owned world coordinates remain unchanged.

### `BossRig2D`

The existing part-zero sprite becomes an atlas-region renderer. All textures and region state are configured inside the existing prewarmed rig. The rig owns only presentation fields: active preset, state, direction, frame index, elapsed state time, and current authoritative attack stage. It exposes:

- `play_moving(direction)`;
- `play_attacking(direction, stage)`;
- `set_facing(direction)`;
- `advance_animation(delta)`;
- `animation_signature()` for deterministic inspection.

The moving state loops at 6 FPS. The attacking state maps frames 0–2 to `TELEGRAPH`, 3–4 to `ACTIVE`, and 5–7 to `RECOVERY`, using each controller’s existing stage duration. A state change snaps to the first frame of the correct stage so retry restoration and large-delta transitions cannot drift. No animation frame emits damage, changes collision, moves sockets, or starts controller actions.

### `CommandBossSession`

The session connects once to `BossVerticalSliceController.attack_changed`, `BossEscalationController.attack_changed`, and `BossRoyalFinaleController.attack_changed`. It keeps the rig in `moving` during `SCREEN`; enters the current attack state when `BARRAGE` or `EXPOSED` begins; forwards subsequent attack stages; and advances the rig from the session clock. Facing is derived from the live robot’s X position relative to the hidden boss host and passed to the rig every frame. Stop, death, wreck transition, retry, and generation cleanup reset the animation with existing lifecycle authority.

## Integration Constraints

| Constraint | Implementation response |
|---|---|
| No gameplay authority in frames | Damage, telegraphs, safe lanes, projectiles, support, evidence, and wreck completion remain in existing controllers/session objects. |
| Fixed runtime allocation | One existing part-zero sprite and five preloaded textures; no nodes, timers, tweens, or frame resources are created during combat. |
| Directional asymmetry | S-04 and CHOIR Prime use separately generated W assets. Other bosses mirror the entire E sequence during deterministic extraction. |
| Mechanical stability | Region rendering affects only `_presentation_root`; hurt regions and sockets never flip or move. |
| Portrait parity | The current portrait presentation scale remains; frame cells retain the same bottom-center origin and 520×390 display envelope. |
| Retry determinism | Restored controller stage immediately selects the corresponding attack frame range. No independent callback survives generation cleanup. |
| Web package budget | Use eight frames, 384×216 processing, one compressed atlas per boss, and exclude generation masters from source/export. Optimize only presentation imports if the fresh PCK exceeds the current ceiling. |
| Static fallback | Existing five static sprites remain source-controlled as identity references and rollback assets but are removed from runtime preload paths. |

## Work Packages

### WP1 — Reference lock and plan

Freeze the five identity briefs, motion grammar, direction safety, production matrix, runtime state contract, and package strategy in this document. Commit and push the plan before generating assets.

### WP2 — Chroma anchors and carriers

Generate seven GPT Image 2 chroma anchors: E/W for S-04, E for the three mirror-safe bosses, and E/W for CHOIR Prime. Generate fourteen four-second Veo 3.1 carriers using identical first/last anchors and audio disabled. Verify MP4 integrity and preserve masters outside the repository.

### WP3 — Extraction and atlas packing

Process every carrier into eight transparent WebP frames. Derive west sequences only for SAMARITAN, MIMESIS, and CANTOR. Pack one four-sequence atlas per boss, emit JSON manifests, inspect the five final atlases, and copy only runtime atlases plus provenance into the repository.

### WP4 — Godot runtime integration

Add the catalog, atlas-region playback, session/controller signal wiring, live player-relative facing, lifecycle reset, import settings, and focused contract coverage. Replace static runtime texture preloads without changing mechanics or backend/server code.

### WP5 — Source, export, and WebDev synchronization

Merge concurrent shared-main work semantically, push the completed feature to `main`, create a fresh Godot 4.7.2 Web export, patch the title/audio shell, upload fresh WASM and PCK objects, update the existing WebDev project and continuity records, save a checkpoint, and publish when a direct publish tool exists. Repository-wide release-gate, Xvfb, browser-matrix, lint/type/build, and equivalent certification steps remain skipped under the project-level override.

## Acceptance Matrix

| Layer | Acceptance requirement |
|---|---|
| Coverage | Five bosses each expose E/W `moving` and `attacking` sequences. |
| Identity | Concept-specific silhouette, palette, body modules, and signature asymmetry remain stable. |
| Camera/key | Carriers use a locked camera, constant scale, fixed origin, flat `#FF00FF`, no audio, and no extra subjects. |
| Runtime | One prewarmed rig sprite renders one region from one boss atlas; no combat-time node allocation occurs. |
| Facing | Visible boss faces the live player; S-04 archive and CHOIR pylon semantics do not swap. |
| State | `SCREEN` uses moving; controller telegraph/active/recovery stages select the corresponding attack frame ranges. |
| Mechanics | Hurt regions, sockets, attack areas, damage timing, safe lanes, supports, wrecks, evidence, and outcomes are unchanged. |
| Responsive | Existing 520×390 fit and portrait presentation scaling remain authoritative. |
| Lifecycle | Armor generation changes, retry, death, wreck, stop, and New Game+ cannot retain stale animation state. |
| Delivery | Shared `main`, the fresh Web export, immutable payload map, runtime manifest, continuity records, and WebDev checkpoint identify the same feature tree. |

## Implementation Record

| Work package | Status | Revision / checkpoint | Notes |
|---|---|---|---|
| WP1 — Reference lock and plan | Complete | `86fa1a5` | Five references and current static sprites inspected; 14-carrier/20-sequence matrix selected and pushed before generation. |
| WP2 — Anchors and carriers | Complete | External masters | Seven GPT Image 2 anchors and fourteen 4-second locked Veo 3.1 carriers; 720p and audio disabled. |
| WP3 — Extraction and atlases | Complete | Implementation commit pending | Twenty eight-frame sequences packed into five 32-frame lossless masters and five compact runtime atlases; visual inspection recorded externally. |
| WP4 — Godot integration | Complete | Implementation commit pending | Catalog, prewarmed region playback, player-relative facing, controller-stage wiring, lifecycle reset, and contract coverage implemented. |
| WP5 — Export and WebDev | Pending | Pending | Fresh runtime payloads and checkpoint. |

## References

[1]: /home/ubuntu/skills/video-to-sprites/SKILL.md "Manus Video to Sprites Production Workflow"
[2]: ../game/art/bosses/RUNTIME_ASSET_MANIFEST.md "Project CHOIR Boss Runtime Asset Manifest"
[3]: ./concepts/district-bosses/README.md "Project CHOIR District Boss Concept Art"
[4]: ./DISTRICT_BOSS_IMPLEMENTATION_PLAN.md "Project CHOIR District Boss Implementation Plan"
[5]: ../game/scripts/siege/boss_rig_2d.gd "BossRig2D Shared Presentation Runtime"
