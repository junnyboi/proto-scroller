# Proto Scroller Asset Optimization and Cleanup — Implementation Plan

**Author:** Manus AI  
**Planning baseline:** `20ed9f9de5625c273f8907642664d9b446bf1c4b`  
**Engine contract:** Godot 4.7.2 stable, GL Compatibility, non-threaded Web templates  
**Release target:** Existing Manus WebDev project `proto-scroller`

## 1. Objective

This plan reduces Proto Scroller's Web PCK without deleting active content, changing gameplay authority, altering the fullscreen host, or silently lowering perceptual quality. It converts the completed asset audit into independently releasable phases ordered by risk. Every phase preserves GitHub as the canonical source, uses the repository's existing `Web` preset, pushes the integrated result to shared `main` without rewriting history, creates a fresh Godot export, updates the existing WebDev project, saves a checkpoint, and publishes when direct publication is available.

The pre-change Phase 1 baseline at `20ed9f9` is **27,149,252 bytes**. Measurements from the preceding audit are treated as estimates until repeated against the phase's final canonical tree because concurrent gameplay development can change alignment and pack overhead.

## 2. Non-negotiable contracts

Optimization must not change resource identity, UIDs, scene paths, input behavior, gameplay timing, collision, scoring, leaderboard payloads, localization, title-media synchronization, or audio routing. Source masters remain at their authored sample rate and dimensions unless a later phase explicitly performs a source repack. Runtime import changes must remain reversible through tracked `.import` metadata.

The package cleanup is conservative. Dynamically constructed dossier resources and Godot's conventional `default_bus_layout.tres` remain shipped. Test-only resources may remain in Git for regression coverage while being excluded from the Web export. Provenance manifests may remain beside their source assets until a later documentation migration, but they must not consume runtime package bytes.

## 3. Phase roadmap

| Phase | Scope | Primary technique | Measured opportunity | Risk | Status |
|---:|---|---|---:|---|---|
| 1 | Safe runtime-package cleanup and eight PCM SFX imports | Web-preset exclusions plus QOA import | **832,068 bytes (0.794 MiB) measured** | Low–moderate | **Complete** |
| 2 | Lossless enemy archetypes and upgrade icons | Convert eligible PNG imports to lossy quality `0.70` | Approximately 1.80 MiB combined | Moderate | Planned |
| 3 | Existing boss and robot atlas compression | Boss quality `0.70→0.55`; robot `0.80→0.60` | Approximately 1.13 MiB combined | Moderate | Planned |
| 4 | Selective audio bandwidth reduction | Voice-first 24 kHz trial, then bounded SFX expansion | 0.18–1.11 MiB depending scope | Moderate–high | Planned |
| 5 | Grid-preserving atlas repacks | 75% boss-cell repack and robot idle-row split | At least 3.57 MiB for bosses; robot TBD | High | Planned |
| 6 | Permanent package-budget enforcement | Inventory manifest, allowlists, and CI/export regression thresholds | Prevents recurrence | Low | Planned |

## 4. Phase 1 — Safe package cleanup and QOA conversion

### 4.1 Runtime exclusion set

Phase 1 retains all source files but excludes eighteen verified non-runtime resources from the Web PCK. This avoids destructive deletion while preserving test fixtures and authorship records.

| Class | Resources | Disposition |
|---|---|---|
| Dormant/orphan media | `art/city/parallax/living/cloud_bank.webp`; `art/city/parallax/sky.png`; `art/presentation/kinetic_impact_halo.png` | Delete after independent verification; keep wildcard exclusions as anti-regression guards |
| Runtime-unused metadata | `art/city/enemies/deployment/conventional-reinforcement-deploy.json`; `art/city/enemies/effects/choir-incubation-payload.json`; both parallax `MANIFEST.json` files; four enemy-impact JSON files; `art/upgrades_art_manifest.json` | Exclude exact JSON paths; keep in Git for provenance/test use |
| Legacy test waves | `resources/encounters/wave_01_contact.tres` through `wave_04_retaliation.tres` | Exclude from Web; retain for excluded GUT tests |
| Script-only candidates | `scripts/combat/weapon_mount_visual_2d.gd`; `scripts/siege/district_recipe_validator.gd` | Exclude scripts and `.uid` companions; retain validator for tests and defer deletion of the unreferenced visual helper |

The exclusions are additive to the existing test, self-test, GUT, artifact, and superseded-art filters. No live dossier, audio bus, district deck, title media, leaderboard resource, or scene dependency is removed.

### 4.2 Audio import conversion

The following eight 48 kHz mono source WAVs change from uncompressed PCM (`compress/mode=0`) to QOA (`compress/mode=2`) without resampling, trimming, normalization, looping, or source modification:

| Functional group | Runtime sources |
|---|---|
| Robot feedback | `dodge_energy_recharged.wav`; `robot_footstep.wav`; `robot_servo.wav` |
| Shop and progression | `shop_repair.wav`; `shop_purchase.wav`; `upgrade_confirm.wav` |
| Rampage feedback | `overdrive_activation.wav`; `combo_break.wav` |

QOA is chosen before sample-rate reduction because it captures most of the available compression opportunity while preserving the complete source bandwidth. Audio routing, preload paths, UIDs, bus assignment, priority, and playback code remain unchanged.

### 4.3 Phase 1 acceptance

The tracked preset must include all eighteen exclusions exactly once. The eight import files must report mode `2`, and their source hashes must remain unchanged. A fresh Godot 4.7.2 export must contain HTML, JavaScript, WASM, and PCK artifacts. The final PCK must be smaller than the same-tree pre-change baseline, and isolated pack enumeration must show none of the eighteen candidates or their excluded companions.

Under the project release-gate override, Phase 1 deliberately omits the repository-wide regression suite, bounded boot, Xvfb certification, browser smoke matrix, and equivalent release ceremony. Delivery checks are limited to successful export generation, required-artifact presence, exact import-mode inspection, source-master immutability, isolated candidate-absence enumeration, and final HTTP payload verification after WebDev synchronization. WebDev must remap the fresh WASM and PCK even when the engine WASM hash is unchanged, preserve the customized shell and local worklet routing, update `PLAN.md`, `STRUCTURE.md`, `MEMORY.md`, and `ASSETS.md`, restart the preview, verify HTTP byte sizes for both private objects, save a checkpoint, and publish if supported.

The pre-integration candidate exported at **26,317,184 bytes**, exactly **832,068 bytes smaller** than the **27,149,252-byte** same-tree baseline. All eighteen candidates were absent from isolated PCK enumeration, all eight imports reported QOA mode `2`, and no WAV, OGG, PNG, WebP, or JPG source master changed.

### 4.4 Phase 1 rollback

Rollback consists of removing the eighteen appended export filters and restoring the eight `compress/mode` values to `0`. Source WAVs and retained candidate files are untouched, so rollback requires no asset restoration.

## 5. Phase 2 — Enemy and upgrade texture import normalization

Phase 2 converts eligible lossless PNG imports in `art/city/enemies/archetypes/` and `art/ui/upgrades/` to Godot lossy texture mode at quality `0.70`. It must not resize source dimensions or change alpha-bearing source files. The implementation begins with a generated before/after manifest recording every path, import mode, dimensions, alpha fraction, source hash, and imported byte count.

Acceptance requires representative galleries covering all affected archetypes, transparent-edge inspection against dark and bright districts, portrait and landscape checks, and pixel-difference review focused on halos, one-pixel silhouettes, weapon tips, and UI glyph-like edges. Any texture with unacceptable fringe or contour loss stays lossless through an explicit exception list. The phase ends with a measured fresh-export delta, source push, WebDev remap, checkpoint, and publication.

## 6. Phase 3 — Boss and robot atlas quality tuning

Phase 3 changes only import quality: five boss atlases move from `0.70` to `0.55`, and `grunt_horizontal_atlas.png` moves from `0.80` to `0.60`. Dimensions, frame grids, expected cell sizes, source files, alpha, and runtime slicing code remain unchanged.

Acceptance covers every boss moving and attacking east/west, white-hit flash, telegraph-to-active transitions, road grounding, defeat freeze, and title/responsive presentation where applicable. Robot validation covers all six 25-frame rows, idle, jab-cross, ground slam, charge hold/release, flash states, and outline stability. Failed visual comparisons revert individual atlases rather than weakening the entire threshold. The phase ends with the standard source push and exact WebDev synchronization.

## 7. Phase 4 — Selective sample-rate reduction

Phase 4 is split into two release candidates. Candidate A limits the twelve voice/announcer WAVs to 24 kHz while preserving existing compression modes. Candidate B extends 24 kHz import limits to additional short WAV effects and combines the eight Phase 1 PCM sources with QOA. Candidate B proceeds only if Candidate A passes listening review and the download target still justifies broader change.

The listening matrix covers speech intelligibility, sibilance, transient attack, loop boundaries, positional localization, dense-combat masking, mobile speakers, headphones, and browser worklet playback. Bright mechanical impacts, recharge tones, and UI transients receive stricter comparison than low-frequency debris or speech. No source master is resampled destructively. Any rejected cue receives a per-file sample-rate exception.

## 8. Phase 5 — Structural atlas repacks

Phase 5 is intentionally separate because it changes source geometry and runtime contracts. The boss repack resizes every cell on exact 8×4 grid boundaries to approximately 75% linear resolution, updates `EXPECTED_CELL_SIZES`, regenerates manifests and hashes, and validates sockets, visible-bottom calibration, attack regions, display envelope, and defeat presentation. Generic `process/size_limit=4096` is forbidden: it generated non-divisible heights for four atlases and regressed CHOIR Prime to its old one-times cell size.

The robot repack removes the mostly empty seventh row by moving the single idle frame to a dedicated 256×256 texture or a compact companion atlas. It updates `RobotSpriteFramesBuilder` without changing animation names, frame counts, FPS, filtering, or gameplay timing. Both repacks require full representative visual certification before release and must be independently revertible.

## 9. Phase 6 — Permanent package-budget enforcement

The final phase turns one-time savings into a maintained contract. It adds a deterministic inventory command that records PCK bytes, physical entry count, logical resource count, media/import totals, and the top payload contributors. A checked-in allowlist documents intentional runtime-unreachable resources and dynamic-load exemptions. CI or the repository verification harness fails when forbidden paths return, the PCK exceeds an agreed budget, or any top contributor grows beyond its approved threshold without an updated rationale.

The budget guard must avoid fragile absolute comparisons where Godot alignment varies; it should use exact forbidden-path checks plus explicit package ceilings and controlled tolerances. Reports remain machine-readable JSON/CSV with a concise Markdown summary.

## 10. Cross-phase release protocol

Each phase begins by protecting local work, fetching and fast-forwarding `main`, and revalidating that its target assets remain eligible. Before final testing, upstream is fetched again and compatible changes are integrated semantically. The phase then performs its focused checks, commits to shared `main`, pushes without force, creates a fresh Godot export from the pushed tree, uploads both WASM and PCK through WebDev-private storage, refreshes the generated shell when changed, updates continuity records, restarts the preview, verifies private-object byte sizes over HTTP, saves a checkpoint, and publishes when a direct tool is available.

No phase may claim additive savings by summing overlapping standalone experiments. Only the exact delta between same-tree baseline and candidate exports is authoritative.

## 11. Phase status record

| Phase | Source status | Export status | WebDev status |
|---:|---|---|---|
| 1 | Implemented in `af5dc4a` and preserved through combined gameplay head `6d2f48d` | Candidate measured at 26,317,184 bytes before final combined export | Complete through the companion WebDev checkpoint and published host |
| 2 | Planned | Not started | Not started |
| 3 | Planned | Not started | Not started |
| 4 | Planned | Not started | Not started |
| 5 | Planned | Not started | Not started |
| 6 | Planned | Not started | Not started |

Phase 1 is complete at source level. Concurrent runtime-tuning adapters and boss-route work landed after the optimization commit and were preserved by fast-forward integration rather than overwritten. The final release procedure therefore exports and remaps the complete shared-main descendant, not the earlier isolated optimization candidate.

## 12. Verified source-retirement follow-up
A conservative audit at baseline `21b15e00c10c4cab11849e6a50f7ebe2900bb163` deleted six obsolete derivatives, their imports, three stale manifest entries, and the cloud-processing recipe. The deletion removes **1,082,614 tracked bytes** before manifest reduction and claims no additive PCK saving because Phase 1 already excluded every path. Export exclusions remain as anti-regression guards.

## References

[1]: https://github.com/junnyboi/proto-scroller/tree/20ed9f9de5625c273f8907642664d9b446bf1c4b "Proto Scroller planning baseline 20ed9f9"
[2]: https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_audio_samples.html "Godot documentation: Importing audio samples"
[3]: https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_images.html "Godot documentation: Importing images"
[4]: https://docs.godotengine.org/en/stable/tutorials/export/exporting_projects.html "Godot documentation: Exporting projects"
