# Global Leaderboard, Callsign Profile, and Career History — Implementation Plan

**Author:** Manus AI
**Date:** 2026-08-27
**Status:** Complete
**Canonical baseline:** `089f486`
**Engine:** Godot 4.7.2 stable, GL Compatibility, non-threaded Web export
**WebDev project:** `proto-scroller`

## 1. Understanding

This release extends the existing After-Action Dossier with three cohesive capabilities: a database-backed worldwide career ranking, a deterministic local leaderboard fallback, and an editable player callsign plus interactive weapon-history visualization. The global board ranks installation profiles by highest authored combo tier first and best score second. It is asynchronous and non-authoritative: no combat or navigation state may depend on network success.

The WebDev host must remain visually identical—one borderless fullscreen iframe. Its upgrade from static hosting to a managed backend is an infrastructure change only. The Godot game remains the owner of gameplay, profile state, charts, localization, and fallback behavior.

## 2. Relevant Code

| Path | Responsibility |
|---|---|
| `game/scripts/rampage/player_combat_profile_store.gd` | Local profile schema, callsign, bounded run history, local ranking, online payload. |
| `game/scripts/rampage/run_summary_snapshot.gd` | Immutable final-run facts used for history insertion. |
| `game/scripts/ui/match_debrief_panel.gd` | Existing responsive final screen; receives tab pages and asynchronous network states. |
| `game/scripts/ui/career_weapon_history_chart.gd` | New data-driven interactive chart control. |
| `game/scripts/network/leaderboard_bridge.gd` | New versioned same-origin Web bridge, request timeout, response decoding, fallback state. |
| `game/scripts/main/main.gd` | Owns and initializes profile plus bridge; injects both into runs. |
| `game/scripts/gameplay/city_slice.gd` | Receives optional bridge dependency beside the current profile store. |
| `game/scripts/gameplay/city_run_lifecycle.gd` | Submits one finalized summary locally and asynchronously requests online upsert/list. |
| `game/localization/en.json`, `zh-CN.json` | Callsign, chart, tabs, global/local states, ranking and validation copy. |
| `game/test/test_match_debrief_analytics.gd` | Profile migration/history/ranking/chart and lifecycle regression coverage. |
| `game/selftest/match_debrief_visual_scenario.gd` | Landscape/portrait page geometry and deterministic screenshots. |
| `client/src/App.tsx` | Sole fullscreen iframe plus invisible trusted message bridge. |
| `client/src/features/leaderboard/*` | Message schemas, bridge controller, and typed tRPC calls after WebDev upgrade. |
| `drizzle/schema.ts` | `leaderboardProfiles` table and ranking indexes. |
| `server/db.ts` | Monotonic profile upsert, callsign update, top list, personal-rank queries. |
| `server/routers/leaderboard.ts` | Public Zod-validated tRPC procedures. |
| `server/routers.ts` | Root router composition. |

## 3. Proposed Approach

### 3.1 Local-first profile schema migration

Bump `PlayerCombatProfileStore` to schema version 2 and implement explicit v1 migration. Preserve the anonymous ID and every existing scalar/dictionary. Add:

- `callsign` with deterministic default `OBELISK-XXXX`;
- `run_history`, maximum 30 entries;
- `latest_submission_state` for UI diagnostics only;
- helper methods for callsign validation/update, ranked local history, history chart snapshots, and online payload construction.

A history item is inserted once inside `enrich_and_submit`. It stores only bounded immutable run metrics and a sanitized weapon-count dictionary. Duplicate finalization remains impossible because `CityRunLifecycle` already freezes and submits once.

### 3.2 Interactive Godot chart

Create `CareerWeaponHistoryChart`, a single reusable `Control` with no child-node churn. It draws axes, grid, up to three weapon trend lines, selected-point markers, legend, and tooltip. It supports:

- `set_history(history)` defensive-copy input;
- `set_mode(KILLS | SHARE)`;
- `_gui_input` hover/touch selection;
- `ui_left`/`ui_right` keyboard/controller selection;
- deterministic top-weapon selection and stable palette;
- `debug_snapshot()` for focused tests and visual harnesses.

The control never invents missing values and clamps percentages to 0–100.

### 3.3 Dossier tabs and profile controls

Refactor `MatchDebriefPanel` into three preallocated pages inside its existing full-screen scrim and action footer:

- **After Action:** current controls unchanged.
- **Career Signal:** callsign LineEdit/Save, validation/status label, chart mode buttons, chart, and five-row local ranking.
- **Global Network:** connection status, refresh button, top-10 landscape/top-8 portrait rows, and personal-rank strip.

The default page remains After Action. Retry and Title actions stay globally accessible. Tab buttons and editor controls participate in explicit focus navigation. The panel accepts a `PlayerCombatProfileStore` and optional `LeaderboardBridge`; when no bridge exists it immediately displays native local mode.

### 3.4 Same-origin asynchronous bridge

`LeaderboardBridge` owns request IDs, pending callbacks, and an approximately five-second timeout. On Web it posts:

```json
{
  "channel": "proto-scroller-leaderboard",
  "version": 1,
  "type": "submit | list | update_callsign",
  "requestId": "...",
  "payload": {}
}
```

The parent sends a response with the same channel/version/request ID and `ok`, `data`, or a bounded error code. The bridge validates dictionary shape and ignores unsolicited, duplicate, stale, or wrong-version replies. In native builds it reports `NATIVE_LOCAL` without evaluating JavaScript.

The bridge submits the career-best payload after local finalization and requests the list whenever the Global tab opens or Refresh is pressed. Callsign saving is always local-first; remote update failure leaves the local callsign intact and marks it pending for the next successful submit.

### 3.5 WebDev database backend

Upgrade the existing `proto-scroller` project in place with the managed database/user scaffold, retaining the existing iframe output. Add one table:

```text
leaderboard_profiles
  id BIGINT PK AUTO_INCREMENT
  installation_hash CHAR(64) UNIQUE NOT NULL
  callsign VARCHAR(20) NOT NULL
  highest_combo_tier INT UNSIGNED NOT NULL DEFAULT 0
  best_score BIGINT UNSIGNED NOT NULL DEFAULT 0
  best_physical_chain INT UNSIGNED NOT NULL DEFAULT 0
  peak_multiplier TINYINT UNSIGNED NOT NULL DEFAULT 1
  total_runs INT UNSIGNED NOT NULL DEFAULT 0
  victories INT UNSIGNED NOT NULL DEFAULT 0
  total_enemy_kills BIGINT UNSIGNED NOT NULL DEFAULT 0
  preferred_weapon VARCHAR(32) NOT NULL DEFAULT 'UNKNOWN'
  source_revision VARCHAR(64) NOT NULL
  recorded_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
```

Indexes cover the unique installation hash and global ordering `(highest_combo_tier DESC, best_score DESC, best_physical_chain DESC, recorded_at ASC)`.

The server hashes the anonymous ID with SHA-256 and applies `GREATEST` semantics to every career maximum/total so stale clients cannot reduce stored records. Callsign and preferred weapon are validated against allowlists. List limits are 1–20; numeric inputs are bounded below JavaScript’s unsafe integer range and the game’s practical limits.

### 3.6 React bridge controller

The React application still renders only the iframe. A narrow controller:

1. captures a ref to the iframe;
2. installs one `message` listener;
3. requires same origin and exact `event.source`;
4. parses data with Zod;
5. calls the appropriate tRPC query/mutation;
6. replies with the exact origin;
7. aborts/ignores work after unmount.

No database credential, session token, or stack trace crosses the bridge. React renders no leaderboard chrome.

## 4. Data Flow

```text
accepted combat events
  → CombatRunTelemetry
  → immutable RunSummarySnapshot
  → PlayerCombatProfileStore v2
      → append bounded local history
      → recompute local ranking/chart snapshots
      → persist atomically
      → build allowlisted career-best payload
  → LeaderboardBridge (non-blocking)
      → same-origin parent message
      → React bridge validation
      → tRPC public procedure
      → Drizzle/MySQL monotonic upsert
      → top rows + personal rank
  → Godot response validation
      → Global Network page
      ↘ timeout/error → local leaderboard fallback
```

## 5. Database and API Contracts

### 5.1 Submission input

The procedure accepts a 32–64 character random installation ID, callsign, source revision, highest combo tier, best score, best physical chain, peak multiplier, career totals, and preferred weapon. It rejects unknown keys and values outside the explicit schema.

### 5.2 Submission output

The output contains server time, normalized player row, current personal rank, and the bounded global list. It never returns installation hashes or database IDs used internally.

### 5.3 Ranking semantics

Global and local comparisons use the same pure ordering function. Global ranks use career maxima. Local rows use individual historical runs. Stable ties use record timestamp then stable ID/run ID.

## 6. Compliance Checks

| Concern | Decision |
|---|---|
| Structure | Preserve the one-project mapping and fullscreen iframe. Separate Godot chart/network/profile responsibilities and WebDev schema/db/router/bridge layers. |
| Architecture | Godot owns gameplay and offline state; WebDev owns database access; React is a typed transport adapter only. |
| React | One visible component, one iframe ref, one bounded listener lifecycle, no render-time side effects. |
| i18n | Every new Godot-visible string receives identical EN and zh-CN keys; callsigns remain user data. |
| Security | Same-origin/source validation, Zod input, server hashing, allowlisted fields, bounded values, parameterized Drizzle, generic errors, no raw identifier at rest. |
| Privacy | Full run history and detailed weapon trends stay local. Only career-best aggregates are submitted. |
| Responsive UI | Preallocated tab pages, fixed footer, landscape/portrait layouts, minimum 48 px interactive controls, bounded chart labels/rows. |

## 7. Preflight Risk Checklist

| Category | Status | Adjustment |
|---|---|---|
| Logic | Risk controlled | One-time run finalization remains authoritative; local/global comparators share explicit tie rules. |
| Security | Risk controlled | Treat all Godot payloads as untrusted; validate at React and server boundaries; hash installation ID before persistence. |
| Architecture | Pass | Database support extends the existing WebDev project; the game remains self-contained when offline. |
| Structure | Pass | New files have single responsibilities; no second visible web application is introduced. |
| React | Risk controlled | Listener validates source/origin and is cleaned up; mutations are invoked only from validated events. |
| i18n | Pass | New labels and validation states are catalog-owned in both languages. |
| Responsive UI | Risk controlled | Tabs avoid adding simultaneous content; rows and chart receive separate layout contracts per orientation. |
| Reviewability | Pass | Work is split into profile/history, UI/bridge, backend/database, and deployment commits. |
| Competitive integrity | Explicit limitation | Community board is client-reported and bounded, not cheat-proof; authoritative simulation is out of scope. |

## 8. Work Packages

| Package | Scope | Exit criteria |
|---|---|---|
| WP0 — Proposal and plan | Product UX, privacy, schema, API, bridge, fallback, chart interaction, risks | Documents committed and pushed; no runtime behavior changed |
| WP1 — Local profile/history | v1→v2 migration, callsign, 30-run history, deterministic local ranking, payload update | Focused store tests pass; malformed/migrated profiles preserve prior records |
| WP2 — Career UI | Tabbed dossier, callsign editor, interactive chart, local board, localization | Focused UI tests and both visual orientations pass |
| WP3 — Network bridge | Godot request/response state machine and trusted parent messaging | Native fallback, timeout, malformed response, and successful response tests pass |
| WP4 — WebDev backend | Full-stack upgrade, schema/migration, Drizzle helpers, tRPC procedures, React bridge | Database migration applies; API tests cover validation/upsert/ranking; host remains iframe-only |
| WP5 — Integration | Lifecycle submit, online refresh, callsign sync, local fallback, README/plan | Focused source and WebDev tests pass; source pushed without overwriting upstream |
| WP6 — Release | Fresh Godot export, immutable payload remap, continuity records, checkpoint, publish | Exact routes/hashes recorded; checkpoint published; broad release gates skipped per project override |

## 8.1 Implementation Record

| Package | Status | Evidence |
|---|---|---|
| WP0 — Proposal and plan | Complete | Proposal and this implementation contract pushed in `754389a`. |
| WP1 — Local profile/history | Complete | Schema v1 migrates to v2 without record loss; callsigns validate and persist; history is capped at 30; local ranking uses combo/score/chain/timestamp ordering. Focused analytics suite passed 10 tests and 148 assertions. |
| WP2 — Career UI | Complete | Three responsive tabs, callsign editing, interactive 12-run kills/share chart, deterministic local ranking, and global/fallback presentation. Focused suite passed 11 tests and 166 assertions; career/global pages passed 1280×720 and 720×1280 focused visual checks. |
| WP3 — Network bridge | Complete | Same-origin/versioned envelopes, correlated request IDs, bounded queue polling, four-second timeout, native-safe local state, local-first callsign updates, and non-blocking post-finalization submission. Focused suite passed 12 tests and 173 assertions. |
| WP4 — WebDev backend | Complete | Existing host upgraded in place to managed MySQL/tRPC. Generated migration `0000_melted_serpent_society.sql` applied; strict shared Zod schemas, SHA-256 installation hashing, monotonic upsert, deterministic personal/global ranking, and public submit/list/callsign procedures implemented. TypeScript passed, six focused Vitest tests passed, and the live empty-board list endpoint returned successfully. |
| WP5 — Integration | Complete | Godot submits after authoritative local finalization, refreshes on Global tab entry, syncs callsigns local-first, rejects unsolicited responses, and falls back after four seconds or any malformed/error response. Latest compatible district projectile/actor VFX were fast-forwarded without overwriting either feature set. Final gameplay source is `339dfa710efa1f75c9ee73894877f40403ff9b1b`. |
| WP6 — Release | Complete | Fresh Godot 4.7.2 Web export remapped to `/manus-storage/game_f9ec2cbd.wasm` (39,514,754 bytes; SHA-256 `fc74679e3b97f76878947fcd4fbe1268cbfa6188182a2e33bbc3f5dc9bfa57d0`) and `/manus-storage/game_9bd5a2d9.pck` (18,178,464 bytes; SHA-256 `2a1330be01c6c30fed16ede1d583a9473d30e4c70b23bb033c77e00b95b5c11b`). WebDev checkpoint `f35e0af3` saved and published to the existing project/domain. Full release gates were skipped under the active user override. |

## 9. Verification

Per the active project override, do not run the full release-gate matrix, exhaustive Xvfb suite, browser smoke matrix, or repeated stabilization loops. Run only focused evidence:

- `gdlint` on changed GDScript files;
- focused GUT suites for profile migration/history/ranking, chart interaction, bridge state, and lifecycle presentation;
- direct import and a bounded headless debrief/bridge scenario only when needed to catch parse failures;
- one focused 1280×720 and one 720×1280 dossier page render;
- focused `pnpm test` and `pnpm check` in WebDev; broad build/release certification remains skipped under the explicit override;
- database migration inspection plus non-test SQL readback of table/index shape;
- strict invalid-input/hash contract tests plus a live empty-list check without inserting fake production rankings;
- fresh Godot Web export and exact payload remap.

## 10. Completion Definition

The feature is complete when profile schema v1 migrates without loss; callsigns persist and validate locally; recent runs create interactive weapon-trend charts; the local board ranks runs deterministically; the online board stores one hashed installation profile and returns deterministic global/player ranks; all online operations fail back to local state without blocking; the host remains a fullscreen iframe; source and deployment records are pushed; and the exact final export is checkpointed and published.
