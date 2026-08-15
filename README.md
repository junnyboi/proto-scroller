# Proto Scroller

A Godot 4.7.1 city-destruction slice with a giant robot, five-layer parallax city, a six-cell mixed-material structural building, destructible props, combined-arms enemies, and a WebAssembly host.

## Project layout

- `game/` — Godot project, launch scene, GUT tests, injected-input scenario, verification entrypoint, and Web export preset.
- `client/` — React host for the exported Godot canvas.
- `client/public/game/` — generated Godot WebAssembly bundle.

## Verify the Godot candidate

```bash
cd game
./verify.sh
./verify.sh --full
```

The full gate runs import, GDScript lint/parse checks, all GUT suites, headless boot, deterministic movement/turn/destruction scenarios, fresh 1280×720 launch and destruction renders, and a cache-bypassed Web export. A required render SKIP or zero-test run is blocking.

## Run the web host

```bash
pnpm install
pnpm dev
```

Open the reported URL, wait for `WEB RUNTIME ONLINE`, then activate `INITIALIZE` inside the canvas. Use **A/D** to move and **Space** to stomp. The first stomp destroys the nearby car; advance into the building to break its three lower bays in sequence. The upper row remains bridged while any lower support survives, then collapses into rubble after the final support fails.

The structural grid uses concrete, glass, and steel profiles. Glass fails quickly into fast cyan shards with a crystalline shatter, concrete sheds medium masonry with a deep crunch, and steel needs sustained impact before releasing slow heavy beams with a stressed-metal groan. Destroying a full floor starts a staggered upward collapse; destroying every steel cell triggers a faster building-wide support cascade. The player robot rejects self-sourced and player-team damage but remains vulnerable to enemy fire. The giant robot owns world Z 100 and therefore renders above every world-space unit, projectile, particle, prop, debris body, and facade; the HUD remains a separate CanvasLayer overlay.

Defeated soldiers now transfer their fatal impact into six RigidBody2D pieces constrained by five PinJoint2D joints, so they launch, tumble, and settle prone on the asphalt. Tanks and helicopters become heavy rigid wrecks first; another stomp, blast, or robot walk-over crushes the wreck into pooled steel scrap with mass-varied trajectories and additional destruction score.

## Production build

```bash
pnpm check
pnpm build
pnpm start
```
