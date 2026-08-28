# Living District Skies — Concept and Implementation Plan

**Author:** Manus AI
**Status:** Implemented, visually verified, and pushed
**Target branch:** `main`
**Engine:** Godot 4.7.2 stable

## Objective

Extend the five district panoramas with fixed-allocation atmospheric motion, district-specific transition grading, and a continuous day/night clock. The feature must preserve the existing imported-width seamless tiling repair, 850 ms district crossfade, spatial district authority, weather synchronization, floating-origin compensation, portrait framing, Web package limits, and fullscreen WebDev host.[1] [2] [3]

## Design Concept

The city should feel inhabited at skyline scale rather than busy at gameplay scale. A **slow cloud band** drifts between the base panorama and far skyline. A faster **air-traffic band** carries two distant vehicle silhouettes on staggered altitudes and repeat intervals. Both bands are decorative, collisionless, and created once during startup. Their tint, opacity, and velocity interpolate with the same eased weight as the district panorama, so the atmosphere changes as one coherent place rather than as independently switched effects.

The day/night clock completes one cycle in six minutes. It starts in late dusk to preserve the existing visual opening, progresses through blue night, muted dawn, cool day, and copper dusk, then loops without discontinuity. Time affects panorama saturation, brightness, air-traffic visibility, and shared depth-band colors. It does not modulate the HUD, combat telegraphs, actors, damage effects, collision, weather authority, or title presentation.

| District | Atmospheric character | Air traffic | Transition grade |
|---|---|---|---|
| Business | Restrained high-altitude smog moving east | Regular courier lanes | Cool steel cyan with restrained contrast |
| Residential | Broader humid utility cloud moving steadily | Sparse service shuttles | Desaturated aqua-gray |
| Entertainment | Slow luminous haze | Fast, frequent nightlife traffic | Subtle cyan-magenta lift |
| Military | Wind-driven dark overcast | Disciplined armored patrol cadence | Olive slate with amber highlights |
| Royal | Slow ceremonial cloud shelf | Sparse heavy state craft | Warm wine-gold grade |

## Asset Direction

GPT Image 2 supplies one wide transparent smoky cloud bank and two transparent side-view vehicle silhouettes. The sprites must match the painterly dystopian side-scroller panoramas, remain readable at 40–160 pixels on screen, contain no text or logos, avoid camera perspective, and use clean alpha. The runtime uses deterministic crop, resize, and WebP/PNG preparation only after generation; no procedural replacement art is introduced.

## Runtime Architecture

| Component | Responsibility | Fixed budget |
|---|---|---:|
| `DistrictSkyLifeRuntime` | Own time-of-day state, district atmosphere profiles, traffic movement, wrapping, reset, and floating-origin compensation | 1 runtime |
| `AirTraffic` | One `Parallax2D` band with two staggered vehicle sprites | 1 band / 2 sprites |
| `DistrictParallaxRuntime` | Continue panorama/depth crossfade; apply district grade and sampled day/night state to sky shader and depth bands | Existing bands/sprites unchanged |
| `seamless_panorama.gdshader` | Preserve exact edge equalization, then apply district grade, cycle tint, brightness, and saturation | 2 existing materials |

The runtime uses normalized time and pure keyframe interpolation. It owns no timers, random generators, particles, physics bodies, collisions, or per-frame node creation. District changes interpolate profile colors, opacity, and velocities. New Game+ resets district and scroll presentation while preserving the world clock, avoiding a visible jump from night back to dusk.

## Implementation Phases

### Phase 1 — Asset production

Generate the three transparent GPT Image 2 sources, inspect alpha and style, create compact runtime derivatives, record prompts, dimensions, hashes, and processing in a provenance manifest, and import through Godot 4.7.2.

### Phase 2 — Fixed living-sky runtime

Add `DistrictSkyLifeRuntime`, build exactly one traffic band and two traffic sprites at startup, implement district profile interpolation, continuous movement, deterministic wrap/repeat behavior, floating-origin compensation, and time-of-day sampling.

### Phase 3 — Environmental grading

Extend the existing seamless panorama shader with district and cycle uniforms. Apply sampled time state to both panorama materials, all three shared depth sprites, and both vehicles. Preserve alpha crossfade and exact edge matching.

### Phase 4 — Integration and focused verification

Wire the runtime through `DistrictParallaxRuntime`, central runtime-budget snapshots, reset behavior, and focused tests. Verify five district profiles, at least four time states, fixed node counts, no transition-time allocation, day-loop continuity, New Game+ clock persistence, floating-origin behavior, and seam preservation.

### Phase 5 — Visual certification and release

Capture all five districts at day, dusk, and night in ultra-wide and portrait layouts, inspect animation displacement and grade transitions, merge concurrent `main`, rerun lightweight focused checks, push without rewriting history, create a fresh Web export, remap fresh immutable WASM/PCK objects in the existing `proto-scroller` WebDev project, and save the final checkpoint. Repository-wide release-gate certification remains omitted by project directive; this feature receives only its requested visual and focused integration checks.

## Implementation Evidence

GPT Image 2 generated the cloud bank, courier shuttle, and heavy state carrier. The reproducible preparation script removed temporary green/magenta key spill, cropped against existing alpha, produced compact 1024×265, 256×125, and 384×154 WebP derivatives, and recorded source/runtime SHA-256 hashes in the asset manifest. `DistrictSkyLifeRuntime` now owns exactly one `Parallax2D` traffic band and two sprites, with five district profiles and normalized smoothstep time keys. `DistrictParallaxRuntime` advances the clock, synchronizes profile interpolation to its existing 850 ms crossfade, updates the seamless panorama shader, retints shared depth sprites, and forwards floating-origin compensation.

Focused Godot 4.7.2 verification passed **16 tests and 371 assertions** across living-sky behavior, district parallax, synchronized weather, and the central runtime budget. The dedicated Xvfb scenario produced **30 full-game captures**: every district at day, dusk, and night in 2048×905 ultra-wide and 720×1280 portrait layouts. The current visual contract retains distinct time grading and air traffic while explicitly requiring no mounted `CloudBank` or `CloudLife` node; gameplay, HUD, panorama coverage, and seam behavior remain unchanged.

The GPT Image 2 concept and runtime-asset phase was pushed as `639eea7acfedacec30c1d2799e1d5ffe8900ead5`. The integrated runtime, shader, budget, focused regression, and visual-scenario phase was pushed as `4ad02ff3a5aa9b52cb2411e9fdce7a3263c04b02`. Both commits use ordinary shared-main history; no branch rewrite or project-format upgrade occurred.

### Cloud-motion retirement

The later annotation-driven polish pass removes the drifting cloud bank entirely because its constant lateral motion overloaded the already active weather, parallax, and air-traffic composition. The original concept remains under documentation provenance; its obsolete runtime derivative, import metadata, manifest record, and processing job were removed during the 2026-08-28 media audit. District grading, the six-minute day/night cycle, both air vehicles, seamless panoramas, weather, and floating-origin compensation remain active.

## Acceptance Matrix

| Concern | Acceptance |
|---|---|
| Animated life | Air-traffic positions change continuously and wrap without allocation or popping; no drifting cloud band is mounted |
| District identity | Five profiles produce visibly distinct motion cadence and tint while retaining panorama identity |
| Transition grading | Panorama, depth bands, traffic, and weather change together over the existing 850 ms transition |
| Day/night | The six-minute loop is continuous, deterministic, visually distinct at day/dusk/night, and does not affect HUD or gameplay |
| Seam safety | Panorama repeat width and edge-equalization shader remain active at every district and time state |
| Responsive view | Ultra-wide and portrait captures retain full coverage and legible atmospheric scale |
| Runtime budget | One runtime, one traffic band, two sprites, zero post-warm creation |
| Deployment | Exact final-tree HTML, JavaScript, WASM, and PCK synchronize to the existing WebDev project |

## References

[1]: ../game/scripts/world/district_parallax_runtime.gd "District parallax runtime"
[2]: DISTRICT_PARALLAX_IMPLEMENTATION_PLAN.md "Five-district parallax implementation and seamless tiling repair"
[3]: ../game/scripts/world/district_weather_runtime.gd "District weather runtime"
