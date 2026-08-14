# Proto Scroller

A Godot 4.7.1 scaffold with a cinematic launch title screen, exported as a WebAssembly game and embedded in a Manus WebDev host.

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

The full gate runs import, GDScript lint/parse checks, two GUT tests, headless boot, injected-input scenario, fresh 1280×720 render capture, and a cache-bypassed Web export. A required render SKIP or zero-test run is blocking.

## Run the web host

```bash
pnpm install
pnpm dev
```

Open the reported URL, wait for `WEB RUNTIME ONLINE`, then activate `INITIALIZE` inside the canvas. The expected terminal title-screen state is `SYSTEM READY / ONLINE / READY`.

## Production build

```bash
pnpm check
pnpm build
pnpm start
```
