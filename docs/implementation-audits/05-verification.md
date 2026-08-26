# Verification, Export, and Budget Impact Audit

**Audit domain:** Project CHOIR verification, Web export, deployment, and runtime/package budgets
**Inspected revision:** `9f6e1279f2a77822e066f2337a21dc1e8b59cb17`
**Contract:** [`docs/PROJECT_CHOIR_STORY_PROPOSAL.md`](../PROJECT_CHOIR_STORY_PROPOSAL.md), especially lines 193–198
**Current measured baseline:** `./verify.sh --full` artifact reports `PASS` in 691 seconds; GUT reports 50 scripts / 301 passing tests; `client/public/game/game.pck` is 14,095,736 bytes against a 16,777,216-byte cap, leaving **2,681,480 bytes (15.98%)**.

## Finding

Project CHOIR can fit the existing verification architecture **only if narrative state remains observer-driven, all presentation is pooled or reconfigured in place, and package growth is treated as a first-class release gate**. The repository already has strong deterministic seams: `CityWorldStream.district_changed`, `StreamedDestructibleRuntime.building_cell_destroyed`, `EncounterRuntime.enemy_died`, `EnemyActor2D.died`, boss signals, fixed-frame selftests, `RuntimeBudget.snapshot()`, a non-threaded Web preset, and a Playwright-backed Chromium smoke. The safest addition is a small set of focused GUT tests plus one combined CHOIR headless/visual scenario, followed by a fresh export-size assertion and a deployed-host smoke.

The present full gate is necessary but not sufficient for an end-to-end production release. It tests a fresh local export through the Vite **development** host, while `client/src/main.ts` switches production to hard-coded `/manus-storage/` engine and PCK objects. CI does not run `pnpm check`, `pnpm build`, start `server/index.ts`, upload the fresh PCK, or prove that the deployed URL serves the same PCK hash. That gap must be closed before CHOIR persistence, endings, or new media can be called released.

## Existing verification architecture

| Layer | Current implementation and blocking behavior | CHOIR integration |
|---|---|---|
| Import and static contract | `game/verify.sh` imports first, pins Godot `4.7.2`, checks GL Compatibility, 1280×720 canvas/stretch settings, non-threaded/no-extension export, `CitySlice` ≤650 lines, asset-name hygiene, and exact audio format/duration/hash constraints. | Add static checks for campaign schema/version, both localization catalogs, asset provenance, and one authoritative PCK constant (`RuntimeBudget.MAX_WEB_PCK_BYTES`) rather than a duplicated shell literal. |
| Parse/lint | Every `scripts/`, `selftest/`, and `test/` `.gd` receives `gdlint` and Godot `--check-only`; any logged `SCRIPT ERROR`, `Parse Error`, `ERROR:`, `FATAL`, or `CRASH` blocks. | New narrative scripts/tests automatically enter this lane. Do not place executable CHOIR code outside those roots. |
| GUT | CLI is `addons/gut/gut_cmdln.gd -gdir=res://test -gexit`; tests conventionally `extends GutTest`, instantiate `PackedScene`s, use `add_child_autofree`, await explicit process/physics frames, call deterministic methods, and reset singleton/persistent state in `before_each`/`after_each`. | Add catalog/state/director/runtime tests under `game/test/test_project_choir_*.gd`; avoid wall-clock waits and random global state. |
| Headless selftests | `SceneTree` scenarios have a frame watchdog, append named checks, emit JSON with `done`, `result`, engine/frame metadata, return nonzero on failure, and mark screenshots `SKIP` only under the headless display. `verify.sh` explicitly validates required JSON. | Add `selftest/project_choir_scenario.gd` to exercise district → breach → dossier/transmission → retry persistence → finale eligibility without rendering. Its report must be asserted with `jq`, not trusted only by process exit. |
| Visual scenarios | Full mode runs Xvfb at 1280×720 and 720×1280 and checks file existence/dimensions. Existing gallery and streaming scenarios prove five districts/25 facades and no post-warm growth. | Add one landscape/portrait CHOIR reveal scenario showing intact facade, breached laboratory, transmission/dossier UI, and protected-payload state. Capture deterministic state, not animation timing; add report checks and dimensions. |
| Runtime budget | `RuntimeBudget` fixes 40 pooled enemies, six street/building slots, 12 hazards, 24 structural debris, 32 scrap, four wrecks, visual/audio pools, and rejects post-warm creation. `test_runtime_budget.gd` verifies exact snapshot shape, saturation recycling, and three clean retries. | Count `NarrativeDirector`, campaign session/store, transmission slots, black-lab reveal slots, dossier/payload markers, and any CHOIR-specific VFX/audio voices. Standard enemies must occupy existing family capacities (`PROCEDURAL_INFANTRY/LIGHT/HEAVY/AIR/SIEGE`), not enlarge `enemy_total`. |
| Web export | Preset `Web` exports all resources except tests/selftests/GUT/artifact and several broad art directories; `thread_support=false`, `extensions_support=false`, desktop texture compression on, PWA off. Full gate post-processes generated JS/HTML, requires JS/WASM/PCK, hashes all nine export files, and enforces 16 MiB PCK. | Re-export from a clean import. Confirm every runtime CHOIR resource is included despite `exclude_filter`, and no concept/source board enters the PCK. Fail on package cap and record byte delta versus baseline. |
| Browser smoke | `scripts/web-gameplay-smoke.mjs` launches system Chromium against Vite, records console/request/HTTP failures, validates title videos, audio worklets, real keyboard input, ordered Godot phases from `WebGameplaySmokeProbe`, and both orientations. | Add a separate CHOIR probe/query or a mode-selectable probe. Keep the existing exact upgrade phase list unchanged; CHOIR phases should prove nonblocking input, persistence reload, localized text, and ending eligibility in the exported build. |
| CI | `.github/workflows/godot-verification.yml` restores checksum-verified Godot/templates, installs dependencies, and runs `./verify.sh --full` on PR, `main`, and dispatch. | Add typecheck/build and a production-host/deployed-artifact lane. Upload the PCK manifest, CHOIR scenario reports, persistence report, screenshots, and browser report. |

### GUT count caveat

`verify.sh` does **not** use GUT's 301-test result as its zero-test guard. It requires `artifacts/unit-tests-ran.txt >= 2`, but that file is manually incremented by selected integration tests (for example `_record_test_execution()` in `test_city_rampage_integration.gd`) and currently contains `8`. New CHOIR tests can pass without changing the sentinel, and the sentinel can pass while most tests are undiscovered. GUT's process exit is still blocking, but the count field in `verify.json` is mislabeled `unit_tests`. Safest correction: emit/parse a machine-readable GUT/JUnit result and assert `tests > 0`, `failures == 0`, `errors == 0`; remove the source-written sentinel rather than propagating `_record_test_execution()`.

## Exact integration points to verify

The narrative implementation should subscribe without taking ownership of combat:

| Producer | Exact signal/API | Deterministic assertion |
|---|---|---|
| `CityWorldStream` (`scripts/world/city_world_stream.gd`) | `district_changed(previous_district_id, district_id, logical_chunk)`, `run_configured(run_seed)`, `chunk_reassigned(...)` | One district arrival per boundary/cycle; deterministic dossier/facade choice for fixed `run_seed`; no duplicate transmission after chunk recycling. |
| `StreamedDestructibleRuntime` (`scripts/world/streamed_destructible_runtime.gd`) | `building_cell_destroyed(building, column, row, event)`, `building_destroyed`, `building_chain_*`, `post_warm_creation_count` | Marked upper payload loss cannot block the three-cell lower route; reveal/payload state restores after slot reassignment; no post-warm node creation. |
| `EncounterRuntime` / `EnemyActor2D` | `enemy_acquired`, `enemy_died(enemy, event, points)`, `EnemyActor2D.died`, `boss_armor_changed`, `boss_armor_broken` | Containment spawn uses an existing family slot, denial is deterministic at saturation, defeat advances exactly one narrative event, and pooled reuse clears CHOIR state. Observe the runtime-level `enemy_died` once; do not double-count both signals. |
| `CitySlice` (`scripts/gameplay/city_slice.gd`) | Existing connections at `_on_spatial_district_changed`, `_on_streamed_building_cell_destroyed`, `_on_enemy_died`; `retry_requested` | `NarrativeDirector` is a sibling observer built by composition, not new logic added to the already capped `CitySlice` file. Input/physics continue while transmissions display. |
| Run/finale systems | `UrbanSiegeRuntime.boss_session`, boss actor signals, frozen run summary, `Main.retry_game()` | Purge always available; Disentangle only at ≥20 dossiers plus five preserved evidence nodes; insufficient evidence produces Ascension Failure; retry resets run-local state but preserves versioned dossier state. |
| Localization | `L10n.keys_for_locale()`, `L10n.t()` and `test_l10n.gd` | EN and zh-CN keys/placeholders are identical, all CHOIR glyphs exist, and every resource stores a key rather than English prose. |

## Safest implementation shape for verification

1. **Inject deterministic configuration, not debug branches.** Give `NarrativeDirector`/campaign state an explicit run seed, campaign-store path (default production `user://...`, test path under `user://test-*`), and optional presentation clock/skip policy. Tests should call public event handlers or emit the real typed signals; they must not depend on OS time, uncontrolled `randi()`, or prior user data.
2. **Separate pure state from presentation.** GUT should test a versioned campaign state object and event reducer without scenes; integration tests then prove signal wiring; visual/browser lanes prove presentation. Transmission presentation must be bounded and nonmodal: assert `Input` still changes robot position while a line is visible and `UrbanSiegeRuntime.pause_coordinator.is_paused()` remains false.
3. **Reuse resident pools.** Configure black-lab children within each of the six resident `StructuralBuilding2D` slots and restore from the existing mutation ledger. Configure Reclaimed/Graft/Siren/Carrier profiles into existing procedural family pools. Add exact snapshot keys for any permanently resident visual/UI/audio slots and retain zero `post_warm_creation_count` after a 0→48→0 traversal.
4. **Keep the existing browser smoke stable.** `web-gameplay-smoke.mjs` requires an exact ten-phase sequence. Do not append CHOIR phases to `WebGameplaySmokeProbe` without updating every ordered assertion. Prefer `?webSmoke=choir` selecting a dedicated `WebProjectChoirSmokeProbe`, or a single probe dispatcher with separate histories and report schemas.
5. **Make package accounting reproducible.** Record fresh `game.pck` bytes and SHA-256 in `verify.json`; compare against `RuntimeBudget.MAX_WEB_PCK_BYTES` and optionally against a checked baseline. The present 2.56 MiB headroom is too small for raw concept art or uncompressed voice sets.

## Asset import and package-budget policy

Existing imported textures are predominantly `CompressedTexture2D`: 83 source textures use `compress/mode=0`, 42 use `compress/mode=1`; mipmaps are generally disabled. The sampled facade (`mercy_exchange_annex.png`) uses mode 0, no mipmaps, and no size limit. WAV effects import as `AudioStreamWAV` with `compress/mode=2`; the music loop is streamed Ogg. The project currently has roughly 26 MiB of source art/audio/localization but exports a 14.10 MB PCK because imports and preset exclusions differ from source size.

**Policy for CHOIR:** do not copy the proposal's full-resolution story-concept JPEGs into `game/`. Crop/atlas in-game reveals to the actual display resolution, use Web-appropriate lossy texture import for photographic/painted panels, retain lossless import only where alpha-edged pixel art requires it, disable mipmaps for 2D UI, and stream longer voice/music as Ogg rather than adding large PCM WAV collections. Validate visual quality in both required resolutions after import. Be aware that `export_filter="all_resources"` includes unreferenced resources unless excluded, while the preset's broad `art/effects/*`, `art/robot/upgrades/*`, and `art/robot/weapons/*` exclusions can also silently omit a referenced CHOIR asset placed there. Prefer an explicit CHOIR runtime directory plus a post-export resource smoke.

Budget acceptance is the existing hard **16 MiB PCK**, not the combined hosting payload. Still record total WASM + PCK + JavaScript + worklets and title media because WebDev cold-load behavior is user-visible. A sensible content target is ≤15 MiB, retaining ≥1 MiB emergency headroom before the hard cap; the current branch has only 2,681,480 bytes total hard-cap headroom.

## WebDev and deployment risks

1. `client/src/main.ts` uses local `/game/game(.pck)` only when `import.meta.env.DEV && ?localGame`; production uses hard-coded `REMOTE_ENGINE_PATH`, `REMOTE_PACK_PATH`, `GAME_PACK_VERSION`, and stale byte constants (`GAME_PACK_BYTES=7,763,444`, while the fresh PCK is 14,095,736). Therefore the local full gate does **not** prove production serves the newly exported CHOIR PCK.
2. `scripts/patch-godot-worklet-base.mjs` patches exact Godot-generated strings and fails if template output changes. This patch is required because production can split remote engine/WASM/PCK from local `/game/game.audio*.worklet.js`. Re-run it after every export and retain its one-target/idempotency assertions.
3. `scripts/patch-title-video-shell.mjs` modifies generated `game.html`, but the normal Vite client builds its own backdrop in `client/src/main.ts`; current smoke exercises the Vite shell, not `game.html`. Treat the generated-HTML patch as a distributable standalone artifact or remove duplicate ownership; do not assume testing one proves the other.
4. All media/engine URLs are root-absolute (`/game`, `/title-video`, `/manus-storage`). Subpath deployments will fail unless the host rewrites from origin root. `server/index.ts` supplies only `express.static`; it does not set explicit MIME/cache policy, COOP, or COEP. Non-threaded Web (`threads:false`) avoids SharedArrayBuffer requirements, so do not enable threads without adding and testing `Cross-Origin-Opener-Policy` and `Cross-Origin-Embedder-Policy` across local and remote assets.
5. The smoke tracks 4xx/5xx responses but only treats selected request failures specially; production storage redirects, cache headers, content lengths, range behavior, and PCK hash are not asserted. A deployed smoke must fetch the final PCK, verify SHA-256/content length, and reject old cache versions.

## Required deterministic tests

| Test | Lane | Blocking contract |
|---|---|---|
| Campaign schema/migration | GUT | Empty, current, previous-version, malformed, and future-version saves have deterministic outcomes; writes are atomic; no production save path is touched. |
| Dossier idempotency/persistence | GUT | Same facade event grants once; fixed 25 IDs; retry/new chassis preserves dossiers; new run resets run-local payloads; corrupted save cannot soft-lock Purge. |
| Event observation | GUT integration | Real `district_changed`, `building_cell_destroyed`, and `enemy_died` signals each advance one expected event; disconnect/free causes no orphan callbacks. |
| Route safety | GUT + headless | Destroy every protected payload/evidence cell and still traverse lower cells through all five districts; failed evidence can deterministically reappear as an elite drop. |
| Nonblocking transmission | Headless + browser | During every line/card, robot input changes position, attack/dash remain accepted as designed, no pause lease exists, and watchdog completes. |
| Family-pool saturation | GUT | Each new archetype acquires/recycles within its existing family; at cap it degrades/denies without allocation; state is clean on reuse. |
| Streaming stability | Headless | Fixed-seed 0→48→0 traversal covers all 25 dossier facades, restores breach/dossier state, preserves node count, and keeps all post-warm counters at zero. |
| Finale matrix | GUT | `(0,0)→PURGE only`, `(20,5)→PURGE+DISENTANGLE`, insufficient evidence request→ASCENSION_FAILURE`; pylon events are idempotent and final summary freezes exactly once. |
| Localization/font parity | GUT | EN/zh-CN key and placeholder parity plus font coverage for all dossier/transmission/ending text. |
| CHOIR visual contract | Xvfb | Intact/breached reveal, payload marker, transmission, dossier summary, and ending choice render at exactly 1280×720 and 720×1280 with deterministic state and no required `SKIP`. |
| Export/resource contract | Full shell gate | Clean release export contains all referenced campaign resources, contains no `test/selftest/addons/gut/artifacts` or raw concept boards, and PCK ≤16,777,216 bytes; output hash manifest is stored. |
| Browser CHOIR smoke | Chromium | Exported build enters gameplay, crosses/reconfigures a district, breaches a marked cell, displays nonblocking localized narrative, retries, and reloads persistence; no console/HTTP/request errors. |
| Production artifact identity | Deployed smoke | Deployment PCK content length and SHA-256 equal the freshly approved manifest; engine/worklets/video MIME types and cross-origin behavior pass; cold and cache-hit launches both reach ready. |

## Exact end-to-end release gates

A CHOIR release candidate is acceptable only when all of the following run from a clean checkout and the same commit/artifact identity:

1. `pnpm install --frozen-lockfile` with Godot **4.7.2-stable** and matching non-threaded Web templates.
2. `cd game && ./verify.sh --full`: import; static constraints; lint/parse diagnostic scan; full GUT; bounded boot/shutdown; all headless reports; all required landscape/portrait visual reports; clean release export; patches; PCK cap/hash; existing browser smoke; new CHOIR scenarios/smoke. Any nonzero exit, timeout, required screenshot `SKIP`, JSON mismatch, logged diagnostic, leak signature, missing file, console/request error, or cap breach blocks.
3. From repository root, `pnpm check` and `pnpm build`; start the production server (`pnpm start`) and smoke that output, not only Vite dev mode.
4. Upload/promote the exact hashed engine/PCK/worklets and update production storage version/size metadata atomically. Never deploy code that references the prior remote PCK.
5. Run the deployed-origin smoke in Chromium at both orientations, verify final redirected PCK hash and MIME, perform a persistence reload, and archive reports/screenshots/hash manifests in CI.
6. Manual review is additive, not a substitute: inspect black-lab/horror readability, Chinese layout, and Web audio/video behavior, then approve the already-green immutable artifact.

## Files expected to change (implementation phase)

No production files were edited by this audit. The minimal verification/release set is:

- `game/test/test_project_choir_campaign_state.gd`
- `game/test/test_project_choir_narrative_director.gd`
- `game/test/test_project_choir_integration.gd`
- `game/test/test_runtime_budget.gd`
- `game/test/test_l10n.gd`
- `game/selftest/project_choir_scenario.gd`
- `game/selftest/project_choir_visual_scenario.gd`
- `game/scripts/quality/runtime_budget.gd`
- `game/scripts/quality/web_project_choir_smoke_probe.gd`
- `game/verify.sh`
- `game/export_presets.cfg` (only if explicit CHOIR include/exclude policy is needed)
- `scripts/web-project-choir-smoke.mjs` or a mode-safe extension of `scripts/web-gameplay-smoke.mjs`
- `client/src/main.ts` (production artifact identity/version/size; remove stale hard-coded PCK metadata)
- `server/index.ts` (explicit production MIME/cache/header policy if this remains the deployment host)
- `.github/workflows/godot-verification.yml`
- `README.md` (regenerated measured baseline only after the complete gate passes)

The existing omitted selftests `destruction_detail_visual_scenario.gd` and `robot_animation_visual_scenario.gd` are not invoked by `verify.sh`; their mere presence is not release coverage. Any CHOIR scenario must be explicitly wired and asserted.

## Compatibility risks

The dominant risks are **production/local artifact divergence**, **PCK exhaustion**, **pool growth hidden behind visual content**, **double-counting adjacent signals**, **persistent-save contamination between tests**, **exact-string Web patch breakage on Godot template changes**, **absolute-path failure on subpath deployments**, and **ordered browser-smoke brittleness**. Enabling Web threads or extensions would also violate the pinned export contract and introduce cross-origin isolation requirements. Finally, the README's recorded 51 scripts / 312 tests and 14,109,168-byte PCK do not match the currently inspected artifacts (50 / 301 and 14,095,736); release documentation must be generated from the same immutable candidate rather than copied forward.

**Recommendation:** treat `./verify.sh --full` as the game-candidate gate, then add a separate production-package identity gate. Project CHOIR should not be promoted until both prove the same PCK hash.
