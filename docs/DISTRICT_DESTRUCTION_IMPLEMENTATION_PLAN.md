# District Destruction Implementation Plan

**Author:** Manus AI  
**Status:** Completed — verified WebDev checkpoint published
**Target branch:** `main`  
**Engine:** Godot 4.7.2-stable

## Objective

Implement five forward-progressing spatial districts and a deterministic roster of 25 destructible buildings without replacing the existing six-act siege encounter model. The implementation must preserve the fixed six-building resident pool, six-cell destruction topology, WorldMutationLedger continuity, runtime budgets, Web export compatibility, and fullscreen Manus WebDev deployment.[1] [2] [3]

## Architectural Decisions

| Decision | Rationale |
|---|---|
| Introduce **spatial district profiles** rather than repurposing `DistrictDefinition` | Existing district resources describe encounter acts, boss completion, and HUD phase cadence, not streamed geography.[4] |
| Keep `StructuralBuilding2D` at **3 columns × 2 rows** | Atlas slicing, hit mapping, support transfer, chain reactions, scoring, state restore, and runtime budgets all depend on six stable cells.[1] |
| Keep exactly **six live buildings** | The streamer owns six resident chunks and requires zero post-warm content creation.[2] [3] |
| Select district by logical forward chunk | The world itself remains stable and replayable; chunks behind zero remain Business, while Royal starts at chunk 32 and continues indefinitely. |
| Select one of five district variants deterministically | A stable catalog and seed/chunk hash provide replay without random searching or slot-dependent rerolls. |
| Reconfigure pooled buildings in place | Texture, size, material grid, crack seed, and metadata change before state restore; cell nodes and physics objects are reused. |
| Use 25 GPT Image 2 transparent facade sprites | This provides actual architectural variety while the existing procedural system supplies cracks, pipes, cables, hollowing, and shared rubble. |
| Raise the Web PCK ceiling to **16 MiB** | The current 8 MiB bundle has negligible headroom; the new ceiling remains explicit, tested, and reported rather than silently bypassed. |

## Work Packages

### WP0 — Concept lock, visual targets, and documentation

**Deliverables:** five district concept boards; 25 named building briefs; design document; implementation plan.

**Checks:** verify every district has exactly five unique buildings; inspect all concept boards for silhouette separation, side-view readability, and art-direction coherence; run `git diff --check`.

**Completion rule:** commit and push documentation/concept assets before runtime code begins.

### WP1 — District and building data contracts

Create `StructuralBuildingVariant`, `CityDistrictProfile`, and `CityDistrictCatalog`. The catalog owns five ordered district IDs, five stable building IDs per district, district road/accent values, display dimensions, material layouts, texture references, and signature metadata.

Extend `CityChunkBlueprint` with `district_index`, `district_id`, `building_variant_index`, and `building_variant_id`. Selection must be deterministic from run seed and logical chunk, independent of resident slot order. Spatial ranges are 0–7, 8–15, 16–23, 24–31, and 32+.

**Tests:** catalog count and uniqueness; six material IDs per variant; direct lookup of all 25 IDs; deterministic generation across multiple seeds and call orders; forward boundary expectations; westward chunks remain in Business.

**Regression gate:** direct import, GDScript checks for touched files, focused GUT tests, then the standard `./verify.sh`. Commit and push after green.

### WP2 — Pooled runtime reconfiguration and persistence

Add `StructuralBuilding2D.apply_variant()` and safe reconfiguration helpers. Existing cell nodes must update facade regions, display size, material profiles, health maxima, collision shapes, rubble geometry, tint, and deterministic damage-pattern seed without allocation.

Add `BuildingDamagePattern2D.reconfigure()` so a pooled cell can adopt a new texture region and variant seed before stream state restore. Structural state gains a schema version and variant ID. Legacy states without identity remain compatible with the original chunk-zero building; incompatible variant state resets rather than crossing identities.

Update `StreamedDestructibleRuntime` to resolve the blueprint variant, apply it before ledger restore, and expose district/variant metadata. Preserve one building per chunk, all existing relayed signals, and current aliases used by `CitySlice`.

**Tests:** every variant exposes six cells; material grids apply; support transfer and floor/steel chains still pass; state capture/restore preserves variant identity and crack signature; slot instance IDs and node count remain constant across all district boundaries; no post-warm creation.

**Regression gate:** focused destruction/streaming tests, standard `./verify.sh`, landscape and portrait representative renders. Commit and push after green.

### WP3 — Production facade asset pack and gallery verification

Generate 25 standalone transparent facade sprites with GPT Image 2 using the approved district boards and current building art as references. Resize and losslessly optimize to a compact gameplay envelope; keep originals out of the source repository if their size is unnecessary. Import runtime sprites without mipmaps.

Wire every catalog entry to its own facade. Use the facade for intact and fracture-patch sampling while retaining shared material-tinted rubble and existing procedural crack/attachment nodes.

Add `building_variant_gallery_scenario.gd` to render five buildings per district in deterministic intact and damaged/hollow states. Capture 1280×720 and 720×1280 representative frames. Add catalog digest and district/variant traces to the endless-terrain selftest.

**Tests:** all sprite resources load; alpha margins and atlas slicing are valid; no facade seam at cell boundaries; gallery shots exist at exact dimensions; district identity remains readable in gameplay; PCK ≤ 16 MiB.

**Regression gate:** `./verify.sh --full`, direct import, bounded boot, log scans, gallery inspection, and fresh Web export. Commit and push after green.

### WP3A — Spatial district transition feedback

Expose `CityWorldStream.current_district_id` and a typed boundary signal without coupling spatial geography to siege acts. Carry district and variant IDs on each pooled street chunk, tint lane marks with the active district accent, and present a prebuilt allocation-free transition banner when forward progression crosses chunks 8, 16, 24, and 32. The banner must reposition responsively below persistent HUD instrumentation in landscape and portrait.

Extend the endless-terrain report with a SHA-256 catalog digest and selected district/variant traces. Require all five districts, stable node count, zero post-warm creation, and mutation continuity while traversing from west of origin through Royal territory.

**Regression gate:** focused transition tests, complete GUT suite, standard `./verify.sh`, and inspected 1280×720 plus 720×1280 Royal gameplay renders. Commit and push after green.

### WP4 — Web runtime, Manus WebDev deployment, and continuity

Re-fetch upstream and repeat affected gates if the revision moves. Export through the repository’s `Web` preset and require HTML, JavaScript, WASM, and PCK artifacts with recorded SHA-256 checksums and sizes. Serve over HTTP and run browser smoke checks for canvas readiness, movement, smash, district trace, mutation restore, portrait resize, request failures, console errors, MIME types, and WebGL context loss.

Refresh the existing `proto-scroller` WebDev project only; preserve its fullscreen, borderless, dynamic-viewport iframe. Upload large WASM/PCK payloads through Manus storage, run `pnpm check` and `pnpm build`, restart and visually verify desktop/portrait previews, update `PLAN.md`, `STRUCTURE.md`, `MEMORY.md`, and `ASSETS.md`, save a checkpoint, and publish.

**Completion rule:** source `main` and WebDev project are clean and synchronized; final checkpoint and published URL are delivered; this plan is updated from “In progress” to “Completed” with actual revisions, test counts, export sizes, and known limitations.

## Verification Matrix

| Layer | Required evidence |
|---|---|
| Data | 5 districts, 25 globally unique variants, six valid material cells each |
| Determinism | Stable district/variant output by seed and logical chunk; direct addressability of all entries |
| Runtime shape | 6 streamed buildings, 36 damage-pattern nodes, zero post-warm creation, constant node count |
| Destruction | Cracks, cable/pipe details, hollow cells, rubble edges, support transfer, floor and steel chains |
| Persistence | District/variant identity, health, destroyed mask, crack signature, and detail mask restored after recycling |
| Visual | Five district galleries plus representative landscape and portrait gameplay frames inspected |
| Export | Nonempty HTML/JS/WASM/PCK; PCK ≤ 16 MiB; checksum manifest recorded |
| Browser | HTTP 200 assets, correct MIME, clean console/network logs, playable input, responsive iframe |
| Delivery | Per-work-package push, final WebDev checkpoint, published deployment, updated continuity docs |

## Risk Controls

The primary risk is package growth. Runtime facade sprites are therefore compact, mipmap-free, and shared across intact/fracture states. The second risk is stale mutation state crossing a changed variant; schema and variant identity are captured and validated before restore. The third risk is accidental node growth; all runtime variety is configuration applied to six existing slots. The fourth risk is conflating spatial and siege districts; the new catalog remains independent until a future task deliberately authors district-specific encounter arcs.

## Implementation Record

| Work package | Status | Source revision | Verification |
|---|---|---|---|
| WP0 | Completed | This work-package commit | Five concept boards and 25 building briefs validated at 1920×1080; documentation links verified |
| WP1 | Completed | This work-package commit | 5 districts, 25 variants, and deterministic chunk boundaries validated; 265 GUT tests passed; standard harness passed in 451 s |
| WP2 | Completed | This work-package commit | 25 profiles reconfigure six pooled building trees in place; 268 GUT tests passed; standard harness passed in 458 s; landscape and portrait Xvfb renders passed |
| WP3 | Completed | This work-package commit | 25 GPT Image 2 facades bound and gallery-verified in both orientations; 269 GUT tests passed; Web PCK measured 13,817,516 bytes under the 16 MiB ceiling; standard harness passed in 474 s |
| WP3A | Completed | This work-package commit | Four boundary transitions and responsive banner validated; 273 GUT tests passed with 27,879 assertions; all five trace IDs and catalog digest passed; post-integration standard harness passed in 463 s |
| WP4 | Completed | `c85fb134d7a03d83b93e8692dceaf5469fff0a25` | 279/279 GUT tests and 27,935 assertions passed; full harness passed in 607 s; PCK 13,766,156 bytes; mission-card, district, mobile, melee-audio, export, and Chromium lanes passed; WebDev checkpoint `6f4645ed` published |

## Deployment Record

The public domain `https://protoscoll-enopta8p.manus.space/` serves checkpoint `6f4645ed` and its immutable `/manus-storage/game_9696d1de.pck` payload. The canonical source branch advanced afterward with independently verified charged-smash work; that later release is outside this district implementation record.

## References

[1]: ../game/scripts/destruction/structural_building_2d.gd "StructuralBuilding2D"
[2]: ../game/scripts/world/city_world_stream.gd "CityWorldStream"
[3]: ../game/scripts/world/streamed_destructible_runtime.gd "StreamedDestructibleRuntime"
[4]: ../game/scripts/siege/district_definition.gd "DistrictDefinition"
[5]: ../game/scripts/quality/runtime_budget.gd "RuntimeBudget"
[6]: ../game/verify.sh "Repository verification harness"
