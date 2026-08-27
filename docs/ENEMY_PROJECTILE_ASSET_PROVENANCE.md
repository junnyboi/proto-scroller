# Enemy Projectile Asset Provenance

This ledger covers the **27 implementation items** in the authored enemy projectile and emission initiative: **26 new or replacement GPT Image 2 runtime assets** and **one reuse-only CHOIR composition integration**. Generation masters are archived outside the repository; only fixed-size runtime derivatives are packaged.

> Plan signature: `0bc99def3d945b9af693941ccdcc813163858d15604a74d9e785d80d88b5ef81`. Service request IDs and seeds were not exposed. `prompt_sha256` hashes the normalized production brief recorded in the machine-readable manifest; the complete service prompts remain in the task transcript.

| ID | Family | Runtime source | Runtime px | Display px | SHA-256 | Status |
|---|---|---|---:|---:|---|---|
| A01 | `straight_bullet` | `res://art/enemies/projectiles/straight_bullet_tracer.png` | 96×32 | 36×12 | `3b515105aac3` | **Accepted** |
| A02 | `straight_shell` | `res://art/combat/projectiles/straight_shell.png` | 256×128 | 36×18 | `a8d5383530bc` | **Accepted** |
| A03 | `single_rocket` | `res://art/city/projectiles/enemy_direct_rocket.png` | 256×96 | 42×16 | `4745c7ec7c7e` | **Accepted** |
| A04 | `rocket_spread_salvo` | `res://art/city/projectiles/hostile-spread-rocket.png` | 192×72 | 36×14 | `c2e18607ea2f` | **Accepted** |
| A05 | `target_mark_support` | `res://art/presentation/target_mark_support.png` | 256×256 | 132×132 | `2ba190c4757e` | **Accepted** |
| A06 | `repair_support` | `res://art/city/enemies/effects/repair-support-pulse.png` | 256×128 | 72×36 | `eb48006ac40b` | **Accepted** |
| A07 | `noop_support_pulse` | `res://art/city/effects/support/jammer-pulse.png` | 512×512 | 320×184 | `01027aa72752` | **Accepted** |
| A08 | `noop_support_pulse` | `res://art/city/effects/support/shield-pulse.png` | 512×512 | 400×256 | `5edd30c9eb3a` | **Accepted** |
| A09 | `conventional_melee_lance` | `res://art/city/enemies/attacks/nemesis_melee_lance.png` | 512×128 | 245×61 | `43406e1be7af` | **Accepted** |
| A10 | `choir_contact_melee` | `res://art/presentation/choir_contact_brace.png` | 512×256 | 300×120 | `4ab4ab19b286` | **Accepted** |
| A11 | `choir_contact_melee` | `res://art/presentation/choir_contact_leap.png` | 512×256 | 360×175 | `0297577f634e` | **Accepted** |
| A12 | `choir_contact_melee` | `res://art/presentation/choir_contact_drop.png` | 256×512 | 140×230 | `fb62ab31ac16` | **Accepted** |
| A13 | `choir_contact_melee` | `res://art/presentation/choir_contact_footprint.png` | 512×256 | 220×84 | `e9a191e73726` | **Accepted** |
| A14 | `conventional_reinforcement_deploy` | `res://art/city/enemies/deployment/conventional-reinforcement-deploy.png` | 1024×512 | 150×113 | `cd7cf6683c84` | **Accepted** |
| A15 | `choir_incubation_payload` | `res://art/city/enemies/effects/choir-incubation-payload.png` | 512×512 | 112×88 | `829e4da81dad` | **Accepted** |
| A16 | `boss_lane_footprint` | `res://art/bosses/boss-lane-footprint.png` | 1024×256 | 1024×256 | `b7d853c9ed3a` | **Accepted** |
| A17 | `boss_line_beam` | `res://art/bosses/boss-line-beam.png` | 1024×128 | 1024×128 | `adcde83fb0f8` | **Accepted** |
| A18 | `armed_afterimage` | `res://art/siege/mimesis-armed-afterimage.png` | 512×384 | 60×40 | `f5ddae7ebc6a` | **Accepted** |
| A19 | `empty_boss_utility_placeholders` | `res://art/bosses/utilities/boss-archive-treasury-bracket.png` | 256×256 | 128×112 | `603996ab4f8d` | **Accepted** |
| A20 | `empty_boss_utility_placeholders` | `res://art/bosses/utilities/boss-evacuation-cradle.png` | 256×256 | 152×112 | `509a1899993b` | **Accepted** |
| A21 | `empty_boss_utility_placeholders` | `res://art/bosses/utilities/boss-extraction-clamp.png` | 256×128 | 144×64 | `99805565e3ce` | **Accepted** |
| A22 | `empty_boss_utility_placeholders` | `res://art/bosses/utilities/boss-show-control-cabinet.png` | 256×256 | 104×136 | `4a89145c0ac1` | **Accepted** |
| A23 | `empty_boss_utility_placeholders` | `res://art/bosses/utilities/boss-rubble-bed.png` | 256×128 | 184×64 | `8655a5805629` | **Accepted** |
| A24 | `empty_boss_utility_placeholders` | `res://art/bosses/utilities/boss-freight-reclamation-anchor.png` | 256×256 | 104×80 | `1d217bbd7814` | **Accepted** |
| A25 | `empty_boss_utility_placeholders` | `res://art/bosses/utilities/boss-seraph-production-projection.png` | 256×256 | 176×112 | `1a237f43f8e2` | **Accepted** |
| A26 | `choir_prime_testimony_projection` | `res://art/finale/choir-pylon.png` | 256×512 | 174×174 | `8427e812d9f9` | **Accepted** |
| A27 | `choir_prime_testimony_projection` | `existing EnemyArchetypeCatalog textures; no new file` | existing sources unchanged | 78×112 | `existing cat` | **Accepted** |

## Processing and review

All generation used a temporary `#00FF00` background. Runtime derivatives were rebuilt with a deterministic color-distance key, alpha threshold, transparent-RGB clearing, aspect-preserving crop, and one Lanczos downsample into fixed transparent canvases. The repair pulse received a stricter alpha floor after a warm-light QA composite exposed a faint rectangular matte. Dark and warm-light contact sheets confirmed transparent edges and silhouette separation before integration.

Godot imports use lossless texture compression, disabled mipmaps, `fix_alpha_border=true`, and no premultiplied alpha. Collision, range, damage, timing, target masks, projectile capacity, safe-lane geometry, and boss area geometry remain code-owned. New focused tests cover all four projectile skins, support/non-projectile reservation semantics, truthful carrier counts, Nemesis no-shell fallthrough, boss presentation roles, ECHO collision isolation, prewarmed utility resets, and CHOIR pylon reuse.

## Atlas manifests

- `res://art/city/enemies/deployment/conventional-reinforcement-deploy.json` records Mule, Hive, soldier, Hound pod, and dispatch-flash regions.
- `res://art/city/enemies/effects/choir-incubation-payload.json` records capsule, trail, bay, hatching, and target-mark regions.

## Rollback

The generic procedural projectile and warning branches remain available when a catalog key or authored texture is absent. Presentation sprites carry no collision, and boss ECHO presentation is explicitly unable to arm collision. Reverting the generated assets and catalog mappings restores prior procedural rendering without changing mechanics.
