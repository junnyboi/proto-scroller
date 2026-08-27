# Enemy Projectile Impact Animation Implementation Plan

**Status:** Implemented; release synchronization in progress  
**Owner:** Manus Agent 6  
**Integration baseline:** `8501803ba72dce11365e833fe02d7551924e87a9`  
**Engine:** Godot 4.7.2, GL Compatibility, non-threaded Web export

## Objective

The four canonical hostile projectile families—`enemy_bullet`, `enemy_shell`, `enemy_rocket_direct`, and `enemy_rocket_salvo`—previously had authored in-flight bodies but no matching frame animation on collision. This package gives each family a distinct hit-only animation while leaving collision, damage, target masks, speed, lifetime, reservations, pool partitions, and recycle timing unchanged.

## Family Contracts

| Projectile visual key | Impact animation | Display envelope | Frames / rate | Duration | Directional read |
|---|---|---:|---:|---:|---|
| `enemy_bullet` | Directional ricochet spark | 44×32 | 10 / 30 FPS | 0.333 s | Narrow cream pin with cyan needles that fans opposite travel |
| `enemy_shell` | Compact armor-fracture burst | 64×48 | 10 / 24 FPS | 0.417 s | Cream/charcoal fracture crown with cyan seams and restrained amber core |
| `enemy_rocket_direct` | Contained directional detonation | 84×56 | 10 / 30 FPS | 0.333 s | Asymmetric one-sided contact wedge with a tapered backward wake |
| `enemy_rocket_salvo` | Tight multi-fin bloom | 60×44 | 10 / 30 FPS | 0.333 s | Four manufactured lobes around a compact hub, visually distinct from the direct rocket |

Every sequence is authored for incoming local `+X`, rotates to the projectile’s actual impact direction, keeps a fixed contact pivot, and ends on a transparent tenth frame. The visual envelope does not define a blast radius. Bullets do not gain ricochet mechanics; shells and rockets do not gain splash damage, secondary hits, knockback, lingering hazards, hit-stop, or camera shake.

## Asset Production

GPT Image 2 produced the four approved impact anchors from the matching projectile bodies. The shell and direct-rocket sequences use preserved image-conditioned, zero-camera-motion video-to-sprites output. The bullet and salvo sequences were deterministically reconstructed from their accepted GPT Image 2 anchors after a sandbox reset removed their intermediate carriers: fixed-origin scale and opacity stages preserve the generated artwork without introducing procedural replacement art.

The final runtime pipeline removes chroma guides, rejects disconnected carrier noise, applies one union crop per family, normalizes a stable contact pivot, and packs ten transparent frames into compact five-column by two-row PNG atlases. High-resolution anchors and processing QA remain outside `res://`; only the four runtime atlases, their import settings, compact JSON metadata, and a machine-readable provenance manifest enter the repository. Cosmetic texture imports use the established lossy `0.3` Web policy already approved for district attack VFX.

## Semantic Integration with Concurrent District VFX

While this work was running, another session added twenty district CHOIR attack identities, including nine district-specific projectile impacts, an eight-slot cosmetic impact cohort inside `ProjectilePool`, `impact_key` signal routing, and atlas-aware `WeaponImpactEffect2D` configuration. The final implementation preserves that entire feature set rather than introducing a competing pool.

`EnemyAttackVfxCatalog` now owns both groups: its existing district impact map remains unchanged, and four canonical frame-sequence specs are added beside it. `ProjectileVisualCatalog` binds the four canonical projectile bodies to those new impact keys. `WeaponImpactEffect2D` remains backward-compatible with player machine-gun impacts and static district impact regions, but can now play fixed-frame atlases with per-family cell size, frame count, playback rate, display envelope, and contact pivot. The existing eight prewarmed hostile impact slots are reused; no collision node, timer, tween, material, particle system, or damage object is allocated on hit.

## Mechanical Invariants

| Contract | Preserved behavior |
|---|---|
| Projectile partitions | 16 bullets, 4 shells, 4 rockets, and 8 player bullets remain unchanged |
| Impact capacity | Exactly 8 collisionless hostile cosmetic slots; saturation overwrites visual presentation only |
| District VFX | All 20 district identities and all 9 district ranged impact keys remain intact |
| Player impacts | The existing 4-slot machine-gun impact path and texture remain unchanged |
| Damage authority | `Projectile2D` still delivers exactly one existing `DamageEvent` before emitting presentation metadata |
| Cleanup | Timeout and manual release do not emit impacts; release paths clear transient impact presentation |

## Focused Regression Evidence

The final focused GUT file passed **5/5 tests and 201 assertions** on Godot 4.7.2. Coverage includes four atlas dimensions, ten-frame metadata, positive display and playback values, canonical impact-key routing, diagonal orientation, direct-versus-salvo isolation, frame advancement, transparent completion/deactivation, eight-slot fixed capacity, node-count stability, projectile partition and reservation parity, clean reset, and preservation of the player machine-gun path. Repository-wide release certification remains intentionally skipped under the explicit project override.

## Delivery Record

| Stage | Result |
|---|---|
| GPT Image 2 anchors | Completed for all four canonical projectile families |
| Sprite/atlas production | Completed; four accepted ten-frame atlases and dark/light QA composites |
| Concurrent feature merge | Completed against source `8501803`; district CHOIR VFX preserved |
| Focused regression | Passed: 5 tests, 201 assertions |
| Source commit / push | Pending final integration commit |
| Fresh Godot Web export | Pending exact pushed revision |
| WebDev checkpoint / deployment | Pending exact fresh payload synchronization |
