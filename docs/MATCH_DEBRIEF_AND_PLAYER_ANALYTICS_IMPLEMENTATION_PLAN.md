# After-Action Dossier and Player Combat Analytics — Implementation Plan

**Author:** Manus AI
**Date:** 2026-08-27
**Status:** Complete and checkpointed
**Canonical baseline:** `21a15680c231646c0a7b2853205be1a2ba19887d`
**Engine:** Godot 4.7.2 stable, GL Compatibility, non-threaded Web export

## 1. Objective

Implement the approved After-Action Dossier from `MATCH_DEBRIEF_AND_PLAYER_ANALYTICS_PROPOSAL.md`. The release must track exact run combat facts, merge bounded facts into a persistent local player profile, revamp the final defeat/extraction screen, and expose a privacy-minimal future leaderboard payload. Existing score, encounter, Project CHOIR, finale, New Game+, retry, title, audio, and fullscreen WebDev behavior remain authoritative.

## 2. Architectural Decisions

### 2.1 Accepted events remain the source of truth

Statistics are recorded only after `GameplayEventHub.accept` succeeds. This preserves deduplication and prevents visual effects, repeated collision callbacks, or late post-summary events from inflating counts. `RampageSession.publish` updates combo state first, then forwards the accepted event and current authored combo tier to a new `CombatRunTelemetry` aggregate.

### 2.2 Event enrichment is minimal and stable

`GameplayEvent` receives three optional semantic identifiers:

| Field | Meaning |
|---|---|
| `enemy_archetype_id` | Concrete defeated enemy identity such as `soldier`, `needle`, or `covenant_warden`. |
| `enemy_family_id` | Stable broad family such as infantry, light, heavy, air, or siege. |
| `weapon_id` | Stable fatal kill-attribution category such as `GROUND_SMASH` or `MISSILE`. |

`RampageEventAdapter.enemy_defeated` populates these values from actor metadata and the accepted fatal `DamageEvent`. Existing event constructors remain source-compatible because the fields default to empty IDs.

### 2.3 Run and career state are separate

`CombatRunTelemetry` is transient and reset with the run, while `PlayerCombatProfileStore` is persistent and owned by `Main`. `CitySlice` receives the optional store before entering the tree. Direct test scenes without an injected store stay isolated. `CityRunLifecycle` submits the immutable summary exactly once after it is frozen.

### 2.4 The debrief is a dedicated UI component

A new `MatchDebriefPanel` owns final-run presentation. The legacy terminal remains intact for finale choice, ending handoff, and New Game+ preparation. `GameplayHud` switches between the two modes so specialized final analytics do not destabilize the campaign terminal.

## 3. Data Model

### 3.1 CombatRunTelemetry

The object stores only bounded scalar values and dictionaries:

- highest authored combo tier;
- total enemy defeats;
- exact enemy-archetype counts;
- enemy-family counts;
- stable weapon-attribution counts.

The preferred weapon is the highest count with an explicit stable priority tie-break. Ranked rows sort by descending count then stable ID. Snapshot methods always duplicate dictionaries.

### 3.2 RunSummarySnapshot extension

Optional summary metrics add:

- `completed`;
- `highest_combo_tier`;
- `enemy_kills`;
- `enemy_family_kills`;
- `weapon_kills`;
- `total_enemies_defeated`;
- `unique_enemy_types`;
- `preferred_weapon`;
- `preferred_weapon_kills`;
- `new_combo_record`;
- `new_score_record`;
- `career_snapshot`.

The existing constructor remains compatible with current tests and call sites.

### 3.3 PlayerCombatProfileStore schema

`user://player_combat_profile.json` uses schema version 1. It stores an anonymous random local profile ID, total runs, victories, best score, highest combo tier, lifetime enemy kills, lifetime weapon kills, and a last-updated timestamp. The implementation validates types and nonnegative ranges, limits dictionary key counts, and uses temp-file replacement for safe writes.

`submit_summary` returns a result dictionary containing personal-best flags and a post-merge snapshot. This result is copied into the final run snapshot before the debrief is shown, ensuring the UI is immutable even if a later run updates the career store.

## 4. Weapon Attribution Contract

| Fatal damage type or cause | Stable weapon ID |
|---|---|
| `ground_smash`, debris rooted in a ground smash | `GROUND_SMASH` |
| `jab_cross`, `punch_shockwave` | `JAB_CROSS` |
| `machine_gun` | `MACHINE_GUN` |
| `missile` | `MISSILE` |
| `laser` | `LASER` |
| `flamethrower` | `FLAMETHROWER` |
| catalyst, collapse, volatile, crash, structural chain | `ENVIRONMENT` |
| any unrecognized fatal source | `UNKNOWN` |

Root attack propagation is retained. The initial implementation categorizes by fatal accepted damage type rather than attempting damage-share attribution, keeping the contract deterministic and testable.

## 5. Enemy Attribution Contract

For procedural and district-variant actors, the exact `enemy_archetype` metadata is authoritative. Legacy pooled actors map to `soldier`, `tank`, or `helicopter` from runtime type. Boss-mode actors may also carry a boss identifier; when unavailable they retain their concrete actor archetype. Broad family comes from `enemy_family` metadata or `EnemyArchetypeCatalog.family_for`.

The UI displays proper-name callsigns from catalog profiles. Base actors use localized labels. Unknown IDs are converted from snake case to uppercase words rather than discarded.

## 6. UI Composition

### 6.1 Shared elements

`MatchDebriefPanel` contains one generated crest, result heading, score/grade strip, run metadata, highest-combo card, career card, weapon-affinity card, enemy-kill matrix, recommendation line, and two action buttons. It preallocates all labels and row controls in `_ready`; showing a summary only updates text, visibility, and generated row values.

### 6.2 Landscape layout

At 1280×720, the panel occupies approximately 1140×626 at `(70, 48)`. The header consumes 108 px. Two equal columns carry four cards. The footer hosts actions at least 210×58. Data rows use 16–18 px typography; headline values use 28–48 px.

### 6.3 Portrait layout

At 720×1280, the panel occupies 656×920 at `(32, 250)`. Cards stack in the order combo, weapon, enemies, career. Data rows condense to the top three enemy types and top three weapon rows. Footer buttons remain within the central safe area and above mobile controls.

### 6.4 Compatibility bridge

`GameplayHud.overlay_title`, `overlay_summary`, `retry_button`, and `title_button` remain valid fields for existing tests and transition flows. In final debrief mode, their text mirrors the new panel and their legacy controls are hidden rather than deleted. Test helpers and title-transition actions therefore retain stable signal ownership.

## 7. Localization

English and Simplified Chinese receive identical keys for section titles, row templates, base enemies, weapon identities, personal-best badges, no-data states, and career/run comparisons. The CJK font subset is regenerated after localization changes. Enemy callsigns sourced from catalog profiles remain canonical proper names.

## 8. GPT Image 2 Asset Pipeline

WP1 generates three concept images with `gpt-image-2`: a landscape UI mockup, a portrait UI mockup, and a square dossier crest. The mockups are proposal evidence only. The crest receives deterministic background cleanup, alpha verification, downscaling to 256×256, and a Godot import. Asset lineage, prompts, model, source files, processing command, sizes, and SHA-256 values are recorded in `MATCH_DEBRIEF_ASSET_PROVENANCE.md`.

## 9. Work Packages

| Package | Scope | Focused exit criteria |
|---|---|---|
| WP0 — Proposal and contracts | Audit baseline, define product hierarchy, telemetry semantics, persistence boundary, responsive behavior, and future leaderboard payload | Proposal and implementation plan committed; `git diff --check` |
| WP1 — GPT Image 2 concepts and crest | Generate landscape/portrait mockups and crest; create deterministic runtime derivative and provenance | Image files exist; crest alpha/dimensions verified; Godot import clean |
| WP2 — Run telemetry | Enrich accepted defeat events; add `CombatRunTelemetry`; extend immutable summary | Focused tests prove dedupe, concrete variants, fatal weapon mapping, ranking, reset, and immutability |
| WP3 — Persistent career profile | Add Main-owned profile store, safe schema load/write, one-time submission, personal-best flags, candidate payload | Temporary-path tests prove save/reload, merge, corruption fallback, bounds, and privacy exclusions |
| WP4 — Responsive debrief | Add `MatchDebriefPanel`; integrate final defeat/extraction only; preserve campaign terminal; add EN/zh-CN | Landscape/portrait scenarios show all required sections and actions without clipping |
| WP5 — Source integration | Update README, Web smoke probe, focused harness contracts, and this plan with actual evidence | Focused GUT and bounded visual checks pass; source pushed to shared `main` |
| WP6 — WebDev synchronization | Fresh compatible Web export from final pushed tree; upload/remap fresh WASM and PCK; update WebDev continuity files; checkpoint and publish | Exact source revision, payload URLs, sizes, hashes, and checkpoint recorded; broad release-gate suites remain skipped per project override |

## 10. Focused Test Matrix

| Layer | Required assertion |
|---|---|
| Event adapter | Defeated district variants retain exact ID/family and every supported fatal damage type maps to the intended weapon ID. |
| Run telemetry | Accepted kills increment once, top rows sort deterministically, highest authored tier exceeds the multiplier cap, and reset clears run facts. |
| Summary | Frozen dictionaries are defensive copies; late events do not mutate the summary. |
| Profile persistence | First run creates a profile; reload preserves it; lower records do not overwrite bests; lifetime counters merge; malformed JSON resets safely. |
| Public payload | Contains only schema/build/profile/run/aggregate facts and excludes settings, narrative saves, raw input, and local paths. |
| HUD compatibility | Defeat, extraction, ending choice, ending result, New Game+, retry, and title signals remain valid. |
| Responsive debrief | 1280×720 and 720×1280 reports assert no overlap, clipping, or offscreen controls; required section labels and rows are visible. |

## 11. Release Strategy

Per the explicit project release-gate override, this task will not run the repository-wide regression suite, lint/type/build ceremony, browser smoke matrix, Xvfb certification matrix, or repeated upstream stabilization loops. Each source work package receives focused tests and a lightweight visual check before its push. After the final source push, a fresh Godot 4.7.2 Web export will be synchronized to the existing `proto-scroller` WebDev project, checkpointed, and published directly.

## 12. Completion Definition

The feature is complete when a finalized run displays exact highest combo tier, concrete enemies defeated, preferred and supporting kill-attribution weapons, career records, personal-best states, and existing narrative/progression facts in both orientations; local profile data persists safely; a privacy-minimal leaderboard candidate can be serialized; focused evidence is recorded; canonical source is pushed; and the current WebDev deployment loads the fresh final export.

## 13. Implementation Record

| Package | Status | Evidence |
|---|---|---|
| WP0 — Proposal and contracts | Complete | Proposal, implementation plan, and concept direction pushed in `1be1423`. |
| WP1 — GPT Image 2 concepts and crest | Complete | Landscape and portrait mockups plus a cleaned transparent 256×256 runtime crest; hashes recorded in `MATCH_DEBRIEF_ASSET_PROVENANCE.md`. |
| WP2 — Run telemetry | Complete | Accepted-event telemetry captures exact archetype, family, fatal weapon, total kills, and uncapped authored combo tier; dedicated suite passed 6/6 tests and 87 assertions. |
| WP3 — Persistent career profile | Complete | Versioned atomic local profile, corruption fallback, personal-best flags, bounded lifetime totals, and privacy-minimal leaderboard candidate covered by the same 6/6 focused suite. |
| WP4 — Responsive debrief | Complete | Dedicated hard-cornered final-run panel uses the GPT Image 2 crest and localized Godot controls; 1280×720 and 720×1280 screenshots passed bounded geometry and visual inspection. |
| WP5 — Source integration | Complete | End-to-end focused suite passed 8/8 tests and 118 assertions; legacy rampage, summary, and live-city compatibility suites passed 27 tests and 277 assertions in aggregate. |
| WP6 — WebDev synchronization | Complete | Fresh exact `ec03c403` export remapped to `/manus-storage/game_e396304f.wasm` and `/manus-storage/game_da759b2a.pck`; WebDev checkpoint `c8247fb8` saved. |

Focused compatibility checks passed `test_rampage_progression.gd` at 14 tests / 170 assertions, `test_overdrive_and_summary.gd` at 7 tests / 55 assertions, and `test_city_rampage_integration.gd` at 6 tests / 52 assertions. Per the active project release override, no full release-gate matrix or certification loop was run.

The final runtime code revision is `ec03c403b9a99ccbf723f4229b24b25d1a445509`. Its PCK is 16,638,892 bytes with SHA-256 `b948d88e845624dc4224ffdb63ceeb77ad27065ccfb6f6bd17f4fe30f47ed4b4`, leaving 138,324 bytes below the 16 MiB ceiling. The matching Godot 4.7.2 WASM is 39,514,754 bytes with SHA-256 `fc74679e3b97f76878947fcd4fbe1268cbfa6188182a2e33bbc3f5dc9bfa57d0`.
