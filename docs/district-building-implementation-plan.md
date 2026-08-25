# Six-District Destructible Building Implementation Plan

**Author:** Manus AI

**Project:** Proto Scroller

**Scope:** Residential, business, nightlife, shopping, government, and military districts; thirty destructible building archetypes

## Executive Summary

The new city should be implemented as a **data-driven district and building layer**, not as thirty bespoke building scripts. Each generated building becomes a `BuildingArchetype` resource containing its district, intact façade texture, structural footprint, material grid, world cell size, spawn weight, and optional district-specific VFX modifiers. The existing `StructuralBuilding2D` remains the single destruction authority, but its hard-coded 3×2 constants become instance configuration so every archetype inherits the same damage, crack, hollow-façade, upper-support damage, chain-collapse, debris, cable, pipe, spark, spray, collision, scoring, and stream-state behavior.

The delivered asset package contains **thirty standalone GPT Image 2 PNGs**, five per district, plus a machine-readable manifest. Every runtime candidate has a true transparent background and a source grid based on **192×256 pixels per structural cell**, closely matching the existing world-cell aspect ratio. The package is conceptually complete for intact façade art; damaged appearance should continue to come from the procedural system rather than requiring thirty separately painted damaged atlases.

## Current Architecture and Required Changes

The current structural building is fixed at three columns, two rows, six cells, and a 500×445 world display. Texture regions, collision shapes, material assignment, chain reactions, neighbor tests, support damage, and state indexing all depend directly on those constants.[1] The streaming runtime prewarms one building per resident chunk, assigns the same three building textures to every slot, and restores damage state when a chunk is reused.[2] Chunk blueprints are already deterministic because each logical chunk derives a generation seed from the run seed and logical index.[3] The world stream maintains six resident chunks across a 1,344-pixel chunk width, with two chunks behind and three ahead of the player.[4] These properties are the correct foundation; the plan preserves deterministic streaming and fixed-cap pooling while replacing fixed building content.

| Current constraint | Target behavior | Required implementation |
|---|---|---|
| `COLUMNS = 3`, `ROWS = 2` | Archetypes use 2–5 columns and 2–4 rows | Replace constants in instance logic with `grid_columns`, `grid_rows`, and `cell_count()` accessors. |
| One intact, damaged, and rubble texture | Thirty intact façades; shared procedural damage and rubble | Bind an archetype’s intact texture; use the intact texture as the façade source for damage fragments and hollow edges; retain a shared rubble texture. |
| One hard-coded 2×3 material grid | Material map authored per archetype | Store a row-major array of material IDs in each archetype resource and validate its size. |
| One building type per chunk | District-weighted deterministic archetype selection | Add district and archetype IDs to `CityChunkBlueprint`. |
| Six fixed building nodes with six cells each | Six fixed building slots supporting up to twenty cells each | Prewarm maximum cell capacity and enable only the selected archetype footprint. |
| Mutation IDs identify only `building` | Persistence must bind damage state to an archetype | Store `archetype_id`, schema version, grid dimensions, and cell state together. |
| Runtime budget assumes 36 building cells | Maximum becomes 120 pooled cells | Update explicit caps and prove no post-warm growth under maximum-size buildings.[5] |

> **Design rule:** District and building selection may change presentation, materials, footprint, and VFX weighting, but never bypass or fork the established destruction state machine.

## Data Model

### `BuildingArchetype`

Create `res://scripts/destruction/building_archetype.gd` as a typed `Resource`. Each `.tres` resource should contain:

| Field | Type | Purpose |
|---|---|---|
| `archetype_id` | `StringName` | Stable persistence and analytics key. |
| `district_id` | `StringName` | District catalog lookup. |
| `intact_texture` | `Texture2D` | Generated façade atlas. |
| `grid_columns` | `int` | Two through five. |
| `grid_rows` | `int` | Two through four. |
| `cell_world_size` | `Vector2` | Default `Vector2(166.67, 222.5)` to preserve current destruction scale. |
| `material_ids` | `Array[StringName]` | Row-major `concrete`, `steel`, or `glass` values. |
| `spawn_weight` | `int` | District-local deterministic selection weight. |
| `score_multiplier` | `float` | Optional reward normalization for larger footprints. |
| `debris_tint` | `Color` | District material accent without new physics. |
| `spark_multiplier` | `float` | Bounded VFX variation. |
| `water_multiplier` | `float` | Bounded pipe-spray variation. |
| `attachment_bias` | `StringName` | `domestic`, `commercial`, `institutional`, or `military`. |

The resource validator must reject duplicate IDs, dimensions outside the declared limits, a material array whose length differs from `columns × rows`, missing textures, or weights below one.

### `DistrictDefinition`

Create `res://scripts/world/district_definition.gd` with `district_id`, display name, ordered archetype resources, chunk-span length, transition palette, and optional hazard/enemy weighting hooks. District definitions should not directly spawn nodes; they are immutable content catalogs consumed by `CityChunkBlueprint`.

### `DistrictCatalog`

Create a static catalog that preloads six district resources and offers deterministic lookup by ID. The generated `building_asset_manifest.json` should remain the asset-authoring source of truth; a checked conversion test must ensure every manifest entry has exactly one `.tres` archetype and every resource points back to the expected PNG.

## Generalizing `StructuralBuilding2D`

Refactor the class in one coordinated change rather than incrementally mixing constant and instance dimensions.

1. Add `configure_archetype(archetype: BuildingArchetype)` before `_ready()` builds cells. The method assigns the texture, grid dimensions, display size, material map, score normalization, and visual modifiers.
2. Replace every use of `COLUMNS`, `ROWS`, and `CELL_COUNT` with `grid_columns`, `grid_rows`, and `cell_count()`. This includes hit lookup, region slicing, cell indexing, chain traversal, floor checks, neighbor queries, rubble geometry, support damage, impact-column ordering, and completion checks.[1]
3. Keep row-major indexing as `row * grid_columns + column` so stream-state arrays remain compact and deterministic.
4. Set `display_size = Vector2(grid_columns, grid_rows) * cell_world_size`. The default cell size preserves current combat scale; therefore a 5×2 building is approximately 833×445 world pixels and fits inside a 1,344-pixel street chunk, while a 2×4 tower becomes approximately 333×890 world pixels.[4]
5. Use the intact façade texture for both `IntactVisual` and the textured procedural damaged fragments. Continue using `BuildingDamagePattern2D` for cracks, missing panels, cables, pipes, sparks, and water. Continue using `BuildingRubbleEdge2D` for complete-cell façade hollowing.
6. Generalize the material map. District resources choose steel, concrete, and glass cell profiles, but those profiles continue to own health, resistance, debris count, chunk count, and tint.
7. Preserve the current rule that destroying a bottom-row cell applies 50% maximum-health support damage to the cell above.[1] For buildings taller than two rows, propagate only one row per direct destruction event; subsequent collapses remain the responsibility of existing chain logic.
8. Replace the hard-coded upper-row collision height with an archetype-independent collision inset derived from `cell_world_size.y`, then add tests for every supported row count.

## Fixed-Cap Pooling and Streaming

The six-chunk resident window must remain allocation-stable.[4] Each streamed building slot should prewarm **twenty cells**, the maximum 5×4 footprint. Selecting a smaller building disables surplus cells, their collision, processing, VFX emitters, and visuals without freeing nodes. Across six resident buildings, the explicit cap becomes 120 cells.

`StreamedDestructibleRuntime._build_slot()` should build one configurable structural building per chunk but should no longer bind textures or dimensions there. `_configure_slot()` should resolve `blueprint.building_archetype_id`, reconfigure the slot, assign its world position, and then restore mutation state.[2]

Because a reused slot may change from one footprint to another, `StructuralBuilding2D` needs a deterministic reset sequence:

1. Increment stream generation to cancel deferred chain reactions.
2. Disable all pooled cells and clear signals/state owned by the previous archetype.
3. Apply the new archetype resource.
4. Enable the first `columns × rows` cells and rebuild only their lightweight region, collision, material, and metadata values; do not allocate nodes.
5. Restore a matching persisted state or pristine defaults.
6. Refresh exposed hollow edges and damage attachments.

The mutation ledger record should become:

```gdscript
{
  "schema": 2,
  "archetype_id": &"res_tenement_block",
  "columns": 3,
  "rows": 4,
  "cells": [...],
  "chain_count": 0,
  "last_chain": &"",
  "steel_chain": false,
  "floor_rows": {},
  "pristine": true,
}
```

The object ID remains based on logical chunk and role, while the record carries the selected archetype. If a future catalog change causes an ID mismatch, the runtime should discard the stale state and start pristine rather than applying damage to a different building.

## District Progression and Procedural Selection

Add the following fields to `CityChunkBlueprint`: `district_id`, `district_index`, `district_progress`, `building_archetype_id`, and `building_local_x`. Selection remains a pure function of run seed and logical chunk, extending the existing deterministic generation pattern.[3]

Use **ten core chunks per district** with a two-chunk blend at each boundary. The recommended forward sequence is residential, shopping, business, nightlife, government, and military. This produces a readable escalation from ordinary city life to defended endgame space without coupling districts to the existing enemy progression tiers.

| District | Core chunks | Transition behavior | Building emphasis |
|---|---:|---|---|
| Residential | 0–9 | Chunks 8–9 admit 25–50% shopping weight | Dense medium buildings, occasional tall narrow tower. |
| Shopping | 10–19 | Chunks 18–19 admit business weight | Broad commercial targets and varied storefront forms. |
| Business | 20–29 | Chunks 28–29 admit nightlife weight | Vertical towers alternating with low exchanges. |
| Nightlife | 30–39 | Chunks 38–39 admit government weight | Neon industrial entertainment forms and wide clubs. |
| Government | 40–49 | Chunks 48–49 admit military weight | Monumental stone, brutalist mass, fortified precincts. |
| Military | 50 onward | Remains military with deterministic cycling | Bunkers, depots, barracks, and communications towers. |

For reverse travel, derive district from absolute progression distance so a logical chunk always maps to one district in a run. Within each district, use weighted selection with a deterministic anti-repeat rule: no archetype may appear more than twice consecutively, and every archetype must appear at least once within any twelve core district chunks. Store only the final archetype ID in the blueprint; the runtime must not consume random numbers.

Position buildings from their computed width. A building’s left edge must remain inside the chunk, with a minimum 96-world-pixel street margin and no overlap with mandatory props. Large 5-column buildings should use a constrained local X range; narrow towers may vary more widely.

## Asset Integration

The generated asset library is located under `res://art/city/districts/` and is indexed by `building_asset_manifest.json`. Every PNG uses a transparent canvas whose dimensions equal `grid_columns × 192` by `grid_rows × 256`. This source-cell ratio approximates the existing runtime cell ratio, minimizing resampling distortion when the façade is divided into regions.[1]

Integration steps are:

1. Keep the thirty PNGs and Godot `.import` sidecars in source control.
2. Generate one `BuildingArchetype` `.tres` per manifest entry under `res://data/buildings/<district>/`.
3. Assign the intact PNG to the archetype. Do not generate a separate painted damaged atlas; bind the intact texture as the fragment source for procedural cracks and hollow remnants.
4. Continue using the existing shared rubble texture until material-specific rubble atlases are justified by playtest evidence.
5. Author material grids in data. Residential favors brick-tinted concrete with selected glass; business favors glass and steel; government favors concrete and steel; military favors steel-heavy lower rows.
6. Preserve source texture filtering and region clipping behavior used by the current cell sprites.[1]
7. Add an automated manifest test that opens every PNG, verifies RGBA alpha, confirms exact manifest dimensions, and rejects files over a defined byte cap.

## Implementation Milestones

| Milestone | Deliverable | Primary files | Exit gate |
|---|---|---|---|
| M1 — Content schema | Typed archetype and district resources plus manifest validator | `building_archetype.gd`, `district_definition.gd`, `district_catalog.gd`, new tests | All 30 resources load; weights total 100 per district. |
| M2 — Variable structural grid | `StructuralBuilding2D` supports 2–5 × 2–4 | `structural_building_2d.gd`, damage/rubble helpers | Matrix test destroys and restores all supported footprints. |
| M3 — Fixed maximum pool | Six slots × twenty prewarmed cells | `streamed_destructible_runtime.gd`, runtime budget | Zero post-warm node creation across repeated district transitions. |
| M4 — Deterministic district blueprints | District/archetype fields and anti-repeat selection | `city_chunk_blueprint.gd`, district sequence tests | Same seed reproduces the same 60-chunk sequence. |
| M5 — Asset resource binding | Thirty `.tres` resources and generated PNG imports | `res://data/buildings/`, manifest tests | Every archetype displays correct grid, texture, and material map. |
| M6 — Persistence migration | Schema-2 mutation state keyed by archetype | stream runtime, mutation ledger tests | Damage survives chunk recycling and cannot cross archetype IDs. |
| M7 — Visual district pass | Transition palettes, props, representative screenshots | world stream and selftests | Six district screenshots pass at landscape and portrait viewports. |
| M8 — Complete release hardening | Full combat, budget, export, and Web validation | full test suite and scenarios | Exact project verification passes with no growth, parser, resource, or export errors. |

## Validation Matrix

Automated coverage must include all thirty archetypes rather than a representative subset.

| Gate | Required assertions |
|---|---|
| Asset contract | Thirty unique IDs; five per district; RGBA alpha; exact dimensions; valid Godot imports; no raw generation duplicates. |
| Construction | Each resource configures correct columns, rows, display size, material count, texture regions, collisions, and enabled cell count. |
| Damage | Every cell accepts damage, enters partial damage, exposes attachments, hollows on destruction, and culls attachments when destroyed. |
| Support behavior | Destroying every lower cell damages only the corresponding cell directly above by 50%. |
| Chain reactions | Floor and steel chains traverse arbitrary dimensions without duplicate destruction or index errors. |
| Persistence | Pristine, partial, and destroyed states restore after slot reuse for all footprints. |
| Determinism | Same run seed and chunk index reproduce district, archetype, placement, and material map. |
| Variety | Five archetypes appear per district window and no archetype appears more than twice consecutively. |
| Runtime budget | Six slots, 120 pooled cells, bounded attachments and particles, no post-warm node or resource growth. |
| Gameplay | Robot collision, jab-cross opening, ground smash, enemy targeting, score, debris, and camera framing work for shortest, tallest, widest, and largest buildings. |
| Visual | One windowed screenshot per district plus portrait samples for the tallest and widest archetypes. |
| Export | Release Web bundle includes all thirty textures and resources with no missing-resource or network errors. |

## Rollout Strategy

Land the system behind a content flag. First ship residential and business using ten archetypes while retaining the legacy building as a fallback. After persistence and budget telemetry are stable, enable shopping and nightlife, then government and military. The final change removes the legacy hard-coded texture constants only after every district is covered by deterministic tests.

Do not merge all thirty resources and the generalized pool in one unreviewable commit. Use milestone-sized commits where each commit passes focused tests, the complete headless gate, and the project’s windowed quality scenarios. If the optional Web preview is explicitly initialized later, refresh it only after each milestone passes the native gates.

## Acceptance Criteria

The feature is complete when the player traverses all six districts in a deterministic run; each district can spawn five recognizable buildings; every building uses the same structural destruction behavior; all partial and complete damage persists through streaming; no pool grows after warmup; all generated art imports cleanly; and full native plus Web release validation passes.

## References

[1]: https://github.com/junnyboi/proto-scroller/blob/main/game/scripts/destruction/structural_building_2d.gd "StructuralBuilding2D current grid, texture slicing, materials, support damage, and chain reactions"
[2]: https://github.com/junnyboi/proto-scroller/blob/main/game/scripts/world/streamed_destructible_runtime.gd "StreamedDestructibleRuntime current pooling, texture assignment, and mutation restoration"
[3]: https://github.com/junnyboi/proto-scroller/blob/main/game/scripts/world/city_chunk_blueprint.gd "CityChunkBlueprint deterministic generation"
[4]: https://github.com/junnyboi/proto-scroller/blob/main/game/scripts/world/city_world_stream.gd "CityWorldStream resident window and progression"
[5]: https://github.com/junnyboi/proto-scroller/blob/main/game/scripts/quality/runtime_budget.gd "RuntimeBudget fixed-cap validation"
