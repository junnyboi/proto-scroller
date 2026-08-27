# Forward-Only Progression and Left-Side Culling Implementation Plan

**Author:** Manus AI  
**Status:** Complete  
**Target branch:** `main`  
**Engine:** Godot 4.7.2-stable

## Objective

Convert the streamed city from unrestricted bidirectional traversal into a **forward campaign ratchet**. The robot may reposition locally, but its furthest-right logical position establishes a moving rear frontier exactly **500 pixels behind**. World chunks fully behind that frontier are culled, the resident spawn range excludes the discarded region, and an invisible collision wall prevents the robot from re-entering culled space. Spatial district progression changes from eight distance-only chunks to **five authored building clears per district**, matching the existing five-facade roster.[1] [2]

The implementation must preserve the six-slot streamed world, floating-origin stability, mutation persistence, district missions and pressure routing, boss gates, campaign progression, Web Audio fixes, Godot 4.7.2 Web export, and the existing fullscreen Manus WebDev host.[3] [4] [5]

## Behavioral Contract

| Concern | New contract |
|---|---|
| Forward progress | `CityWorldStream` records the maximum logical X reached during the run; moving left never reduces it. |
| Rear frontier | The minimum traversable logical X is `furthest_progress_x - 500.0`. |
| Physical enforcement | A pooled, invisible `StaticBody2D` follows the rear frontier. A defensive clamp repairs teleports or external displacement behind it. |
| Contact feedback | First contact with the rear wall emits one debounced event, pulses a left-weighted red vignette, and synchronously plays a subtle carrier-derived warning plus “We can't go back now!”; held contact does not restart either channel every frame. |
| Culling | A resident chunk is culled only after its right edge is at or behind the rear frontier. Culling hides the chunk, disables processing, and removes collision layers without deleting pooled nodes. |
| Spawn safety | `resident_bounds()` clamps its lower bound to the rear frontier so enemies and hazards cannot spawn in discarded space. |
| District size | Business, Residential, Entertainment, Military, and Royal each reserve seven logical chunks: five unique facades followed by two road-only handoff chunks. |
| District clear | A clear is credited once per unique `building_variant_id` in the building’s own district. Repeated signals, restored ruins, and duplicate variants cannot inflate progress. |
| District exit | An invisible eastbound gate advances one facade after each clear, then holds at the transition corridor until the boss, salvage shop, and old-skyline cull phases finish. |
| Boss handoff | The fifth unique facade arms and starts the current district boss before any shop or destination content can appear. |
| Salvage shop | Finishing the boss wreck creates one marked overlap at the defeated boss position; walking forward across it opens that district's shop. |
| Empty corridor | Shop checkout opens two road-only chunks. Future-district buildings and props remain hidden, nonprocessing, and noncolliding while the player advances. |
| Next district | The next district and act activate atomically only when the rear frontier has passed the right edge of every old facade. |
| Final district | Royal completes directly after its post-boss salvage shop; there is no nonexistent sixth-district stream activation. |
| Reset | Retry/New Game+ stream reset clears the rear frontier, district-clear sets, and geographic unlock state using the new run’s current robot position. |

## Architecture

### `CityWorldStream`

`CityWorldStream` remains the authority for logical coordinates, resident-window reuse, and spatial district identity.[1] It gains the monotonic furthest-progress position, rear-frontier calculation, two preallocated barriers, per-district unique-clear sets, and district unlock state. Every physics update advances the floating origin as before, updates the frontier, repairs illegal rear displacement, refreshes resident chunks, applies culling only when a chunk changes state, and positions both barriers in runtime coordinates.

District transitions continue to emit only when the robot actually crosses into an activated destination chunk. The eastbound gate starts before the second facade, advances one chunk per accepted unique clear, and stops at the road-only handoff corridor after the fifth. `district_boss_ready` starts the matching boss; boss completion arms a world-space salvage trigger; shop checkout opens the corridor; and `post_boss_corridor_is_clear()` waits until the moving rear frontier has passed the last old facade before `complete_district_handoff()` activates the destination. This makes every required facade reachable, keeps the old skyline resident through the boss and shop, and prevents a recycled future facade from materializing on the player or over an old ruin.[4]

### `CityStreetChunk`

Each pooled chunk gains an idempotent `set_culled()` contract. The method stores original collision layers and masks on descendant `CollisionObject2D` nodes, zeros them while culled, restores them when recycled ahead, and disables processing without freeing any object. A forced refresh covers destructible children added after the base stream constructs its six chunk nodes.

### `StreamedDestructibleRuntime` and `CitySlice`

Streamed buildings receive explicit `logical_chunk` metadata during slot configuration. `CitySlice` forwards the existing deduplicated building-destroyed signal to `CityWorldStream.report_building_cleared()` before publishing ordinary rampage events. This keeps scoring and mission events untouched while giving spatial progression a stable building identity.[3]

### District Catalog and Boss Gates

`CityDistrictCatalog.CHUNKS_PER_DISTRICT` is seven: five authored facade slots plus two transition-corridor slots whose pooled destructibles are deliberately suppressed.[2] Boundaries become `0–6`, `7–13`, `14–20`, `21–27`, and `28+`. Boss trigger/unlock chunks align with the fifth facade and following district start: `4/7`, `11/14`, `18/21`, `25/28`, and Royal `32`.[5]

## Implementation Phases

### Phase 1 — Data contracts and plan lock

Update the catalog’s district span, profile boundaries, progression-tier cadence, boss trigger catalog, conceptual district tables, and user-facing README. Add the new plan and declare exact constants for the 500-pixel retention distance and five unique clears.

**Completion:** source data and documentation agree on the five-building geography model.

### Phase 2 — Rear frontier and pooled culling

Create the rear barrier and district exit gate once during stream initialization. Track logical furthest progress across floating-origin rebases. Clamp resident bounds, cull fully discarded chunks, restore recycled chunks, and enforce the physical ratchet without changing node count.

**Completion:** the robot can move left only within the retained 500-pixel envelope, and no active spawn/collision target remains fully behind it.

### Phase 3 — Clear-driven boss handoff

Attach logical chunk metadata to streamed buildings, forward destruction completion into the stream, deduplicate by district and facade ID, and arm the current district boss at five clears without activating the next district. Preserve the final Royal path.

**Completion:** five unique clears start the boss first; neither the shop nor next-district content can appear early.

### Phase 3B — Salvage shop and empty-corridor commit

Keep the boss arena resident after defeat, create one prewarmed overlap at the defeated wreck, open the shop only when the advancing robot crosses it, then expose two road-only chunks after checkout. Continue advancing and culling without destination facades until every old building is behind the rear frontier; then activate the next district and act in one commit.

**Completion:** the skyline never swaps on top of the robot, old and new pooled facades never overlap, and the player reads a deliberate boss → salvage → breathing-space → next-act cadence.

### Phase 4 — Contract tests and implementation record

Replace bidirectional endless-terrain assumptions with monotonic-frontier assertions. Add focused tests for the 500-pixel wall, culling and restoration, resident spawn bounds, duplicate-clear rejection, five-clear unlock, district transition boundaries, floating-origin invariance, reset semantics, and updated boss gates. Update this plan’s implementation record after code completion.

Under the project-level release override, full release-gate certification, broad regression suites, Xvfb/browser matrices, and repeated stabilization loops are skipped unless explicitly requested. The source contracts are still updated so future verification runs exercise the new behavior.

### Phase 5 — Source and WebDev delivery

Commit and push the final integrated tree to shared `main`, create a fresh Godot 4.7.2 non-threaded Web export, apply the title-video and audio-worklet patches, upload fresh immutable WASM/PCK objects, update the existing `proto-scroller` WebDev host and continuity records, and save the checkpoint for publication.

## Acceptance Matrix

| Layer | Acceptance requirement |
|---|---|
| Movement | Furthest progress is monotonic; rear frontier remains exactly 1,000 px behind it. |
| Collision | Walking or dodging left cannot cross the invisible rear wall. |
| Feedback | Rear-wall contact produces one responsive red vignette pulse and one non-spatial `Voice`-bus warning cue from the same debounced event, with no input interception. |
| Culling | Chunks fully behind the frontier are hidden, nonprocessing, and noncolliding; recycled chunks restore correctly. |
| Streaming | Exactly six chunk nodes and six building slots remain allocated. |
| Spawning | Resident lower bound never enters culled territory. |
| Districts | Five geographic districts retain five globally unique facades each, with two additional road-only handoff chunks per district. |
| Unlocks | Exactly five unique current-district clears arm the boss; only boss defeat, salvage-shop checkout, and old-facade culling unlock the next district. |
| Deduplication | Duplicate destruction notifications and restored ruins do not add progress. |
| Bosses | Bosses start immediately after each fifth facade and retain handoff ownership until the corresponding shop and corridor complete. |
| Pop-in | Future-district buildings remain suppressed until all old facades have crossed the rear frontier. |
| Floating origin | Logical frontier and district gates remain stable across runtime rebases. |
| Delivery | Shared `main`, fresh Web export, immutable WebDev payloads, continuity docs, and final checkpoint identify the same revision. |

## Risks and Controls

The highest risk is disabling pooled collisions without restoring mutation-sensitive state. The culling API therefore changes only collision layers and masks, never individual destruction shape flags. The second risk is a skipped facade becoming unreachable after the rear frontier advances; the sequential eastbound gate prevents the robot from entering facade N+1 until facade N is cleared. The third risk is district and boss gate disagreement; both derive their boundaries from the same five-chunk contract and remain separately testable. The fourth risk is floating-origin drift; all authoritative frontier and gate values remain logical coordinates and convert to runtime X only for presentation and physics. The fifth risk is premature district credit from a recycled slot; explicit district, variant, and logical-chunk metadata plus per-district sets prevent cross-identity credit.

## Implementation Record

| Phase | Status | Revision | Notes |
|---|---|---|---|
| 1 — Contracts and plan | Complete | `8324c7e` | Existing eight-chunk design and boss assumptions reviewed; exact forward-ratchet contract recorded. |
| 2 — Rear frontier/culling | Complete | `fca74d1` | Monotonic 500-pixel frontier, invisible rear wall, pooled chunk culling/restoration, spawn-bound clamping, and actor release implemented. |
| 3 — Clear-driven unlocks | Complete | `fca74d1` | Sequential eastbound gate advances across five unique facades; district and boss caps now align at five-chunk intervals. |
| 4 — Contract updates | Complete | `fca74d1` | Streaming, district, boss, narrative, persistence, localization, and scenario contracts updated without executing release-gate suites per project override. |
| 5 — Source/WebDev delivery | Complete | `fca74d1` / WebDev `c0da9c13` | Shared `main` updated non-force; fresh Godot 4.7.2 Web export synchronized to immutable WASM/PCK payloads and saved in the existing host checkpoint. |
| 6 — Rear-wall warning feedback | Complete | `5b16bd9` / WebDev `82a6869a` | Debounced contact signal, prewarmed input-transparent shader vignette, HUD wiring, runtime-budget contract, fresh Godot 4.7.2 export, and existing-host synchronization delivered. |
| 7 — Rear-wall warning audio | Complete | `66b4b21` / WebDev `4f2100a8` | GPT Image 2 anchor, generated video-carrier bed, exact `Gacrux` line, mastered 48 kHz mono cue, synchronous debounced HUD playback, fresh Godot 4.7.2 export, and combined concurrent-host checkpoint delivered. |
| 8 — Boss/shop/corridor handoff | Complete | `dd5f25f` / WebDev `240dc289` | Each fifth facade triggers its boss first; the defeated-boss overlap opens the shop; future content remains suppressed through two road-only chunks; old facades must be culled before the next district and act activate atomically. The checkpoint also preserves concurrent district weather, progressive facade hollowing, and optimized cosmetic Web imports. |

## Delivered Runtime

The delivered staged-handoff revision is `dd5f25f`. WebDev checkpoint `240dc289` maps `/manus-storage/game_0b8d1591.wasm` (39,514,754 bytes) and `/manus-storage/game_38b66e51.pck` (14,655,884 bytes). The checkpoint semantically preserves concurrent district weather, progressive facade hollowing, optimized cosmetic Web imports, the two-stage transformer, size-aware enemy telegraphs, responsive fullscreen rendering, the managed leaderboard, and prior audio/title behavior. Full release-gate certification was intentionally not executed under the project-level user override; the required Godot 4.7.2 Web export completed successfully from shared `main`.

## References

[1]: ../game/scripts/world/city_world_stream.gd "CityWorldStream"
[2]: ../game/scripts/world/city_district_catalog.gd "CityDistrictCatalog"
[3]: ../game/scripts/world/streamed_destructible_runtime.gd "StreamedDestructibleRuntime"
[4]: ./DISTRICT_MISSIONS_AND_BALANCE_PLAN.md "District Missions and Difficulty Escalation Plan"
[5]: ../game/scripts/siege/boss_campaign_catalog.gd "BossCampaignCatalog"
