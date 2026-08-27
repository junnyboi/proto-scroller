# Kill-Score Combo Combat Herald — Implementation Plan

**Author:** Manus AI  
**Date:** 2026-08-27  
**Canonical repository:** `https://github.com/junnyboi/proto-scroller`  
**Baseline revision:** `eba869b77fe5ae3cd91f51af8b1ca5066713ddf0`  
**Engine:** Godot `4.7.2-stable`, GL Compatibility, non-threaded Web export

## 1. Objective

This work adds a **Combat Herald** presentation layer to the density-normalized kill-score combo system. Scoring, weighted progress units, multiplier growth, the 1.5-second decay window, damage reset, and the compact HUD ring remain authoritative and unchanged. When a meaningful authored tier is reached, the game presents a short, center-screen, non-blocking visual animation and an original arena-announcer voice line.

The system must be readable during dense combat, responsive in 1280×720 and 720×1280 layouts, safe under rapid milestone escalation, and bounded for Web. It must not pause gameplay, create combat-time nodes, mutate score math, or depend on the announcer audio finishing before the next milestone can replace it.

## 2. Existing Contract

The synchronized `ComboTracker` accepts only qualifying enemy defeats, increments the physical chain count, advances density-normalized progress units, caps the score multiplier at `5×`, refreshes a 1.5-second grace window, and resets on accepted player damage or expiry. Two physical regular-enemy kills equal one authored tier; singular named bosses contribute one complete authored step. `GameplayHud` renders the current multiplier and decay ring. `CityRunLifecycle` owns combo-break audio. The Web smoke probe and focused scenarios verify the normalized score award, multiplier, HUD label, and damage reset.

The new system will extend this contract rather than replace it:

| Existing behavior | Required treatment |
|---|---|
| `1×` through capped `5×` score math | Preserve exactly |
| Three-second grace window | Preserve exactly |
| Props and chain reactions do not grow the combo | Preserve exactly |
| Any accepted player damage resets the chain | Preserve exactly |
| Compact multiplier label and decay ring | Preserve as persistent HUD telemetry |
| Combo-break cue | Preserve and make it dismiss any active herald |

## 3. Player-Facing Design

### 3.1 Milestone ladder

The herald is milestone-based rather than kill-spam-based. It announces the early multiplier steps, then rewards longer chains beyond the `5×` score cap.

| Authored tier | Localized title key | English callout | Visual identity | Audio treatment |
|---:|---|---|---|---|
| 2 | `hud.combo_herald.double` | **DOUBLE KILL** | Twin opposing blades and split cyan corona | Firm, clipped declaration |
| 3 | `hud.combo_herald.triple` | **TRIPLE KILL** | Three-point reactor crest and triple pulse | Louder, rising authority |
| 4 | `hud.combo_herald.overkill` | **OVERKILL** | Four armored vanes and red warning core | Dark, contemptuous emphasis |
| 5 | `hud.combo_herald.unstoppable` | **UNSTOPPABLE** | Five-segment crown and white-hot center | Triumphant, maximal impact |
| 7 | `hud.combo_herald.annihilation` | **ANNIHILATION** | Broken orbital cage and expanding gold fracture | Slow, ominous domination |
| 10 | `hud.combo_herald.extinction` | **EXTINCTION EVENT** | Ten-rayed catastrophic reactor seal | Deep final-tier proclamation |

Progress beyond authored tier ten keeps the `EXTINCTION EVENT` state without replaying it on every kill. The physical chain remains numerically tracked for summaries.

### 3.2 Animation language

The animation lasts approximately **1.15 seconds** and never captures input:

1. **Impact entry (0–140 ms):** the generated insignia appears at 70% scale with a 9° counter-rotation, flashes cyan-white, and snaps to 112% scale.
2. **Lock-on (140–360 ms):** the insignia settles to 100%; a duplicated energy echo expands behind it; the localized title slides upward by a few pixels and resolves from overbright to tier color.
3. **Authority hold (360–780 ms):** the insignia rotates slowly in the opposite direction while the title remains stable and readable.
4. **Combat exit (780–1,150 ms):** the echo expands and fades, title tracking widens, and the whole herald dissolves without obscuring controls.

A new milestone immediately supersedes the previous animation. The presenter kills the old tween, stops the old voice, resets transforms, and begins the newer tier. This makes rapid triple or quadruple kills feel like escalation rather than queued stale notifications.

### 3.3 Responsive composition

| Layout | Insignia | Title placement | Safe-area rule |
|---|---:|---|---|
| Landscape | 196×196 maximum | Centered below the insignia, 42 px title | Keep clear of top HUD and directive panel |
| Portrait | 150×150 maximum | Centered below the insignia, 30 px title | Place at 36% viewport height, above touch controls |

The generated images contain **no text**. Godot renders localized labels from the existing EN and zh-CN catalogs, ensuring exact language, font coverage, and responsive typography.

## 4. Visual Asset Production

All six final insignias will be generated with **GPT Image 2**. The reference language combines the existing New Game+ machine medallion with the full-charge photon shockwave: gunmetal and antique-gold mechanical geometry, cyan-white energy filaments, sparse red warning accents, and transparent backgrounds.

Each source is generated as a standalone 1:1 transparent PNG, with no words, letters, digits, logos, watermarks, frames, or background scene. The production acceptance criteria are:

- complete centered silhouette with clean alpha;
- readable at 96–220 rendered pixels;
- no tier information that depends on generated typography;
- no hot-pink contamination from temporary alpha extraction;
- consistent perspective and light direction across the set;
- materially distinct segment/ray geometry per tier.

The source PNGs will live under `docs/combo-feedback-concepts/`. Runtime derivatives will be deterministic 512×512 optimized PNGs under `game/art/ui/combo_herald/`. A provenance document will record prompts, model, source paths, processing, hashes, and runtime mapping.

## 5. Announcer Audio Production

### 5.1 Original voice direction

The announcer will be an original **armored orbital-combat herald**, not an imitation of a named game, actor, or commercial voice. The voice is a deep adult male bass-baritone with controlled theatrical weight, slight synthetic command-channel resonance, precise consonants, and no crowd, music, or copyrighted melody.

Each line is short and self-contained. Delivery intensity rises by tier while remaining intelligible over combat:

- `DOUBLE KILL.` — clipped and approving;
- `TRIPLE KILL.` — stronger upward pressure;
- `OVERKILL.` — dark emphasis on the first syllable;
- `UNSTOPPABLE.` — broad, triumphant authority;
- `ANNIHILATION.` — slower and ominous;
- `EXTINCTION EVENT.` — deepest final-tier proclamation.

### 5.2 Video-carrier sound workflow

In accordance with the project asset policy, announcer sound production uses the **video-carrier-to-sound** method:

1. Generate one 16:9 GPT Image 2 anchor showing the original herald broadcast core, with no text.
2. Generate one short image-conditioned carrier video per callout, with audio enabled and the exact original voice direction.
3. Verify only MP4 integrity.
4. Extract the audio track with `ffmpeg`, trim silence, convert to 48 kHz mono PCM WAV, apply conservative loudness normalization, and preserve a short natural decay.
5. Store carrier videos and anchor provenance outside runtime imports; place only the optimized WAV files under `game/audio/voice/combo/`.

The runtime routes announcer clips through the existing **Voice** bus. A dedicated non-spatial `AudioStreamPlayer` avoids attenuation bugs as the robot moves through the city.

## 6. Runtime Architecture

### 6.1 Combo milestone signal

`ComboTracker` will add:

```gdscript
signal milestone_reached(tier: int, chain_count: int, multiplier: int)
```

The signal fires only when density-normalized progress crosses authored tiers `2`, `3`, `4`, `5`, `7`, and `10`. If one future event crosses multiple thresholds, only the highest crossed tier is emitted. This keeps score math and `combo_changed` untouched while providing a semantic event for presentation and tests.

### 6.2 Catalog

A new `ComboHeraldCatalog` centralizes immutable tier data:

- threshold;
- localization key;
- texture preload;
- voice preload;
- tier accent color;
- animation intensity scalar.

The catalog exposes exact-threshold lookup and highest-tier lookup. No resources are loaded during combat.

### 6.3 Presenter

A new `ComboHerald` `Control` owns:

- one non-interactive root container;
- one generated insignia `TextureRect`;
- one expanding echo `TextureRect`;
- one localized `Label`;
- one non-spatial `AudioStreamPlayer` on the Voice bus;
- one active tween reference;
- telemetry fields for threshold, title key, presentation count, audio count, and supersession count.

`GameplayHud` creates this presenter once, forwards milestone events through `show_combo_milestone`, dismisses it on combo break, and delegates responsive layout. `CityRunLifecycle` connects the tracker signal during setup and preserves the existing break cue.

### 6.4 Lifecycle and reset behavior

The herald must reset on:

- combo break from damage;
- combo expiry;
- run reset/retry;
- New Game+ cycle start;
- terminal overlays and defeat;
- node teardown.

Stopping the presenter clears its tween, resets transforms and alpha, hides both textures and label, and stops/releases active voice playback. All runtime objects are created at HUD initialization; no node or audio-player growth is allowed during a chain.

## 7. Localization

The EN and zh-CN catalogs receive identical keys. Proposed Simplified Chinese callouts are concise combat titles rather than literal sentences:

| English | zh-CN |
|---|---|
| DOUBLE KILL | 双重击杀 |
| TRIPLE KILL | 三重击杀 |
| OVERKILL | 过载歼灭 |
| UNSTOPPABLE | 势不可挡 |
| ANNIHILATION | 全域歼灭 |
| EXTINCTION EVENT | 灭绝事件 |

The CJK subset builder must be rerun after localization changes.

## 8. Work Packages

| Work package | Scope | Focused regression and exit criteria |
|---|---|---|
| WP0 — Plan and contracts | Finalize milestone ladder, asset/audio briefs, runtime boundaries, and acceptance criteria | Markdown lint by inspection, `git diff --check`, push plan baseline |
| WP1 — Production assets | Generate six GPT Image 2 insignias, one GPT Image 2 carrier anchor, six carrier videos, six optimized WAV files, deterministic runtime derivatives, provenance | File integrity, alpha/dimensions, WAV format/duration, import scan, push asset phase |
| WP2 — Semantic event and catalog | Add milestone signal and immutable catalog; add exact-threshold and non-repeat tests | Focused combo tracker tests and resource load test |
| WP3 — Responsive presenter | Build ComboHerald, integrate HUD/lifecycle, localization, break/reset behavior, telemetry | Focused city integration and landscape/portrait visual scenario; no overlap/clipping |
| WP4 — Browser-ready source release | Update Web smoke telemetry and authoritative harness assertions; focused direct import/boot only under release-gate override | Focused GUT, direct import, bounded boot, asset/log scan; push source release |
| WP5 — WebDev synchronization | Fresh Godot Web export from final pushed tree; upload/remap fresh WASM and PCK; update WebDev continuity files; checkpoint and publish | Required payload files and exact source revision recorded; no full release-gate ceremony unless explicitly requested |

**Status:** WP0 and WP1 are complete and pushed. WP2 through WP4 are implemented in the current source candidate with focused tests and responsive visual evidence complete. WP5 remains pending until the final source commit is pushed and its fresh Web export is synchronized to the existing WebDev project.

## 9. Focused Test Matrix

| Layer | Assertion |
|---|---|
| `ComboTracker` | Emits authored tiers 2/3/4/5/7/10 exactly once while preserving physical-kill progress normalization and the capped multiplier |
| Catalog | Every threshold resolves a texture, voice, localization key, and accent |
| Scoring | Existing `1× + 2× + 3×...` score math remains byte-for-byte behaviorally equivalent |
| HUD | Third kill presents `TRIPLE KILL`, x3 compact label remains visible, and the visual is non-interactive |
| Supersession | A new tier replaces active tween and voice rather than queueing stale feedback |
| Reset | Damage and expiry hide the herald and stop voice while preserving pending-score semantics |
| Responsive | Generated insignia and localized label stay inside both 1280×720 and 720×1280 viewports |
| Audio lifecycle | Voice player is non-spatial, uses Voice bus, starts once per milestone, and stops on reset/teardown |
| Web export | HTML, JS, WASM, and PCK are regenerated from the final pushed tree and synchronized to the existing WebDev project |

## 10. Implemented evidence

The source candidate adds a preloaded `ComboHeraldCatalog`, a preallocated responsive `ComboHerald`, density-aware milestone emission, lifecycle dismissal, EN/zh-CN titles, Voice-bus playback, future Web-smoke telemetry, and updated release-harness asset requirements. Six visual sources and one carrier anchor were generated with GPT Image 2; six original announcer cues were extracted from image-conditioned carriers and speech-verified. Deterministic processing, models, hashes, and final durations are recorded in `docs/KILL_COMBO_ASSET_PROVENANCE.md`.

Focused GUT checks passed **14/14 tests with 170 assertions** for rampage progression/catalog behavior and **6/6 tests with 52 assertions** for live city/HUD integration. The updated final-tier visual scenario passed at **1280×720** and **720×1280** with no script, resource-retention, or ObjectDB leak diagnostics. Screenshot inspection confirmed the Extinction Event insignia and localized title remain clear of top telemetry, narrative transmission, robot readability, and the portrait touch-control region.

## 11. Completion Definition

The feature is complete when the final pushed source visibly and audibly escalates qualifying kill chains through all six milestone tiers, preserves every existing score/reset contract, uses only GPT Image 2-derived visual assets, uses the mandated video-carrier workflow for announcer sound, remains responsive and bounded, updates this plan and provenance with actual output evidence, and is synchronized to the existing Proto Scroller WebDev checkpoint and public deployment.
