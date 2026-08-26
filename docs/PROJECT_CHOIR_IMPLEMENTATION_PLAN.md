# Project CHOIR End-to-End Implementation Plan

**Author:** Manus AI | **Status:** Implementation complete; release certification in progress | **Target engine:** Godot 4.7.2 stable

## Objective

Implement the approved Project CHOIR narrative across the complete playable loop without weakening Proto Scroller's deterministic streaming, bounded pools, one-button combat, localization parity, Web package budget, or release gates. The campaign must transform destruction into investigation through persistent dossiers, black-lab reveals, short nonblocking transmissions, six bio-mechanical enemy archetypes, and a Royal-district CHOIR Prime finale with three outcomes.

## Architectural decisions

| Concern | Decision |
|---|---|
| Persistent progress | A `CampaignProgressStore` is owned by `Main`, injected into each retry-created `CitySlice`, versioned, and independently testable through an injected path. |
| Narrative runtime | A `NarrativeDirector` observes existing spatial district, destruction, enemy, boss, and run signals. It never owns combat, pauses gameplay, or allocates after warm-up. |
| Dossiers | Exactly twenty-five static definitions map one-to-one to the twenty-five stable facade variant IDs. Repeated chunks and retries cannot award duplicates. |
| Lab reveals | One compressed GPT Image 2 laboratory panorama is reused through a fixed-capacity reveal layer. District-specific tinting and localized metadata provide variety without exhausting the Web package. |
| Transmissions | A bounded, nonmodal HUD toast displays short localized lines and never takes focus or a pause lease. |
| Hybrid enemies | Six GPT Image 2 transparent sprites extend existing infantry, light, air, and siege pools. Behavior remains data-driven and deterministic. |
| Encounter placement | Spatial-district resolution injects hybrids without mutating the existing six-act resource deck. Conventional units remain available throughout the campaign. |
| Finale | The existing `CommandBossSession` and prewarmed `BossUtilityPool` are specialized for canonical `CHOIR_PRIME`, avoiding a second boss pool. Royal arc completion activates five fixed memory-organ pylons, one GPT Image 2 core, and a bounded five-family replay gauntlet before requesting a choice. |
| Endings | PURGE is always available. A stable threshold snapshot controls DISENTANGLE; an insufficient attempt resolves ASCENSION FAILURE. Ending metadata is additive to existing summaries. |
| UI | Title briefing gains a campaign codex. Gameplay gains transmissions, dossier recovery, final choice, and ending presentation, all responsive at 1280×720 and 720×1280. |
| Localization | Every new player-facing string exists in English and Simplified Chinese with identical placeholders and tested key parity. |
| Export | Raw concepts, audits, and tests remain excluded from release. The final PCK must stay below the existing 16 MiB cap. |

## Work packages

| Phase | Scope | Acceptance gate |
|---|---|---|
| **WP0 — Architecture and production assets** | Record implementation contracts; generate six transparent hybrid sprites, one gameplay lab reveal, and CHOIR Prime core/pylon assets with GPT Image 2; normalize and verify alpha/size/import settings. | All assets are valid PNGs, visually inspected, source references recorded, no unexpected text/background, and projected package growth remains within budget. |
| **WP1 — Campaign foundation** | Add campaign persistence, twenty-five dossiers, narrative director, fixed lab reveal, nonblocking transmission UI, initial Business intro, district story beats, retry continuity, tests, and documentation. | Focused GUT, localization parity, save migration, stream idempotency, runtime-budget, headless traversal, landscape/portrait story render, client checks; commit and push. |
| **WP2 — Bio-horror escalation** | Add Reclaimed Breacher, Graft Runner, CHOIR Siren, Ossuary Crawler, Seraph Carrier, and Pale Engine profiles and bounded behavior extensions; district introduction logic; containment releases; visual gallery and deterministic pool tests. | All twenty-six archetypes validate; fixed pools allocate no post-warm nodes; all six hybrids appear in intended districts; landscape/portrait gallery and focused encounter gates pass; commit and push. |
| **WP3 — CHOIR Prime finale** | Add five pylons, core, Royal/arc latch, deterministic replay phases, ending eligibility snapshot, Purge/Disentangle/Ascension Failure resolution, summary metadata, ending overlay, and cleanup. | Event-order, threshold matrix, exact-once resolution, pause-lease, reset, command-boss compatibility, and visual finale tests pass; commit and push. |
| **WP4 — Campaign depth and codex** | Finish all twenty-five localized dossier entries, title codex, campaign progress display, retry/continuity copy, district directive context, ending archive, accessibility/focus behavior, and updated canonical docs. | Twenty-five-entry bijection and full EN/zh-CN parity; codex ordering/focus; longest-copy responsive tests; campaign integration scenario; commit and push. |
| **WP5 — Release certification** | Re-fetch latest main, resolve concurrent changes, run direct import/boot, full GUT and selftests, Xvfb landscape/portrait checks, Web export, HTTP/browser/network/audio/runtime checks, artifact hashes and budget scan. | `./verify.sh --full` passes on final shared head; required HTML/JS/WASM/PCK exist; browser CHOIR smoke and logs are clean. |
| **WP6 — WebDev release** | Refresh local shell and loader, upload/remap final WASM and PCK, update `PLAN.md`, `STRUCTURE.md`, `MEMORY.md`, `ASSETS.md`, type/build, restart, responsive/live-input/audio/finale validation, checkpoint and publish when available. | Exact deployed artifact URLs, sizes, and hashes match final export; preview passes desktop/portrait and runtime diagnostics; final checkpoint saved. |

## Risk controls

The design preserves fixed-capacity systems and avoids instantiating story scenes during traversal. New enemy effects reuse existing families and must degrade deterministically under saturation. Narrative events are stable-ID idempotent because chain destruction emits multiple callbacks. Finale start requires both Royal geography and siege-arc completion in either order. Campaign files tolerate missing, corrupt, old, and future versions. The Web export excludes high-resolution concept sources and uses production-scale textures only.

## Completion record

This section will be updated after each work package with the source revision, checks performed, measured test totals, visual evidence, Web artifact size, and any approved deviations.

| Work package | Status | Revision | Evidence |
|---|---|---|---|
| WP0 | Complete | Phase 1 | Five architecture audits completed at source `9f6e127`. GPT Image 2 produced six hybrid enemies, CHOIR Prime, a reusable pylon, evidence node, black-lab reveal, and Continuity Cradle. Production assets total approximately 2.2 MiB before Godot import; raw sources are excluded from `game/`. Every final image passed visual alpha/silhouette review. |
| WP1 | Complete | Phase 1 | After integrating thirteen concurrent commits through source `e26b7df`, `./verify.sh` passed with 54 scripts, 326 tests, 31,075 assertions, direct boot, all headless scenarios, and a clean Project CHOIR dossier/reveal lane. The campaign store is Main-owned and retry-safe; all 25 facade IDs map bijectively to localized dossiers; one six-slot reveal pool mirrors the streamed building pool; transmissions remain bounded and nonblocking. The title briefing/codex and black-lab reveal were visually approved at 1280×720 and 720×1280. The regenerated CJK subset covers all 702 current zh-CN catalog codepoints. |
| WP2 | Complete | Phase 2 | Six GPT Image 2 hybrids now extend the existing infantry, light, air, and siege shells without increasing pool capacities: Reclaimed Breacher braces against frontal fire, marked Graft Runners coordinate with CHOIR controllers, Sirens mark targets, Entertainment containment cells release one bounded Ossuary Crawler, Seraph Carriers deploy a capacity-limited three-Runner pack, and Pale Engines carry independent ablative armor. A deterministic, non-mutating spatial resolver preserves the authored six-act deck and original threat ceilings while introducing the complete approved roster in Residential, Entertainment, Military, and Royal. Per-run first-contact transmissions are localized in English and Simplified Chinese. Focused hybrid coverage passed 6 tests / 70 assertions; after integrating the concurrent district-boss foundation, the synchronized `./verify.sh` standard gate passed 56 scripts, 346 tests, and 31,926 assertions in 647 seconds. Dedicated GPT Image 2 production galleries passed at 1280×720 and 720×1280 with six unclipped silhouettes. The regenerated CJK subset covers all 749 merged catalog codepoints. |
| WP3 | Complete | Phase 3 | The canonical Royal terminal encounter now presents the GPT Image 2 CHOIR Prime core, five visible armor-linked memory organs, and one bounded replay unit from each prior Project CHOIR threat family. A stable `FinaleEligibilitySnapshot` gates Disentangle at 20 dossiers, four district evidence records, and at most two continuity generations; Purge is always valid, and an ineligible Disentangle request resolves Ascension Failure. All outcomes persist, enter immutable run summaries, and render through the responsive terminal overlay. After integrating the certified New Game+ release and streamed five-boss campaign, Royal completion now requires both the six-act arc and the streamed CHOIR Prime gate in either order; the selected ending remains attached to extraction while cycle one can continue into New Game+. The synchronized standard gate passed 59 scripts, 365 tests, and 32,388 assertions. The dedicated finale scenario passed five-pylon, eligibility, two-latch exact-once choice, New Game+ handoff, and cleanup checks; CHOIR Prime, ending choice, and Severance were visually accepted at 1280×720 and 720×1280. |
| WP4 | Complete | Phase 3 | All 25 localized dossiers remain bijective with the 25 stable facade IDs. The title briefing presents recovered dossier count, continuity generation, persistent concise ending history, and a focus-safe 25-entry codex with encrypted lock states. English and Simplified Chinese catalogs retain exact key and placeholder parity; the deterministic CJK subset covers all 789 merged catalog codepoints. Title, codex, campaign panel, and ending archive tests pass, and final landscape/portrait renders show complete `ASH PROTOCOL · SEVERANCE` history without clipping. |
| WP5 | Pending | — | — |
| WP6 | Pending | — | — |
