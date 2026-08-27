# District Chimera Projectile and Attack VFX Implementation Plan

**Project:** Proto Scroller  
**Engine:** Godot 4.7.2  
**Feature:** Unique projectile, impact/explosion, and attack VFX for twenty district CHOIR variants  
**Author:** Manus AI  
**Status:** In implementation  
**Canonical design:** [District Chimera Projectile and Attack VFX Proposal](DISTRICT_CHIMERA_ATTACK_VFX_PROPOSAL.md)

## 1. Objective

This plan gives all twenty district CHOIR variants a unique three-phase attack presentation without changing their approved gameplay contracts. Every variant receives a delivery payload motif, an impact or completion burst, and an anticipation or attack channel. Nine damaging ranged variants skin their existing pooled bullet, shell, or rocket and dispatch a corresponding cosmetic impact. Eleven support or melee variants use the same three visual phases through prewarmed actor-owned sprites and continue to reserve zero projectiles.

The implementation preserves the existing twenty-six base archetypes, twenty district variants, forty-six total procedural IDs, five procedural family pools, thirty-two pooled projectiles, projectile partitions, attack styles, target selection, damage values, projectile speeds, collision radii, support values, telegraph durations, body and wreck budgets, encounter decks, resolver behavior, and district threat costs.

## 2. Non-Negotiable Contracts

No new enemy, projectile, remains, hazard, decoy, carrier, or damage-area pool may be introduced. No projectile partition or projectile count may change. No attack may gain a second damage instance, lingering zone, status field, tracking rule, hidden origin, control effect, collision change, or altered timing. Cosmetic impact slots may overwrite an older cosmetic effect under extreme saturation, but they must never deny, delay, recycle, or mutate a gameplay projectile.

The eleven presentation-only variants are Testament Kite, Receivership Ambulance, Intake Shepherd, Evacuation Litter, Balcony Recall Beacon, Memorial Usher, Recall Lantern, Suture Marshal, Privy Chirurgeon, Laureate Courser, and Ninefold Witness. Their visual payloads are not physics projectiles. Scan remains a three-second mark, choir ring remains a four-second mark, repair remains one nearest damaged non-self ally within 520 pixels for exactly 22 health, and melee remains one existing bounded completion event.

The nine ranged variants are Covenant Warden, Mercy Recovery Cart, Rainvault Pressure Ward, Glassback Double, Marquee Anesthetist, Mercy Raker, Revetment Ward, Triage Kite, and Regency Conservator. Their bullet, shell, or rocket kind, pool partition, velocity, radius, damage, target mask, lifetime, and reservation count remain unchanged.

The project release-gate override remains active. Work packages use only focused Godot parse checks, selected GUT files or test filters, direct asset integrity checks, and the required fresh export/deployment synchronization. Repository-wide verification gates, broad browser matrices, repeated stabilization loops, and release certification are intentionally omitted.

## 3. Asset Architecture

GPT Image 2 generated twenty standalone 2304×1536 triptych masters. Each triptych contains a delivery payload, impact/completion, and anticipation/channel design. Masters remain outside the Godot runtime under `docs/story-concepts/production-sources/choir-attack-vfx/`. Proposal-ready images are stored under `docs/concepts/choir-attack-vfx/`.

`scripts/process-choir-attack-vfx.py` deterministically slices every master into three equal source columns, trims alpha, preserves aspect ratio, rotates only vertically authored physical ranged payloads into canonical horizontal travel orientation, and packs the results into three 960×768 WebP atlases. Each atlas uses a five-column by four-row grid of 192-pixel cells in exact `DISTRICT_VARIANT_IDS` order.

| Atlas | Runtime role | Planned source size |
|---|---|---:|
| `game/art/city/enemies/choir-attacks/district-projectile-vfx.webp` | Physical ranged projectile skins and actor-only payload motifs | 88,382 bytes |
| `game/art/city/enemies/choir-attacks/district-impact-vfx.webp` | Projectile impacts and actor-only completion bursts | 245,380 bytes |
| `game/art/city/enemies/choir-attacks/district-attack-vfx.webp` | Anticipation, muzzle, scan, brace, or channel cues | 144,400 bytes |
| **Total** | Sixty unique atlas regions | **478,162 bytes** |

## 4. Data Contract

A new `EnemyAttackVfxCatalog` owns all district-variant attack presentation data. The catalog keys must exactly equal `EnemyArchetypeCatalog.DISTRICT_VARIANT_IDS`. Each entry records delivery class, atlas region, display size, local placement, flip policy, completion duration, projectile kind where relevant, and deterministic visual keys. It must not contain damage, speed, range, target, collision, attack interval, telegraph duration, health, threat, or spawn data.

The catalog exposes `has()`, `spec()`, `phase_spec()`, `projectile_key()`, `impact_key()`, `projectile_spec_for_key()`, `impact_spec_for_key()`, `is_projectile_delivery()`, and `validation_errors()`. Validation requires exactly twenty entries, the exact 9/11 delivery split, three valid atlas regions per entry, unique projectile and impact keys for the ranged set, empty physical keys for actor-only entries, cell bounds inside 960×768, positive display sizes and durations, and projectile radius parity with the inherited damage kind.

`EnemyArchetypeCatalog` adds only one presentation identity field, `attack_vfx_id`, to each of the twenty overlays. Flattened gameplay fields remain unchanged. Catalog validation proves that every variant's VFX ID resolves and that no base archetype receives a district VFX identity.

## 5. Runtime Architecture

### 5.1 Actor-owned anticipation, payload, and completion

`ProceduralEnemy` caches the immutable VFX spec during `configure_archetype()`. Once the existing telegraph reservation succeeds, district variants render the attack-channel region and, for actor-only deliveries, the payload region using two of the five already-prewarmed presentation sprites. Ranged variants render only the attack-channel region because their payload appears on the physical projectile.

At support or melee completion, the actor replaces anticipation layers with its unique impact/completion region. Repair anchors the completion at the selected ally. Scan and choir ring anchor to the current player target. Shock brace and drop lunge anchor to the existing contact point. No new node, tween, timer, collision shape, damage area, or process owner is created during combat.

Cancellation, attack denial, interruption, death, release, deactivation, and old→variant→old shell reuse synchronously clear texture, region, visibility, transform, flip, tint, timer, and cached VFX identity from all five presentation sprites. Completion fading remains bounded by the existing `_presentation_remaining` timer.

### 5.2 Ranged projectile skins

`ProceduralEnemy._complete_attack()` supplies the variant's unique projectile visual key to the existing `fire_telegraphed_projectile()` call. `ProjectileVisualCatalog.spec()` continues to resolve the four existing legacy entries and delegates district keys to `EnemyAttackVfxCatalog` without changing default keys. The projectile renderer draws the atlas region directly; it does not allocate an `AtlasTexture` during combat.

`Projectile2D` stores a cosmetic `impact_key` derived solely from the selected projectile visual. Collision, damage delivery, and recycle order remain unchanged. Its impact signal carries the impact key explicitly. `deactivate()` clears both keys, rotation, tint, source, masks, radius, velocity, and lifetime.

### 5.3 Cosmetic impacts inside the existing projectile pool

`ProjectilePool` prewarms a bounded hostile-impact cohort inside the existing pool node. This is not a projectile or damage pool: it owns no collision, targetability, or damage behavior and cannot influence reservation admission. Eight slots are sufficient for ordinary on-screen impact density; a ring cursor may overwrite the oldest cosmetic impact without affecting projectile delivery.

`WeaponImpactEffect2D` is made idempotently reconfigurable. `setup()` creates its fixed sprite and particle children once. `configure()` replaces texture, atlas region, display size, lifetime, tint, and particle policy without adding nodes. Atlas-backed CHOIR impacts use the sprite region and disable texture particles to avoid sampling the full atlas. `deactivate()` restores age, visibility, transform, modulation, region state, and emission state.

The existing four machine-gun impact slots and their behavior remain unchanged. `release_all()` and hostile release paths clear the hostile cosmetic cohort and reset its cursor.

## 6. Work Packages

| Work package | Status | Deliverable | Focused evidence | Milestone |
|---|---|---|---|---|
| WP0 — Proposal and GPT Image 2 art | Completed | Canonical proposal, twenty embedded triptychs, masters, processor, three runtime atlases, provenance | 20 masters, 20 concepts, 3 atlases, 60 valid regions, visual pass, 478,162 source bytes | Commit and push documents/assets |
| WP1 — Catalog and ranged delivery | Pending | Exact twenty-entry VFX catalog, nine custom projectile keys, explicit impact identity, bounded hostile impacts | Catalog/schema tests, projectile radius/speed/damage parity, pool counts and reset | Commit and push ranged layer |
| WP2 — Actor support/melee presentation | Pending | Twenty anticipation cues plus eleven actor-only payload/completion paths | Zero projectile reservations for 11, support/melee parity, cancel/death/reuse cleanup | Commit and push actor layer |
| WP3 — Focused integration and plan closure | Pending | Focused district VFX suite, gallery/report extension, provenance, final completion record | Selected GUT filters, parse, direct asset and node-count assertions | Commit and push final source |
| WP4 — Fresh export and WebDev synchronization | Pending | Godot 4.7.2 Web export, immutable WASM/PCK remap, existing WebDev checkpoint and publish | HTML/JS/WASM/PCK existence, exact sizes/routes, PCK ≤16 MiB, public shell route | Checkpoint and deploy existing project |

## 7. WP0 — Proposal and Art

WP0 records the approved design before gameplay modification. It produces the canonical proposal with all twenty embedded GPT Image 2 concept plates, preserves full-resolution masters, generates the three compact atlases, writes asset provenance, and verifies that every grid cell contains visible alpha inside its declared bounds.

**Files:** `docs/DISTRICT_CHIMERA_ATTACK_VFX_PROPOSAL.md`, `docs/DISTRICT_CHIMERA_ATTACK_VFX_IMPLEMENTATION_PLAN.md`, `docs/concepts/choir-attack-vfx/*.png`, `docs/story-concepts/production-sources/choir-attack-vfx/*`, `scripts/process-choir-attack-vfx.py`, and `game/art/city/enemies/choir-attacks/*.webp`.

**Exit criteria:** exactly twenty masters and twenty proposal plates; exactly three 960×768 runtime atlases; sixty nonempty 192×192 cells; no visible clipping or background contamination; combined runtime source art below 600 KiB; explicit GPT Image 2 provenance.

## 8. WP1 — Catalog and Ranged Delivery

WP1 creates `EnemyAttackVfxCatalog`, adds `attack_vfx_id` only to district overlays, delegates district visual-key resolution through `ProjectileVisualCatalog`, carries explicit impact identity through `Projectile2D`, and adds the fixed cosmetic hostile-impact cohort to `ProjectilePool`.

**Primary files:** `game/scripts/combat/enemy_attack_vfx_catalog.gd`, `game/scripts/encounter/enemy_archetype_catalog.gd`, `game/scripts/combat/projectile_visual_catalog.gd`, `game/scripts/combat/projectile_2d.gd`, `game/scripts/combat/projectile_pool.gd`, `game/scripts/combat/weapon_impact_effect_2d.gd`, `game/scripts/quality/runtime_budget.gd`, and focused tests.

**Exit criteria:** exact catalog-set equality; exact nine physical projectile deliveries; all nine unique projectile keys resolve to valid atlas regions; bullet/shell/rocket radii remain 5/9/7; speed, damage, target mask, lifetime, and reservation count match pre-feature values; physical projectile count remains 32 with 16/4/4/8 partitions; hostile impacts are cosmetic and bounded; all pooled keys and visuals reset.

## 9. WP2 — Actor Presentation

WP2 integrates the catalog with `ProceduralEnemy`. Every district variant receives a unique anticipation cue. The eleven actor-only variants also show their unique payload during the existing telegraph and their unique completion at the existing target/contact point. The nine ranged variants supply the unique projectile key after the ordinary telegraph succeeds.

**Primary files:** `game/scripts/actors/procedural_enemy.gd`, `game/scripts/actors/enemy_actor_2d.gd` only if cleanup integration requires it, `game/scripts/encounter/telegraph_presenter_2d.gd` for metadata pass-through only, and focused presentation tests.

**Exit criteria:** actor child counts remain fixed; no combat-time node creation; all twenty telegraph snapshots carry their VFX identity; eleven actor deliveries reserve zero projectiles; scan, choir ring, repair, shock brace, and drop lunge preserve their current effects; cancellation, death, deactivation, and cross-archetype reuse leave no stale sprite, region, tint, timer, or VFX ID.

## 10. WP3 — Focused Integration

WP3 adds a dedicated `test_district_variant_attack_vfx.gd` suite and focused extensions to projectile, emission, archetype, runtime-budget, and district gallery checks. The existing twenty-variant gallery remains exactly twenty and may report VFX delivery/key/region metadata without becoming a release-certification matrix.

**Focused checks:** Godot 4.7.2 script parse, `gdlint` for touched scripts, exact catalog validation, all nine ranged delivery cases, all eleven actor-only cases, support/melee parity, projectile pool saturation, impact cursor wrap, old→variant→old cleanup, atlas cell alpha integrity, and relevant runtime-budget constants. No full `verify.sh` run is permitted under the active override.

## 11. WP4 — Export and Existing WebDev Synchronization

After final source integration, WP4 re-fetches shared `main`, performs a fresh Godot 4.7.2 Web export, and treats that export as the authoritative package measurement. HTML, JavaScript, WASM, and PCK must exist and be nonempty. The PCK must remain at or below 16,777,216 bytes.

The existing `/home/ubuntu/proto-scroller` WebDev project is reused. Fresh WASM and PCK objects are uploaded and remapped even if the engine WASM checksum is unchanged. The fullscreen borderless iframe host remains unchanged. `MEMORY.md`, `ASSETS.md`, `PLAN.md`, and `STRUCTURE.md` record the exact source revision, payload hashes, routes, sizes, checkpoint, and public deployment. The public shell is queried once to confirm the exact immutable routes; broad browser and screenshot certification remains skipped.

## 12. Focused Test Matrix

| Area | Required assertion |
|---|---|
| Catalog | Exact 20 keys, five districts × four, 9/11 delivery split, sixty valid nonempty atlas cells |
| Gameplay parity | Behavior, attack style, projectile kind, speed, damage, anticipation, interval, range, health, threat, collision, and family unchanged |
| Ranged delivery | One existing partition reservation, unique visual and impact keys, unchanged radius/mask/lifetime/damage |
| Support and melee | Zero projectile reservations; unchanged repair/mark/melee results; unique payload and completion visible |
| Telegraph | Same adjusted duration, origin, target, threat scaling, and record capacity; added metadata cannot affect admission |
| Reset | Cancel, death, release, `release_all`, and old→variant→old reuse clear all keys, atlas regions, sprites, impacts, and reservations |
| Capacity | Procedural shells and projectile partitions unchanged; five presentation sprites per procedural shell; bounded cosmetic impact slots only |
| Packaging | Fresh PCK at or below 16 MiB; no master/proposal images inside the Godot resource root |
| Deployment | Existing WebDev project reused; exact final immutable WASM/PCK routes checkpointed and published |

## 13. Completion Record

A package is complete only after focused evidence is recorded, the plan is updated, shared `main` is fetched and semantically integrated without rewriting history, and the milestone is pushed. The final package also requires a fresh export and synchronized existing WebDev checkpoint.

| Work package | Completion | Commit / checkpoint | Focused evidence | Notes |
|---|---|---|---|---|
| WP0 | Completed | `ab0c2ef14c995899e97fcf3d2adb83528169c8c8` | 20 GPT Image 2 masters, 20 embedded proposal plates, 3 atlases, 60/60 nonempty cells, 478,162 runtime source bytes | Visual contact sheet and packed atlases passed the lightweight inspection; no fatal clipping, text, gore, or opaque-background defect. |
| WP1 | Pending | — | — | — |
| WP2 | Pending | — | — | — |
| WP3 | Pending | — | — | — |
| WP4 | Pending | — | — | — |
