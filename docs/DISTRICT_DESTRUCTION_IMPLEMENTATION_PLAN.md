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
| Select district by five-building forward spans | Each district maps one unique facade to each of five chunks; clearing all five unlocks the next span, while Royal starts at chunk 20 and continues indefinitely. |
| Select one of five district variants deterministically | A stable catalog and seed/chunk hash provide replay without random searching or slot-dependent rerolls. |
| Reconfigure pooled buildings in place | Texture, size, material grid, crack seed, and metadata change before state restore; cell nodes and physics objects are reused. |
| Use 25 GPT Image 2 transparent facade sprites | This provides actual architectural variety while one shared procedural system supplies alpha-clipped cavities, cracks, pipes, cables, bursts, and physical debris without destroyed cross-section or rubble-background art. |
| Raise the Web PCK ceiling to **16 MiB** | The current 8 MiB bundle has negligible headroom; the new ceiling remains explicit, tested, and reported rather than silently bypassed. |

## Work Packages

### WP0 — Concept lock, visual targets, and documentation

**Deliverables:** five district concept boards; 25 named building briefs; design document; implementation plan.

**Checks:** verify every district has exactly five unique buildings; inspect all concept boards for silhouette separation, side-view readability, and art-direction coherence; run `git diff --check`.

**Completion rule:** commit and push documentation/concept assets before runtime code begins.

### WP1 — District and building data contracts

Create `StructuralBuildingVariant`, `CityDistrictProfile`, and `CityDistrictCatalog`. The catalog owns five ordered district IDs, five stable building IDs per district, district road/accent values, display dimensions, material layouts, texture references, and signature metadata.

Extend `CityChunkBlueprint` with `district_index`, `district_id`, `building_variant_index`, and `building_variant_id`. Selection must be deterministic from run seed and logical chunk, independent of resident slot order. The current forward-only progression revision uses spatial ranges 0–4, 5–9, 10–14, 15–19, and 20+, with exits gated by five unique building clears.

**Tests:** catalog count and uniqueness; six material IDs per variant; direct lookup of all 25 IDs; deterministic generation across multiple seeds and call orders; forward boundary expectations; westward chunks remain in Business.

**Regression gate:** direct import, GDScript checks for touched files, focused GUT tests, then the standard `./verify.sh`. Commit and push after green.

### WP2 — Pooled runtime reconfiguration and persistence

Add `StructuralBuilding2D.apply_variant()` and safe reconfiguration helpers. Existing cell nodes must update facade regions, display size, material profiles, health maxima, collision shapes, tint, and deterministic damage-pattern seed without allocation. No secondary destroyed-cell texture or geometry channel is permitted.

Add `BuildingDamagePattern2D.reconfigure()` so a pooled cell can adopt a new texture region and variant seed before stream state restore. The same node remains authoritative after cell failure, darkening only opaque facade texels and retaining final cracks, pipes, and cables. Structural state gains a schema version and variant ID. Legacy states without identity remain compatible with the original chunk-zero building; incompatible variant state resets rather than crossing identities.

Update `StreamedDestructibleRuntime` to resolve the blueprint variant, apply it before ledger restore, and expose district/variant metadata. Preserve one building per chunk, all existing relayed signals, and current aliases used by `CitySlice`.

**Tests:** every variant exposes six cells; material grids apply; support transfer and floor/steel chains still pass; state capture/restore preserves variant identity and crack signature; slot instance IDs and node count remain constant across all district boundaries; no post-warm creation.

**Regression gate:** focused destruction/streaming tests, standard `./verify.sh`, landscape and portrait representative renders. Commit and push after green.

### WP3 — Production facade asset pack and gallery verification

Generate 25 standalone transparent facade sprites with GPT Image 2 using the approved district boards and current building art as references. Resize and losslessly optimize to a compact gameplay envelope; keep originals out of the source repository if their size is unnecessary. Import runtime sprites without mipmaps.

Wire every catalog entry to its one authored facade. Use that same texture for intact and alpha-clipped cavity sampling while retaining procedural crack/attachment nodes. Do not add a second facade shell, damaged texture, rubble texture, interior plate, or destroyed cross-section sprite.

Add `building_variant_gallery_scenario.gd` to render five buildings per district in deterministic intact and damaged/hollow states. Capture 1280×720 and 720×1280 representative frames. Add catalog digest and district/variant traces to the endless-terrain selftest.

**Tests:** all sprite resources load; alpha margins and atlas slicing are valid; no facade seam at cell boundaries; gallery shots exist at exact dimensions; district identity remains readable in gameplay; PCK ≤ 16 MiB.

**Regression gate:** `./verify.sh --full`, direct import, bounded boot, log scans, gallery inspection, and fresh Web export. Commit and push after green.

### WP3A — Spatial district transition feedback

Expose `CityWorldStream.current_district_id` and a typed boundary signal without coupling spatial geography to siege acts. Carry district and variant IDs on each pooled street chunk, tint lane marks with the active district accent, and present a prebuilt allocation-free transition banner when forward progression crosses chunks 5, 10, 15, and 20 after clearing the preceding district’s five unique buildings. The banner must reposition responsively below persistent HUD instrumentation in landscape and portrait.

Extend the endless-terrain report with a SHA-256 catalog digest and selected district/variant traces. Require all five districts, stable node count, zero post-warm creation, and mutation continuity while traversing from west of origin through Royal territory.

**Regression gate:** focused transition tests, complete GUT suite, standard `./verify.sh`, and inspected 1280×720 plus 720×1280 Royal gameplay renders. Commit and push after green.

### WP3B — Guaranteed live facade roster mapping

Replace modulo selection from a per-chunk string hash with a deterministic, seed-aware permutation of each district's authored five-building roster. The first five forward chunks in every district must select all five variants exactly once; later chunks cycle through the same permutation. Preserve the original Mercy Exchange Annex at chunk zero while allowing the remaining Business entries and all later districts to permute reproducibly.

Extend catalog tests to check complete roster coverage across multiple run seeds. Extend the pooled streaming test to traverse all 25 roster slots and compare each live cell sprite's resource path with its blueprint facade. Extend the endless-terrain report with expected/live variant and texture identities, and make `all_twenty_five_live_facades_mapped` a blocking runtime assertion while preserving six pooled buildings and zero post-warm allocation.

**Regression gate:** focused catalog/stream tests, all-25 live endless traversal, `./verify.sh --full`, five landscape district galleries, portrait gallery inspection, representative live landscape/portrait frames, non-threaded Web export, and Chromium gameplay smoke. Commit and push after green.

### WP3C — Natural breach traversal and visible facade cycling

Replace per-cell ground collision teardown with a continuous full-height passage contract. Destroying any ground-row structural cell must remove that cell’s blocking collision while disabling every intact collider required by the open passage, allowing the robot to walk through low and tall silhouettes alike. Persistent remains are limited to shallow, nonblocking rubble fragments at each terminal cell’s lower edge; no cell-sized background, interior, or replacement facade may remain. The passage state must be reconstructed from the mutation ledger after pooled slot reuse.

Add a non-teleport unit regression that destroys one ground cell, advances the robot with normal horizontal physics, and requires the next facade variant to become active. Add an Xvfb visual scenario that naturally reaches all five Business facades at their intact gameplay approach points and captures five unique landscape plus five unique portrait frames. This gate exists because the previous all-25 traversal test teleported between chunks and therefore could validate data mapping while stepping around a physical wall.

**Regression gate:** focused destruction and pooled-stream tests; normal-input passage reproduction; five unique naturally reached Business facades in 1280×720 and 720×1280; `./verify.sh --full`; direct boot; Web export; Chromium gameplay smoke; clean runtime logs. Commit and push after green.

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
| Destruction | Alpha-clipped dark hollows, cracks, cable/pipe details, transient bursts, physical debris, support transfer, floor and steel chains; every failed ground bay leaves a shallow road-level fragment pile while upper failures add no floating rubble; no failure adds a persistent cross-section, interior, replacement facade, or cell-sized background art; terminal props/catalysts obey the same rubble-only rule; any ground breach opens a full-height walkable passage |
| Persistence | District/variant identity, health, destroyed mask, crack signature, and detail mask restored after recycling |
| Visual | Five district galleries, five naturally reached Business facades, and representative landscape and portrait gameplay frames inspected |
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
| WP3B | Completed | This bugfix commit | Root cause confirmed as hash-modulo roster collisions (2/5 Entertainment and 3/5 Residential at seed zero). Full gate passed in 586 s with 288/288 tests and 28,467 assertions; all 25 live facade IDs and texture paths matched across five districts; landscape/portrait galleries and live Crownward renders passed; Web PCK measured 13,796,484 bytes; Chromium smoke passed. |
| WP3C | Completed | `c1c9c5b99ab6af47c8751774426d1b011039fa1a` | Root cause confirmed as intact neighboring and overhead cell colliders retaining a physical wall after a visible ground breach. The non-teleport passage test and ten natural traversal screenshots require all five Business facades to become actual gameplay targets. The pushed-revision full gate passed in 667 s with 301/301 tests and 28,786 assertions; five distinct landscape and five distinct portrait approach frames passed; Web PCK measured 14,105,752 bytes; Chromium gameplay smoke passed. |
| WP4 | Completed | `c85fb134d7a03d83b93e8692dceaf5469fff0a25` | 279/279 GUT tests and 27,935 assertions passed; full harness passed in 607 s; PCK 13,766,156 bytes; mission-card, district, mobile, melee-audio, export, and Chromium lanes passed; WebDev checkpoint `6f4645ed` published |
| Post-WP4 presentation maintenance | Completed | This maintenance commit | Replaced the English title hook with the user-approved payback story, expanded responsive story bounds, and lifted only the robot visual root to a tested 15–16 px road-line clearance. Full gate passed in 711 s with 296/296 tests and 28,672 assertions; title and gameplay landscape/portrait renders, 9-file Web export, 13,823,212-byte PCK, and Chromium gameplay smoke passed. |
| Procedural facade restoration | Completed | Current maintenance contract | Deleted facade-resampled cross-section rendering plus every structural damaged/rubble texture channel. All 25 variants use one authored facade while `BuildingDamagePattern2D` drives progressive erosion and preserves each terminal cell as a darkened, bottom-connected jagged arch with recognizable side piers and crown. Every terminal ground bay exposes four fixed material-matched rubble fragments on the road. Static and all-variant regressions prevent a separate cross-section, rubble backdrop, or replacement facade from returning. |
| Progressive sprite hollowing | Completed | `172fa284e23f0620ea741a283b3e47438588e5a1` | Replaced overlay-only cavity darkening with one material on each authored cell sprite. Normalized damage expands a seed-stable, atlas-normalized center-out alpha void and darkens surviving pixels continuously; terminal failure erases most of the center/lower middle while retaining dark irregular side rails and a top lintel. Nonterminal progress persists and legacy state reconstructs from health. Four focused tests passed with 4,316 assertions across all 25 facades and 150 terminal cells; the fresh PCK is 16,108,216 bytes. |
| Terminal arch and fracture polish | Completed | Current maintenance contract | Replaced terminal radial craters with six seed-stable bottom-connected jagged arch families that preserve original side piers while varying crown cadence, asymmetry, notches, and serration; increased terminal darkening; matched each ground bay to a seed-stable chipped top; added four deterministic road-level rubble sprites; and extended each prewarmed burst slot with subtle residual smoke. Terminal crack scribbles remain suppressed and nonterminal fracture density remains restrained across all 25 variants. |
| Rubble-only terminal policy | Completed | Current maintenance contract | Ground-level facade failures and every terminal streamed car, streetlamp, and catalyst structure use fixed nonblocking fragment beds. Broken/wreck/spent prop sprites remain legal only before terminal destruction; terminal state hides them and leaves fragment rubble. The shared presenter accepts only concrete, glass, and steel debris textures and cannot create collision, interiors, cross-sections, replacement facades, or stretched backgrounds. |
| Severe interior and impact-profile VFX | Completed | This maintenance commit | Added one fixed additive fire/ember/electrical renderer per damage pattern, attack-family cavity profiles for punches, missiles, and ground smashes, and one falling-debris emitter plus expanded dust cloud in every existing section-burst slot. Profile and direction persist across streaming; pooled reset restores generic pristine state. Nine focused tests passed with 283 assertions, including runtime retry and saturation budgets. |
| Districts 2–5 layer audit and silhouette diversification | Completed | Current maintenance contract | Landscape and portrait galleries exposed one remaining opaque authored plate behind the Residential Bluewire Laundry Walkup stairwell; its source alpha now opens the stairwell to the world while preserving rails and landings. Entertainment, Military, and Royal showed no cross-section, duplicate-shell, or alpha-halo anomaly. Fixed ground rubble uses four material-matched pieces with deterministic concrete, steel, and glass scale ranges on the road layer. The semantic upstream integration passed 9 focused tests with 6,965 assertions across all variants, upper/ground persistence, terminal props, and exact budgets. Both gallery lanes and a dedicated actual-city, production-baseline layer scenario completed in landscape and portrait, producing eight Districts 2–5 road-context captures without parser or shader diagnostics; independent final review passed all four districts in both orientations. |

## Deployment Record

The public domain `https://protoscoll-enopta8p.manus.space/` serves checkpoint `6f4645ed` and its immutable `/manus-storage/game_9696d1de.pck` payload. The canonical source branch advanced afterward with independently verified charged-smash work; that later release is outside this district implementation record.

## References

[1]: ../game/scripts/destruction/structural_building_2d.gd "StructuralBuilding2D"
[2]: ../game/scripts/world/city_world_stream.gd "CityWorldStream"
[3]: ../game/scripts/world/streamed_destructible_runtime.gd "StreamedDestructibleRuntime"
[4]: ../game/scripts/siege/district_definition.gd "DistrictDefinition"
[5]: ../game/scripts/quality/runtime_budget.gd "RuntimeBudget"
[6]: ../game/verify.sh "Repository verification harness"
