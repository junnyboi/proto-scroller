# District Missions and Difficulty Escalation Plan

**Author:** Manus AI  
**Status:** In progress — planning complete  
**Target branch:** `main`  
**Engine:** Godot 4.7.2-stable

## Objective

Add deterministic, district-specific mission pools; provide continuous mission countdown and objective progress feedback; and replace the current raw distance-tier pressure stack with a bounded five-district difficulty curve. Spatial districts remain independent of the six temporal siege acts: `CityWorldStream` selects geography and district pressure, while `DistrictDefinition` continues to author the six-act combat sequence.[1] [2]

The implementation must preserve the fixed six-chunk world window, existing destruction-state persistence, current score and XP formulas, prewarmed enemy/hazard pools, the three-card mission selection overlay, English and Simplified Chinese parity, and the Godot 4.7.2 Web export contract.

## Shared Contracts

`CityWorldStream.current_district_id` is the sole routing authority for spatial missions and pressure. Mission events observe existing deduplicated `GameplayEvent` records and never publish synthetic score events. `DirectiveSession` remains the sole mission clock. Pauses freeze both gameplay and mission time. District exit withdraws the old mission without success, failure, or score penalty, clears its persistent effect, invalidates deferred work, closes any stale choice overlay, and offers the destination pool at most once per cycle.

Runtime variety remains bounded. The game keeps six resident world chunks, 24 pending enemy records, at most three elite assignments, hazard pressure at or below ten, at most three pending hazard events, at most six active hazards, and zero post-warm gameplay allocation.

## District Mission Roster

Each district owns three globally unique missions, matching the three-card choice overlay. Existing directive effects become reusable effect kinds rather than being hard-coded to mission IDs.

| District | Mission | Predicate | Target | Time | Effect |
|---|---|---|---:|---:|---|
| **Business** | Demolition Breach | Structural cell destroyed | 3 | 14 s | Breach multiplier |
| **Business** | Asset Liquidation | Street prop destroyed | 3 | 16 s | None |
| **Business** | Concrete Audit | Concrete structural cell destroyed | 2 | 16 s | None |
| **Residential** | Block Clearance | Structural chain collapse | 1 | 18 s | None |
| **Residential** | Street Cleanup | Street prop destroyed | 4 | 18 s | None |
| **Residential** | Glass Eviction | Glass structural cell destroyed | 3 | 18 s | None |
| **Entertainment** | Crowd Pleaser | Combo-qualified enemy defeated | 3 | 18 s | None |
| **Entertainment** | Neon Blackout | Catalyst triggered | 1 | 20 s | None |
| **Entertainment** | Aftershock Encore | Combo-qualified directive aftershock event | 2 | 16 s | Aftershock |
| **Military** | Armor Disposal | Enemy wreck scrapped | 2 | 20 s | None |
| **Military** | Causal Offensive | Causal-chain event at depth two or greater | 2 | 20 s | None |
| **Military** | Ordnance Rupture | Catalyst triggered | 2 | 22 s | None |
| **Royal** | Skybreaker | Airborne debris hit | 1 | 20 s | Skybreaker |
| **Royal** | Steel Abdication | Steel structural cell destroyed | 3 | 22 s | None |
| **Royal** | Palace Ruin | Structural cell destroyed | 5 | 24 s | None |

All names and instructions are localized through `en.json` and `zh-CN.json`. Pool validation requires exactly the five catalog district IDs, three profiles per pool, unique mission IDs, correct ownership, valid event predicates, valid localization keys, and non-null icons.[3] [4]

## Mission Offer and Lifecycle Design

`DistrictMissionCatalog` owns the five immutable pools. Selection sorts profiles by mission ID, performs a deterministic local shuffle keyed by run seed, cycle, district ID, and district ordinal, and emits exactly three choices without mutating source arrays. `UrbanSiegeRuntime` tracks offered `(cycle, district)` keys. The existing `DIRECTIVE_CHOICE` milestone requests the current district only if it has not already been offered; spatial boundary changes request the destination district and cannot be farmed through backtracking or stream resets.

`DirectiveProfile.matches_event()` replaces mission-ID switches with declarative filters for event kind, action tag, cause, material, combo qualification, and minimum causal depth. A separate effect kind preserves Breach, Aftershock, and Skybreaker behavior. Deferred Aftershock work carries a session generation token so withdrawal, stop, or reset prevents stale damage.

## Mission Card Telemetry

The card expands from the previous result-only 392×104 geometry into a responsive active layout containing a numeric countdown, timer bar, objective counter, objective bar, instruction, and pending-score label. Controls, fills, and styles are created once. During active play, the frame loop performs only scalar reads and existing-property mutation. Countdown text updates only when the displayed ceiling-second changes, and objective text updates only when progress changes.

The countdown uses `DirectiveSession.remaining`, not a second UI timer. Timer and progress ratios are clamped to `[0, 1]`. Result mode retains the existing 2.4-second display hold and rejects late countdown, progress, and bank signals. Landscape and portrait layouts keep the card inside the viewport and outside the mobile Dash/Smash safe zone. Numeric values remain visible so status is not communicated by color alone.

## District Difficulty Curve

The current distance tier stacks extra copies, cadence compression, recovery compression, elites, and hazards without accounting for enemy threat cost. The replacement locks one bounded district pressure profile at the start of each beat. Pressure is readiness-gated by player level so sprinting into Royal architecture cannot instantly force Royal combat density.

| District | Threat allowance | Live-threat ceiling | Cadence scale | Recovery scale | Elite bonus | Hazard pressure bonus | Hazard event bonus | Readiness level |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| **Business** | 0 | 8 | 1.00 | 1.00 | 0 | 0 | 0 | 1 |
| **Residential** | +1 | 11 | 0.96 | 1.00 | 0 | +1 | 0 | 2 |
| **Entertainment** | +2 | 14 | 0.92 | 0.96 | +1 | +2 | +1 | 3 |
| **Military** | +3 | 17 | 0.88 | 0.92 | +1 | +3 | +1 | 4 |
| **Royal** | +4 | 20 | 0.84 | 0.88 | +2 | +4 | +2 | 5 |

Enemy copy planning becomes threat-aware. Eligible spawn entries are ordered by threat cost with a deterministic rotation for variety. The planner prefers infantry and light copies, respects the district allowance and ceiling, never exceeds absolute threat twenty, and never duplicates a heavy or siege entry when a cheaper legal copy exists. Reservation failure degrades the extra plan rather than extending the beat indefinitely.

Hazard planning consumes the same locked profile and enforces caps at both planner and runtime. Active hazard IDs remain unique, pending events never exceed three, active hazards never exceed six, and delays maintain at least 0.75 seconds between independent damage windows. Score and XP formulas remain unchanged for the initial pass; deterministic simulations validate upgrade cadence before any narrow `xp_value` adjustment is considered.[5] [6]

## Work Packages

### WP1 — District mission catalog and routing

Implement declarative mission predicates, reusable effects, five validated pools, deterministic offers, once-per-cycle district routing, and non-penalizing withdrawal. Add localization and focused catalog, selector, transition, scoring, and stale-callback tests. Run the complete standard verification gate, review, commit, and push.

### WP2 — Live countdown and objective progress UI

Make mission time pause-aware, expose authoritative countdown state, build allocation-free timer/progress bars, add responsive landscape/portrait layouts, and expand the directive-card visual scenario to active, low-time, success, and failure states. Run focused tests, complete standard verification, inspect both orientations, commit, and push.

### WP3 — Bounded five-district difficulty escalation

Add district pressure profiles, readiness gating, threat-aware enemy copies, and hazard cap enforcement. Add a five-district by six-act planning matrix plus saturation, determinism, runtime-budget, and economy trace tests. Run the complete standard gate and representative traversal visuals, commit, and push.

### WP4 — Release verification and deployment

Re-fetch shared `main`, integrate concurrent work by fast-forward only, and rerun affected gates. Execute direct import, bounded boot, full GUT, Xvfb landscape/portrait scenarios, log scans, Web export, package-size enforcement, and Chromium smoke. Refresh the existing `proto-scroller` WebDev project, preserve the fullscreen iframe, run TypeScript/build checks, verify exact storage payloads and runtime input over HTTP, save a checkpoint, and publish when the tool is available.

## Verification Matrix

| Layer | Required evidence |
|---|---|
| Mission data | Five pools, fifteen unique missions, three valid choices per district, localization/icon parity |
| Determinism | Equal seed/cycle/district gives equal choice order; call order and backtracking do not change offers |
| Lifecycle | Pause freezes time; equal-deadline objective wins; withdrawal is penalty-free; stale effects cannot fire |
| Card telemetry | Timer and progress ratios correct; text updates bounded; no active/result signal leakage |
| Responsive UI | 1280×720 and 720×1280 card children remain in bounds and clear of mobile controls |
| Difficulty | Five exact profiles; nondecreasing bounded pressure; threat ≤20; pending enemies ≤24 |
| Hazards | Pressure ≤10; pending ≤3; active ≤6; unique IDs; no accidental recycle or post-warm creation |
| Economy | Readiness levels gate pressure; boundary transitions do not grant more than one immediate entitlement |
| Regression | Six resident chunks, mutation persistence, charge/dash/audio, directives, districts, and Web smoke remain green |

## References

[1]: ../game/scripts/world/city_world_stream.gd "CityWorldStream"
[2]: ../game/scripts/siege/district_response_director.gd "DistrictResponseDirector"
[3]: ../game/scripts/directives/directive_profile.gd "DirectiveProfile"
[4]: ../game/scripts/directives/directive_session.gd "DirectiveSession"
[5]: ../game/scripts/hazards/hazard_pressure_controller.gd "HazardPressureController"
[6]: ../game/scripts/quality/runtime_budget.gd "RuntimeBudget"
