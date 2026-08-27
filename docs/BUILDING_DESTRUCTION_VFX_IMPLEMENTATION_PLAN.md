# Building Section Destruction VFX — Implementation Plan

**Status:** In progress
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

The authoritative physical debris remains `DebrisPool`/`DebrisBody2D`, preserving kinetic damage, collision, culling, capacity, and recycling. GPT Image 2 textures replace only the procedural presentation of concrete, glass, and steel building chunks. A new `BuildingSectionBurstPool` owns twelve prewarmed `BuildingSectionBurst2D` slots. Each slot contains fixed CPU particle emitters and a reusable flash sprite; saturation recycles the oldest active slot rather than allocating.

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
