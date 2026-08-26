# Implementation Audit 01: Narrative, Dossiers, and Persistence

**Audit scope:** Project CHOIR narrative delivery, 25 dossiers, black-lab reveals, retry continuity, short transmissions, and campaign persistence.
**Repository baseline:** synchronized `main` at `9f6e127` (`docs: record district mission release`).
**Contract:** `docs/PROJECT_CHOIR_STORY_PROPOSAL.md`.
**Constraint observed:** no production files were edited.

## Executive assessment

The current game already exposes nearly all low-level events required by a lightweight `NarrativeDirector`, but it has **no campaign-lifetime owner, no narrative save, and no run-start/run-finish signals**. The safest implementation is an observer layer rather than a combat owner: a Main-owned, versioned `CampaignProgressStore` survives `CitySlice` replacement; a per-city `NarrativeDirector` subscribes to spatial district, siege, destruction, enemy, boss, and lifecycle events; fixed-capacity presentation nodes render transmissions and black-lab reveals without pausing play.

The most important distinction is that there are two different meanings of “district.” `CityWorldStream.district_changed(previous_district_id, district_id, logical_chunk)` is the five-district **spatial campaign transition** and is the correct story-arrival source. `UrbanSiegeRuntime.district_completed` is emitted only after the six-act response arc and command-wreck finisher; it is the **run terminal choice**, not completion of a spatial district. `UrbanSiegeRuntime.act_changed(index, act_id, display_name)` and `beat_changed(...)` are response-phase hooks. Conflating these will fire district truth reveals and completion thresholds at the wrong time.

## Existing architecture and exact integration points

| Concern | Existing class/signal/path | Audit finding and intended use |
|---|---|---|
| Stable app lifetime | `Main` in `game/scripts/main/main.gd` | `retry_game()` removes and frees the old `CitySlice`, then `_spawn_city_slice()` creates a fresh one. `Main` survives and is therefore the correct owner of campaign state. An autoload is unnecessary. |
| Run-local root | `CitySlice` in `game/scripts/gameplay/city_slice.gd` | Builds services, stream, destructibles, encounters, HUD, siege, `CityRunLifecycle`, and upgrades dynamically. Add and configure `NarrativeDirector` here, but inject the Main-owned store before `add_child(city_slice)` so `_ready()` can use it. |
| Retry request | `CitySlice.retry_requested`; `GameplayHud.retry_pressed`; `Main.retry_game()` | Retry currently guarantees fresh run-local score, upgrades, enemies, hazards, and nodes. Campaign state must not live below `CitySlice`. Record continuity before `retry_requested` causes replacement, and save immediately. |
| Run finish | `CityRunLifecycle.robot_defeated()` and private `_finish_run(completed)` in `game/scripts/gameplay/city_run_lifecycle.gd` | There is no public finish signal. Add `signal run_finished(completed: bool, summary: RunSummarySnapshot)` and emit once after `freeze_summary(...)`, before presentation. Optionally add `run_started(seed)` at a centralized CitySlice start point; do not infer completion from HUD visibility. |
| Spatial district | `CityWorldStream.district_changed(...)`, `current_district_id`, `current_logical_chunk`, and `run_configured(run_seed)` in `game/scripts/world/city_world_stream.gd` | Subscribe for Residential through Royal arrivals. Business has no initial transition signal, so `NarrativeDirector.begin_run(seed, current_district_id)` must explicitly process the initial arrival. Dedupe arrivals per run because moving backward also emits. |
| District card | `DistrictTransitionBanner.present(district, logical_chunk)` in `game/scripts/world/district_transition_banner.gd` | Existing 2.25-second, `MOUSE_FILTER_IGNORE`, non-pausing card already fits the contract. Extend it with localized optional story subtitle/target keys rather than creating a blocking overlay. Its current raw `district_id`/`display_name` text is not localized. |
| Siege progression | `UrbanSiegeRuntime.act_changed`, `beat_changed`, `recovery_started`, `milestone_reached`, `district_completed` in `game/scripts/siege/urban_siege_runtime.gd` | Observe for act/reveal/boss transmission triggers. `milestone_reached` is preferable to polling. Treat `district_completed` only as terminal-run flow. |
| Boss progression | `CommandBossSession.state_changed`, `armor_changed`, `completed` in `game/scripts/siege/command_boss_session.gd` | Use `state_changed` for short boss lines and `completed` for command-wreck resolution; avoid reading private state timers. |
| Enemy defeat | `EncounterRuntime.enemy_died(enemy, event, points)` in `game/scripts/encounter/encounter_runtime.gd` | Suitable for elite-drop dossier recovery and authored enemy reveal triggers. `CitySlice._on_enemy_died` already consumes the same signal; narrative must only observe and never release/spawn the defeated node itself. |
| Cell destruction | `StructuralBuilding2D.cell_destroyed(column, row, event)` → `StreamedDestructibleRuntime.building_cell_destroyed(building, column, row, event)` → `CitySlice._on_streamed_building_cell_destroyed(...)` | This is the canonical dossier/reveal hook. It carries building, exact 3×2 cell, and `DamageEvent`; the building exposes `current_variant_id()` plus metadata `stream_object_id`, `district_id`, `district_index`, and `building_variant_id`. |
| Whole facade destruction | `StructuralBuilding2D.destroyed(event)` → `StreamedDestructibleRuntime.building_destroyed(building, event)` | Observe only for consequences or fallback delivery. Do not award a dossier here if its authored cell was never breached. |
| In-run streamed mutation | `WorldMutationLedger` in `game/scripts/world/world_mutation_ledger.gd` | Preserves damaged cells while six building nodes are recycled, keyed as `chunk:<logical>:building`; it resets on run configuration. It is explicitly **not** a campaign save and must not store dossier ownership. |
| Facade identity | `CityDistrictCatalog` in `game/scripts/world/city_district_catalog.gd` | Defines exactly `DISTRICT_COUNT = 5`, `VARIANTS_PER_DISTRICT = 5`, and 25 globally unique `StructuralBuildingVariant.variant_id` values. Key one dossier to each exact variant ID. Seeded order changes placement but not identity; the opening Business variant remains Mercy Exchange Annex. |
| HUD | `GameplayHud` in `game/scripts/ui/gameplay_hud.gd` | Existing `status_label` and `objective_label` are frequently overwritten and are unsuitable for dialogue. Add a dedicated bounded `TransmissionToast` child with `MOUSE_FILTER_IGNORE`; keep the game-over overlay for summary/codex deltas. |
| Summary | `RunSummarySnapshot` and `RampageSession.freeze_summary(...)` in `game/scripts/rampage/` | Snapshot is immutable after construction and currently has no dossier fields. Prefer passing a separate `NarrativeRunSnapshot` to HUD or adding constructor metrics once, rather than mutating a frozen summary later. |
| Settings persistence precedent | `AudioVolumeSettings`, `InputBindingSettings`, and `L10n` | All use injected `user://` ConfigFile paths and safe defaults. Campaign data needs its own versioned file, separate from `audio_settings.cfg`, `input_bindings.cfg`, and `localization.cfg`. |
| Localization | `L10n` plus `game/localization/en.json` and `zh-CN.json` | Both catalogs are expected to have matching keys and placeholder shapes. Every dossier title/body, speaker, district subtitle, transmission, continuity line, and codex label must exist in both catalogs. |
| Title/codex surface | `TitleScreen` in `game/scripts/title_screen.gd` and `game/scenes/title_screen.tscn` | The existing TAB briefing layer is the least disruptive place for an out-of-combat dossier codex. Configure it from Main-owned campaign state; do not make title UI read the save file independently. |

## Safest implementation shape

### 1. Separate persistent campaign state from run-local narrative state

Add `CampaignProgressStore` as a `Node` or `RefCounted` owned by `Main`. `Main._ready()` loads it before `_show_title()`. `_spawn_city_slice()` instantiates the city, calls a new `city_slice.configure_campaign(progress_store)` **before** `add_child(city_slice)`, and then connects retry. The same store instance is supplied to `TitleScreen` for the briefing/codex. This preserves dossier and continuity state across scene replacement without adding an autoload or coupling combat systems to disk I/O.

Use `user://choir_campaign.cfg`, with an injected path for tests. Recommended schema:

```ini
[meta]
schema_version=1

[progress]
collected_dossiers=PackedStringArray(...)
preserved_evidence=PackedStringArray(...)
unlocked_reveals=PackedStringArray(...)
continuity_generation=0

[ending]
seen_endings=PackedStringArray(...)
```

The store should expose typed operations such as `has_dossier(id)`, `collect_dossier(id)`, `dossier_count()`, `district_dossier_count(district_id)`, `increment_continuity()`, `snapshot()`, `load(path)`, and `save(path)`. `collect_dossier` must be idempotent and should emit `dossier_changed(id, total)` only on the first insert. Save immediately after a new dossier/evidence/continuity mutation so a destroyed chassis or browser close cannot lose already transmitted evidence. On missing/corrupt/unsupported data, retain a clean in-memory default and report an error; never block run startup. Validate IDs against the content catalog and ignore unknown IDs while retaining a migration path for future schema versions.

Do not put run score, upgrades, world mutation, current act, pending transmissions, or enemies in this file. Existing tests deliberately require upgrades, score, momentum, hazards, and node shape to reset on every `Main.retry_game()`.

### 2. Make dossiers content-addressed by the 25 stable facade IDs

Add `DossierDefinition` resources and `DossierCatalog`, with exactly one definition for every `StructuralBuildingVariant.variant_id` in `CityDistrictCatalog`. Each definition should contain `dossier_id`, `building_variant_id`, `district_id`, trigger `column`/`row`, image resource, localized title key, two localized body keys, and optional reveal/transmission IDs. Keep story metadata out of `StructuralBuildingVariant`: that resource currently owns rendering, materials, and destruction signature, and expanding it would couple campaign content to streaming validation.

The collection key must be `dossier_id`/variant identity, not `stream_object_id`. Facades repeat after five local chunks, while `stream_object_id` is chunk-specific; chunk keys would allow duplicate dossiers forever. Conversely, using only district ID would collapse five case files into one. Validate that the catalog is a bijection over all 25 variants, has five dossiers per district, every trigger cell is within `StructuralBuilding2D.COLUMNS = 3` and `ROWS = 2`, and all localization/image resources exist.

On `StreamedDestructibleRuntime.building_cell_destroyed`, `NarrativeDirector` reads `building.current_variant_id()` and compares `(column, row)` to the definition. It asks `CampaignProgressStore.collect_dossier(...)`; only a true first collection queues a toast and reveal. Preserve route safety by placing protected/dossier triggers in authored upper cells where intended and never gating `StructuralBuilding2D.ground_passage_open()` or collision on narrative state.

**Callback-order caveat:** `StructuralBuilding2D._on_cell_destroyed(...)` calls `_damage_cell_above(...)` before emitting the lower cell’s own `cell_destroyed`; this can synchronously emit an upper-cell callback first. Chain reactions also create later callbacks. Narrative handling must therefore be order-independent, match exact coordinates, and dedupe by dossier/event ID rather than assume lower-to-upper order or one callback per player strike.

### 3. Keep `NarrativeDirector` observational and deterministic

Create one `NarrativeDirector` per `CitySlice`. It owns only run-local sets/queues such as `fired_event_ids`, `arrived_district_ids`, and pending transmission IDs. It subscribes to:

- `CityWorldStream.district_changed` and `run_configured`;
- `UrbanSiegeRuntime.act_changed`, `beat_changed`, `milestone_reached`, and `district_completed`;
- `StreamedDestructibleRuntime.building_cell_destroyed` and `building_destroyed`;
- `EncounterRuntime.enemy_died`;
- `CommandBossSession.state_changed` and `completed`;
- the proposed `CityRunLifecycle.run_finished`.

Expose presentation requests as signals, for example `transmission_requested(event_id, speaker_key, line_key, seconds)`, `dossier_collected(definition, total, district_total)`, `facade_reveal_requested(building, column, row, reveal_id)`, and `continuity_updated(generation)`. `CitySlice` wires these to HUD/reveal presenters. The director must never pause `UrbanSiegeRuntime`, acquire a `RunPauseCoordinator` token, modify collision, award score, release enemies, or own combat spawn caps.

Provide a deterministic `begin_run(seed, initial_district_id)` because the initial Business district does not emit `district_changed`. Narrative selection should derive solely from stable event IDs and the run seed, never frame time. Tests should be able to call public event handlers or inject an event source without advancing real timers.

### 4. Prewarm black-lab visuals against the six-slot streaming model

The stream guarantees six reusable buildings (`CityWorldStream.CHUNK_CAPACITY`) and tests assert zero post-warm node creation. Add a fixed-capacity `FacadeRevealRuntime`/`BlackLabRevealPool` with one prebuilt reveal slot per resident building (or a documented fixed maximum if multiple simultaneous cells are required). A slot is configured from dossier/reveal data, parented or positioned behind the matching `StructuralBuilding2D`, and toggled visible when its authored cell is destroyed. It must not add collision or alter `capture_stream_state()`.

`StreamedDestructibleRuntime` currently has no public “building configured” signal. Add `signal building_configured(building, logical_chunk, variant_id)` emitted at the end of `_configure_slot(...)`; use it to clear/reconfigure the recycled reveal slot and restore visibility by inspecting `building.is_cell_destroyed(...)`. Initial six buildings are configured before a later NarrativeDirector can subscribe, so setup must also iterate `streamed_destructibles.buildings` once. Avoid connecting directly to `_slot_buildings` or `_configure_slot` internals.

The first reveal maps to `business_mercy_exchange_annex`, which `CityDistrictCatalog._variant_order(...)` deliberately pins first in Business. Reveals should use fixed textures/sprites, `visible` toggles, and generation checks analogous to structural streaming; do not instantiate a new lab scene on every breach.

### 5. Add a dedicated, nonblocking transmission surface

Add `TransmissionToast` under `GameplayHud`, separate from `status_label`, `objective_label`, directive choices, upgrade choices, and `GameOverOverlay`. It should have a bounded queue (recommended 3), replace/drop policy for stale low-priority lines, 2–5 second display duration, `process_mode` compatible with normal play, `MOUSE_FILTER_IGNORE`, and no focus grab. A new line must never call `get_tree().paused`, `RunPauseCoordinator.acquire`, disable `MobileControls`, or block attack input. The district card remains 2.25 seconds and noninteractive.

On chassis destruction, show a localized continuity line in the existing summary overlay and include “dossiers transmitted”/total; then increment/save continuity before retry. Dossier bodies belong in the post-run summary or title briefing codex, not in the combat toast. The toast should show only speaker plus one short localized line and optional dossier title.

### 6. Introduce explicit lifecycle events without changing reset ownership

Keep `Main.retry_game()` as the reset mechanism. Add `CityRunLifecycle.run_finished(completed, summary)` and emit it exactly once from `_finish_run` after campaign mutations can be snapshotted and before `GameplayHud.show_game_over/show_district_complete`. For start, either add a `CitySlice.run_started(seed)` after all runtime wiring or call `NarrativeDirector.begin_run(...)` explicitly after setup. Do not move campaign state into `RunSummarySnapshot`; the summary is frozen once, whereas campaign progress survives it.

Current `UrbanSiegeRuntime.start_run()` is called inside `CitySlice._build_urban_siege()` only outside headless mode. A broad start-order refactor risks tests that explicitly drive directors. The lower-risk phase-one change is explicit narrative `begin_run` after director setup, while leaving siege start semantics unchanged. If start ownership is later centralized, preserve the same-frame behavior for non-headless builds and the existing headless test behavior.

## Proposed production files

| Action | Path | Purpose |
|---|---|---|
| Add | `game/scripts/narrative/campaign_progress_store.gd` | Versioned ConfigFile load/save, validation, migration, idempotent campaign mutations. |
| Add | `game/scripts/narrative/dossier_definition.gd` | Typed dossier content resource. |
| Add | `game/scripts/narrative/dossier_catalog.gd` | Exact 25-variant mapping and validation. |
| Add | `game/scripts/narrative/narrative_director.gd` | Observer/rule engine and deterministic run-local dedupe. |
| Add | `game/scripts/narrative/narrative_run_snapshot.gd` | Immutable per-run dossier/reveal/continuity summary, if HUD needs more than scalar tokens. |
| Add | `game/scripts/narrative/facade_reveal_runtime.gd` | Fixed-capacity black-lab presentation tied to streamed slots. |
| Add | `game/scripts/ui/transmission_toast.gd` | Bounded, nonblocking short-transmission queue. |
| Add | `game/resources/narrative/dossiers/*.tres` and narrative art | 25 dossier definitions/images and reveal assets. |
| Modify | `game/scripts/main/main.gd` | Own/load store; inject it into title and each new city; preserve it across retry. |
| Modify | `game/scripts/gameplay/city_slice.gd` | Accept store, create director/reveal runtime, wire presentation signals. |
| Modify | `game/scripts/gameplay/city_run_lifecycle.gd` | Emit explicit one-shot `run_finished`; supply narrative snapshot to end overlay. |
| Modify | `game/scripts/world/streamed_destructible_runtime.gd` | Emit public `building_configured` after slot reconfiguration. |
| Modify | `game/scripts/ui/gameplay_hud.gd` | Build/use transmission toast and show dossier/continuity summary tokens. |
| Modify | `game/scripts/world/district_transition_banner.gd` | Localized optional narrative subtitle/target while retaining nonblocking behavior. |
| Modify | `game/scripts/title_screen.gd`, `game/scenes/title_screen.tscn` | Add dossier codex to existing briefing surface and accept injected progress snapshot. |
| Modify | `game/localization/en.json`, `game/localization/zh-CN.json` | All dossier, district, transmission, continuity, summary, and codex keys. |
| Modify | `game/scripts/quality/runtime_budget.gd` | Account for fixed narrative presenter/reveal capacities if budget snapshots enumerate them. |

`StructuralBuilding2D`, combat actors, scoring, and `WorldMutationLedger` should not require narrative-specific production edits for phase one.

## Compatibility and failure risks

| Risk | Consequence | Mitigation |
|---|---|---|
| Storing progress under `CitySlice` | Every retry erases dossiers and continuity. | Main-owned store injected into each city/title instance. |
| Treating `UrbanSiegeRuntime.district_completed` as a five-district transition | Truth reveals occur after the command boss regardless of spatial location. | Use only `CityWorldStream.district_changed` for campaign arrivals; name handlers explicitly (`_on_spatial_district_changed`, `_on_run_terminal_completed`). |
| Missing initial Business arrival | No opening card/transmission because no district change occurs at chunk 0. | Explicit `NarrativeDirector.begin_run(...)`. |
| Keying dossier ownership by chunk object ID | Repeated facades create duplicate dossier awards and unbounded saves. | Persist one dossier ID per stable variant ID. |
| Nested support/chain destruction callback order | Wrong reveal, duplicate transmission, or assumed event ordering. | Exact cell matching plus idempotent dossier/event IDs. |
| Allocating reveal scenes on destruction | Violates fixed node-growth/runtime budget guarantees. | Prewarm six reveal slots and reconfigure on `building_configured`. |
| Recycled building retains stale lab art | Wrong district’s lab remains behind a reused facade. | Clear/reconfigure on every slot assignment and check stream generation/variant ID. |
| Using status/objective labels for dialogue | Combat and objective updates overwrite story lines immediately. | Dedicated bounded toast. |
| Pausing for transmissions | Breaks the core no-momentum-loss contract and can conflict with directive/upgrade pause tokens. | Presentation-only node; assert no pause/input state changes. |
| Saving every frame or from multiple UI owners | Web storage churn and corrupt/conflicting writes. | Single store owner; save only on idempotent campaign mutations; UI receives snapshots. |
| Corrupt or future save schema | Startup failure or lost progress. | Version field, validation, migration, safe default, test-injected paths, and nonfatal errors. Prefer temporary-file replacement where supported. |
| Extending `RunSummarySnapshot` after freeze | HUD sees stale campaign totals. | Freeze a separate narrative snapshot before the end overlay or pass explicit tokens at finish. |
| Locale gaps or long Chinese copy | Raw keys, missing glyphs, or toast overflow. | Catalog parity/placeholder/font tests and responsive toast geometry in both orientations. |
| Start-order refactor | Siege may start before narrative wiring or headless tests may unexpectedly run. | Phase-one explicit `begin_run`; defer broad lifecycle centralization. |
| Title screen loading save independently | Divergent in-memory state after a collection/retry. | Main injects one authoritative store/snapshot. |

## Deterministic test plan

Add focused GUT suites under `game/test/` and extend existing budget/localization tests:

1. **Catalog bijection:** `DossierCatalog.validation_errors()` is empty; exactly 25 dossier IDs map one-to-one to `CityDistrictCatalog` variants, exactly five per district, all trigger cells are in the 3×2 bounds, and Mercy Exchange Annex owns the opening black-lab reveal.
2. **Seed independence of ownership:** for multiple seeds, traverse each district’s first five local chunks and assert the same five dossier IDs are obtainable once despite shuffled facade order.
3. **Cell callback idempotence/order:** destroy a lower trigger that synchronously damages its upper cell, then force chain callbacks; assert only the exact authored cell collects and each dossier/transmission emits once regardless of callback order.
4. **Repeat facade dedupe:** breach the same variant again at a later repeated chunk and in a new run; campaign total remains unchanged and no second `dossier_changed` fires.
5. **Persistence round trip:** write to `user://test_choir_campaign_<test>.cfg`, reload a new store, and assert dossier IDs, evidence, ending flags, and continuity generation. Clean the path in `after_each`.
6. **Missing/corrupt/future save:** missing file yields clean defaults; malformed ConfigFile, wrong types, unknown IDs, and unsupported schema do not crash or grant progress; a known older schema migrates deterministically.
7. **Retry continuity:** instantiate `Main`, collect a dossier, finish by robot defeat, invoke retry, and assert a new `CitySlice` instance with zero score/upgrades/momentum but the same Main-owned dossier total and continuity generation +1. Repeat three generations alongside the existing runtime-shape test.
8. **Run finish exactly once:** call `robot_defeated()` twice and assert one `run_finished`, one continuity increment, one save, and one visible summary.
9. **Spatial transition semantics:** move to chunks 8/16/24/32 and assert four arrival events; moving backward does not replay a once-per-run intro. Separately emit `UrbanSiegeRuntime.district_completed` and assert it does not mark a spatial district truth complete.
10. **Initial Business event:** after city setup, call/observe `begin_run`; assert Business intro is queued once even though `CityWorldStream.district_changed` never fired.
11. **Reveal slot reuse:** traverse beyond all four boundaries, breach configured cells, and assert fixed reveal node/slot IDs, zero post-warm creation, correct variant after reassignment, and restored visibility when returning to a damaged streamed building.
12. **No collision coupling:** revealing/collecting a dossier never changes cell health, collision layers, or `ground_passage_open()`; destroying any lower cell still opens progression without a required dossier/evidence state.
13. **Nonblocking toast:** enqueue more than capacity, advance with deterministic `delta`, and assert bounded queue/child count, expiry order, no focus grab, `get_tree().paused == false`, unchanged `RunPauseCoordinator` token state, controls enabled, and attacks still accepted.
14. **Responsive/localized HUD:** transmission and dossier summary render in landscape/portrait under English and Simplified Chinese without raw localization keys; catalog key sets and placeholders remain identical and the configured font covers all new glyphs.
15. **Runtime budget:** extend `test_runtime_budget.gd` to assert fixed narrative director, toast, and reveal counts; after 100 reveal/transmission requests and three retries, node count and capacities remain at baseline with no post-warm allocation.
16. **Web-safe save behavior:** a headless test injects a writable path and verifies each unique collection triggers one save while duplicate callbacks trigger none; web smoke should verify the game starts with unavailable/corrupt storage using defaults.

## Recommended sequencing

Implement the Main-owned store and catalog validation first, then the observer director and explicit finish signal, then the nonblocking HUD toast, and only then the fixed reveal runtime. This order proves retry persistence and event correctness before visual content is attached. Phase one should ship Business and Residential definitions through the same 25-entry validated catalog shape (with unavailable entries rejected in release validation or filled before release), so later districts add content rather than alter persistence semantics.

The key compatibility rule is: **narrative observes existing gameplay truth; it does not become the source of combat, progression collision, pause, or reset truth.**
