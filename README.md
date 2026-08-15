# Proto Scroller

A Godot 4.7.1 city-destruction slice with a giant robot, five-layer parallax city, destructible props and building, combined-arms enemies, and a WebAssembly host.

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

The full gate runs import, GDScript lint/parse checks, seven GUT tests, headless boot, deterministic movement/turn/destruction scenarios, fresh 1280×720 launch and destruction renders, and a cache-bypassed Web export. A required render SKIP or zero-test run is blocking.

## Run the web host

```bash
pnpm install
pnpm dev
```

Open the reported URL, wait for `WEB RUNTIME ONLINE`, then activate `INITIALIZE` inside the canvas. Use **A/D** to move and **Space** to stomp. The first stomp destroys the nearby car; advance to reach the streetlamp, building, soldiers, tank, and helicopter.

## Production build

```bash
pnpm check
pnpm build
pnpm start
```
