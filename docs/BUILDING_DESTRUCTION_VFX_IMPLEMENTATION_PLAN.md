# Building Section Destruction VFX — Implementation Plan

**Status:** Complete and deployed
**Engine:** Godot 4.7.2 stable, GL Compatibility, non-threaded Web export
**Target branch:** `main`

## Objective

Make every structural-cell failure feel materially distinct and forceful without changing damage, scoring, collision, traversal, chain-reaction, or streaming persistence contracts. The final effect combines generated material-specific macro debris, a bounded burst of textured micro-fragments, dust or sparks, and a short impact flash. All runtime nodes are prewarmed and reused.

## Design Contract

| Material | Macro debris | Particle burst | Motion character |
|---|---|---|---|
| Concrete | Jagged reinforced masonry | Dense tan-gray dust and small chips | Broad, heavy fan with moderate gravity |
| Glass | Translucent cyan shard | Fast crystal splinters with a restrained dust mist | Wide, sharp spray with lower gravity |
| Steel | Torn beam fragment | Orange-white sparks and dark metal flakes | Narrow directional fan with high gravity and slower heavy bodies |

The authoritative physical debris remains `DebrisPool`/`DebrisBody2D`, preserving kinetic damage, collision, culling, capacity, and recycling. GPT Image 2 textures replace only the procedural presentation of concrete, glass, and steel building chunks. A new `BuildingSectionBurstPool` owns twelve prewarmed `BuildingSectionBurst2D` slots. Each slot contains fixed CPU emitters for the directional impact fragments, a longer falling-debris cascade, and a broad dust cloud plus a reusable flash sprite; saturation recycles the oldest active slot rather than allocating.

## Work Packages

### WP0 — Architecture and visual target

Document the material language, fixed capacities, integration points, responsive/camera behavior, reset behavior, and focused acceptance criteria. Commit and push the plan before asset generation.

### WP1 — GPT Image 2 production assets

Generate five isolated, no-text visual assets on removable chroma backgrounds: concrete chunk, glass shard, steel fragment, dust puff, and impact flash. Use the existing authored facade as style reference. Deterministically remove the temporary background, trim transparent margins, pad to square power-of-two canvases, resize runtime derivatives, and record source/runtime hashes and prompts.

**Acceptance:** clean alpha, complete silhouettes, no chroma fringe, no text, no baked environment or drop shadow, compact 128×128 runtime files, successful Godot import.

### WP2 — Pooled runtime implementation

1. Add generated material textures to `DebrisBody2D` while preserving procedural drawing as a fallback for non-building scrap.
2. Add `BuildingSectionBurst2D` with fixed dust, fragment, and flash children.
3. Add `BuildingSectionBurstPool` with twelve prewarmed slots, oldest-active recycling, activation counters, material telemetry, pause-safe reset, and no post-warm creation.
4. Mount the pool in `CityRuntimeServices`, expose it through `CitySlice`, route it into every streamed structural cell, and clear it during New Game+ reset.
5. Trigger the burst exactly once when an accepted damage event transitions a cell to destroyed, including support and chain-reaction failures.
6. Keep all effects beneath the robot/HUD render layers and non-authoritative for gameplay.

### WP3 — Focused evidence

Add regressions for fixed capacity, no node growth under saturation, material texture selection, bounded material-specific particle counts, single activation per destroyed cell, reset behavior, and preservation of physical debris collision/kinetic behavior. Add a deterministic visual scenario that captures concrete, glass, and steel section bursts in landscape and portrait.

Repository-wide release gates are intentionally skipped under the project override. Run only touched-file lint/import, selected GUT cases, and the dedicated visual scenario.

### WP4 — Source integration and WebDev deployment

Push the final source phase to shared `main`, produce a fresh exact Godot Web export, apply the existing local-worklet/title-shell patches, upload both WASM and PCK, remap the existing `proto-scroller` WebDev project, update `PLAN.md`, `STRUCTURE.md`, `MEMORY.md`, and `ASSETS.md`, save a checkpoint, and deploy through the existing project.

## Completed Evidence — WP0–WP3

| Evidence | Result |
|---|---|
| GPT Image 2 assets | Five canonical 1920×1920 source concepts and five deterministic 128×128 transparent runtime derivatives; exact SHA-256 lineage recorded in `BUILDING_DESTRUCTION_VFX_ASSET_PROVENANCE.md` |
| Runtime architecture | Twelve prewarmed composite burst slots; concrete/glass/steel fragment emitter, dust emitter, low-opacity residual-smoke emitter, and flash sprite per slot; oldest-active recycling under saturation |
| Physical debris | Existing 24-body structural pool preserved; concrete, glass, and steel building chunks use generated textures while enemy machinery scrap retains its procedural visual path |
| Focused unit integration | Three dedicated VFX tests passed with 48 assertions, including fixed capacity, material selection, one-shot destruction, stream restore, replay, and New Game+ teardown |
| Related debris regressions | Eight focused tests across the new VFX, organic damage, and culling suites passed with 133 assertions |
| Responsive visuals | Concrete, glass, and steel failures produced exactly three live section bursts plus sixteen physical debris bodies in both 1280×720 and 720×1280 captures |
| Diagnostic scan | Touched-file lint, Godot 4.7.2 import, headless fixture, and both Xvfb lanes completed without script, parse, leak, or retained-resource markers |

## Completed Deployment — WP4

The runtime implementation landed in `4c81f0c4122512b9d112ee8874a07ee39e7ff877`. Concurrent projectile-impact cue compression was then integrated by fast-forward, producing final canonical descendant `f9ae2365fde613e53cce938a66be520c442d8e72` without rewriting shared history. A fresh Godot 4.7.2 non-threaded Web export was generated from that exact tree and synchronized to the existing full-stack `proto-scroller` WebDev project.

| Deployment item | Final value |
|---|---|
| Source revision | `f9ae2365fde613e53cce938a66be520c442d8e72` |
| WebDev checkpoint | `manus-webdev://9ab37b4b` |
| WASM | `UVgwogCabHumLyOE.wasm`; 39,514,754 bytes; SHA-256 `fc74679e3b97f76878947fcd4fbe1268cbfa6188182a2e33bbc3f5dc9bfa57d0` |
| PCK | `OZecJchIZDOKnjbr.pck`; 16,885,708 bytes; SHA-256 `80cf44d6d784d6e2bf24dfb16a2bbccb771507c4529c1de00b95b01eb298196e` |
| Host contract | Dynamic-viewport, borderless fullscreen iframe; managed leaderboard/database retained; local audio worklets and title scheduler retained |
| Release policy | Repository-wide gates and historical package-budget enforcement skipped under the explicit project override |

## Acceptance Criteria

- Every newly destroyed building section emits one visible material-specific burst.
- Macro debris uses generated concrete/glass/steel textures and preserves existing rigid-body behavior.
- Concrete, glass, and steel have observably different particle count, spread, color, gravity, and texture.
- Twelve burst slots and twenty-four structural debris bodies remain the hard runtime ceilings.
- Saturation recycles; it never creates new combat nodes.
- Restored destroyed cells do not replay bursts; a later fresh destruction does.
- New Game+ clears active bursts.
- Landscape and portrait captures keep effects inside the world viewport and below the robot/HUD.
- Fresh exact WASM and PCK payloads are synchronized to the existing fullscreen WebDev host.

## Post-Deployment Facade Presentation Restoration

The generated concrete, glass, steel, dust, and flash assets remain the source for transient section bursts, physical macro debris, and fixed persistent rubble fragments beneath every terminal structural cell. Persistent failed cells still instantiate no `BuildingRubbleEdge2D`, second facade shell, interior plate, stretched rubble backdrop, or destroyed cross-section image. `BuildingDamagePattern2D` preserves the single authored facade cell, applies deterministic fatal geometry as a bottom-connected jagged arch, darkens the surviving side piers and crown more heavily, and chips the lower story's upper silhouette. Damaged but living sections deterministically show only one of generated fire, one broken pipe, or one dangling cable; terminal failure stops and hides that accent immediately. Every fresh failure also restarts a subtle residual-smoke emitter inside the existing twelve-slot burst pool. This contract applies automatically to all 25 district variants through the existing pooled reconfiguration path.

`PersistentRubbleBed2D` extends the same bounded terminal-remains contract to streamed cars and streetlamps plus destructible catalyst structures. Their authored wreck or spent texture is strictly a nonterminal stage. Full destruction hides it and activates only three transparent steel-fragment sprites with no collision, facade sampling, rectangular fill, or interior imagery. Persistent rubble never consumes the transient 24-body debris pool and never replays a destruction burst when restored.

The district-style extension keeps the same fragment textures and fixed node ceilings. Each rubble bed now combines its material color with one of five restrained grades: cold cyan-blue Business, weathered teal Residential, desaturated neon-magenta Entertainment, olive-amber Military, and bronze-gold Royal. Facade variants carry their authoritative district identity; streamed props update it whenever a resident slot is reassigned; catalysts capture the live district when armed. The existing twelve `BuildingSectionBurst2D` slots now also support a dust-only rubble-formation activation: nine low-opacity puffs spread across the rubble footprint for 1.05 seconds, recycle the oldest slot under saturation, and trigger only on the live terminal transition. Existing facade bursts receive the same district grade, while restored terminal state activates rubble silently without replaying dust.

The later severe-damage extension preserves the twelve-slot ceiling while adding a dedicated falling-debris emitter to each slot and increasing the dust emitter's lifetime, size, and material-specific particle count. Destruction still triggers the composite slot exactly once, streamed restore never replays it, and saturation still recycles without node growth.

The original custom-drawn flame triangles and electrical arcs were subsequently removed. Severe sections selected for fire now play a shared 24-frame transparent WebP animation generated from a GPT Image 2 anchor through a locked Veo 3.1 carrier and the Manus video-to-sprites extractor. The animation shares one `SpriteFrames` resource across fixed per-cell players and stops at terminal failure; no runtime allocation or additional burst slot is introduced.
