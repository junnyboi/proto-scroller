# Proto Scroller

A Godot 4.7.2 city-destruction slice with a giant robot, five forward-progressing spatial districts, score-funded district weapon shops, 25 six-cell mixed-material destructible buildings, a four-band unobstructed parallax city, destructible props, combined-arms enemies, and a WebAssembly host.

## Engine requirements

Use **Godot 4.7.2-stable** with the matching **4.7.2 non-threaded Web export templates**. The verification harness rejects other engine patch versions, and the Web preset requires both thread support and extension support to remain disabled.

## Project layout

- `game/` — Godot project, launch scene, GUT tests, injected-input scenario, verification entrypoint, and Web export preset.
- `client/` — minimal static fullscreen loader for the exported Godot canvas.
- `client/public/game/` — generated Godot WebAssembly bundle.
- `client/public/title-video/` — silent orientation-specific title loops, static fallbacks, and generation provenance.

## Verify the Godot candidate

```bash
cd game
./verify.sh
./verify.sh --full
```

The standard gate performs a direct import, strict GDScript lint and parse-log checks, the complete GUT suite, a bounded headless boot, and deterministic title-screen, charged-smash, city-slice, directive-card, district-gallery, enemy-variety, street-volatility, and endless-terrain scenarios. The endless lane traverses all five spatial districts, records district and variant identities with a catalog SHA-256, restores prior destruction after stream recycling, and rejects post-warm node growth. The full gate adds Xvfb visual scenarios at **1280×720** and **720×1280**, including a dedicated responsive weapon-shop interstitial, produces a cache-bypassed release export through the repository's `Web` preset, and runs a required Chromium gameplay smoke. The browser lane proves both silent eight-second title loops decode, advance, select the correct orientation, and transition through an input-blocking fade to full black before gameplay is revealed; it then enters gameplay, proves Web background audio is running, holds and releases a real Space input while proving first-frame freeze, charge particles, proportional damage, and animation resume. It triggers and resolves a real upgrade offer, moves the robot beyond the mechanics-audio attenuation radius, and proves ground slam, punch, Dash, recharge, upgrade-confirm, walk-servo, and footstep cues remain active and co-located before both directional walk clips advance. A required render `SKIP`, browser phase failure, logged parse diagnostic, zero-test run, missing export artifact, oversized PCK, or nonzero process exit is blocking.

### Latest verified baseline

The full harness passed on **2026-08-26** against weapon-shop gameplay revision `3ff79b03d035541a084afa3551609e01d5aeb001` using `Godot 4.7.2.stable.official.ed1daf0bf`.

| Check | Result |
|---|---|
| Harness command | `./verify.sh --full` |
| Process result | Exit `0`; `[VERIFY-PASS] mode=full` |
| GUT suite | 53 scripts; 319 of 319 tests passed; 30,359 assertions |
| Headless scenarios | Title screen, city slice, charged smash, directives, district gallery, enemy variety, street volatility, and endless terrain passed |
| Visual scenarios | Required landscape and portrait renders passed, including the responsive three-product weapon shop |
| Reference title render | SHA-256 `92775e50df36c046d6c81347c2d672450c38d62167e1b48d723172067f34d590` |
| Web release export | 9 generated Godot files plus two MP4 title loops and two static fallbacks; HTML, JavaScript, WebAssembly, and PCK present |
| PCK size | 14,148,788 bytes, below the 16 MiB harness limit |
| Browser gameplay smoke | Landscape 1280×720 and portrait 720×1280 title loops decoded, advanced, and selected correctly; `idle → fade_out → black → black_ready → fade_in → complete` passed, the held 1280×720 transition frame was fully black, and the landscape video paused before gameplay appeared. Both local audio worklets fulfilled; `ready → charge_started → charge_progress → charge_released → attack_started → upgrade_visible → upgrade_resolved → post_upgrade_sfx_ok → east_walk_ok → pass`; the exported punch cue reported 1.17 seconds, ground slam and punch reported the exact 25-percent-reduced 8.54365 dB playback level, and all audited SFX passed at progression distance with zero drops |
| Error scan | No script, parse, browser console, request, fatal, or crash errors |
| Duration | 700 seconds |

To run only the browser lane after producing a fresh Web export:

```bash
pnpm smoke:web
```

The smoke uses the local exported WASM/PCK bundle and system Chromium (`/usr/bin/chromium` by default, overridable with `CHROMIUM_PATH`). It writes its ordered phase report and screenshot beneath `game/artifacts/browser/`. GitHub Actions runs the complete full gate for pull requests, pushes to `main`, and manual dispatches.

In the headless sandbox, unavailable ALSA hardware caused Godot to fall back to its dummy audio driver. This environmental warning was non-blocking; the harness completed successfully with no gameplay or export errors.

## Spatial districts and destructible buildings

Forward logical-chunk progress selects geography independently of the six-act siege encounter model. Business remains active west of origin and through chunk 7; Residential occupies chunks 8–15, Entertainment 16–23, Military 24–31, and Royal begins at chunk 32 and continues indefinitely. Crossing a forward boundary changes the streamed facade family and road accent, opens the destination weapon shop exactly once, and presents the responsive transition banner after the player continues. Backtracking changes geography without reopening a shop.

| District | Forward chunks | Destructible building roster |
|---|---:|---|
| **Business — The Ledger Spine** | ≤ 7 | Mercy Exchange Annex; Helix Clearinghouse Spine; Orison Custody Vault; Vanta Compliance Tribunal; Crown Reserve Data Treasury |
| **Residential — Ashwater Commons** | 8–15 | Emberpot Canteen House; Bluewire Laundry Walkup; Rainvault Cooperative; Sixfold Balcony Court; Nightglass Mutual Clinic |
| **Entertainment — The Afterglow Strip** | 16–23 | Voltage Chapel; Orpheum Vanta; Halcyon Stack Hotel; Prism Crown Revue; House of Static Casino Hotel |
| **Military — The Iron Corridor** | 24–31 | Ordnance Transload Bastion; Revetment Armory Stack; Aegis Signal Citadel; Manticore Siege-Repair Gantry; Prefect War Keep |
| **Royal — The Crownward** | ≥ 32 | Laureate Processional Gate; Aurelian Menagerie Conservatory; Tribunal of Nine Seals; Ministry of Privilege Spire; Palace of the Last Sovereign |

All 25 buildings reuse the fixed six-building resident pool and the established three-column by two-row destruction topology. Variant changes reconfigure facade atlas regions, dimensions, material resistance, deterministic crack seeds, pipes, cables, hollow edges, and rubble geometry in place before mutation restore. The complete visual briefs and GPT Image 2 concept boards are documented in [`docs/DISTRICT_DESTRUCTION_DESIGN.md`](docs/DISTRICT_DESTRUCTION_DESIGN.md); phased architecture, risk controls, and measured gates are recorded in [`docs/DISTRICT_DESTRUCTION_IMPLEMENTATION_PLAN.md`](docs/DISTRICT_DESTRUCTION_IMPLEMENTATION_PLAN.md).

Each spatial district owns a validated pool of three unique missions. Mission selection is deterministic for the run seed, cycle, and district; crossing a district boundary withdraws the old objective without a score penalty and offers the destination pool once per cycle. Active mission cards expose the authoritative pause-aware countdown, timer bar, objective count, objective progress bar, instruction, and pending score in both viewport orientations. Combat pressure also follows the spatial district through five readiness-gated profiles: enemy-copy allowance, absolute live threat, cadence, recovery, elite chance, and hazard pressure rise monotonically from Business through Royal while retaining fixed pool and runtime caps. Full mission, telemetry, and balance specifications plus measured verification evidence are recorded in [`docs/DISTRICT_MISSIONS_AND_BALANCE_PLAN.md`](docs/DISTRICT_MISSIONS_AND_BALANCE_PLAN.md).

Each district weapon shop offers exactly three run-local modules that never appear in level-up choices. The shop banks pending score, displays the current total as **Rampage Credit**, and deducts purchases directly from the final high score. Products include repairs, melee hit-area expansion, weapon damage and cooldown modifiers, deterministic criticals, elite and structural specialization, and Royal capstones. Combat, directives, and queued level-up choices remain serialized behind the same pause coordinator. The full economy, product catalog, responsive UI specification, and five GPT Image 2 concept boards are documented in [`docs/WEAPON_SHOP_SYSTEM_PROPOSAL.md`](docs/WEAPON_SHOP_SYSTEM_PROPOSAL.md).
The proposed narrative campaign, **Project CHOIR**, connects the five districts, twenty-five facades, retries, directives, and enemy escalation to a human bio-weapons conspiracy. Its canonical storyline and GPT Image 2 laboratory, enemy, carrier, and final-boss concepts are documented in [`docs/PROJECT_CHOIR_STORY_PROPOSAL.md`](docs/PROJECT_CHOIR_STORY_PROPOSAL.md). The canon-aligned five-boss roster, regenerated concept plates, and three-outcome Royal finale are specified in [`docs/DISTRICT_BOSS_ENCOUNTER_PROPOSAL.md`](docs/DISTRICT_BOSS_ENCOUNTER_PROPOSAL.md); its phased runtime, persistence, verification, packaging, and WebDev release work is defined in [`docs/DISTRICT_BOSS_IMPLEMENTATION_PLAN.md`](docs/DISTRICT_BOSS_IMPLEMENTATION_PLAN.md).

## Run the web host

```bash
pnpm install
pnpm dev
```

Open the reported URL and activate **Begin Expedition** when the title appears. The hook is explicitly rendered as **“An evil organisation killed everyone you love...”** followed by **“it's payback time!”** on the next line. The obsolete **ENTER / A / TAP** helper is removed, and the launch action retains extra bottom spacing before language selection. On Web, silent orientation-specific cinematic loops animate the robot through **idle → ground smash → idle** behind the transparent Godot title UI; the original static art remains the immediate preload and decoder-failure fallback. Starting an expedition applies a 450 ms ease-in fade to black, swaps into the city while fully covered, then reveals gameplay with a 350 ms ease-out fade; the input-blocking overlay prevents duplicate launches throughout the transition. The video pauses and disappears while the screen is black. The Web host contains only the game viewport and never scrolls. Desktop controls use **A/D** to move, **Space** to smash, and **Shift** to dash in the held direction or current facing. Standard gamepads use the **left stick or D-pad** to move, **A/Cross** to smash, and **B/Circle** to dodge in the held direction (or the robot's current facing when the stick is neutral); title-screen buttons use Godot's native gamepad focus navigation. Tapping smash attacks at normal power. Holding smash freezes the robot on the first frame of the selected melee animation while golden photon spheres accelerate inward from a wide radius and concentrate into a growing chest-core sphere for up to two seconds. A generated cream-and-charcoal meter above the robot tracks the same normalized progress, and a dedicated charging cue follows the buildup. Charge grows linearly from 100 percent to 200 percent actor and structural damage, then remains capped until release; reaching the cap stops incoming motes, pulses the full meter and core, and announces **“Fully charged!”** exactly once. Releasing resumes the clip and commits damage. When a fully charged attack actually damages at least one enemy, it produces a distinctive gold impact flash and signature lock accent plus a bounded 110 ms hit-stop, stronger camera kick, and haptic pulse; whiffs and structure-only impacts do not trigger the cue. The jab-cross cue aligns its impacts to animation frames **11** and **14**, an exact 250 ms one-two at 12 FPS. Ground-slam and jab-cross impact playback is attenuated by exactly 25 percent from the previous mix. Every successful dash plays a distinct 1.7-second warp-drive ignition, fold, displacement, and suction cue. Pressing smash during a dodge cancels it immediately into a jab-cross in the dodge direction at 50 percent momentum and output, which can then be charged to twice that canceled attack's damage. The spent dodge cooldown remains active, and dodge invulnerability ends as soon as charging begins. The Settings panel can persistently remap every keyboard key and gamepad button, swaps conflicting bindings instead of duplicating them, restores defaults on demand, and can disable strength-scaled controller vibration without disabling mobile haptics. On touch-capable mobile devices, press and hold anywhere outside the action controls to summon a neutral-gray floating joystick, drag horizontally for analog movement, hold or tap the persistent bottom-right **SMASH** button, and use the smaller **DASH** button stacked above it. The Dash control dims during cooldown, then flashes through a compact cyan completion burst before settling into a restrained ready pulse. Each control owns its touch independently, so movement, dashing, direction reversals, charged attacks, repeated attacks, and arbitrary release order remain responsive. Devices that expose vibration receive a short pulse when a smash executes and a firmer pulse as each structural bay fails. Smash impulse is mass-scaled at 1,020 units per mass—exactly 50 percent above the previous value—without charge amplification. When a live enemy is airborne, each smash also throws three pooled masonry chunks on ballistic intercept paths; physical contact deals up to 12 light damage. The first stomp destroys the nearby car; advance into the building to break its three lower bays in sequence. The upper row remains bridged while any lower support survives, then collapses into rubble after the final support fails. The robot artwork is calibrated to remain 15–16 rendered pixels above the cyan road line; collision and ground-impact geometry stay unchanged.

Ground-smash actor and structural damage are doubled at the attack resolver before charge, directive, and upgrade multipliers. The default tap therefore commits 360 damage and a full two-second charge commits 720 damage while preserving the established radius and mass-scaled impulse. Act 5 Retaliation scales every pressure, recovery, and act-duration trigger to 75 percent of its authored baseline. If an earlier act reaches its bounded overrun with surviving pooled enemies, those stale actors are released before the next act reserves its first wave, preventing a permanent empty Retaliation state. The HUD label **SAFE** still refers only to an empty volatile score bank; it does not suppress encounters.

The structural grid uses concrete, glass, and steel profiles. Glass fails quickly into fast cyan shards with a crystalline shatter, concrete sheds medium masonry with a deep crunch, and steel needs sustained impact before releasing slow heavy beams with a stressed-metal groan. Destroying a full floor starts a staggered upward collapse; destroying every steel cell triggers a faster building-wide support cascade. The player robot rejects self-sourced and player-team damage but remains vulnerable to enemy fire. The giant robot owns world Z 100 and therefore renders above every world-space unit, projectile, particle, prop, debris body, and facade; the HUD remains a separate CanvasLayer overlay.

Defeated soldiers transfer fatal impacts into one intact soldier sprite on a pooled RigidBody2D. The body is thrown and spun by the hit, fades quickly, and is culled back into an eight-object pool; no separated body parts remain. Building rubble is capped at 24 bodies and machinery scrap at 32, with saturated pools recycling their oldest active effect instead of allocating during combat. The street keeps its physics plane and textured foreground, but no longer draws an opaque rectangle over the lower view.

Destroyed cars, wrecks, defeated soldiers, rubble, and scrap are on nonblocking remains layers, so robot locomotion passes through without shoving them. Robot attacks still query those layers and apply mass-scaled linear and angular impulses, preserving explosive scattering without turning ordinary walking into an accidental leaf blower.

## Localization

The game ships with English (`en`) and Simplified Chinese (`zh-CN`) JSON catalogs in `game/localization/`. The landing-page selector below **Begin Expedition** switches all live title copy and briefing art immediately, then stores a manual EN or ZH-CN choice in `user://localization.cfg` for future launches. Selecting **Auto** clears that manual preference and immediately returns control to Simplified Chinese OS/browser detection, with English as the fallback for every other locale. The Auto control displays its live resolution as **AUTO · EN**, **AUTO · ZH-CN**, or the localized equivalent. A deterministic test override is available through `PROTO_SCROLLER_LOCALE=en` or `PROTO_SCROLLER_LOCALE=zh-CN` before launch.

All player-facing copy must be stored as a catalog key and rendered through named placeholders: `L10n.t("hud.health", {"current": "080", "maximum": "100"})`. Resource-authored names, descriptions, and instructions store localization keys rather than English values. Both catalogs must retain identical key sets.

## Production build

```bash
pnpm check
pnpm build
pnpm start
```
