# Proto Scroller Runtime Tuning Laboratory — Implementation Plan

**Author:** Manus AI
**Status:** In implementation
**Canonical repository:** `https://github.com/junnyboi/proto-scroller`
**Planning baseline:** `8cd2c6484eae25e78de7b79508912135f33a00c9`
**Engine:** Godot `4.7.2-stable`, GL Compatibility, matching non-threaded Web templates

## 1. Objective

Implement a production-quality in-game tuning laboratory tailored to Proto Scroller. It must generate controls from one typed metadata catalog, apply values at explicit immutable boundaries, persist only validated user deltas, pause and resume the exact gameplay state, provide a real production-path sandbox, and defend ranked career and leaderboard integrity.

This release enables **50 active controls**. It deliberately does not expose every numeric constant. The selection covers the values with the greatest design leverage while excluding allocation topology, identities, collision contracts, save schemas, deterministic ordering, and other invariants.

## 2. Architectural contract

| Component | Ownership and responsibility |
|---|---|
| `RuntimeTweakDescriptor` | Immutable parsed metadata: ID, category, type, default, bounds, step, unit, apply mode, integrity class, localization keys, and tags. |
| `RuntimeTweakCatalog` | Loads `res://` first, validates schema and duplicate IDs, sorts descriptors, and produces the complete baseline. |
| `RuntimeTweakService` | Main-owned `PROCESS_MODE_ALWAYS` authority for requested values, run/district snapshots, hash, persistence state, and sticky provenance. |
| `RuntimeTweakAccess` | Narrow static bridge to the Main-owned service for boundary reads; falls back to existing constants when no service is bound. |
| `RuntimeTweakPersistence` | Loads user deltas after the baseline, quarantines corruption, debounces writes, and atomically replaces the delta file. |
| `RunTuningProvenance` | Records `BASELINE`, `TUNED`, or `SANDBOX`, applied reasons, run seed, catalog revision, and short hash. |
| `RuntimeTweakPanel` | Responsive metadata renderer with category/search filtering, validation feedback, reset controls, and sandbox actions. No domain balance logic. |
| `TuningPauseAdapter` | Acquires one pause lease, captures previous state, pauses the SceneTree, neutralizes mobile input, and restores exactly. |
| `SandboxScenarioRunner` | Executes a closed catalog of safe commands through existing game factories and APIs. |

The source constants remain fail-closed defaults. Consumers obtain effective values through one of `live_value`, `run_value`, `district_value`, `next_spawn_value`, or `next_attack_value`. Boundary reads return deep-copied/quantized values and mark non-default gameplay changes as applied.

## 3. Enabled descriptor catalog

### 3.1 Player and feedback — 10 controls

| ID | Default | Range / step | Mode | Integrity |
|---|---:|---|---|---|
| `player.move.max_speed` | 260 px/s | 180–340 / 10 | LIVE | SCORE_AFFECTING |
| `player.move.ground_acceleration` | 1800 px/s² | 1000–2800 / 100 | LIVE | SCORE_AFFECTING |
| `player.melee.ground_smash_damage` | 180 | 100–260 / 10 | NEXT ATTACK | SCORE_AFFECTING |
| `player.melee.ground_smash_radius` | 320 px | 220–400 / 10 | NEXT ATTACK | SCORE_AFFECTING |
| `player.melee.charge_duration` | 2.0 s | 1.2–3.0 / 0.1 | NEXT ATTACK | SCORE_AFFECTING |
| `feedback.player_jab_camera_impulse` | 22 | 0–32 / 1 | LIVE | COSMETIC |
| `feedback.player_slam_camera_impulse` | 26 | 0–32 / 1 | LIVE | COSMETIC |
| `feedback.full_charge_hit_stop_ms` | 110 ms | 25–110 / 5 | LIVE | COSMETIC |
| `input.mobile_deadzone` | 0.14 | 0.05–0.30 / 0.01 | LIVE | GAMEPLAY |
| `input.mobile_response_speed` | 18 | 8–30 / 0.5 | LIVE | GAMEPLAY |

### 3.2 Opposition and siege — 9 controls

| ID | Default | Range / step | Mode | Integrity |
|---|---:|---|---|---|
| `enemy.outgoing_damage_multiplier` | 0.75× | 0.50–1.00 / 0.05 | NEXT ATTACK | GAMEPLAY |
| `enemy.aegis_aura_radius` | 560 px | 360–700 / 20 | LIVE | GAMEPLAY |
| `enemy.aegis_damage_taken_multiplier` | 0.65× | 0.50–0.85 / 0.05 | LIVE | GAMEPLAY |
| `enemy.static_attack_interval_multiplier` | 0.82× | 0.65–0.95 / 0.05 | LIVE | GAMEPLAY |
| `enemy.target_mark_damage_multiplier` | 1.15× | 1.00–1.30 / 0.05 | LIVE | GAMEPLAY |
| `spawn.quantity_multiplier` | 2 | 1–2 / 1 | NEXT RUN | SCORE_AFFECTING |
| `spawn.interval_scale` | 0.50× | 0.50–1.00 / 0.05 | NEXT RUN | SCORE_AFFECTING |
| `projectile.hostile_lifetime` | 2.5 s | 1.0–3.0 / 0.1 | NEXT ATTACK | GAMEPLAY |
| `projectile.hostile_impact_pitch_jitter` | 0.035 | 0–0.10 / 0.005 | LIVE | COSMETIC |

### 3.3 Bosses — 6 controls

| ID | Default | Range / step | Mode | Integrity |
|---|---:|---|---|---|
| `boss.exposed_health_multiplier` | 1.00× | 0.75–1.25 / 0.05 | NEXT SPAWN | GAMEPLAY |
| `boss.intro_screen_seconds` | 4.0 s | 2–6 / 0.25 | NEXT SPAWN | GAMEPLAY |
| `boss.standard_projectile_damage_multiplier` | 1.00× | 0.75–1.25 / 0.05 | NEXT ATTACK | GAMEPLAY |
| `boss.reinforcement_interval_multiplier` | 1.00× | 0.75–1.50 / 0.05 | NEXT SPAWN | GAMEPLAY |
| `boss.animation_moving_fps` | 6 FPS | 4–10 / 0.5 | LIVE | COSMETIC |
| `boss.s04_release_camera_impulse` | 10 | 0–16 / 1 | NEXT ATTACK | COSMETIC |

### 3.4 World and atmosphere — 13 controls

| ID | Default | Range / step | Mode | Integrity |
|---|---:|---|---|---|
| `world.facade.health_multiplier` | 0.75× | 0.50–1.25 / 0.05 | NEXT RUN | SCORE_AFFECTING |
| `world.facade.damaged_stage_ratio` | 0.65 | 0.45–0.85 / 0.05 | NEXT ATTACK | COSMETIC |
| `world.facade.support_transfer_ratio` | 0.50 | 0.25–0.75 / 0.05 | NEXT ATTACK | SCORE_AFFECTING |
| `world.facade.chain_delay_multiplier` | 1.00× | 0.50–1.50 / 0.05 | NEXT ATTACK | GAMEPLAY |
| `world.street_prop.health_multiplier` | 1.00× | 0.50–1.50 / 0.05 | NEXT RUN | GAMEPLAY |
| `world.repair_drop.amount` | 50 HP | 20–80 / 5 | NEXT SPAWN | GAMEPLAY |
| `world.repair_drop.lifetime_seconds` | 12 s | 6–20 / 1 | NEXT SPAWN | GAMEPLAY |
| `world.weather.density_multiplier` | 1.00× | 0.50–1.10 / 0.05 | LIVE | COSMETIC |
| `world.weather.opacity_multiplier` | 1.00× | 0.50–1.10 / 0.05 | LIVE | COSMETIC |
| `world.weather.motion_multiplier` | 1.00× | 0.50–1.50 / 0.05 | LIVE | COSMETIC |
| `world.parallax.motion_multiplier` | 1.00× | 0.75–1.25 / 0.05 | LIVE | COSMETIC |
| `world.sky.day_night_cycle_seconds` | 360 s | 120–900 / 30 | LIVE | COSMETIC |
| `world.sky.traffic_speed_multiplier` | 1.00× | 0.50–1.25 / 0.05 | LIVE | COSMETIC |

### 3.5 Progression and economy — 7 controls

| ID | Default | Range / step | Mode | Integrity |
|---|---:|---|---|---|
| `progression.xp.base_requirement` | 500 | 250–1000 / 25 | NEXT RUN | SCORE_AFFECTING |
| `progression.xp.growth_factor` | 1.35 | 1.10–1.50 / 0.01 | NEXT RUN | SCORE_AFFECTING |
| `progression.combo.base_grace_seconds` | 3.0 s | 2–5 / 0.25 | NEXT RUN | SCORE_AFFECTING |
| `progression.combo.max_multiplier` | 5× | 3–5 / 1 | NEXT RUN | SCORE_AFFECTING |
| `progression.score.bank_base_seconds` | 1.0 s | 0.5–3 / 0.25 | NEXT RUN | SCORE_AFFECTING |
| `progression.rewards.named_boss_multiplier` | 3× | 1–5 / 1 | NEXT RUN | SCORE_AFFECTING |
| `progression.shop.price_multiplier` | 1.00× | 0.75–1.25 / 0.05 | NEXT RUN | SCORE_AFFECTING |

### 3.6 Interface — 5 controls

| ID | Default | Range / step | Mode | Integrity |
|---|---:|---|---|---|
| `input.mobile_smash_cooldown` | 0.40 s | 0.15–0.75 / 0.05 | LIVE | GAMEPLAY |
| `input.controller_vibration_enabled` | true | boolean | LIVE | COSMETIC |
| `interface.title_transition_duration_scale` | 1.00× | 0.50–1.50 / 0.05 | NEXT RUN | COSMETIC |
| `interface.upgrade_modal_shade_opacity` | 0.88 | 0.65–0.95 / 0.01 | LIVE | COSMETIC |
| `interface.leaderboard_timeout_seconds` | 4.0 s | 2–10 / 0.5 | LIVE | COSMETIC |

## 4. Persistence and validation

Startup order is mandatory:

1. Validate `res://config/runtime_tweaks/catalog.json` and construct the complete baseline.
2. Read `user://runtime_tweaks/v1/current.json` only as an overlay.
3. Ignore unknown IDs; reject wrong types and non-finite numbers; clamp and quantize numeric values.
4. Apply the overlay transactionally and compute a canonical hash from stable sorted IDs.
5. Bind LIVE consumers. Deferred controls wait for their declared boundary.

Only differences from the baseline are written. Five rapid edits produce five immediate memory changes but one write after a 0.40-second debounce. Save uses `.tmp` plus a one-generation `.bak`. Reset removes a key. Invalid primary data is quarantined and never wins over a valid baseline or backup.

## 5. Pause and input implementation

The panel is mounted under Main and processes while paused. `TuningPauseAdapter.open()` captures `SceneTree.paused`, mobile-control enabled state, and focus. It acquires `runtime_tuning` from the current `RunPauseCoordinator`, neutralizes virtual movement, disables mobile emission without rebuilding touch controls, and sets `SceneTree.paused = true`. Existing gameplay `SceneTreeTimer` calls are made pause-aware so active attacks, catalysts, directives, and tutorial holds do not continue behind the panel.

`close()` flushes persistence, restores only captured state, releases only its token, and returns focus. The modal policy rejects opening when the pause coordinator already has a lease, during title/city transitions, or after run completion.

`runtime_tuning` is bound to F10. Main also recognizes Back/Share + Y/Triangle as a chord. The implementation does not change `stomp`, `ui_accept`, or remappable gameplay actions.

## 6. Sandbox implementation

The panel’s Session category provides the following fixed actions:

| Action | Production API |
|---|---|
| Restart with pending values and optional seed | Main rebuilds `CitySlice` and freezes a new run snapshot before `add_child`. |
| Spawn selected enemy | Existing `EnemyArchetypeCatalog` selector and `EncounterRuntime.acquire`. |
| Activate selected hazard | Existing `EnvironmentalHazardCatalog` selector and `HazardRuntime.activate`. |
| Clear transient combat | Existing cancel/release APIs; no `queue_free` on pooled objects. |
| Grant 1,000 test XP | `RunExperience.add_experience`. |
| Repair 100 chassis health | `GiantRobotController.repair_chassis`. |

Every action sets the active provenance to `SANDBOX`. Campaign progress and ranked career data remain untouched at run end.

## 7. Competitive-integrity implementation

`RunSummarySnapshot` gains transient fields for tuning status, full hash, catalog revision, reasons, and ranked eligibility. `CityRunLifecycle` attaches provenance before profile enrichment. `PlayerCombatProfileStore.enrich_and_submit` rejects ineligible summaries defensively, and `LeaderboardBridge.submit_summary` performs the same check before constructing a web payload. The existing web protocol remains unchanged because ineligible runs are never submitted.

The debrief displays an explicit `BASELINE`, `TUNED`, or `SANDBOX` marker and short hash. A tuned run gets no new-score/new-combo flag and does not alter total runs, victories, history, career bests, or global rank.

## 8. Work packages

### WP0 — Prerequisite contract repair

Fix the unreachable pending-hazard activation block and add an integration assertion that a due record activates and leaves the pending list. Reconcile repair authority at **50 HP** in code, tests, and documentation. Write the concept and implementation plan.

**Exit criteria:** focused environmental-hazard and repair tests pass; documents and runtime agree.

### WP1 — Typed core, overlay, persistence, and hash

Create the 50-entry catalog, descriptor parser, service, access bridge, run/district snapshots, provenance, user overlay loading, validation, canonical hash, debounce, atomic save, backup recovery, and reset APIs. Mount the service in Main before title/city construction.

**Exit criteria:** catalog count/default parity, baseline-before-user precedence, delta-only save, corruption recovery, hash stability, immediate memory changes, one debounced write, and forced close/exit flush pass focused tests.

### WP2 — Responsive panel, true pause, localization, and sandbox

Build the fixed-node responsive panel, metadata rows, category/search filtering, requested/active status, reset actions, session status, selectors, and six sandbox commands. Add English and Simplified Chinese text. Add F10 and controller chord routing. Implement exact pause-state restoration and pause-aware gameplay timers.

**Exit criteria:** opening freezes movement, attacks, projectiles, directives, hazards, weather, and timers; closing restores prior state; no token leaks; both orientations fit; Space remains melee and A/Cross remains confirm.

### WP3 — Provenance, debrief, career, and leaderboard defenses

Attach sticky run provenance, add summary fields, display status/hash, bypass ranked career enrichment, and reject network submission defensively.

**Exit criteria:** pending next-run changes do not taint the current run; applied gameplay changes do; resetting cannot untaint; cosmetic-only changes remain eligible; sandbox/tuned runs update neither profile nor bridge.

### WP4 — Fifty consumer adapters

Route each enabled descriptor at its declared boundary. Preserve constants as fallbacks, static catalog immutability, fixed pools, RNG order, collision geometry, and source IDs. Rebase live player movement without double-applying upgrade multipliers. Snapshot attacks, spawns, districts, and runs rather than mutating in-flight data.

**Exit criteria:** every enabled descriptor has one consumer, one boundary assertion, and default equivalence. Fixed pools and RuntimeBudget remain unchanged.

### WP5 — Integration, documentation, release synchronization

Run the focused tuning suites and lightweight representative regressions, update this plan with completion evidence, reconcile upstream once, push main, generate a fresh Godot 4.7.2 Web export, patch the title/audio shell, upload fresh WASM and PCK, synchronize the existing Proto Scroller WebDev project, verify payload URLs and live panel behavior, save a checkpoint, and publish when available.

**Exit criteria:** source and WebDev worktrees are clean; exact source revision and runtime payloads are recorded; the live hosted build opens, pauses, edits, persists, resumes, marks tuned state, and blocks ranked submission.

## 9. Focused acceptance matrix

| Area | Required assertions |
|---|---|
| Catalog | Exactly 50 unique enabled IDs; valid types/ranges/modes/integrity; sorted stable hash; defaults match code fallbacks. |
| Persistence | `res://` baseline always loads first; valid user deltas win; reset deletes keys; malformed values cannot partially apply; one debounce write. |
| Boundaries | Active charge/projectile/spawn/district/run retains old snapshot; next operation uses the queued value. |
| Pause | 120 paused frames do not change robot position, charge, projectile lifetime, directive time, hazard state, world clock, or weather phase. |
| Input | F10/chord opens; Space cannot activate panel buttons; A/Cross confirms; B/Escape closes without dodge or attack leakage. |
| Responsive UI | Panel and footer fit at 1280×720 and 720×1280; minimum touch target 48 px; English/Chinese text is visible. |
| Sandbox | Commands use existing pools and APIs, report denial, create no runtime nodes, and mark `SANDBOX`. |
| Integrity | Gameplay edits are sticky tuned; cosmetic-only edits are ranked; tuned/sandbox summaries cannot update profile or network. |
| Default parity | Identity profile preserves existing focused gameplay expectations and exact catalog behavior. |

## 10. Release-gate policy

Per current project directive, repository-wide certification, slow Xvfb matrices, and the monolithic full release gate are skipped unless explicitly requested. Implementation uses focused GUT suites, direct import/boot where needed, one live managed-browser check, and exact HTTP payload verification. A fresh Web export and WebDev synchronization remain mandatory.

## 11. Implementation record

| Work package | Status | Source revision | Evidence |
|---|---|---|---|
| WP0 | Complete | `1c3423c164ae60cfd13724ce6b3f1ec423c3470a` | Fixed due-hazard activation/removal, reconciled the Aegis Patch Cell at 50 HP, and passed `runtime_tweak_prerequisites`: 2 tests / 7 assertions. |
| WP1 | Complete | `924815ef4066dac25e69eaa84422c8713b334553` | Added 50 typed descriptors, res-first validated deltas, canonical SHA-256 identity, run/district/attack/spawn boundaries, sticky provenance, and atomic debounced persistence. `runtime_tweak_catalog`: 4 tests / 468 assertions; `runtime_tweak_service`: 8 tests / 53 assertions; `title_transition`: 3 tests / 47 assertions. |
| WP2 | Complete | `5e09c867726c267763b35ddf1d93779700cb903a` | Added the metadata-driven responsive panel, exact SceneTree pause/restore adapter, F10 input, bilingual UI, modal arbitration, and fixed-pool sandbox. `runtime_tweak_panel`: 5 tests / 47 assertions, including 120 paused frames and both target orientations. |
| WP3 | Complete | `836c436d6bc7ee1fe569a597ccb7da449b5ee54f` | Added sticky `BASELINE`/`TUNED`/`SANDBOX` run provenance, immutable summary metadata, debrief disclosure, profile suppression, and a final leaderboard network guard. `runtime_tweak_integrity`: 5 tests / 22 assertions. |
| WP4 | Complete | `c6635a6be2e9b1d070474505f7a7c0e4f666b2b8` | Wired all 50 descriptors to production consumers with default-preserving fallbacks and declared LIVE/NEXT ATTACK/NEXT SPAWN/NEXT RUN snapshots; retained fixed pools, immutable shop catalog data, and attack-local projectile state. Static consumer audit: 50/50. `runtime_tweak_adapters`: 5 tests / 36 assertions; `runtime_tweak_service`: 9 tests / 62 assertions; focused boss, world, progression, budget, localization, panel, and integrity suites passed. |
| WP5 | Pending | — | — |

## References

[1]: https://github.com/junnyboi/proto-scroller "Proto Scroller source repository"
[2]: https://docs.godotengine.org/en/stable/tutorials/ui/gui_containers.html "Godot Engine documentation: GUI containers"
[3]: https://docs.godotengine.org/en/stable/classes/class_fileaccess.html "Godot Engine documentation: FileAccess"
[4]: https://docs.godotengine.org/en/stable/tutorials/io/data_paths.html "Godot Engine documentation: File paths in Godot projects"
[5]: https://docs.godotengine.org/en/stable/classes/class_range.html "Godot Engine documentation: Range"
[6]: https://docs.godotengine.org/en/stable/classes/class_json.html "Godot Engine documentation: JSON"
