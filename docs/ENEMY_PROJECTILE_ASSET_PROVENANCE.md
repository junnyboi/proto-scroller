# Enemy Projectile Asset Provenance

This ledger covers the **27 implementation items** in the authored enemy projectile and emission initiative: **26 new or replacement GPT Image 2 runtime assets** and **one reuse-only CHOIR composition integration**. Generation masters are archived outside the repository; only fixed-size runtime derivatives are packaged.

The final merged census covers **55 hostile identities**: three base actors, 26 canonical procedural archetypes, 20 district variants, one legacy command boss, and five authored campaign bosses. District variants inherit the authored emission family of their canonical base archetype, so every current identity is covered without duplicating projectile ownership or changing fixed pool capacities.

> Plan signature: `0bc99def3d945b9af693941ccdcc813163858d15604a74d9e785d80d88b5ef81`. Service request IDs and seeds were not exposed. `prompt_sha256` hashes the normalized production brief recorded in the machine-readable manifest; the complete service prompts remain in the task transcript.

| ID | Family | Runtime source | Runtime px | Display px | SHA-256 | Status |
|---|---|---|---:|---:|---|---|
| A01 | `straight_bullet` | `res://art/enemies/projectiles/straight_bullet_tracer.png` | 96×32 | 36×12 | `3b515105aac3` | **Accepted** |
| A02 | `straight_shell` | `res://art/combat/projectiles/straight_shell.png` | 256×128 | 36×18 | `a8d5383530bc` | **Accepted** |
| A03 | `single_rocket` | `res://art/city/projectiles/enemy_direct_rocket.png` | 256×96 | 42×16 | `4745c7ec7c7e` | **Accepted** |
| A04 | `rocket_spread_salvo` | `res://art/city/projectiles/hostile-spread-rocket.png` | 192×72 | 36×14 | `c2e18607ea2f` | **Accepted** |
| A05 | `target_mark_support` | `res://art/presentation/target_mark_support.png` | 256×256 | 132×132 | `2ba190c4757e` | **Accepted** |
| A06 | `repair_support` | `res://art/city/enemies/effects/repair-support-pulse.png` | 256×128 | 72×36 | `eb48006ac40b` | **Accepted** |
| A07 | `noop_support_pulse` | `res://art/city/effects/support/jammer-pulse.png` | 256×256 | 320×184 | `2e811d99aba6` | **Accepted** |
| A08 | `noop_support_pulse` | `res://art/city/effects/support/shield-pulse.png` | 256×256 | 400×256 | `08c286b40d2a` | **Accepted** |
| A09 | `conventional_melee_lance` | `res://art/city/enemies/attacks/nemesis_melee_lance.png` | 256×64 | 245×61 | `718d0789d250` | **Accepted** |
| A10 | `choir_contact_melee` | `res://art/presentation/choir_contact_brace.png` | 256×128 | 300×120 | `fa057fd81664` | **Accepted** |
| A11 | `choir_contact_melee` | `res://art/presentation/choir_contact_leap.png` | 256×128 | 360×175 | `ad7c5d7b6a53` | **Accepted** |
| A12 | `choir_contact_melee` | `res://art/presentation/choir_contact_drop.png` | 128×256 | 140×230 | `2ff8ccdb1051` | **Accepted** |
| A13 | `choir_contact_melee` | `res://art/presentation/choir_contact_footprint.png` | 256×128 | 220×84 | `4834bf308f42` | **Accepted** |
| A14 | `conventional_reinforcement_deploy` | `res://art/city/enemies/deployment/conventional-reinforcement-deploy.png` | 512×256 | 150×113 | `8bdc3ef67b7c` | **Accepted** |
| A15 | `choir_incubation_payload` | `res://art/city/enemies/effects/choir-incubation-payload.png` | 256×256 | 112×88 | `e725f1ee8631` | **Accepted** |
| A16 | `boss_lane_footprint` | `res://art/bosses/boss-lane-footprint.png` | 512×128 | 1024×256 | `4583e61df3af` | **Accepted** |
| A17 | `boss_line_beam` | `res://art/bosses/boss-line-beam.png` | 512×64 | 1024×128 | `45504c79b4e9` | **Accepted** |
| A18 | `armed_afterimage` | `res://art/siege/mimesis-armed-afterimage.png` | 256×192 | 60×40 | `c01f1c2ee373` | **Accepted** |
| A19 | `empty_boss_utility_placeholders` | `res://art/bosses/utilities/boss-archive-treasury-bracket.png` | 256×256 | 128×112 | `603996ab4f8d` | **Accepted** |
| A20 | `empty_boss_utility_placeholders` | `res://art/bosses/utilities/boss-evacuation-cradle.png` | 256×256 | 152×112 | `509a1899993b` | **Accepted** |
| A21 | `empty_boss_utility_placeholders` | `res://art/bosses/utilities/boss-extraction-clamp.png` | 256×128 | 144×64 | `99805565e3ce` | **Accepted** |
| A22 | `empty_boss_utility_placeholders` | `res://art/bosses/utilities/boss-show-control-cabinet.png` | 256×256 | 104×136 | `4a89145c0ac1` | **Accepted** |
| A23 | `empty_boss_utility_placeholders` | `res://art/bosses/utilities/boss-rubble-bed.png` | 256×128 | 184×64 | `8655a5805629` | **Accepted** |
| A24 | `empty_boss_utility_placeholders` | `res://art/bosses/utilities/boss-freight-reclamation-anchor.png` | 256×256 | 104×80 | `1d217bbd7814` | **Accepted** |
| A25 | `empty_boss_utility_placeholders` | `res://art/bosses/utilities/boss-seraph-production-projection.png` | 256×256 | 176×112 | `1a237f43f8e2` | **Accepted** |
| A26 | `choir_prime_testimony_projection` | `res://art/finale/choir-pylon.png` | 128×256 | 174×174 | `320c696c1f00` | **Accepted** |
| A27 | `choir_prime_testimony_projection` | `existing EnemyArchetypeCatalog textures; no new file` | existing sources unchanged | 78×112 | `existing cat` | **Accepted** |

## Processing and review

All generation used a temporary `#00FF00` background. Runtime derivatives were rebuilt with a deterministic color-distance key, alpha threshold, transparent-RGB clearing, aspect-preserving crop, and one Lanczos downsample into fixed transparent canvases. The repair pulse received a stricter alpha floor after a warm-light QA composite exposed a faint rectangular matte. Dark and warm-light contact sheets confirmed transparent edges and silhouette separation before integration.

The final merged package initially measured **17,590,236 bytes**, exceeding the 16 MiB ceiling by 813,020 bytes. A single deterministic Lanczos pass reduced 13 presentation-only derivatives from 2,115,794 to 603,434 source bytes. Their existing world display dimensions were preserved through texture-rect sizing, scale correction, or half-resolution atlas regions. The final merged PCK is **16,513,100 bytes**, leaving **264,116 bytes** of headroom.

Godot imports use lossless texture compression, disabled mipmaps, `fix_alpha_border=true`, and no premultiplied alpha. Collision, range, damage, timing, target masks, projectile capacity, safe-lane geometry, and boss area geometry remain code-owned. New focused tests cover all four projectile skins, all 46 spawnable procedural identities, support/non-projectile reservation semantics, truthful carrier counts, Nemesis no-shell fallthrough, boss presentation roles, ECHO collision isolation, prewarmed utility resets, and CHOIR pylon reuse.

## Atlas manifests

- `res://art/city/enemies/deployment/conventional-reinforcement-deploy.json` records half-resolution Mule, Hive, soldier, Hound pod, and dispatch-flash regions.
- `res://art/city/enemies/effects/choir-incubation-payload.json` records half-resolution capsule, trail, bay, hatching, and target-mark regions.

## Rollback

The generic procedural projectile and warning branches remain available when a catalog key or authored texture is absent. Presentation sprites carry no collision, and boss ECHO presentation is explicitly unable to arm collision. Reverting the generated assets and catalog mappings restores prior procedural rendering without changing mechanics.
