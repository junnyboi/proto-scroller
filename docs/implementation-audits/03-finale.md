# Implementation Audit 03: CHOIR Prime Finale and Endings

**Scope:** CHOIR Prime, five pylons, PURGE, DISENTANGLE, ASCENSION FAILURE, and the existing act-completion/extraction/summary/city-stream integration they must replace or preserve.
**Audited revision:** `9f6e1279f2a77822e066f2337a21dc1e8b59cb17` (`main`, clean at inspection).
**Contract:** [`docs/PROJECT_CHOIR_STORY_PROPOSAL.md`](../PROJECT_CHOIR_STORY_PROPOSAL.md), especially lines 100, 144–160, 185–197.

## Executive finding

The current finale is not a campaign finale. `DistrictResponseDirector` runs one six-act timed arc and emits inherited `district_completed`; `UrbanSiegeRuntime._on_arc_completed()` then starts `CommandBossSession`, and its wreck finisher emits `UrbanSiegeRuntime.district_completed`. `CityRunLifecycle._on_district_completed()` interprets that signal as a meta-run checkpoint and opens **EXTRACT / CONTINUE**, not an ending. Geography is independent: `CityWorldStream` selects ROYAL from logical chunk 32 onward and remains endless, so the six-act arc can complete in any spatial district.

The safest implementation is therefore **additive orchestration**, not expansion of `CommandBossSession`. Add a dedicated `ChoirPrimeSession` and arena scene, let `UrbanSiegeRuntime` choose the terminal encounter only after both conditions are true—six-act arc complete and `CityWorldStream.current_district_id == &"ROYAL"`—and leave `CommandBossSession` as the legacy/arcade encounter. The finale session should own only finale state and authored schedules; it should reuse `EncounterRuntime`, `ProjectilePool`, `TelegraphPresenter2D`, `HazardRuntime`, `DestructionDirector`, and their prewarmed capacities. Ending eligibility must be supplied as an immutable snapshot and the resolved ending must flow additively into `RunSummarySnapshot`.

## Current architecture and exact seams

| Area | Current exact contract | Finale consequence |
|---|---|---|
| Act completion | `DistrictResponseDirector` (`game/scripts/siege/district_response_director.gd`) advances `phase_index` across `DistrictDefinition.acts`; `_advance_act()` sets `completed = true`, `running = false`, and emits inherited `district_completed` after act 6. It already emits `phase_changed`, `beat_changed`, `recovery_started`, and `milestone_reached`. | Do not put pylon phases into `DistrictDefinition`; doing so would break the fixed six-act HUD/mastery contract and curated deck tests. Treat this signal as **arc complete**, despite its ambiguous name. |
| Runtime orchestration | `UrbanSiegeRuntime` (`game/scripts/siege/urban_siege_runtime.gd`) wires `director.district_completed` to `_on_arc_completed()`, which unconditionally calls `boss_session.start()`. `CommandBossSession.completed` calls `_on_boss_completed()`, which emits `UrbanSiegeRuntime.district_completed`. | Replace the unconditional call with a terminal-encounter coordinator. Add signals for finale progress/resolution; retain `district_completed` only for the existing extract/continue path. |
| Current boss | `CommandBossSession` (`game/scripts/siege/command_boss_session.gd`) has `state_changed`, `armor_changed`, `completed(elapsed_seconds)` and states `IDLE`, `SCREEN`, `BARRAGE`, `EXPOSED`, `WRECK_FINISHER`, `COMPLETE`. It acquires one pooled `TankEnemy`, relies on `EnemyActor2D.configure_boss()`, and completes only after `EnemyRemainsFactory.wreck_scrapped`. | Five independent organs, a core, a choice, and timed severance are structurally different. Do not add five-pylon/ending branches to this tank-specific state machine or overload its `completed` signal. |
| Lifecycle/extraction | `CityRunLifecycle` (`game/scripts/gameplay/city_run_lifecycle.gd`) connects `UrbanSiegeRuntime.district_completed` to `_on_district_completed()`, calls `prepare_terminal_choice()`, and displays `GameplayHud.show_cycle_choice()`. `_on_extract_pressed()` calls `_finish_run(true)`; `_on_continue_pressed()` starts cycle 2. | Finale resolution must bypass this checkpoint. Do not reinterpret `extract_pressed` as PURGE. Add ending-choice signals/UI and call `_finish_run(true, ending_metrics)` only after `ChoirPrimeSession.ending_resolved`. |
| Terminal pause | `UrbanSiegeRuntime.prepare_terminal_choice()` acquires `RunPauseCoordinator` lease `&"extract_continue"`. `RunPauseCoordinator` disables robot controls, mobile controls, encounters, projectiles, telegraphs, director, catalysts, and hazards. | Use this coordinator only while the ending choice overlay is visible. Release it before PURGE combat or the timed DISENTANGLE sequence; otherwise the approved “CHOIR continues attacking” behavior is impossible. |
| Summary | `RampageSession.freeze_summary()` creates one immutable `RunSummarySnapshot`. Existing additive metrics include `boss_result`, `contract_result`, `run_seed`, and `cycle_count`; `GameplayHud._show_summary()` renders only the existing mastery tokens. | Add `ending_id`, `dossier_count`, and `evidence_nodes_preserved` as new read-only snapshot fields. Do not repurpose `boss_result == &"WRECK_RESOLVED"`, because current mastery and command-boss tests assert it. |
| Geography | `CityWorldStream` (`game/scripts/world/city_world_stream.gd`) emits `district_changed(previous, current, logical_chunk)` only when district ID changes and `window_changed(current_chunk)` on every logical-chunk change. It maintains exactly six chunks and floating-origin rebasing. | Gate start using existing `district_changed` plus a direct current-district check when the act arc completes. The two events can occur in either order. No narrative state belongs in chunk blueprints. |
| Royal extent | `CityDistrictCatalog.district_index_for_chunk()` clamps to index 4; Royal has `end_chunk = -1`, so chunks 32 through infinity remain ROYAL. | Do not make Royal finite: existing stream/catalog tests require chunk 96 to be ROYAL. Spawn and lock a bounded arena at the robot’s current runtime position once the finale starts. |
| Scene composition | `game/scenes/gameplay/city_slice.tscn` contains only the `CitySlice` root; `CitySlice._ready()` builds stream, encounters, HUD, siege, lifecycle, and upgrades in code. | Preload/instantiate the finale arena through the new session or `CitySlice`, not by permanently adding an active boss graph to the root scene. Prewarm its fixed children at run setup if budget rules require zero combat-time allocation. |
| Retry/persistence | `Main.retry_game()` destroys and recreates `CitySlice`. There is no campaign save. Only audio, input, and localization preferences use `user://`. | Persistent dossiers cannot live in `CitySlice`/`RampageSession`. `Main` must own/inject a versioned campaign-progress object; current-run evidence preservation must reset with each new `CitySlice`. |
| Destruction plumbing | `Destructible2D.receive_damage(DamageEvent)` already deduplicates nonzero `attack_id`, emits `damaged`, `damage_applied`, and `destroyed`, and is discovered through `DamageReceiverLookup`. `DestructionDirector` routes explosions to that receiver contract. | Pylons, severance targets, and the core should use a small finale target class based on this receiver contract. Avoid bespoke polling or direct calls from player attacks. |
| Runtime caps | `RuntimeBudget` fixes enemy, projectile, telegraph, hazard, wreck, six-chunk, and single boss-session capacities; `RuntimeBudget.validation_errors()` and `test_runtime_budget.gd` enforce them. | Reuse existing pools and declare explicit fixed counts for one finale session, one arena, five pylons, one core, and severance targets. Pylon replay compositions must reserve within existing family caps; no dynamic enemy creation is acceptable. |

## Recommended implementation shape

### 1. Keep finale state separate from the command tank

Create `ChoirPrimeSession` under `UrbanSiegeRuntime`, beside `CommandBossSession`. Its public contract should be narrow and deterministic:

```gdscript
class_name ChoirPrimeSession
extends Node

signal state_changed(state: StringName)
signal pylon_changed(pylon_id: StringName, remaining: int)
signal ability_removed(ability_id: StringName)
signal choice_requested(eligibility: FinaleEligibilitySnapshot)
signal severance_changed(step: int, total: int, seconds_remaining: float)
signal ending_resolved(ending_id: StringName, elapsed_seconds: float)

const STATE_IDLE := &"IDLE"
const STATE_ENTRY := &"ENTRY"
const STATE_PYLONS := &"PYLONS"
const STATE_CHOICE := &"CHOICE"
const STATE_PURGE := &"PURGE"
const STATE_DISENTANGLE := &"DISENTANGLE"
const STATE_COMPLETE := &"COMPLETE"

const ENDING_PURGE := &"PURGE"
const ENDING_DISENTANGLE := &"DISENTANGLE"
const ENDING_ASCENSION_FAILURE := &"ASCENSION_FAILURE"
```

`start(run_seed, eligibility)` must release the act encounter, cancel telegraphs/projectiles, place the already-created `ChoirPrimeArena2D` around the robot, lock stream advancement, then enter `PYLONS`. `stop()`/`reset_state()` must be idempotent and restore stream processing, arena visibility/collision, attack gates, schedules, reservations, and all child targets. `advance(delta)` should be directly callable by tests, as `CommandBossSession.advance(delta)` is today.

The arena should contain exactly five authored `ChoirPylon2D` targets and one `ChoirPrimeCore2D`. Use IDs **LEDGER, NURSERY, STAGE, ARSENAL, CROWN**. Each pylon profile should carry its removable core ability and a bounded replay composition. Destroying pylons may occur in any order; destruction removes only that pylon’s ability, cancels its pending schedule, and emits once. After all five, the core enters `CHOICE` and the runtime acquires a short `RunPauseCoordinator` lease for the overlay.

### 2. Use data-driven replay profiles but existing pools

A `ChoirPylonProfile` resource should define `pylon_id`, `ability_id`, telegraph/hazard IDs, and an array of existing `EnemySpawnEntry` records. `ChoirPrimeSession` should use `CapacityReservationLedger` before scheduling each replay and `EncounterRuntime.acquire()` for actual actors. This preserves role/trait profiles, projectile routing, family caps, and deterministic run-seed behavior. The finale must not start `DistrictResponseDirector` again and must not duplicate its private `_beat_pending` implementation.

For a pylon whose full composition cannot be reserved, deterministically degrade from the end of its authored optional list; never wait forever. Track denials/degradations for tests and budget telemetry. All hostile schedules must use run seed + stable pylon salt, never frame time or global RNG.

### 3. Gate on both campaign arc and Royal geography

In `UrbanSiegeRuntime`, introduce booleans such as `_arc_completed` and `_royal_reached`. Initialize them in `start_run()`/`_prepare_cycle()`. `_on_arc_completed()` sets the first; `_on_spatial_district_changed()` updates the second. A single `_try_start_terminal_encounter()` handles either event order and is guarded against duplicate start. For campaign runs it starts CHOIR Prime only when both are true. For a retained arcade/legacy run goal it starts `CommandBossSession` exactly as today.

On finale start, use a public `CityWorldStream.set_stream_locked(true)` (or equivalently named API), rather than mutating its `process_mode` from several callers. Locking freezes chunk reassignment while retaining the six resident chunks and current logical coordinates. The arena is positioned in runtime space around the robot and supplies bounded collision walls. Unlock only on reset/stop; terminal endings normally destroy the scene shortly afterward. Preserve `district_changed` and `window_changed` signatures.

### 4. Model eligibility as immutable input, not live UI logic

The finale needs one frozen `FinaleEligibilitySnapshot` containing at least `dossier_count`, a deduplicated set of preserved district evidence IDs, and `can_disentangle()` defined as dossier count >= 20 **and** all five campaign district IDs present. Dossiers may come from persistent campaign progress; the five evidence-node flags must represent the current clear so old successful runs cannot mask destruction in the present run.

At `CHOICE`, always present both actions:

* **PURGE** is always enabled. It releases the pause lease, enters `PURGE`, exposes the core, and resolves `PURGE` only when the core target is destroyed.
* **DISENTANGLE** is always selectable. The UI may label it stable or unstable but must not disable it; otherwise ASCENSION FAILURE is unreachable. It releases the pause lease and enters a timed, ordered severance sequence while attacks remain enabled. With a qualifying frozen snapshot, completing all severance steps resolves `DISENTANGLE`. With an insufficient snapshot, the attempted sequence resolves `ASCENSION_FAILURE` (the approved bad-ending condition). For an otherwise eligible player who misses the timer, reset the severance sequence or return to `CHOICE`; do not invent a fourth eligibility rule for ASCENSION FAILURE.

Resolve exactly once, set `STATE_COMPLETE` before emitting, then cancel every hostile schedule. Ending copy must use the approved final lines verbatim through localization keys.

### 5. Separate ending choice from extraction and freeze the result once

Add `purge_pressed` and `disentangle_pressed` to `GameplayHud`, plus `show_ending_choice(eligibility)`, `show_severance_status(...)`, and `show_ending(summary)`. Keep `extract_pressed`, `continue_pressed`, and `show_cycle_choice()` untouched for legacy mode. `CityRunLifecycle` should subscribe to `ChoirPrimeSession.choice_requested`, `severance_changed`, and `ending_resolved`; only `ending_resolved` calls terminal cleanup and summary freeze.

Refactor `_finish_run(completed)` to accept an optional metrics dictionary and merge finale values before `RampageSession.freeze_summary()`. Preserve its existing one-shot `game_over_active` guard and cleanup sequence. Additive `RunSummarySnapshot` getters should default to `&"NONE"`, `0`, and `0`, so all existing callers and tests remain valid. The ending overlay selects the correct localized title/final line from `summary.ending_id`; `waves_cleared` remains 6 for mastery compatibility.

### 6. Put persistence above the recreated city

Create a versioned `CampaignProgress`/store outside `RampageSession`. `Main` loads it once and assigns it to `CitySlice` before `add_child(city_slice)` triggers `_ready()`. Tests that instantiate `CitySlice` directly should receive a clean in-memory progress object. Persist dossier IDs atomically; preserve unknown fields or migrate by explicit schema version. Keep current-run five-node evidence in a run-local narrative/evidence session and pass only its snapshot into the finale.

This split satisfies canonical retry: `Main.retry_game()` may still replace every gameplay node and reset upgrades/evidence, while dossiers survive. It also avoids an autoload, consistent with the current project (which has no autoload section).

## State and signal flow

```text
DistrictResponseDirector.district_completed
  -> UrbanSiegeRuntime._on_arc_completed() [_arc_completed = true]
CityWorldStream.district_changed(..., ROYAL, ...)
  -> UrbanSiegeRuntime._on_spatial_district_changed() [_royal_reached = true]
Either callback
  -> _try_start_terminal_encounter()
  -> ChoirPrimeSession.start(seed, frozen eligibility)
  -> PYLONS: five ChoirPylon2D.destroyed signals
  -> ChoirPrimeSession.choice_requested(snapshot)
  -> GameplayHud PURGE / DISENTANGLE
  -> CityRunLifecycle forwards selection
  -> ChoirPrimeSession ending_resolved(PURGE | DISENTANGLE | ASCENSION_FAILURE, elapsed)
  -> CityRunLifecycle._finish_run(true, ending metrics)
  -> RampageSession.freeze_summary(...)
  -> GameplayHud.show_ending(summary)
```

The state transition guard should reject every invalid action: repeated `start()`, choice before all pylons, pylon events after completion, duplicate severance hits, and second ending resolution. State must be assigned before each corresponding signal emit so observers see the new state synchronously.

## Files to add or change

| File | Expected change |
|---|---|
| `game/scripts/finale/choir_prime_session.gd` | New finale state machine, schedules, choices, cleanup, and exact-once resolution. |
| `game/scripts/finale/choir_pylon_2d.gd` and `game/scripts/finale/choir_prime_core_2d.gd` | New damage-receiver targets using the `Destructible2D` contract; no combat polling. |
| `game/scripts/finale/choir_pylon_profile.gd` and `game/resources/finale/*.tres` | Five authored organ IDs, removable abilities, and bounded replay compositions. |
| `game/scripts/finale/finale_eligibility_snapshot.gd` | Immutable dossier/evidence threshold contract. |
| `game/scenes/finale/choir_prime_arena.tscn` (plus arena script/art/audio as required) | Fixed, bounded arena with five pylons, core, severance targets, and pooled visual children. |
| `game/scripts/siege/urban_siege_runtime.gd` | Construct/wire `ChoirPrimeSession`; two-condition Royal gate; legacy command-boss branch; terminal cleanup. |
| `game/scripts/world/city_world_stream.gd` | Add one public, idempotent stream-lock API; preserve all existing mapping/signals/caps. |
| `game/scripts/gameplay/city_run_lifecycle.gd` | Wire ending-choice/progress/resolution; keep extract/continue separate; pass ending metrics into one-shot finish. |
| `game/scripts/gameplay/city_slice.gd` | Supply campaign/evidence dependency and expose/prewarm arena integration; include finale in cleanup/rebase only if session placement requires it. |
| `game/scripts/ui/gameplay_hud.gd` | Add two-action ending choice, timed severance status, and ending-specific summary presentation while retaining current terminal overlay APIs. |
| `game/scripts/rampage/run_summary_snapshot.gd` and `game/scripts/rampage/rampage_session.gd` | Add immutable ending/evidence fields and default-compatible metric freezing. |
| `game/scripts/main/main.gd` plus new campaign-progress/store scripts | Own/inject versioned persistent dossier progress above retry-created `CitySlice`; do not persist run upgrades/evidence. |
| `game/scripts/quality/runtime_budget.gd` | Declare/snapshot/validate fixed finale session, pylon, core, severance, and arena visual capacities. |
| `game/localization/en.json`, `game/localization/zh-CN.json` | Identical keys/placeholders for pylon states, both choices, eligibility warning, three endings, and approved final lines. |
| `game/test/test_choir_prime.gd`, `game/test/test_finale_endings.gd` | New deterministic state-machine, threshold, ordering, and exact-once tests. |
| Existing `game/test/test_command_boss.gd`, `test_district_arc.gd`, `test_curated_deck.gd`, `test_overdrive_and_summary.gd`, `test_runtime_budget.gd`, `test_l10n.gd`, `test_city_district_catalog.gd` | Extend for the additive branch and prove no regression in command boss, six acts, extraction, summary, budgets, bilingual keys, or endless Royal mapping. |

`game/scripts/siege/command_boss_session.gd` should ideally require **no production change**. If a run-goal selector is introduced, adapt only its caller and tests; keeping this class intact is the strongest compatibility boundary.

## Compatibility risks and mitigations

| Risk | Why it is concrete | Required mitigation |
|---|---|---|
| Finale starts outside Royal or never starts | Timed act progression and spatial travel are currently independent. | Latch both conditions and test both arrival orders; never require both signals in the same frame. |
| Existing extraction tests/UI break | `district_completed` currently means “show EXTRACT / CONTINUE.” | Do not emit it for CHOIR endings. Add distinct finale signals and retain the legacy branch. |
| Bad ending becomes unreachable | Contract says DISENTANGLE is available only when qualified but also defines failure when attempted unqualified. | Offer the action in an explicitly unstable state rather than disabling it; resolve by frozen eligibility. |
| Pause accidentally disables the timed fight | `RunPauseCoordinator` disables player, enemies, projectiles, telegraphs, director, catalysts, and hazards. | Hold its lease only during the choice overlay and release before either action. |
| Royal stream changes under the arena | Royal is endless and six chunk objects are continuously reassigned. | Use one owner-controlled stream lock and bounded arena collision; restore idempotently on stop/retry. |
| Pool starvation deadlocks a pylon | Current pools are shared and `acquire()` can return null. | Reserve through `CapacityReservationLedger`, deterministic degradation, bounded pending arrays, and timeout-free completion logic. |
| `boss_result` semantic regression | Tests and mastery currently expect `WRECK_RESOLVED`. | Add `ending_id`/`finale_result`; do not reinterpret the existing field. |
| Persistent progress leaks across test/retry boundaries | `Main` recreates `CitySlice`, while direct scene tests bypass `Main`. | Inject persistence explicitly; use in-memory defaults and test-specific `user://` paths; current-run evidence never enters the save. |
| Dynamic arena allocation violates budgets | Runtime policy asserts zero post-warm growth for major systems. | Instantiate fixed finale nodes at setup, hide/disable until start, and add exact counts to `RuntimeBudget`. |
| Floating-origin mismatch | An arena created at absolute logical coordinates can drift after origin shifts. | Start from current runtime coordinates only after locking the stream, or register one rebase handler; never mix logical and runtime X. |
| Duplicate ending or stale callbacks | Destruction and deferred enemy/wreck signals can arrive during teardown. | Transition to `COMPLETE` before emit; disconnect/reset target signals and guard every callback by state/session generation. |
| Localization/package regressions | `test_l10n.gd` requires identical EN/zh-CN keys/placeholders; Web PCK is capped at 16 MiB. | Add both catalogs together, retain font coverage, and run full Web budget verification after assets land. |

## Deterministic test plan

1. **Five-organ contract:** instantiate the session with a fixed seed; assert exactly five unique IDs in the required order set (`LEDGER`, `NURSERY`, `STAGE`, `ARSENAL`, `CROWN`), five fixed target nodes, one core, and no post-start node growth.
2. **Pylon order independence:** destroy pylons in two different orders using unique `DamageEvent.attack_id` values. Assert one `pylon_changed` and one `ability_removed` per ID, no duplicate emission on repeated damage, all five abilities gone, then exactly one `choice_requested`.
3. **Replay determinism/caps:** record composition IDs, anchors, delays, traits, hazards, and degradation count for seed 731 twice; assert equality, all actor reservations released, family counts/cost ceilings respected, pending records bounded, and a different seed changes only declared randomized choices.
4. **Royal/arc gate ordering:** (a) complete the six-act director while in BUSINESS, assert pending but no finale, then emit transition to ROYAL and assert one start; (b) enter ROYAL first, then complete the arc and assert one start; repeated callbacks must not start twice.
5. **Stream lock:** begin the finale at logical chunk 32, attempt movement/`advance_stream()`, and assert resident chunk assignments and current logical chunk stay fixed, arena remains aligned, six stream nodes remain, and `stop()` restores normal transitions.
6. **PURGE universal path:** with 0 dossiers/0 nodes and with 25/5, destroy all pylons, choose PURGE, destroy the exposed core, and assert `ending_resolved(&"PURGE", ...)` exactly once plus the approved “NO HOSTILES…” localized line.
7. **DISENTANGLE threshold matrix:** test (19,5), (20,4), duplicate district IDs, and (20,5). The first three permit the attempt but resolve `ASCENSION_FAILURE`; only (20,5) completing the ordered timed sequence resolves `DISENTANGLE`. Assert eligibility cannot mutate after `start()`.
8. **Eligible timeout behavior:** let the severance timer expire with (20,5); assert no ending resolves, the authored reset/return-to-choice behavior occurs, attacks remain gated on, and a subsequent complete sequence can resolve once.
9. **Combat continuity:** during DISENTANGLE, assert robot controls, `EncounterRuntime.process_mode`, `ProjectilePool.process_mode`, `TelegraphPresenter2D.process_mode`, and hazards are enabled; during the choice overlay assert the pause lease disables them; assert the lease count returns to zero after selection/stop.
10. **Lifecycle exact-once cleanup:** emit each ending and assert `CityRunLifecycle` sets `game_over_active`, stops upgrades/siege, releases enemies/projectiles/telegraphs/hazards, disables mobile controls, freezes one summary, and ignores a second resolution.
11. **Summary compatibility:** freeze a legacy command-boss summary and assert all new fields default safely; freeze each finale ending and assert `ending_id`, dossier count, evidence count, score/mastery, and cycle fields remain immutable after late gameplay events.
12. **Extraction compatibility:** run existing command-boss completion and assert `show_cycle_choice()`, EXTRACT/CONTINUE, cycle-2 preservation, and `boss_result == &"WRECK_RESOLVED"` still work. In campaign-finale mode assert those buttons never appear.
13. **Retry persistence split:** through `Main`, collect a dossier and mark run evidence, call `retry_game()`, then assert dossier progress persists while all five run evidence flags, upgrades, score, finale state, and arena visibility reset. Reload a versioned test save and assert deterministic migration/defaults.
14. **Localization:** extend `test_l10n.gd` to require identical keys/placeholders, approved English final-line text, Simplified Chinese glyph coverage, and no raw key displayed for every pylon/state/ending.
15. **Budget and Web:** extend `RuntimeBudget.snapshot()/validation_errors()` for exact finale capacities; saturate pylon replay schedules without node/capacity growth; run focused GUT suites, then `game/verify.sh full` to enforce the 16 MiB Web PCK cap and browser smoke.

## Safest delivery sequence

First add the pure eligibility snapshot and headless `ChoirPrimeSession` tests with fake/fixed targets. Next add the arena and fixed runtime-budget accounting. Then integrate the two-condition gate while keeping the command boss selectable for regression tests. Finally wire choice/lifecycle/summary/persistence and localized presentation. This order keeps every commit runnable and prevents UI or save code from concealing state-machine defects.

The critical acceptance rule is: **one six-act completion plus Royal arrival starts one five-pylon session; one explicit choice produces exactly one of the three approved ending IDs; only the resolved ending freezes the run summary.**
