# Forward-Only Progression and Left-Side Culling Implementation Plan

**Author:** Manus AI  
**Status:** In progress  
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
| Culling | A resident chunk is culled only after its right edge is at or behind the rear frontier. Culling hides the chunk, disables processing, and removes collision layers without deleting pooled nodes. |
| Spawn safety | `resident_bounds()` clamps its lower bound to the rear frontier so enemies and hazards cannot spawn in discarded space. |
| District size | Business, Residential, Entertainment, Military, and Royal each expose five unique facade chunks before the next geography can be entered. |
| District clear | A clear is credited once per unique `building_variant_id` in the building’s own district. Repeated signals, restored ruins, and duplicate variants cannot inflate progress. |
| District exit | An invisible forward district gate remains closed at the next district’s first chunk until all five unique buildings in the current district are destroyed. |
| Boss compatibility | Existing boss gates remain independent and may continue blocking the same boundary after the geographic five-building requirement is satisfied. |
| Final district | Royal still streams indefinitely after its five-building roster; there is no nonexistent sixth-district gate. |
| Reset | Retry/New Game+ stream reset clears the rear frontier, district-clear sets, and geographic unlock state using the new run’s current robot position. |

## Architecture

### `CityWorldStream`

`CityWorldStream` remains the authority for logical coordinates, resident-window reuse, and spatial district identity.[1] It gains the monotonic furthest-progress position, rear-frontier calculation, two preallocated barriers, per-district unique-clear sets, and district unlock state. Every physics update advances the floating origin as before, updates the frontier, repairs illegal rear displacement, refreshes resident chunks, applies culling only when a chunk changes state, and positions both barriers in runtime coordinates.

District transitions continue to emit only when the robot actually crosses into the destination chunk. Clearing the fifth building opens the geographic exit; it does not emit `district_changed` prematurely. This preserves mission withdrawal, pressure selection, narrative introduction, and transition-banner semantics.[4]

### `CityStreetChunk`

Each pooled chunk gains an idempotent `set_culled()` contract. The method stores original collision layers and masks on descendant `CollisionObject2D` nodes, zeros them while culled, restores them when recycled ahead, and disables processing without freeing any object. A forced refresh covers destructible children added after the base stream constructs its six chunk nodes.

### `StreamedDestructibleRuntime` and `CitySlice`

Streamed buildings receive explicit `logical_chunk` metadata during slot configuration. `CitySlice` forwards the existing deduplicated building-destroyed signal to `CityWorldStream.report_building_cleared()` before publishing ordinary rampage events. This keeps scoring and mission events untouched while giving spatial progression a stable building identity.[3]

### District Catalog and Boss Gates

`CityDistrictCatalog.CHUNKS_PER_DISTRICT` changes from eight to five so the first five chunks of every district map one-to-one to its complete authored facade permutation.[2] Boundaries become `0–4`, `5–9`, `10–14`, `15–19`, and `20+`. Boss trigger/unlock chunks move to the matching district caps: `4/5`, `9/10`, `14/15`, `19/20`, and Royal `24`.[5]

## Implementation Phases

### Phase 1 — Data contracts and plan lock

Update the catalog’s district span, profile boundaries, progression-tier cadence, boss trigger catalog, conceptual district tables, and user-facing README. Add the new plan and declare exact constants for the 500-pixel retention distance and five unique clears.

**Completion:** source data and documentation agree on the five-building geography model.

### Phase 2 — Rear frontier and pooled culling

Create the rear barrier and district exit gate once during stream initialization. Track logical furthest progress across floating-origin rebases. Clamp resident bounds, cull fully discarded chunks, restore recycled chunks, and enforce the physical ratchet without changing node count.

**Completion:** the robot can move left only within the retained 500-pixel envelope, and no active spawn/collision target remains fully behind it.

### Phase 3 — Clear-driven district unlocking

Attach logical chunk metadata to streamed buildings, forward destruction completion into the stream, deduplicate by district and facade ID, open the next boundary at five clears, and reset progress on a new stream run. Preserve the final Royal endless path.

**Completion:** crossing into the next district is impossible before five unique clears and possible immediately afterward, subject to existing boss gates.

### Phase 4 — Contract tests and implementation record

Replace bidirectional endless-terrain assumptions with monotonic-frontier assertions. Add focused tests for the 500-pixel wall, culling and restoration, resident spawn bounds, duplicate-clear rejection, five-clear unlock, district transition boundaries, floating-origin invariance, reset semantics, and updated boss gates. Update this plan’s implementation record after code completion.

Under the project-level release override, full release-gate certification, broad regression suites, Xvfb/browser matrices, and repeated stabilization loops are skipped unless explicitly requested. The source contracts are still updated so future verification runs exercise the new behavior.

### Phase 5 — Source and WebDev delivery

Commit and push the final integrated tree to shared `main`, create a fresh Godot 4.7.2 non-threaded Web export, apply the title-video and audio-worklet patches, upload fresh immutable WASM/PCK objects, update the existing `proto-scroller` WebDev host and continuity records, and save the checkpoint for publication.

## Acceptance Matrix

| Layer | Acceptance requirement |
|---|---|
| Movement | Furthest progress is monotonic; rear frontier remains exactly 500 px behind it. |
| Collision | Walking or dodging left cannot cross the invisible rear wall. |
| Culling | Chunks fully behind the frontier are hidden, nonprocessing, and noncolliding; recycled chunks restore correctly. |
| Streaming | Exactly six chunk nodes and six building slots remain allocated. |
| Spawning | Resident lower bound never enters culled territory. |
| Districts | Five geographic districts retain five globally unique facades each, with five chunks per finite district. |
| Unlocks | Exactly five unique current-district building clears unlock the next geographic boundary. |
| Deduplication | Duplicate destruction notifications and restored ruins do not add progress. |
| Bosses | Boss triggers align with district caps and continue to gate campaign progression independently. |
| Floating origin | Logical frontier and district gates remain stable across runtime rebases. |
| Delivery | Shared `main`, fresh Web export, immutable WebDev payloads, continuity docs, and final checkpoint identify the same revision. |

## Risks and Controls

The highest risk is disabling pooled collisions without restoring mutation-sensitive state. The culling API therefore changes only collision layers and masks, never individual destruction shape flags. The second risk is district and boss gate disagreement; both derive their boundaries from the same five-chunk contract and remain separately testable. The third risk is floating-origin drift; all authoritative frontier and gate values remain logical coordinates and convert to runtime X only for presentation and physics. The fourth risk is premature district credit from a recycled slot; explicit district, variant, and logical-chunk metadata plus per-district sets prevent cross-identity credit.

## Implementation Record

| Phase | Status | Revision | Notes |
|---|---|---|---|
| 1 — Contracts and plan | In progress | Pending | Existing eight-chunk design and boss assumptions reviewed. |
| 2 — Rear frontier/culling | Pending | Pending | |
| 3 — Clear-driven unlocks | Pending | Pending | |
| 4 — Contract updates | Pending | Pending | |
| 5 — Source/WebDev delivery | Pending | Pending | |

## References

[1]: ../game/scripts/world/city_world_stream.gd "CityWorldStream"
[2]: ../game/scripts/world/city_district_catalog.gd "CityDistrictCatalog"
[3]: ../game/scripts/world/streamed_destructible_runtime.gd "StreamedDestructibleRuntime"
[4]: ./DISTRICT_MISSIONS_AND_BALANCE_PLAN.md "District Missions and Difficulty Escalation Plan"
[5]: ../game/scripts/siege/boss_campaign_catalog.gd "BossCampaignCatalog"
