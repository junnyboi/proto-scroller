# Proto Scroller

A Godot 4.7.2 city-destruction slice with a giant robot, five forward-progressing spatial districts, 25 six-cell mixed-material destructible buildings, a four-band unobstructed parallax city, destructible props, combined-arms enemies, and a WebAssembly host.

## Engine requirements

Use **Godot 4.7.2-stable** with the matching **4.7.2 non-threaded Web export templates**. The verification harness rejects other engine patch versions, and the Web preset requires both thread support and extension support to remain disabled.

## Project layout

- `game/` — Godot project, launch scene, GUT tests, injected-input scenario, verification entrypoint, and Web export preset.
- `client/` — minimal static fullscreen loader for the exported Godot canvas.
- `client/public/game/` — generated Godot WebAssembly bundle.

## Verify the Godot candidate

```bash
cd game
./verify.sh
./verify.sh --full
```

The standard gate performs a direct import, strict GDScript lint and parse-log checks, the complete GUT suite, a bounded headless boot, and deterministic title-screen, charged-smash, city-slice, directive-card, district-gallery, enemy-variety, street-volatility, and endless-terrain scenarios. The endless lane traverses all five spatial districts, records district and variant identities with a catalog SHA-256, restores prior destruction after stream recycling, and rejects post-warm node growth. The full gate adds Xvfb visual scenarios at **1280×720** and **720×1280**, produces a cache-bypassed release export through the repository's `Web` preset, and runs a required Chromium gameplay smoke. The browser lane enters gameplay, proves Web background audio is running, holds and releases a real Space input while proving first-frame freeze, charge particles, proportional damage, and animation resume; it then triggers and resolves a real upgrade offer, moves the robot beyond the mechanics-audio attenuation radius, and proves ground slam, punch, Dash, recharge, upgrade-confirm, walk-servo, and footstep cues remain active and co-located before both directional walk clips advance. A required render `SKIP`, browser phase failure, logged parse diagnostic, zero-test run, missing export artifact, oversized PCK, or nonzero process exit is blocking.

### Latest verified baseline

The full harness last passed on **2026-08-25** against revision `1c2a4a22f90691504785466d37acf8a905ef1f73` using `Godot 4.7.2.stable.official.ed1daf0bf`.

| Check | Result |
|---|---|
| Harness command | `./verify.sh --full` |
| Process result | Exit `0`; `[VERIFY-PASS] mode=full` |
| GUT suite | 50 scripts; 296 of 296 tests passed; 28,673 assertions |
| Headless scenarios | Title screen, city slice, enemy variety, street volatility, and endless terrain passed |
| Visual scenarios | Required landscape and portrait renders passed |
| Reference title render | SHA-256 `050fe68a57a1beeaa61182d3e49061899e3315bfca33bc51d0e61ad264a3417d` |
| Web release export | 9 files; HTML, JavaScript, WebAssembly, and PCK present |
| PCK size | 13,813,196 bytes, below the 16 MiB harness limit |
| Browser gameplay smoke | Both local audio worklets fulfilled; `ready → charge_started → charge_progress → charge_released → attack_started → upgrade_visible → upgrade_resolved → post_upgrade_sfx_ok → east_walk_ok → pass`; the exported punch cue reported 1.17 seconds, ground slam and punch reported the exact 25-percent-reduced 8.54365 dB playback level, and all audited SFX passed at progression distance with zero drops |
| Error scan | No script, parse, browser console, request, fatal, or crash errors |
| Duration | 615 seconds |

To run only the browser lane after producing a fresh Web export:

```bash
pnpm smoke:web
```

The smoke uses the local exported WASM/PCK bundle and system Chromium (`/usr/bin/chromium` by default, overridable with `CHROMIUM_PATH`). It writes its ordered phase report and screenshot beneath `game/artifacts/browser/`. GitHub Actions runs the complete full gate for pull requests, pushes to `main`, and manual dispatches.

In the headless sandbox, unavailable ALSA hardware caused Godot to fall back to its dummy audio driver. This environmental warning was non-blocking; the harness completed successfully with no gameplay or export errors.

## Spatial districts and destructible buildings

Forward logical-chunk progress selects geography independently of the six-act siege encounter model. Business remains active west of origin and through chunk 7; Residential occupies chunks 8–15, Entertainment 16–23, Military 24–31, and Royal begins at chunk 32 and continues indefinitely. Crossing a boundary changes the streamed facade family and road accent, emits typed district metadata, and presents a responsive transition banner below persistent HUD instrumentation.

| District | Forward chunks | Destructible building roster |
|---|---:|---|
| **Business — The Ledger Spine** | ≤ 7 | Mercy Exchange Annex; Helix Clearinghouse Spine; Orison Custody Vault; Vanta Compliance Tribunal; Crown Reserve Data Treasury |
| **Residential — Ashwater Commons** | 8–15 | Emberpot Canteen House; Bluewire Laundry Walkup; Rainvault Cooperative; Sixfold Balcony Court; Nightglass Mutual Clinic |
| **Entertainment — The Afterglow Strip** | 16–23 | Voltage Chapel; Orpheum Vanta; Halcyon Stack Hotel; Prism Crown Revue; House of Static Casino Hotel |
| **Military — The Iron Corridor** | 24–31 | Ordnance Transload Bastion; Revetment Armory Stack; Aegis Signal Citadel; Manticore Siege-Repair Gantry; Prefect War Keep |
| **Royal — The Crownward** | ≥ 32 | Laureate Processional Gate; Aurelian Menagerie Conservatory; Tribunal of Nine Seals; Ministry of Privilege Spire; Palace of the Last Sovereign |

All 25 buildings reuse the fixed six-building resident pool and the established three-column by two-row destruction topology. Variant changes reconfigure facade atlas regions, dimensions, material resistance, deterministic crack seeds, pipes, cables, hollow edges, and rubble geometry in place before mutation restore. The complete visual briefs and GPT Image 2 concept boards are documented in [`docs/DISTRICT_DESTRUCTION_DESIGN.md`](docs/DISTRICT_DESTRUCTION_DESIGN.md); phased architecture, risk controls, and measured gates are recorded in [`docs/DISTRICT_DESTRUCTION_IMPLEMENTATION_PLAN.md`](docs/DISTRICT_DESTRUCTION_IMPLEMENTATION_PLAN.md).

## Run the web host

```bash
pnpm install
pnpm dev
```

Open the reported URL and activate `INITIALIZE` when the title appears. The Web host contains only the Godot canvas: it scales to the largest undistorted 16:9 area available in the browser, centers any unavoidable letterboxing, and never scrolls. Desktop controls use **A/D** to move, **Space** to smash, and **Shift** to dash in the held direction or current facing. Standard gamepads use the **left stick or D-pad** to move, **A/Cross** to smash, and **B/Circle** to dodge in the held direction (or the robot's current facing when the stick is neutral); title-screen buttons use Godot's native gamepad focus navigation. Tapping smash attacks at normal power. Holding smash freezes the robot on the first frame of the selected melee animation while golden energy converges for up to two seconds; releasing resumes the clip and commits damage. Charge grows linearly from 100 percent to 200 percent actor and structural damage, then remains capped until release. The jab-cross cue aligns its two impacts to animation frames **11** and **14**, an exact 250 ms one-two at 12 FPS. Ground-slam and jab-cross impact playback is attenuated by exactly 25 percent from the previous mix. Every successful dash plays a distinct 1.7-second warp-drive ignition, fold, displacement, and suction cue. Pressing smash during a dodge cancels it immediately into a jab-cross in the dodge direction at 50 percent momentum and output, which can then be charged to twice that canceled attack's damage. The spent dodge cooldown remains active, and dodge invulnerability ends as soon as charging begins. The Settings panel can persistently remap every keyboard key and gamepad button, swaps conflicting bindings instead of duplicating them, restores defaults on demand, and can disable strength-scaled controller vibration without disabling mobile haptics. On touch-capable mobile devices, press and hold anywhere outside the action controls to summon a neutral-gray floating joystick, drag horizontally for analog movement, hold or tap the persistent bottom-right **SMASH** button, and use the smaller **DASH** button stacked above it. The Dash control dims during cooldown, then flashes through a compact cyan completion burst before settling into a restrained ready pulse. Each control owns its touch independently, so movement, dashing, direction reversals, charged attacks, repeated attacks, and arbitrary release order remain responsive. Devices that expose vibration receive a short pulse when a smash executes and a firmer pulse as each structural bay fails. Smash impulse is mass-scaled at 1,020 units per mass—exactly 50 percent above the previous value—without charge amplification. When a live enemy is airborne, each smash also throws three pooled masonry chunks on ballistic intercept paths; physical contact deals up to 12 light damage. The first stomp destroys the nearby car; advance into the building to break its three lower bays in sequence. The upper row remains bridged while any lower support survives, then collapses into rubble after the final support fails.

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
