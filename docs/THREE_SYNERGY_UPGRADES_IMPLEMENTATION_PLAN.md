# Siege Drill, Gravity Crucible, and Tesla Tower Implementation Plan

**Author:** Manus AI
**Repository:** `https://github.com/junnyboi/proto-scroller`
**Target engine:** Godot 4.7.2 stable, GL Compatibility, GDScript
**Canonical baseline:** `2138c622ed7a79f9aa1fbb65bd37e0aa3378970c`
**Working branch:** `agent4/three-synergy-upgrades`

## 1. Objective

This work adds three approved run upgrades that amplify the robot’s established dash and charged-melee verbs instead of introducing new controls. **Siege Drill** turns a successful dash into a bounded multi-contact battering ram. **Gravity Crucible** captures nearby physical debris and ordinary enemy wrecks during a held melee charge, then hurls them forward on release. **Tesla Tower** plants one grounded autonomous electrical tower whenever a fully charged melee attack is released, including when the attack ultimately misses.

All three upgrades enter the existing `UpgradeCatalog` → `UpgradeSession` → `UpgradeRuntime` → `PlayerUpgradeAssembler` pipeline. Each has three ranks, deterministic offers, complete English and Simplified Chinese localization, fixed prewarmed runtime capacities, GPT Image 2 production art, focused Godot tests, telemetry-compatible damage provenance, and a fresh Godot Web export synchronized to the existing `proto-scroller` Manus WebDev project.

> The implementation deliberately extends existing player verbs rather than adding an upgrade-specific button. This preserves input clarity while creating visibly different build identities.

## 2. Design and Scope Decisions

| Upgrade | Trigger | Core result | Fixed budget | Explicit non-goals |
| --- | --- | --- | --- | --- |
| **Siege Drill** | `GiantRobotController.dodge_started` after a successful dash begins | Deploys a front-mounted drill and damages each contacted canonical target once per dash | One hitbox, one sprite, 24-result bounded contact query | No dash speed/duration/invulnerability changes; no projectile; no extra input |
| **Gravity Crucible** | Existing `charge_started` / `charge_updated` / `charge_released` flow | After a 0.35-second hold, captures 1–3 eligible physical debris/wreck bodies and throws them forward | Three capture slots using bodies already owned by current pools | No live-enemy capture; no boss wreck; no hostile-projectile reflection; no new debris capacity |
| **Tesla Tower** | Existing `charge_released` when `spec.is_fully_charged()` | Plants or replaces one grounded tower at the robot’s release position; pulses nearby live enemies | One tower sprite and three reusable arc sprites | No enemy attachment; no structural damage; no stacking; no stun; no line-of-sight system |

### 2.1 Gravity Crucible projectile decision

Rank three will capture a third physical body rather than reflect a hostile projectile. The current `ProjectilePool` does not expose a stable active iterator or a reversible ownership/team/collision conversion contract. Mutating a live hostile projectile would risk same-frame impact, stale source attribution, partition corruption, and premature recycle. A future projectile-reflection feature should begin with a dedicated pooled-projectile suspend/resume API rather than smuggling ownership changes into this upgrade.

### 2.2 Tesla deployment timing

Tesla Tower subscribes to `ContextualAttackController.charge_released`, not `attack_active` or `full_charge_enemy_hit`. `release_charge()` has already applied the final charge multiplier when it emits this signal. Planting here guarantees that a valid full-charge release deploys a tower even when no enemy is struck, which matches the requested behavior. Cancellation before release does not deploy; cancellation during anticipation after release does not retract an already committed tower.

### 2.3 Damage provenance

Siege Drill uses `damage_type = &"jab_cross"` so existing melee armor, knockback, destructible, score, and feedback paths remain authoritative, but it does not call `JabCrossImpact.resolve()` because that resolver intentionally changes robot velocity and stops after certain structural hits. Gravity Crucible uses `damage_type = &"debris_impact"` plus a new provenance flag. Tesla Tower uses `damage_type = &"tesla_tower"` plus a new provenance flag and a telemetry mapping. Secondary damage cannot retrigger charge-release listeners.

## 3. Rank Tuning

### 3.1 Siege Drill

| Rank | Actor damage | Structural damage | Impulse per mass | Geometry and cap |
| --- | ---: | ---: | ---: | --- |
| 1 | 40 | 36 | 360 | Fixed 126 × 92 forward rectangle; 24-query cap |
| 2 | 48 | 44 | 420 | Same geometry and cap |
| 3 | 56 | 52 | 480 | Same geometry and cap |

The drill is intentionally weaker per target than an ordinary uncharged Jab-Cross because it can contact multiple targets over the duration of a dash. Each canonical receiver can be hit only once per dash, even if physics returns both its body and hurtbox.

### 3.2 Gravity Crucible

| Rank | Capture cap | Radius | Orbit radius | Throw speed | Damage per body |
| --- | ---: | ---: | ---: | ---: | ---: |
| 1 | 1 | 190 px | 96 px | 760 px/s | 12 |
| 2 | 2 | 230 px | 108 px | 850 px/s | 16 |
| 3 | 3 | 270 px | 120 px | 940 px/s | 20 |

Capture begins only after 0.35 seconds of uninterrupted charge. Candidates are ordered by squared distance, source category, and stable instance identity. Eligible categories are active structural debris, active enemy-scrap debris, and ordinary active enemy wrecks. Aerial shrapnel, Kinetic Field deliveries, inactive bodies, scrapped wrecks, boss/finale wrecks, and already captured bodies are excluded.

### 3.3 Tesla Tower

| Rank | Lifetime | Pulse interval | Range | Targets per pulse | Damage per target |
| --- | ---: | ---: | ---: | ---: | ---: |
| 1 | 5.0 s | 1.20 s | 430 px | 1 | 18 |
| 2 | 6.0 s | 1.00 s | 500 px | 2 | 20 |
| 3 | 7.0 s | 0.90 s | 570 px | 3 | 22 |

A tower has a 0.25-second arming delay for readable placement. A new fully charged release replaces the existing tower; it never creates a second active tower. Per pulse, targets are selected from the fixed encounter registry in deterministic family order and then sorted by distance and stable ordinal. Only active, living enemy actors are valid. The tower does no structural damage and applies zero impulse.

## 4. Production Asset Plan

All new visual content is generated with **GPT Image 2**. Runtime transforms, alpha fades, and sprite reuse are allowed; procedural production imagery using `_draw()`, `Line2D`, generated polygons, or shader-authored substitutes is not.

| Asset | Shipping path | Shipping canvas | Purpose |
| --- | --- | ---: | --- |
| Siege Drill icon | `res://art/ui/upgrades/siege_drill.png` | 256 × 256 | Upgrade card |
| Siege Drill mount | `res://art/player/weapons/siege_drill_mount.png` | 160 × 112 or smaller | Front-mounted dash drill |
| Gravity Crucible icon | `res://art/ui/upgrades/gravity_crucible.png` | 256 × 256 | Upgrade card |
| Tesla Tower icon | `res://art/ui/upgrades/tesla_tower.png` | 256 × 256 | Upgrade card |
| Tesla Tower world sprite | `res://art/player/upgrades/tesla_tower.png` | 192 × 256 or smaller | Grounded autonomous tower |
| Tesla arc sprite | `res://art/player/upgrades/tesla_arc.png` | 256 × 64 or smaller | Reusable electric link card |

Masters remain outside the source repository under `/home/ubuntu/proto-scroller-art-masters/three-upgrades/v1`. Shipping derivatives are alpha-trimmed, padded with a transparent border, resized with Lanczos while preserving all content, quantized deterministically where suitable, saved as optimized PNG, imported without mipmaps, and recorded in `game/art/upgrades_art_manifest.json` with model, prompt, master hash, shipping hash, dimensions, encoded size, and review state.

The visual direction follows the canonical robot: oxidized bronze armor, charcoal mechanical internals, restrained cyan emissive energy, and amber/gold charge accents. The tower must have a wide grounded foot and a readable coil silhouette. The drill must point horizontally and remain legible at gameplay scale. Icons must remain centered, high contrast, transparent, and text-free.

## 5. Architecture and File Changes

### 5.1 Shared upgrade integration

`game/scripts/upgrades/player_upgrade_assembler.gd` will create all three runtimes during warm-up and inject current robot, attack controller, encounter registry, debris pools, remains factory, feedback systems, and visual marker dependencies. `game/resources/upgrades/upgrade_catalog.tres` will add the three profiles. `game/localization/en.json` and `game/localization/zh-CN.json` will add matching names and descriptions; Tesla also adds a debrief weapon label.

The completed catalog grows from **11 profiles / 40 ranks** to **14 profiles / 49 ranks**. The generated-art manifest grows from **29 records** to **35 records**. Existing deterministic offer logic, pause leasing, overlay rendering, and upgrade-acquisition feedback remain unchanged.

### 5.2 Siege Drill runtime

`game/scripts/upgrades/siege_drill_runtime.gd` owns one `SiegeDrillHitbox`, connects to successful dodge lifecycle signals, reserves one attack ID per dash, and retracts on natural finish, dash cancellation, attack start, pause stop, or run reset. `game/scripts/combat/siege_drill_hitbox.gd` owns one rectangle query, one mount sprite, bounded result scratch state, deterministic receiver ordering, and a per-dash hit ledger. It delivers damage directly without altering robot velocity.

The mount follows current facing during the dash. When smash cancels a dash, `cancel_dodge()` synchronously emits `dodge_finished` before the charged Jab-Cross begins; this ensures the drill disappears before the momentum attack takes ownership of the interaction.

### 5.3 Gravity Crucible runtime

`game/scripts/upgrades/gravity_crucible_runtime.gd` owns three fixed capture slots and listens to the existing charge lifecycle. It scans indexed active-body accessors added to `DebrisPool` and `EnemyRemainsFactory`, selects deterministic eligible candidates, delegates reversible orbit/release state to `DebrisBody2D` and `EnemyWreck2D`, and derives orbit positions around the robot without generating new world bodies.

While captured, a body is frozen, collision participation is disabled, contact damage is suppressed, and pool culling/replacement avoids it. Release restores physics and collision, assigns fixed forward/upward velocity, and arms one upgrade-authored delivery with the original charged-melee root ID. Cancellation restores the body harmlessly without an armed delivery. Original pools retain ownership at all times.

### 5.4 Tesla Tower runtime

`game/scripts/upgrades/tesla_tower_runtime.gd` owns one prewarmed `TeslaTower2D`. `game/scripts/combat/tesla_tower_2d.gd` owns the fixed pulse clock, tower sprite, and three `TeslaArcVisual2D` children. `game/scripts/combat/tesla_arc_visual_2d.gd` transforms and fades the generated horizontal arc sprite between a tower origin and an endpoint snapshot.

The tower plants at the existing `VisualRoot/VisualGroundOrigin` marker’s global position on a full-charge release. It remains at that world position when the robot moves, shifts correctly with floating-origin rebases as part of the city tree, and is replaced by the next full-charge release. It selects active enemies through a new deterministic read-only query on `EncounterRuntime` and delivers direct `DamageEvent` instances with fresh pulse IDs and the deployment attack as root.

## 6. Runtime Budgets and Determinism

`RuntimeBudget` gains explicit constants and snapshot checks for one drill hitbox, three Gravity Crucible capture slots, one Tesla tower, and three Tesla arc sprites. No existing projectile, debris, wreck, particle, or audio capacity increases.

Gameplay paths after warm-up must not instantiate nodes, shapes, sprites, particles, timers, tweens, resources, or collections with unbounded growth. Physics results and encounter candidates are hard-capped and deterministically ordered. Repeated dashes, charges, releases, replacement towers, pauses, retries, and New Game+ transitions must preserve the warmed node count.

## 7. Phased Delivery Plan

### Phase 1 — Siege Drill

Generate and process the Siege Drill icon and mount. Add the profile, localization, runtime, bounded hitbox, assembler wiring, runtime-budget entry, focused tests, asset-manifest records, catalog-count updates, and documentation. Verify accepted contacts, once-per-dash deduplication, fixed cap ordering, unchanged dash physics, dash-cancel retraction, pause/reset cleanup, and asset borders. Run a focused regression, review the diff, merge non-destructively into the latest shared `main`, and push `main` without force.

**Phase 1 acceptance:** A successful dash visibly deploys the drill; each contacted valid target takes at most one drill hit during that dash; a rejected dash does nothing; dash speed/duration/cooldown/invulnerability remain unchanged; dash-cancel melee starts with the drill retracted; the catalog totals 12 profiles and 43 ranks.

**Phase 1 status — implemented:** The generated drill icon and world mount are imported with transparent gutters and recorded with exact GPT Image 2 provenance. The runtime uses one prewarmed hitbox, a fixed 24-entry hit ledger, deterministic contact ordering, and unchanged dash physics. Focused Godot evidence passed 4 tests / 58 assertions; catalog, localization, rank-soak, and non-audio asset contracts passed 17 of 17 relevant tests. One pre-existing shared-audio test still reports three active external voices where it expects one and is unrelated to this phase.

### Phase 2 — Gravity Crucible

Generate and process the Gravity Crucible icon. Add the profile, localization, runtime, indexed pool accessors, reversible debris/wreck capture state, causal flag, runtime-budget entries, focused tests, asset record, and aggregate count updates. Verify the hold threshold, rank caps/radii, candidate ordering, exclusions, collision suppression, pause behavior, safe cancellation, one-hit release delivery, pool recycling, boss-wreck safety, and no node growth. Fetch and integrate upstream once, run a focused regression, review, and push the merged `main` without rewriting history.

**Phase 2 acceptance:** Holding melee charge for at least 0.35 seconds visibly orbits 1–3 existing physical bodies by rank; releasing throws them forward; taps capture nothing; cancellation restores them safely; existing pools retain capacity; hostile projectiles are untouched; the catalog totals 13 profiles and 46 ranks.

**Phase 2 status — implemented:** The runtime captures one to three nearest eligible pooled debris bodies or ordinary factory-owned wrecks after 0.35 seconds, suspends collision and damage authority while orbiting, and restores every saved physics field on release or cancellation. Released bodies use dedicated delivery IDs and `FLAG_GRAVITY_CRUCIBLE`, deal one bounded hit, inherit Kinetic Field bonus state, and cannot be reclaimed by saturated pools while held. Hostile projectiles and boss-owned wrecks remain outside the candidate registries. Focused evidence passed 6 tests / 77 assertions; debris, wreck, catalog, localization, all-rank, manifest, icon, and alpha-border regressions passed 25 tests / 9,007 assertions.

### Phase 3 — Tesla Tower

Generate and process the Tesla Tower icon, world sprite, and arc sprite. Add the profile, localization, deterministic live-enemy query, tower runtime/actor/arc slots, damage flag and telemetry label, New Game+ cleanup, runtime-budget entries, focused tests, asset records, and final catalog/manifest count updates. Verify full-charge whiff deployment, release-position grounding, replacement semantics, target ordering, rank caps and pulse tuning, pause/reset/New Game+ cleanup, non-recursion, accepted kill attribution, and fixed node count. Fetch and integrate upstream once, run focused regression, review, and push the merged `main` without force.

**Phase 3 acceptance:** Any fully charged melee release plants one grounded tower at the robot’s release position even with no targets; at most one tower exists; it selects only living enemies; at most three reusable arcs appear; tower damage cannot deploy another tower; the catalog totals 14 profiles and 49 ranks.

**Phase 3 status — implemented:** One prewarmed tower listens directly to `charge_released`, deploys at `VisualGroundOrigin` on every fully charged release including whiffs, and replaces itself without creating another node. After its fixed arming delay it scans the encounter registry in stable base/family order, keeps the nearest one to three living candidates in fixed arrays, and sends zero-impulse `tesla_tower` damage with dedicated pulse IDs, the melee deployment root, and `FLAG_TESLA_TOWER`. Three reusable GPT Image 2 arc sprites transform between endpoint snapshots and fade without procedural drawing. Focused evidence passed 6 tests / 51 assertions; catalog, localization, 49-rank soak, debrief analytics, manifest, icon, and alpha-border contracts passed 29 tests / 11,588 assertions.

### Phase 4 — Integrated Web Release

Fast-forward or semantically merge the newest shared `main` once, preserving all compatible concurrent feature contracts. Run lightweight focused integration checks in accordance with the project’s release-gate override: direct import/parse, bounded boot, the three new upgrade suites, upgrade catalog/assets/localization/session/budget/hardening suites, and a concise visual inspection of drill, crucible, and tower behavior. Do not run the full repository certification gate unless explicitly requested.

Create a fresh Godot 4.7.2 Web export containing HTML, JavaScript, WASM, and PCK artifacts. Restore generated source residue afterward. Upload both fresh WASM and PCK to immutable Manus storage, update the existing `proto-scroller` WebDev shell without touching leaderboard backend behavior, preserve title/audio/worklet/dynamic-viewport configuration, update `PLAN.md`, `STRUCTURE.md`, `MEMORY.md`, and `ASSETS.md`, run WebDev type/build checks, restart the preview, verify exact payload routes and sizes over HTTP, save a final checkpoint, and publish when the managed tool exposes publication.

## 8. Focused Test Matrix

| Contract | Siege Drill | Gravity Crucible | Tesla Tower |
| --- | --- | --- | --- |
| Rank-zero inert | Required | Required | Required |
| Rank tuning | Damage/impulse | Cap/radius/speed/damage | Lifetime/rate/range/targets/damage |
| Deterministic ordering | Forward distance then ID | Distance/category/ID | Distance/family ordinal |
| Fixed capacity | 24 query, one hitbox | Three capture slots | One tower, three arcs |
| Pause/reset cleanup | Retracts | Restores harmlessly | Deactivates |
| No node growth | Repeated dashes | Repeated capture/release | Repeated replace/pulse |
| Existing verb preserved | Dash physics | Melee charge and multiplier | Charged attack and hit feedback |
| Edge case | Dash-cancel melee | Pool recycle and boss wreck | Full-charge whiff |
| Damage attribution | Existing Jab-Cross path | Debris-impact root/flag | Tesla type/root/flag/telemetry |
| Localization/assets | EN/zh-CN + two assets | EN/zh-CN + one asset | EN/zh-CN + three assets |

## 9. Completion Criteria

The task is complete when all three upgrades are selectable in ordinary run-upgrade offers, all nine ranks function with the tuning above, every new sprite/icon comes from GPT Image 2 and is represented in the art manifest, both locales have complete copy, focused tests pass, each implementation phase has been pushed to shared `main`, the final tree has been freshly exported with Godot 4.7.2, the existing Manus WebDev project serves the exact new WASM/PCK, and a managed final checkpoint is saved.

## References

[1]: https://github.com/junnyboi/proto-scroller "Proto Scroller canonical source repository"
[2]: https://docs.godotengine.org/en/latest/classes/class_physicsdirectspacestate2d.html "Godot PhysicsDirectSpaceState2D documentation"
[3]: https://docs.godotengine.org/en/latest/classes/class_rigidbody2d.html "Godot RigidBody2D documentation"
