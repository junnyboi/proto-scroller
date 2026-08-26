# Weapon Shop Completion and New Game+ Implementation Plan

**Author:** Manus AI
**Status:** Implemented, fully verified, and release-ready
**Canonical repository:** `https://github.com/junnyboi/proto-scroller`
**Engine:** Godot 4.7.2-stable with matching non-threaded Web templates

## 1. Objective

This work completes the accepted weapon-shop design as a deterministic campaign interstitial rather than a geography-triggered convenience screen. Each thematic shop will open immediately after its corresponding campaign act is defeated, explain the Rampage Score economy on first contact, expose exact before-and-after statistics, require an explicit purchase confirmation, and deliver differentiated audiovisual feedback for module acquisition versus chassis repair.

The Royal checkout becomes the gateway to **New Game+**. Continuing from that checkout preserves the player’s current Rampage Score, level-up modules, weapon-shop modules, and chassis state; returns the world stream and campaign director to Business/Act 1; and applies an exact **2× maximum-health and 2× outgoing-damage multiplier to every enemy unit**, including base enemies, procedural archetypes, elite variants, and the final command unit. New Game+ is limited to the existing second-cycle contract, so the multiplier is not compounded beyond 2×.

## 2. Campaign-to-shop sequence

The six authored acts do not map one-to-one to five districts. Royal is therefore treated as a two-act climax: Retaliation is the approach and Command Test plus its command-unit encounter is the Royal defeat condition.

| Campaign completion | Destination shop | Presentation order | Continue result |
|---|---|---|---|
| Act 1 — Contact | Business: Black Ledger Exchange | Intro dialogue → shop → Act 2 | Continue the first run |
| Act 2 — Containment | Residential: Ashwater Mutual Garage | Intro dialogue → shop → Act 3 | Continue the first run |
| Act 3 — Escalation | Entertainment: Afterglow Mod Parlor | Intro dialogue → shop → Act 4 | Continue the first run |
| Act 4 — Command Response | Military: Iron Corridor Field Armory | Intro dialogue → shop → Act 5 | Continue the first run |
| Act 5 — Retaliation | No shop | Recovery → Act 6 | Preserve dramatic escalation |
| Act 6 + command-unit defeat | Royal: Crownward Reliquary | Intro dialogue → shop → New Game+ or extract | Continue to NG+ or finish the run |

The old spatial-boundary shop trigger will be removed. Crossing district scenery boundaries will continue to update facades, pressure profiles, directives, and banners without opening commerce. The act director will emit an explicit completion event before advancing, and the shop session will own a pause lease until checkout. Non-Royal checkout resumes the next act. Royal checkout hands control to the terminal New Game+ choice.

## 3. Player experience

### 3.1 Introductory dialogue

Every shop opens with a short, skippable operator transmission. The first Business transmission contains the complete economic explanation: **Rampage Credit is the player’s actual score; every purchase permanently lowers the run total; repairs spend the same score; unspent credit remains on the leaderboard**. Later district transmissions reinforce the tradeoff in one sentence and establish each vendor’s identity.

Dialogue uses a generated district operator portrait, speaker name, two localized lines, a short continue action, and the same pause lease as the shop. It must be navigable by mouse, touch, keyboard, and controller. Dialogue is shown once per shop per cycle and never stacks with directives, upgrades, terminal choices, or telegraphs.

### 3.2 Stat preview

Focus, pointer hover, or touch selection updates a persistent preview panel. The panel uses a lightweight translucent `StyleBoxFlat` rather than generated frame artwork. It displays each localized statistic label on its own line with the current and resulting values directly beneath it. Repair products show current integrity versus repaired integrity. Compound modifiers display the actual cumulative result rather than merely echoing the product percentage.

| Effect family | Before/after source |
|---|---|
| Repair / Aegis | Robot current and maximum integrity; incoming-damage multiplier where applicable |
| Damage modules | Weapon-shop runtime’s cumulative damage multipliers |
| Cooldown modules | Weapon-shop runtime’s cumulative cooldown multiplier and representative percentage reduction |
| Melee radius | Current and resulting radius multiplier |
| Critical chance | Current and resulting deterministic critical chance |
| Debris damage | Current and resulting bonus impact damage |
| Structural / elite specialization | Current and resulting specialized multiplier |

Unavailable cards remain focusable for preview but cannot open confirmation. This prevents inaccessible information when the player is short on score or already owns the product.

### 3.3 Confirmation prompt

Selecting an available card opens an input-blocking confirmation modal above the shop. The prompt contains product name, price, current Rampage Credit, post-purchase Rampage Credit, the same before/after statistic, and explicit **Confirm Purchase** and **Cancel** actions. The default focus is Cancel to prevent accidental score destruction; pointer and touch retain direct access to both actions. The shop cannot close while confirmation is active.

### 3.4 Successful transaction feedback

A successful upgrade emits a cyan-gold circuitry burst centered on the purchased card, flashes the preview value, plays the distinct upgrade-purchase cue, updates the score, and marks the card sold. A successful repair emits a mint-white nanoweld burst, briefly sweeps a repair glow through the integrity value, plays the distinct repair cue, and displays the exact restored integrity. No redundant transaction-status banner is shown beneath the products, and the stat preview contains no availability/confirmation status line; card state, credit total, preview values, the explicit confirmation panel, audio, and particles provide the confirmation. Failed transactions do not emit success effects or consume score.

## 4. New Game+ architecture

A new run-cycle difficulty runtime will be the single source of truth for cycle scaling. `cycle_count == 1` yields 1× health and damage; `cycle_count == 2` yields 2× health and damage. Encounter acquisition applies the multiplier after base archetype, role, trait, and boss configuration so every final maximum-health value is doubled exactly once. Projectile, contact, lance, aura, trait-death, and boss damage use a shared outgoing-damage multiplier so no hostile damage path escapes scaling.

The New Game+ transition will release active enemies, projectiles, telegraphs, hazards, catalysts, and boss state; clear queued interstitials; return the robot and floating origin to the opening Business position; refresh streamed geometry; reset act progress to Contact; increment the existing cycle count to two; and resume input only after the reset is complete. It will preserve Rampage Score, player health, level-up ranks, shop purchases/effects, experience, and current arsenal state. A compact generated New Game+ insignia and localized `CYCLE 2 · THREAT ×2` banner communicate the new state.

## 5. Asset production

All new static UI artwork will be generated with **GPT Image 2** and then deterministically resized, converted, and compressed for Godot/Web use. No new runtime UI art will be procedurally drawn. Text remains localized Godot UI so English and Simplified Chinese remain exact.

| Asset set | Quantity | Runtime use | Target format/budget |
|---|---:|---|---|
| District shop backplates | 5 | Full-shop background behind responsive controls | WebP/JPEG, 1280×720, ≤150 KB each |
| District operator portraits | 5 | Intro transmission panel | WebP, 512×512, ≤70 KB each |
| Product icons | 15 | One unique icon per catalog product | Transparent WebP, 256×256, ≤25 KB each |
| Confirmation frame | 1 | Confirmation modal decoration | Transparent WebP, ≤80 KB |
| Stat preview container | 1 | Before/after panel decoration | Runtime `StyleBoxFlat`; no texture payload |
| Rampage Credit sigil | 1 | Economy explanation and price emphasis | Transparent WebP, ≤30 KB |
| Upgrade success burst | 1 | Transaction particle texture | Transparent WebP/PNG, ≤40 KB |
| Repair success burst | 1 | Repair particle texture | Transparent WebP/PNG, ≤40 KB |
| New Game+ insignia | 1 | Royal checkout and cycle-start banner | Transparent WebP, ≤50 KB |

The asset budget is **≤1.5 MiB added to the release PCK**, preserving margin under the repository’s 16 MiB hard limit. Generated source masters and prompt provenance remain in `docs/concepts/weapon-shops/final-assets/`; optimized runtime derivatives live under `game/art/ui/weapon_shop/`.

## 6. Audio production

The project-required Mirelo-style carrier workflow will produce two cues. Each cue begins with a GPT Image 2 anchor, then a short image-conditioned video with synchronized sound, followed by audio extraction, deterministic trimming, PCM16 conversion, peak limiting, loudness analysis, and provenance recording.

| Cue | Sound brief | Runtime target |
|---|---|---|
| Upgrade purchase | Heavy secure mechanical latch, energized capacitor lock, ascending digital confirmation, short metallic resonance; powerful but not explosive | 0.65–1.15 s, 48 kHz mono PCM16, UI bus |
| Chassis repair | Industrial nanoweld sweep, servo clamps, dense electrical knitting, pressure-seal completion; restorative rather than delicate | 0.85–1.40 s, 48 kHz mono PCM16, UI bus |

Both cues must remain audible under ducked music, stay below clipping, and pass Godot import and Web playback checks.

## 7. Work packages

| Phase | Implementation scope | Regression gate | Delivery gate |
|---|---|---|---|
| 1. Plan and asset foundation | Final plan, GPT Image 2 UI/FX masters, optimized runtime derivatives, carrier-derived audio, provenance, PCK-budget check | Asset dimensions/alpha/hash checks; audio format/loudness checks; Godot import | Commit and push asset foundation |
| 2. Act interstitial architecture | Director act-completion pause, act-to-shop mapping, removal of spatial shop trigger, dialogue sequence, serialized resume | Focused director, shop, pause, district-stream, localization, and transition tests | Commit and push campaign flow |
| 3. Transaction UX | Generated backplates/icons/portraits, stat preview model, confirmation modal, score projection, purchase/repair audio, particle success effects | Focused shop UI, keyboard/controller/touch, transaction atomicity, responsive visual scenarios | Commit and push transaction UX |
| 4. New Game+ | Royal checkout choice, score/power preservation, world reset, exact enemy 2× health/damage scaling, NG+ banner | Focused cycle, every-enemy scaling, score preservation, boss, world-stream reset, and runtime-budget tests | Commit and push New Game+ |
| 5. Release | Documentation reconciliation, complete regression suite, direct import/boot, Xvfb landscape/portrait review, Web export, HTTP/browser/network/runtime checks | `./verify.sh --full`, `pnpm check`, `pnpm build`, exact payload sizes and checksums | Push final candidate; synchronize and checkpoint WebDev; publish when available |

### Phase record

**Phase 1 — Plan and asset foundation: complete.** GPT Image 2 produced 21 static UI/FX masters, two SFX carrier anchors, and five district-specific sets covering all fifteen products. The deterministic runtime pipeline generated 31 WebP files totaling 1,211,952 bytes. The synchronized carrier workflow produced separate 48 kHz mono PCM16 purchase and repair cues with verified durations, peaks, hashes, waveforms, and provenance.

**Phase 2 — Interstitial architecture and dialogue: complete.** Shops now open at deterministic act-completion boundaries rather than spatial district crossings: Business after Act 1, Residential after Act 2, Entertainment after Act 3, Military after Act 4, and Royal only after the terminal boss. The next act is held until checkout, milestone/directive presentation waits behind the shop, spatial district banners remain independent, score banking occurs on entry, and a generated-portrait operator dialogue explains the Rampage Score tradeoff before product interaction. Royal checkout now precedes terminal cycle choices.

**Phase 3 — Transaction clarity and feedback: complete.** Hover, mouse entry, and controller focus now populate a simple styled before/after stat panel with exact live values split into label and value lines. Every available product opens a purchase confirmation prompt showing the selected module, projected score deduction, and stat delta; canceling preserves score and state. Successful purchases and repairs use distinct carrier-derived PCM16 cues on the fixed UI voice pool and separate generated-texture particle bursts without runtime node growth or a redundant footer banner.

**Phase 4 — Royal checkout and New Game+: complete.** Closing the Royal shop now opens an explicit generated-insignia New Game+ choice. Continuing banks and preserves the current Rampage Score, player health, level-up ranks, shop upgrades, and directive path; clears transient combo/telegraph/projectile/remains state; restores the destructible city, parallax, camera, robot, and stream to Business/Act 1; and reuses the same bounded pools. Every pooled base, procedural, elite, reinforcement, and command-boss unit receives exactly `2.0×` maximum health and `2.0×` outgoing attack damage in cycle two, applied centrally and exactly once.

**Phase 5 — Release verification and packaging: complete.** The final candidate includes the concurrent Project CHOIR boss and hybrid-enemy foundations plus unified title/defeat transitions, and passed `./verify.sh --full` under Godot `4.7.2.stable.official.ed1daf0bf`: **56 scripts, 348/348 tests, 32,078 assertions**, all required headless and Xvfb scenarios, nine-file Web export, and Chromium gameplay/defeat smoke. Certified lossy runtime imports for GPT Image 2 shop, boss, district, narrative, finale, and parallax art reduced the final PCK to **11,186,848 bytes**, leaving **5,590,368 bytes** below the fixed 16 MiB gate without changing source masters. Landscape and portrait shop confirmation plus New Game+ terminal renders passed visual inspection with no clipping, missing textures, alpha defects, or compression artifacts.

**Phase 6 — Fourfold price rebalance: complete.** Every one of the fifteen catalog prices is exactly four times its launch value, from the 9,600-point Collateral Refinance service through the 54,000-point Crownfire Protocol capstone. Exact-price regression coverage prevents partial or accidental drift, and the Entertainment visual fixture now carries enough score to exercise a real 24,800-point confirmation. After integrating the concurrent boss-evidence persistence and robot-presentation releases, the definitive Godot 4.7.2 full gate passed in **931 seconds** with **62 scripts, 383/383 tests, and 32,629 assertions**. All headless and landscape/portrait scenarios, the nine-file Web export, and Chromium gameplay smoke passed; the PCK measured **11,288,256 bytes**, leaving **5,488,960 bytes** below the 16 MiB limit. The updated five-digit prices and projected deductions remain legible in both shop orientations with no clipping or overlap regressions.

## 8. Acceptance criteria

The feature is complete only when all five shops open at the specified act completion points; each introductory dialogue appears before its shop; no shop opens from spatial backtracking; all fifteen products remain exclusive from level-up offers; every catalog price equals exactly four times its launch value; every available purchase requires confirmation; every preview reports exact cumulative before/after values; repair and module purchases play distinct generated cues and distinct generated success bursts; score deductions remain atomic and visible; and Royal checkout offers New Game+ while preserving score and player power.

In New Game+, every base, procedural, elite, and boss unit must spawn with exactly twice its final cycle-one health and deal exactly twice its cycle-one outgoing damage without compounding role, trait, aura, or boss multipliers incorrectly. The world must restart in Business at Act 1 with clean enemies, projectiles, telegraphs, hazards, and interstitials. The full release must stay below the Web PCK cap, render correctly at 1280×720 and 720×1280, load over HTTP/HTTPS with correct WASM/PCK responses, accept representative gameplay and shop input, and produce no script, resource, network, browser-console, fatal, or crash errors.
