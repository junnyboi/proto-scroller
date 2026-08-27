# District-Specific Weather Implementation Plan

**Author:** Manus AI
**Status:** Completed
**Engine:** Godot 4.7.2-stable
**Target branch:** `main`

## Objective

Extend the five district panoramas with distinct, synchronized screen-space weather while preserving combat readability, responsive landscape and portrait layouts, deterministic fixed runtime allocation, New Game+ reset, floating-origin behavior, and the existing fullscreen WebDev host.

## Atmosphere Profiles

| District | Weather identity | Visual contract | Budget |
|---|---|---|---:|
| **Business — The Ledger Spine** | Wind-sheared acid drizzle | Thin cyan-gray diagonal rain, restrained skyline haze, fast eastward drift | 72 particles |
| **Residential — Ashwater Commons** | Heavy utility rain and low fog | Long cold rain, three low municipal mist bands, slower lateral drift | 112 particles |
| **Entertainment — The Afterglow Strip** | Neon drizzle and charged motes | Short magenta-cyan rain, violet haze, sparse electrical motes | 88 particles |
| **Military — The Iron Corridor** | Wind-driven ash and dust | Gray-olive ash flecks, two low dust sheets, turbulent lateral gusts | 80 particles |
| **Royal — The Crownward** | Ceremonial ember fall and smog | Slow brass-crimson embers, three wine-gray smog bands, gentle rise-and-fall | 68 particles |

## Architecture

`DistrictWeatherRuntime` is a fixed `CanvasLayer` at layer 10, above the world and below the layer-20 gameplay HUD and layer-95 transition banner. It owns exactly one `DistrictWeatherSurface`, one deterministic 128-record normalized particle seed table, five immutable profile dictionaries, and one transition state. The surface uses Godot canvas primitives only—lines, circles, and low-alpha rectangles—so the feature adds no texture, import, or PCK payload.

`CityWorldBuilder.build_environment()` mounts parallax and weather together. `transition_environment()` forwards each canonical `CityWorldStream.district_changed` event to both systems. `reset_environment()` returns both to Business during New Game+. The weather uses viewport-local normalized positions and a portrait density multiplier, so dynamic-viewport Web layouts remain covered without allocating on resize.

## Phases

### Phase 1 — Profile and runtime contract

Define the five immutable atmosphere profiles, deterministic particle seed table, responsive density policy, layer ordering, and public inspection methods. Register one runtime, one surface, a fixed 128-particle capacity, and zero post-warm creations with `RuntimeBudget`.

### Phase 2 — Rendering and transition integration

Implement rain, ash, ember, charged-mote, fog, and dust drawing on the fixed surface. Crossfade density, color, wind, fog, and opacity over 850 ms while switching the primitive family at the transition midpoint. Route spatial district changes and New Game+ reset through the shared environment entry points.

### Phase 3 — Focused verification and source integration

Verify all five profiles, distinct effect kinds, responsive portrait density, layer ordering, fixed node count, zero post-warm growth, canonical district transitions, invalid-ID rejection, and Business reset. Run focused lint/import/GUT checks only under the project release-gate override, then merge concurrent `main` semantically and push without rewriting history.

### Phase 4 — Exact export and WebDev synchronization

Fresh-export the final pushed Godot 4.7.2 tree, upload and remap both WASM and PCK, preserve the fullscreen iframe plus managed leaderboard service, update WebDev continuity records, and save a final checkpoint. Repository-wide gates, screenshot matrices, browser smoke matrices, and WebDev build certification remain omitted unless explicitly requested.

## Acceptance Criteria

| Concern | Acceptance |
|---|---|
| District identity | Five stable profiles expose five distinct weather kinds and palettes |
| Combat readability | Maximum opacity remains below 0.42 and weather stays below all HUD layers |
| Runtime allocation | One runtime, one surface, 128 deterministic records, zero transition-time node creation |
| Responsive behavior | Portrait density is reduced while coverage remains viewport-wide |
| Spatial authority | Only the existing world-stream district signal drives live transitions |
| Lifecycle | Startup and New Game+ select Business immediately |
| Deployment | Exact final-tree WASM/PCK are mapped in the existing WebDev project |

## Implementation Record

| Phase | Status | Evidence |
|---|---|---|
| Phase 1 | Completed | Five immutable profiles; one layer-10 runtime; one surface; deterministic 128-record capacity; responsive portrait density |
| Phase 2 | Completed | Rain, neon drizzle, charged motes, ash, embers, fog, and dust integrated through shared environment transition/reset entry points |
| Phase 3 | Completed | Weather 3/3 tests and 56 assertions; parallax/runtime-budget compatibility 6/6 tests and 240 assertions; strict GDScript lint and clean Godot import diagnostics |
| Phase 4 | Completed | Merged implementation commit `547b820`; exact final Godot 4.7.2 export synchronized to the existing fullstack WebDev host with fresh immutable WASM/PCK mappings |
