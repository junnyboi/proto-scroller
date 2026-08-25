# Proto Scroller

A Godot 4.7.2 city-destruction slice with a giant robot, four-band unobstructed parallax city, a six-cell mixed-material structural building, destructible props, combined-arms enemies, and a WebAssembly host.

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

The standard gate performs a direct import, GDScript lint and parse checks, the complete GUT suite, a bounded headless boot, and deterministic title-screen, city-slice, enemy-variety, street-volatility, and endless-terrain scenarios. The full gate adds Xvfb visual scenarios at **1280×720** and **720×1280**, then produces a cache-bypassed release export through the repository's `Web` preset. A required render `SKIP`, zero-test run, missing export artifact, oversized PCK, or nonzero process exit is blocking.

### Latest verified baseline

The full harness last passed on **2026-08-25** against gameplay revision `d7b016159f54606119b085e1da8e74d83e03ba1e` using `Godot 4.7.2.stable.official.ed1daf0bf`.

| Check | Result |
|---|---|
| Harness command | `./verify.sh --full` |
| Process result | Exit `0`; `[VERIFY-PASS] mode=full` |
| GUT suite | 47 scripts; 258 of 258 tests passed; 26,740 assertions |
| Headless scenarios | Title screen, city slice, enemy variety, street volatility, and endless terrain passed |
| Visual scenarios | Required landscape and portrait renders passed |
| Reference title render | SHA-256 `3e3ff3478dab903541c1b41c90017a2136c5431e16cec5b0c5f16fc25e2f58f3` |
| Web release export | 9 files; HTML, JavaScript, WebAssembly, and PCK present |
| PCK size | 8,367,156 bytes, below the 8 MiB harness limit |
| Error scan | No script, parse, fatal, or crash errors |
| Duration | 518 seconds |

In the headless sandbox, unavailable ALSA hardware caused Godot to fall back to its dummy audio driver. This environmental warning was non-blocking; the harness completed successfully with no gameplay or export errors.

## Run the web host

```bash
pnpm install
pnpm dev
```

Open the reported URL and activate `INITIALIZE` when the title appears. The Web host contains only the Godot canvas: it scales to the largest undistorted 16:9 area available in the browser, centers any unavoidable letterboxing, and never scrolls. Desktop controls use **A/D** to move and **Space** to stomp. Standard gamepads use the **left stick or D-pad** to move, **A/Cross** to smash, and **B/Circle** to dodge in the held direction (or the robot's current facing when the stick is neutral); title-screen buttons use Godot's native gamepad focus navigation. The Settings panel can persistently remap every keyboard key and gamepad button, swaps conflicting bindings instead of duplicating them, restores defaults on demand, and can disable strength-scaled controller vibration without disabling mobile haptics. On touch-capable mobile devices, press and hold anywhere outside the smash control to summon a neutral-gray floating joystick, drag horizontally for analog movement, and use the persistent bottom-right **SMASH** button with a second thumb. Each control owns its touch independently, so movement, direction reversals, repeated attacks, and arbitrary release order remain responsive. Devices that expose vibration receive a short pulse when a smash executes and a firmer pulse as each structural bay fails. Smash impulse is mass-scaled at 1,020 units per mass—exactly 50 percent above the previous value—without increasing direct attack damage. When a live enemy is airborne, each smash also throws three pooled masonry chunks on ballistic intercept paths; physical contact deals up to 12 light damage. The first stomp destroys the nearby car; advance into the building to break its three lower bays in sequence. The upper row remains bridged while any lower support survives, then collapses into rubble after the final support fails.

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
