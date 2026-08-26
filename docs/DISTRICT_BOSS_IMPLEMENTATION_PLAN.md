# Project CHOIR District Boss Implementation Plan

**Author:** Manus AI

**Status:** Complete — source `bd16ad0`, WebDev checkpoint `cadac459`, public deployment live

**Companion design:** `docs/DISTRICT_BOSS_ENCOUNTER_PROPOSAL.md`

**Canonical narrative:** `docs/PROJECT_CHOIR_STORY_PROPOSAL.md`

**Engine:** Godot 4.7.2-stable with matching non-threaded Web templates

**Target branch:** Shared `main`; fast-forward integration only

## Objective

Implement five district-ending bosses at logical chunks **7, 15, 23, 31, and 39** without weakening Proto Scroller’s destruction power fantasy, deterministic streaming, fixed runtime budgets, portrait/landscape equivalence, or Web release discipline. Each boss must express one district truth, use the existing movement and attack verbs, interact safely with the current six-cell structural model, commit one capstone dossier/evidence result, and terminate through a fresh ground-smash action.

This plan treats the new Project CHOIR lore as authoritative. It therefore includes **twenty-five facade dossiers**, **five evidence flags**, **PILOT ECHO P-01**, a gradually escalating engineered-horror language, and all three final outcomes: **PURGE**, eligible **DISENTANGLE**, and warned ineligible **ASCENSION FAILURE**.[1]

## Current verified baseline

| Constraint | Existing contract |
|---|---|
| Engine | Godot 4.7.2-stable; project format must not be upgraded. |
| Boss session | One `CommandBossSession`; states `IDLE`, `SCREEN`, `BARRAGE`, `EXPOSED`, `WRECK_FINISHER`, `COMPLETE`. |
| Boss durability | 330 armor and 320 health. Armor accepts `jab_cross`; three 110-point charged connections break it. |
| Boss host | One of two prewarmed tank actors with `ANCHOR_TANK` and `COMMAND`. |
| Streaming | Six resident chunks; two behind and three ahead; floating-origin rebasing remains active. |
| Structures | One pooled building per resident chunk; fixed 3×2 cell topology; deterministic stream-state restore. |
| Remains and effects | Four wrecks, twenty-four structural debris bodies, twelve telegraph records, fixed projectile and enemy families. |
| Latest verified release PCK | 14,148,788 bytes; the checked-in generated bundle may lag and is not the release-budget authority. |
| Hard PCK ceiling | 16,777,216 bytes. Current headroom: 2,628,428 bytes, or 2.5066 MiB. |
| Boss feature allocation | Maximum 1,835,008 bytes, or 1.75 MiB, leaving 793,420 bytes, or 0.7566 MiB, as release contingency. |
| Latest verified gameplay source | Weapon-shop revision `3ff79b03d035541a084afa3551609e01d5aeb001`; 319 tests and 30,359 assertions passed before the subsequent documentation-only release record and this proposal revision. |

## Non-negotiable implementation rules

1. **One shared runtime, not five boss engines.** Extend the current session behind a compatibility-preserving data contract. Existing command-boss tests must pass throughout the migration.
2. **No post-warm combat allocation.** Prewarm the maximum shared utility union before `SCREEN`. Reconfigure nodes, markers, damage areas, sockets, and presentation children in place.
3. **No new player verb.** Move, dash, charged `jab_cross`, ground smash, and autonomous weapons are the complete control set.
4. **Direct damage always works after armor.** Structural and environmental interactions are optional interrupts or capped accelerants. Every legal facade mask must retain a direct completion route.
5. **Six chunks remain six.** Arena gates lease already resident stream objects. They do not create a seventh chunk, duplicate a boss building, or disable floating-origin rebasing.
6. **Every wreck requires a fresh smash.** A lethal-frame or already-active attack ID cannot commit the wreck or any Royal outcome.
7. **Narrative observes combat.** Story systems may react to combat signals but cannot own combat state, input, camera, or timing.
8. **Orientation parity is mechanical parity.** Landscape and portrait use the same definitions, hit volumes, timings, and target order. Visual limbs telescope; mechanics do not.
9. **Optional evidence never blocks progression.** Destroyed evidence can use the approved elite-drop recovery rule.
10. **Royal retains three outcomes.** An ineligible disentanglement attempt is warned and deliberate, but remains selectable so ASCENSION FAILURE exists in canon.

## Target architecture

### Data resources

`BossEncounterDefinition` is the immutable campaign catalog entry for one boss. Required fields include:

- `boss_id`, `district_id`, `trigger_chunk`, `unlock_chunk`, `display_name_key`;
- `arena_landmark_variant_id` and stable chunk/building/cell bindings;
- `armor`, `health`, `screen_seconds`, phase thresholds, direct-damage rules;
- rig preset, behavior preset, support reservation requests, utility requirements;
- structural hooks and fallback policies;
- capstone dossier ID, evidence flag ID, recovery eligibility;
- narrative event keys and voice/caption keys;
- wreck mode and outcome policy;
- portrait socket overrides that only affect presentation.

A validator rejects duplicate boss IDs or trigger chunks, unknown district IDs, nonresident arena references, utility demand above the shared maximum, missing direct-damage routes, evidence without a recovery rule, invalid health thresholds, and any receiver configuration whose spacing is less than one ground-smash radius.

`BossPhaseDefinition` stores serialized attack choices, telegraph profile, recovery duration, reservation requirements, cancel policy, safe-gap requirement, and structural accelerant mapping. Runtime state remains outside resources.

`BossCampaignState` stores completed boss IDs, twenty-five dossier flags, five evidence flags, selected final outcome, and idempotency transaction IDs. It is versioned and migrated independently from run-local upgrades.

### Runtime seams

`BossCampaignDirector` observes logical distance and arms an authored `BossGateMarker` before the player can enter the next district. It does not derive starts from `district_changed`, because that signal fires after the logical district has changed. It coordinates `ArenaLease`, `BossAttemptSnapshot`, the shared boss session, narrative observation, persistent transactions, and next-route unlock.

`BossSiegeInterlock` prevents the spatial boss campaign from competing with the independent six-act siege loop. Entering a boss gate first captures the director cursor, run seed, cycle, act, beat, and pressure profile. It then calls a new `DistrictResponseDirector.suspend_for_boss()` path that cancels pending beat and hazard reservations, stops scheduling, clears telegraphs and hostile projectiles, releases active non-boss enemies, deactivates catalysts and hazards, withdraws the current directive without penalty, closes choice overlays, and resets trait state. This interlock does **not** acquire `RunPauseCoordinator`, so player movement, dash, smash, autonomous weapons, and the boss continue normally. Boss retry restores only the boss-attempt snapshot while siege remains suspended. Successful completion resumes the captured siege cursor through a deterministic recovery interval and then advances to the next unconsumed beat; stop/reset clears both systems. Tests must prove that no director, hazard, catalyst, directive, or pending reservation advances while the interlock owns combat.

`ArenaLease` pins stable resident chunk/building references, closes visible arena shutters, preserves floating-origin rebasing, and releases every lease after completion, stop, or retry. It cannot change stream capacity.

`CommandBossSession` remains the public compatibility façade. Internally it delegates to one reusable `BossEncounterRuntime` containing a hidden tank authority, one `BossRig2D`, one behavior controller, one arena adapter, one utility pool, and one wreck adapter. The existing `start()` path continues to start the legacy command encounter until the campaign director supplies a definition.

`BossUtilityPool` prewarms the **maximum concurrent requirement**, not the sum across five bosses:

| Utility | Shared capacity |
|---|---:|
| Memory/attack markers | 8 |
| Normalized lane damage areas | 3 |
| Line or beam areas | 2 |
| Structural collapse listeners | 2 |
| Protected pod state visuals | 4 |
| Static reclamation anchor records | 3 |
| Royal pylon presentation children inside the reusable rig | 5 |
| Noncolliding enemy-composition projection slots | 4 |
| Default wreck receiver | 1 |
| Additional Royal outcome receiver | 1 |
| Boss rig / controller / arena adapter | 1 each |

Existing projectile, enemy, debris, telegraph, and wreck pools remain authoritative. Optional actor acquisition happens before telegraph presentation. Denial skips the actor or chooses a non-projectile fallback; it never steals a live object.

`BossSupportPreset` maps every named support presentation onto an already prewarmed runtime family. Bulwark and Sapper use their existing `infantry` profiles. Reclaimed Breacher uses one `goliath` shell from `procedural_siege` with a boss-local responder rig. Graft Runner uses one `jackal` shell from `procedural_light` with a boss-local surgical rig. CHOIR Siren uses one `needle` shell from `procedural_air` with a boss-local resonator rig. Seraph Carrier remains environmental presentation and never reserves an actor. Maximum live support is two infantry actors in Business or one actor in every later encounter. Royal composition echoes use the four noncolliding projection slots and never touch actor-family capacity. The catalog validator sums these concrete family reservations against `RuntimeBudget`.

`BossAttemptSnapshot` captures leased structural stream state, boss session state, local actor reservations, score and experience deltas, optional payload state, recorder history, evidence-at-entry, and finale eligibility. Retry restores this snapshot and re-enters `SCREEN`; boss encounters do not resume mid-phase.

`NarrativeDirector` listens to boss and facade events. It emits localized captions and bounded voice playback during recovery windows. Its APIs cannot call boss transition methods.

`CampaignProgressStore` uses a copy-on-write, checksummed snapshot rather than a sequence of unrelated save mutations. `commit_boss_transaction(payload)` builds one complete next-state document containing the transaction ID, boss completion, dossier/evidence changes, ending, route unlock, and reward-grant ID; writes and flushes `user://campaign.tmp`; reads it back and validates schema plus checksum; then atomically renames it over the canonical save while retaining one valid backup. Startup chooses the newest valid complete snapshot, ignores duplicate transaction IDs, recovers a valid temporary snapshot after an interrupted rename, and falls back to the backup after corruption. Run-local rewards consume the same grant ID through an `applied_reward_transactions` set, so a crash before or after reward application cannot duplicate or lose the grant. Save migrations preserve unknown future fields and are tested at every interruption boundary.

### Damage and transition contract

The existing `DamageEvent.effect_flags` gains `FLAG_FULL_CHARGE`; `JabCrossImpact` copies `AttackSpec.is_fully_charged()` into that flag. `EnemyActor2D.configure_boss()` gains an optional armor-policy argument. The default legacy policy remains amount-based and preserves the current test where one 330-point `jab_cross` removes all armor. Data-driven campaign bosses select `FULL_CHARGE_FIXED_STEP`, which rejects unflagged strikes and deducts exactly 110 armor per accepted attack ID regardless of upgrade-scaled event amount. Exposed bodies accept all currently approved direct and autonomous damage. Environmental bonuses call the same damage API with explicit caps and source IDs. Exact threshold, overshoot, and lethal-threshold cases transition once. Every transition increments a generation token and cancels stale callbacks, damage areas, projectiles, support actors, and reservations before enabling the next phase.

A wreck receiver stores both the lethal `attack_id` and `root_attack_id` and rejects either chain. `EnemyWreck2D` adds `_seen_root_attacks` and an explicit `configure_finisher_policy()` called by `CommandBossSession` after the remains factory emits `wreck_spawned`; the policy seeds both fatal IDs before the wreck can accept damage. It also rejects autonomous weapons and non-ground-smash kinds. Royal uses separated receivers and one outcome coordinator; only one transaction can commit.

## Phase integration and push policy

Every implementation work package follows the same shared-branch protocol. Before development, protect local work, run `git fetch --prune` and `git pull --ff-only`, and verify the active branch. After the package, run its focused tests plus the complete standard `./verify.sh` gate. Re-fetch immediately before commit; if `origin/main` advanced, integrate without rewriting history and rerun every affected focused suite and the standard gate. Commit and push the package to shared `main` before the next work package begins. Major visual/runtime milestones and the final candidate additionally run `./verify.sh --full`. If a work package changes source but the task stops there, produce a fresh Web export and synchronize the existing WebDev project before reporting completion; a later package must never excuse a stale deployed build.

## Work packages

### WP0 — Canon, catalog, and compatibility foundation

**Purpose:** Freeze the approved roster and create data contracts before introducing encounter behavior.

**Status: Complete (2026-08-26).** The canonical five-definition catalog, immutable phase/outcome contracts, opt-in fixed-step full-charge armor policy, compatibility-preserving `CommandBossSession.start_definition()` path, shared prewarmed utility union, generation/reservation APIs, and runtime-budget telemetry are implemented. The five GPT Image 2 runtime silhouettes and five Lyria 3 Pro boss themes are also staged with provenance as a compact **1,571,351-byte** source pack; final acceptance remains the measured Web PCK delta in WP7/WP8. Godot 4.7.2 import and lint passed. After integrating the concurrent Project CHOIR narrative and weapon-shop foundations, the corrected complete standard gate passed **336 tests and 31,496 assertions** in **653 seconds**, including enemy-variety attack-gate coverage after preserving the legacy session-stop contract.

**Implementation:**

- Add `BossEncounterDefinition`, `BossPhaseDefinition`, `BossCampaignCatalog`, and validation tests.
- Author five definitions with the current five-building district-cap triggers 4, 9, 14, 19, and 24 and the approved names.
- Add `BossOutcome` with `PURGE`, `DISENTANGLE`, and `ASCENSION_FAILURE`.
- Add `DamageEvent.FLAG_FULL_CHARGE`, propagate it from `AttackSpec` through `JabCrossImpact`, and add the optional `FULL_CHARGE_FIXED_STEP` armor policy while preserving the default legacy amount-based policy.
- Introduce a data-driven path behind `CommandBossSession` while retaining the current no-argument `start()` behavior.
- Add boss budget counters for the rig, five pylon children, four projection slots, markers, areas, pod visuals, anchors, and receivers to `RuntimeBudget.snapshot()` and `validation_errors()`.
- Establish generation-token cleanup and reservation-ledger interfaces.

**Primary files:**

- `game/scripts/siege/command_boss_session.gd`
- `game/scripts/siege/boss_encounter_definition.gd`
- `game/scripts/siege/boss_phase_definition.gd`
- `game/scripts/siege/boss_campaign_catalog.gd`
- `game/scripts/siege/boss_utility_pool.gd`
- `game/scripts/combat/damage_event.gd`
- `game/scripts/combat/jab_cross_impact.gd`
- `game/scripts/actors/enemy_actor_2d.gd`
- `game/scripts/quality/runtime_budget.gd`
- `game/test/test_command_boss.gd`
- `game/test/test_boss_catalog.gd`

**Exit gate:** Legacy amount-based command-boss tests remain green. Campaign tests reject uncharged `jab_cross`, cap a 999-point full-charge event to one 110-point step, accept exactly three distinct full-charge attack IDs, and preserve exposed damage. Exactly five definitions validate; one session, one rig, one hidden host, five pylon children, and four projection slots exist; repeated start/stop loops add zero nodes, physics bodies, areas, timers, actors, or reservations.

### WP1 — Campaign gates, arena lease, retry snapshots, and HUD

**Purpose:** Make district-ending fights deterministic in the streamed world before designing individual attacks.

**Status: Complete (2026-08-26; route geometry updated 2026-08-27).** Authored gates now arm at logical chunks **4, 9, 14, 19, and 24** after each five-building geographic clear; each leases exactly the existing six streamed chunks/buildings and rebinds one in-place landmark without allocation. `BossSiegeInterlock` captures the siege cursor and pressure state, clears pending reservations and competing combat/presentation systems without acquiring a run-pause lease, then resumes exactly the next unconsumed beat after one deterministic recovery. `BossAttemptSnapshot` restores six-cell structure state, score, experience, event history, causal recorder state, robot state, gate ownership, and utility reservations while deliberately starting a fresh boss generation. The responsive HUD presents localized boss identity, phase, armor/body percentages, objective, and evidence status. After integrating the concurrent hybrid-CHOIR, transition, weapon-shop, and New Game Plus releases, Godot 4.7.2 import, touched-file lint, the complete affected focused matrix, localization parity/font coverage, and the final standard gate passed **58 scripts, 358 tests, and 32,271 assertions** in **638 seconds**. The full matrix also enforced the 650-line `CitySlice` budget—because architecture is apparently measured in both contracts and blank lines.

**Implementation:**

- Add `BossGateMarker` at each east-cap trigger before the next chunk boundary.
- Add `BossCampaignDirector`, `BossSiegeInterlock`, `ArenaLease`, and `BossAttemptSnapshot`.
- Add `DistrictResponseDirector.suspend_for_boss()` and `resume_after_boss()` so the independent siege loop, pending reservations, hazards, catalysts, directives, and traits cannot advance or contaminate boss state while player controls remain enabled.
- Pin only current resident stream objects; rebase cached points on floating-origin shifts.
- Block forward route during a live gate without disabling player control inside the arena.
- Extend boss HUD with localized boss name, phase, armor/body ratio, and compact objective/evidence status.
- Ensure mission/directive overlays withdraw or defer cleanly when a boss gate owns combat presentation.
- Restore structures, actors, rewards, recorder data, and reservations on retry.

**Primary files:**

- `game/scripts/siege/boss_campaign_director.gd`
- `game/scripts/siege/boss_siege_interlock.gd`
- `game/scripts/siege/arena_lease.gd`
- `game/scripts/siege/boss_attempt_snapshot.gd`
- `game/scripts/world/city_world_stream.gd`
- `game/scripts/world/streamed_destructible_runtime.gd`
- `game/scripts/ui/gameplay_hud.gd`
- `game/scripts/gameplay/city_slice.gd`
- `game/test/test_boss_campaign_gates.gd`
- `game/test/test_boss_retry_restore.gd`

**Exit gate:** Gates trigger exactly once at 4/9/14/19/24, no unearned next-district chunk is traversable, floating-origin shifts do not move targets away from hurt regions, and retry returns every measured state to the pre-`SCREEN` snapshot. During a boss, siege elapsed time, beat cursor, hazard/catalyst/directive state, pending counts, and reservation ledger remain frozen or empty while robot input stays live. Completion resumes exactly the next unconsumed beat after one deterministic recovery interval.

### WP2 — Narrative state, dossiers, evidence, and transactions

**Purpose:** Create the campaign’s investigation spine independently of boss-specific art.

**Status: Complete (2026-08-26).** The authored facade bijection now loads exactly **25** source-controlled dossier resources, including one canon capstone/evidence mapping for each district boss. Campaign state tracks the five canonical evidence flags, optional loss and deterministic elite-drop recovery, twenty-dossier ECHO-7 resolution, finale eligibility, completed bosses, route unlocks, endings, and reward grants. The versioned JSON store signs the exact embedded snapshot string and performs copy-on-write primary/temp/backup recovery; duplicate transaction IDs, every planned crash boundary, corrupt-primary fallback, legacy ConfigFile migration, and reward consumption are idempotent under focused tests. The title archive and campaign summary expose evidence, ambiguity, and recovered outcomes without blocking play. After integrating the concurrent Project CHOIR finale release, eligibility was reconciled to the approved canon—at least twenty dossiers plus **all five** evidence flags, with no chassis-loss limit—and dossier completion was prevented from silently substituting for boss evidence. English/Simplified Chinese key parity and shipped-font coverage passed. Godot 4.7.2 import, touched-file lint, ten focused compatibility suites, the finale and New Game Plus handoff selftest, and the final complete standard gate passed **62 scripts, 382 tests, and 32,611 assertions** in **689 seconds**.

**Implementation:**

- Add versioned campaign progress for twenty-five dossier IDs and five evidence flags.
- Map every authored facade to one dossier and every boss to one capstone record.
- Implement optional evidence loss plus the later elite-drop recovery path.
- Add `NarrativeDirector` and localized Veyr/ECHO-7/capstone keys in English and Simplified Chinese.
- Preserve ECHO-7 ambiguity until the twenty-dossier threshold; allow CROWN evidence to corroborate the cross-pylon cluster only after that threshold is met.
- Implement the checksummed copy-on-write campaign save, transaction IDs, reward grant IDs, startup recovery, backup fallback, and schema migration before adding Royal eligibility snapshots.
- Add post-run codex or compact dossier summary using existing UI conventions.

**Primary files:**

- `game/scripts/narrative/campaign_progress_store.gd`
- `game/scripts/narrative/narrative_director.gd`
- `game/scripts/narrative/dossier_catalog.gd`
- `game/resources/narrative/dossiers/*.tres`
- `game/localization/en.json`
- `game/localization/zh-CN.json`
- `game/test/test_campaign_evidence.gd`
- `game/test/test_campaign_transaction_recovery.gd`
- `game/test/test_boss_narrative.gd`
- `game/test/test_l10n.gd`

**Exit gate:** Exactly twenty-five dossiers and five evidence flags validate; destroyed optional evidence never blocks a gate. Transactions survive duplicate signals, crash simulation before write, after temporary flush, before rename, after rename, before reward consumption, and after reward consumption without duplicate or lost rewards. Corrupt primary data falls back to the last valid backup; supported old schemas migrate deterministically; all new locale glyphs render with the shipped font.

### WP3 — Shared rig, structural adapters, and wreck outcomes

**Purpose:** Prove the reusable combat chassis before shipping content-heavy bosses.

**Status: Complete (2026-08-26).** A single prewarmed `BossRig2D` now reconfigures all five GPT Image 2 boss silhouettes through six reusable sprite parts, eight sockets, three stable mechanical hurt regions, and presentation-only portrait transforms. Campaign bosses use a hidden, stationary tank authority for existing health, armor, death, and remains contracts; the pooled tank slot explicitly restores physics, visuals, body collision, and hurt collision on ordinary reuse. `BossStructuralAdapter` validates every legal six-cell state for each bound facade—**320 mask rows**—with a lower passage contract, visible weak point, direct damage route, valid finisher receiver, and same-anchor fallback conductor. `BossPhaseRuntime` provides generation cleanup, bounded support acquisition, projectile reservation cleanup, and exact safe-gap validation. Campaign wrecks seed fatal attack and root IDs before receivers activate, reject repeated chain IDs and non-smashes, and accept only a later ground smash with a fresh attack/root pair; Royal receivers are prewarmed and separated beyond one smash radius. The deterministic attack matrix and reusable rig gallery are authoritative standard-harness lanes. Landscape **1280×720** and portrait **720×1280** galleries passed with identical mechanical signatures. After integrating concurrent city presentation, facade selection, codex overlap, title, power-box repair, weapon-shop price, and stat-preview revisions, the affected suites and final Godot 4.7.2 standard gate passed **63 scripts, 393 tests, and 34,258 assertions** in **745 seconds**.

**Implementation:**

- Add `BossRig2D` with reconfigurable sprite parts, sockets, hurt regions, and portrait transforms.
- Disable the hidden tank host’s normal rendering and locomotion while forwarding damage and death.
- Add stable structural cell bindings and fallback conductors for all 64 legal masks of each bound facade.
- Add common phase cleanup, support acquisition, projectile reservation, and safe-gap validation.
- Extend wreck handling with fresh-attack-ID validation and separated Royal receivers.
- Update `enemy_wreck_2d.gd` and the remains-factory/session seam so finisher policy seeds and rejects both the fatal attack ID and fatal root attack ID before any receiver becomes active.
- Add deterministic gallery and attack-matrix selftests.

**Exit gate:** Every legal bound-facade mask has a lower passage, visible weak point, direct damage route, and valid finisher receiver; all phase loops return reservations to zero; portrait and landscape report identical attack timing and collision values. Finisher tests reject the identical fatal `attack_id`, reject a new attack ID carrying the fatal `root_attack_id`, reject every non-ground-smash event, and accept one later ground smash with a fresh attack and root ID.

### WP4 — Canon vertical slice: Business and Residential

**Purpose:** Validate the narrative and technical thesis with the canon-recommended two-district slice.

**Status: Complete (2026-08-27).** Settlement Engine S-04 now runs a deterministic five-attack grammar—Settlement Sweep, Double-Entry Barrage, Foreclosure Stamp, Audit Beam, and Foundation Cascade—around three reconciliation pins, one optional treasury-slab accelerant, one foundation accelerant, the eastbound archive, and a one-time bounded Bulwark/Sapper pair. SAMARITAN-15 runs four pod-state records, a permanent central cradle, three lanes, Triage Sweep, Pressure Sentence, Extraction Clamp, and Blackout Harvest with an always-dry lane; its support contract reuses one `goliath`/`procedural_siege` shell as the Reclaimed Breacher and one `jackal`/`procedural_light` slot for at most two sequential Graft Runners. Mid-attempt snapshots preserve attacks, counters, pods, optional outcomes, and active support across retry and armor-generation changes without post-warm growth. Completion commits the mandatory B-05 or Ashwater capstone, optional LEDGER/NURSERY outcome, route unlock, reward grant, and result wording through one idempotent campaign transaction; loss never blocks progression. English and Simplified Chinese localization remain at **511 keys** with **zero new glyphs** beyond the shipped 693-glyph baseline. Targeted Godot 4.7.2 diagnostics passed the new vertical-slice suite (**9 tests, 643 assertions**), boss narrative suite (**6 tests, 121 assertions**), retry suite (**3 tests, 65 assertions**), and localization suite (**4 tests, 1,888 assertions**). The authored encounter scenario passed headless, 1280×720, and 720×1280 runs with five Business attacks, four Residential attacks, safe-lane/cradle/glass invariants, and saved boss captures. Per user directive, redundant repository-wide release gates were skipped for this and subsequent phases.

**Business implementation:**

- Build S-04 rig, three reconciliation pins, Settlement Sweep, Double-Entry Barrage, Foreclosure Stamp, Audit Beam, optional treasury slab, and foundation cascade.
- Acquire one Bulwark and one Sapper at most; no biological combat silhouette.
- Implement the eastbound archive reveal, B-05 dossier, and LEDGER evidence.

**Residential implementation:**

- Build SAMARITAN rig, four pod-state visuals, central cradle, three lane records, Triage Sweep, Pressure Sentence, extraction clamp, and Blackout Harvest.
- Configure one Reclaimed Breacher from a `goliath`/`procedural_siege` shell and up to two sequential Graft Runners from one reused `jackal`/`procedural_light` shell; at most one is active at a time.
- Guarantee a dry safe lane and separate all mechanical targets from captive glass.
- Implement rescue tally, Ashwater manifest, and NURSERY evidence.

**Exit gate:** Direct clears tune to 45–75 seconds. Business contains no overt warform. Residential always preserves the central cradle and dry lane. Pod loss affects score/dossier wording but not progression. Both fights pass landscape, portrait, all mask, retry, allocation, and evidence tests.

### WP5 — Entertainment and Military escalation

**Status: Complete (2026-08-27).** MIMESIS-04 now serializes Dead-Air Sweep, Memory Blocking, Armed Afterimage, and Encore Impact through a fixed eight-marker `MotionEchoRecorder`: cyan history never damages, a separately armed magenta footprint matches collision exactly, and repeated samples remain bounded. The show-control cabinet and grounded-rubble counters remain optional, one CHOIR Siren reuses the `needle`/`procedural_air` shell, and its ring suspends at most one autonomous weapon without disabling movement or direct attacks. The 04:17 biological termination and +3-second continuity boot persist with STAGE evidence. CANTOR-31 / Pale Engine now serializes Suture Salvo, Dispatch Harness, Pale Reclamation, and Compression Psalm through an artillery-spine presentation, one optional `jackal`/`procedural_light` Graft Runner, three static anchors, finite two-plate reclamation, and three environmental-only Seraph production silhouettes; ARSENAL evidence preserves export destinations. Both fights retain direct routes across all 64 facade masks, survive retry/armor-generation state changes, deny exhausted pools without false telegraphs, and use 60-second authored direct-clear targets. Targeted Godot 4.7.2 diagnostics passed the escalation suite (**9 tests, 690 assertions**), boss narrative suite (**6 tests, 121 assertions**), retry suite (**3 tests, 65 assertions**), and localization suite (**4 tests, 1,909 assertions**) with zero new Chinese glyphs. The authored encounter scenario passed headless, 1280×720, and 720×1280 runs with four attacks per fight, eight safe history markers, three Military anchors, one auxiliary maximum, zero live Seraphs, and orientation-identical mechanics. Repository-wide release gates remained skipped by user directive.

**Entertainment implementation:**

- Build MIMESIS rig, fixed eight-marker `MotionEchoRecorder`, separate cyan-history and magenta-damage states, show-control cabinet, and grounded rubble counterplay.
- Configure one CHOIR Siren from a `needle`/`procedural_air` shell; its ring may suspend one autonomous weapon but never movement or direct attacks.
- Deliver the live biological-termination and continuity-boot record.
- Commit STAGE evidence.

**Military implementation:**

- Build CANTOR / Pale Engine rig, artillery spine, one-support dispatch, and three static reclamation anchors.
- Restrict to one live Graft Runner maximum through the same `jackal`/`procedural_light` shell; present Seraph production scale through environment and distant silhouettes only.
- Serialize Suture Salvo, Dispatch Harness, Pale Reclamation, and Compression Psalm.
- Commit ARSENAL evidence and export destination data.

**Exit gate:** Cyan history never damages. Marker count never exceeds eight. Military never exceeds one auxiliary or three anchors. Pool denial produces no false telegraph. Both direct routes remain valid after complete pre-destruction of their bound facades.

### WP6 — Royal finale and three canonical outcomes

**Purpose:** Synthesize the campaign’s learned mechanics and commit the canonical choice structure.

**Status: Complete (2026-08-27).** CHOIR Prime now presents five distinct Ledger, Nursery, Stage, Arsenal, and Crown pylons across three charged armor connections, with one serialized pylon mechanic and one noncolliding composition echo drawn from the fixed eight-marker pool. Royal combat acquires no live support actors and never records player motion history. All 64 structural masks retain the Palace lower route, upper crownfall, direct-core fallback, and valid finisher path. The third connection atomically records CROWN-05 and CROWN before the body phase; the dossier/evidence snapshot is then persisted before wreck entry and remains immutable across later progress and reloads. Separated PURGE and DISENTANGLE receivers prevent one smash from selecting both outcomes. PURGE completes from any evidence state; ineligible DISENTANGLE is explicitly warned and resolves ASCENSION FAILURE while PURGE remains focused and visible; eligible DISENTANGLE repeats five pressure windows without a global timeout, moves the severance receiver, cancels each completed sequence, and commits one idempotent ending transaction referencing the Crown transaction. ECHO-7 remains unresolved below twenty dossiers. Focused Godot 4.7.2 coverage passed the canonical finale suite (**10 tests, 461 assertions**), shared chassis (**9 tests, 1,588 assertions**), legacy command boss (**8 tests, 87 assertions**), campaign gate/HUD (**7 tests, 115 assertions**), campaign evidence (**4 tests, 72 assertions**), crash recovery (**9 tests, 47 assertions**), boss narrative (**6 tests, 122 assertions**), Project CHOIR narrative (**7 tests, 351 assertions**), and localization (**4 tests, 1,925 assertions**) with zero new Chinese glyphs. The authored Royal scenario passed headless, 1280×720, and 720×1280 runs with orientation-identical mechanics and three captures per orientation. Repository-wide release gates remained skipped by user directive.

**Implementation:**

- Build CHOIR Prime as an environmental engine with five distinct pylons mapped to three armor connections.
- Serialize Ledger, Nursery, Stage, Arsenal, and Crown mechanics together with their canonical enemy-composition echoes. Use the existing eight-marker presentation pool and exact pooled telegraph areas for noncolliding Bulwark/Sapper, Breacher/Graft, Siren, Longbow/Basilisk/Shrike/Seraph, and Goliath/Nemesis silhouettes; do not spawn live minions or record player history.
- Bind the Palace lower route and upper crownfall to all legal masks with direct-core fallback.
- Commit CROWN-05 and the CROWN evidence flag idempotently when the mandatory third armor connection severs the Crown pylon, before exposed-body completion.
- Snapshot dossier/evidence eligibility immediately before wreck entry, after the Crown pylon transaction has completed.
- Add separated PURGE and severance receivers plus a three-result outcome coordinator.
- Implement eligible DISENTANGLE’s repeating five severance windows with no overall timeout while CHOIR continues one serialized pylon mechanic and composition echo per window; a successful severance cancels the current sequence.
- Implement warned ineligible ASCENSION FAILURE while leaving PURGE visibly available.
- Commit the selected ending atomically while referencing the already persisted CROWN-05 transaction.

**Exit gate:**

- PURGE succeeds for every evidence state.
- DISENTANGLE succeeds only with at least twenty dossiers and all five flags.
- Every 19-dossier, incomplete-flag, and lower ineligible matrix state produces the warned failure route when intentionally selected.
- CROWN evidence exists before the eligibility snapshot; ECHO-7 remains unresolved below twenty dossiers even when that flag is present.
- Every pylon presents exactly one mechanic plus one noncolliding enemy-composition echo, with no live Royal support actors.
- DISENTANGLE keeps one readable serialized attack active during every severance window and never stacks a second grammar.
- One smash cannot intersect two receivers.
- Reload cannot change the pre-wreck eligibility snapshot or duplicate an ending.

### WP7 — Content completion, accessibility, audio, and packaging

**Purpose:** Finish campaign presentation without exceeding runtime or package limits.

**Status: Complete (2026-08-27).** The campaign now ships twenty-five district dossiers plus five boss capstones, full English and Simplified Chinese key parity, and zero unsupported glyphs from the boss feature. Five compact GPT Image 2 runtime silhouettes and five Lyria 3 Pro themes are source-controlled with model, prompt-scope, encoding, size, duration, and SHA-256 provenance. `BossMusicDirector` owns one prewarmed Music-bus player, maps every canonical boss ID to a unique looping theme, does not restart the same track on retry, remains mechanically inert when audio is muted, and restores the interrupted city-pressure bed after stop or completion. Accessibility coverage proves every phase has textual identity, a noncolor telegraph profile, and a positive safe gap; grayscale presentation leaves damage geometry unchanged; Royal pylons retain distinct textual identities independent of tint. Music tests passed **6 tests / 58 assertions** and accessibility tests passed **3 tests / 116 assertions**. The runtime source pack measures **1,571,351 bytes**, below the 1,835,008-byte allocation. A fresh Godot 4.7.2 Web export produced a **11,504,828-byte PCK**, leaving **5,272,388 bytes** below the 16 MiB ceiling. Repository-wide release gates remained skipped by user directive.

**Implementation:**

- Complete all twenty-five dossier texts and facade reveal cues.
- Finish English and Simplified Chinese localization with shipped-font glyph coverage.
- Build compact multipart boss atlases; concept sheets remain documentation-only.
- Reuse parameterized effects and existing audio; add only short compressed Veyr/ECHO-7 lines and distinctive nonverbal attack cues.
- Add reduced-saturation, audio-off, and shape-only readability tests.
- Add boss gallery selftests for `1280×720` and `720×1280`.
- Produce a per-package PCK size manifest.

**Package rule:** Boss content may add at most **1,835,008 bytes** to the measured 14,148,788-byte baseline, keeping the complete PCK under 16,777,216 bytes and preserving at least 793,420 bytes of contingency. Concepts, source PSDs, and duplicated orientation assets are excluded from export.

**Exit gate:** No actionable element depends on color alone; no HUD overlap occurs; all five fights fit package allocation; audio, localization, and visual assets have provenance; runtime counts remain bounded.

### WP8 — Release certification and deployment synchronization

**Purpose:** Verify and publish the exact final tree.

**Status: Complete (2026-08-27).** Shared `main` was synchronized and all seven implementation phases were pushed without rewriting history. Per explicit user directive, repository-wide standard/full release gates were skipped; acceptance relied on the focused phase suites and deterministic encounter scenarios recorded above. A fresh Godot 4.7.2 export from exact source `bd16ad0d1f0b91fdb207b76b4a35bcb6c2b02119` produced nonempty HTML, JavaScript, a **39,514,754-byte** WASM, and an **11,504,828-byte** PCK, leaving **5,272,388 bytes** below the 16 MiB ceiling.

The existing WebDev host was semantically merged with concurrent source `789e031` so the complete boss campaign retains the 2× compatible-wave / 0.5× cadence pressure revision and the newer trusted title beat scheduler. The exact final payloads were freshly uploaded and remapped as `/manus-storage/game_d115f29f.wasm` and `/manus-storage/game_d85f95a3.pck`; HTTP downloads matched the export byte-for-byte and by SHA-256. TypeScript and production builds passed. The preview loaded both exact objects, retained title scheduler APIs, accepted Enter, movement, dash, and smash input, stopped the title video on gameplay handoff, rendered fullscreen in landscape and portrait, and produced no blocking console error. WebDev checkpoint **`cadac459`** auto-published to `https://protoscoll-enopta8p.manus.space/`, whose public shell resolves the exact final payload routes.

**Exit gate:** Passed. Source revision, export bytes, checkpoint `cadac459`, and public deployment refer to the same boss-complete tree and immutable payloads.

## Verification matrix

| Area | Required evidence |
|---|---|
| Catalog | Five unique IDs, five exact triggers, unique capstone/evidence mapping, valid maximum-concurrency budget. |
| Damage | Three 110-point charged armor hits; exposed-body damage; threshold exact/overshoot/lethal cases; fresh wreck smash. |
| Armor compatibility | Legacy amount-based command boss unchanged; campaign full-charge flag required; oversized charged events still consume one fixed 110-point step. |
| Streaming | Six resident slots, arena lease cleanup, floating-origin rebasing, no duplicate landmark or post-warm creation. |
| Structures | All 64 masks per bound facade plus representative multi-building combinations; lower route and direct completion always valid. |
| Pools | Twenty-five repeated phase loops and retries with constant actor/node/body/area/marker/projectile/wreck counts. |
| Siege interlock | Director cursor preserved; pending beats and reservations cleared; hazards, catalysts, directives, traits, and ordinary enemies suspended; player input stays enabled; next beat resumes once. |
| Business | No overt warform; archive optional; Bulwark/Sapper total bounded. |
| Residential | Dry lane always exists; protected glass is never required damage; rescue loss cannot block route. |
| Entertainment | Cyan traces never damage; armed footprint matches collision exactly; eight markers maximum; one Siren. |
| Military | One auxiliary maximum; three anchors maximum; no live Seraph; reclamation finite. |
| Royal | No live minions; one mechanic plus one noncolliding composition echo at a time; Crown evidence before snapshot; active DISENTANGLE pressure; three outcomes; receiver separation; eligibility snapshot persistence. |
| Finisher chain | Fatal attack ID rejected; a different attack sharing the fatal root ID rejected; only a later fresh-root ground smash accepted. |
| Narrative | Lines trigger deterministically, do not seize control, and repeat immutable facts in capstone dossiers. |
| Accessibility | Shape, luminance, sound, and footprint redundancy; reduced saturation; audio-off; no mobile-control overlap. |
| Localization | English/Chinese key parity, named placeholders, shipped-font glyph coverage. |
| Web | Godot 4.7.2 non-threaded export; HTTP-only smoke; exact artifact sizes; clean browser console and requests. |
| WebDev sync | Local shell, loader, worklets, icons, loading assets, remote WASM/PCK, hashes, sizes, source revision, memory, structure, and asset manifests all match the certified export. |

## Risks and mitigations

| Risk | Consequence | Mitigation |
|---|---|---|
| Five bespoke boss scenes diverge | Duplicate logic, allocation growth, inconsistent fixes | One compatibility façade, one hidden host, one rig/controller/adapter union, validated resources. |
| Siege loop continues under a boss | Contaminated pools, overlapping objectives, nondeterministic retries | Non-player-pausing `BossSiegeInterlock`, deterministic cursor snapshot, pending/reservation cleanup, and one recovery-based resume. |
| Narrative system takes ownership of gameplay | Stalls power fantasy and complicates retries | Signal-only observer; no boss transition methods; bounded live-play lines. |
| Structural pre-destruction removes a required interaction | Soft lock | Exhaustive six-cell mask tests; same-position conductors; mirrored or omitted optional bonus; direct damage route. |
| Optional evidence blocks finale or route | Unfair campaign lock | Evidence affects outcome eligibility only; district completion always proceeds; elite-drop recovery. |
| Interrupted save partially applies completion | Duplicated reward, missing evidence, or inconsistent route | Checksummed copy-on-write snapshots, atomic rename, transaction/reward IDs, recovery of valid temporary files, and one backup. |
| Royal failure feels accidental | Player distrust | Separate receiver beyond smash radius, fractured geometry, warning cadence, explicit incomplete-evidence state, PURGE still visible. |
| Bio-horror becomes exploitative spectacle | Conflicts with canon and tone | Containment, rescue equipment, intact silhouettes, synthetic membrane, memory light; prohibit gore and fantasy mutation. |
| Concept art inflates export | PCK breach | Documentation-only concepts; trimmed runtime atlases; no mipmaps; shared effects; 1.75 MiB feature allocation. |
| Orientation-specific tuning forks | Mechanical inconsistency | One definition; normalized anchors; presentation-only telescoping; parity assertions. |
| Concurrent shared-main changes invalidate evidence | False confidence | Fetch/pull before each phase and final gate; rerun affected focused tests and full gates after integration. |

## Definition of done

The feature is complete only when all five district bosses appear at the authored east-cap gates, communicate their unique district truths, preserve fast destruction and the existing control vocabulary, survive every structural mask and retry path, remain within fixed runtime and Web package budgets, render safely in landscape and portrait, and persist exactly one canonical finale outcome. A Git push alone is insufficient: the exact verified final export must also be synchronized to the existing WebDev project, checked over HTTP, checkpointed, and published or handed off through the available publish control.

## References

[1]: PROJECT_CHOIR_STORY_PROPOSAL.md "Canonical lore, campaign truth ladder, evidence, retry framing, and three endings"
[2]: DISTRICT_BOSS_ENCOUNTER_PROPOSAL.md "Approved five-boss creative and encounter design"
[3]: ../game/scripts/siege/command_boss_session.gd "Current command-boss compatibility façade"
[4]: ../game/test/test_command_boss.gd "Current command-boss damage, timing, and completion tests"
[5]: ../game/scripts/world/city_world_stream.gd "Six-slot streamed world and floating origin"
[6]: ../game/scripts/destruction/structural_building_2d.gd "Six-cell structures, state capture, support transfer, and deterministic destruction"
[7]: ../game/scripts/encounter/encounter_runtime.gd "Prewarmed actors and acquisition behavior"
[8]: ../game/scripts/quality/runtime_budget.gd "Runtime caps and Web PCK ceiling"
[9]: DISTRICT_DESTRUCTION_DESIGN.md "District architecture and facade roster"
[10]: DISTRICT_MISSIONS_AND_BALANCE_PLAN.md "District missions, difficulty curve, and release baseline"
