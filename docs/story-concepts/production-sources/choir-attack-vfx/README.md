# District CHOIR Attack VFX Asset Provenance

## Generation

All twenty source triptychs in this directory were generated with **GPT Image 2** on 27 August 2026. Each generation used the corresponding approved district enemy concept as a visual reference and requested three isolated elements on a transparent background: a delivery payload, an impact or completion burst, and an anticipation or attack channel. The prompts explicitly prohibited text, gore spectacle, fantasy magic, hidden attacks, persistent hazards, control effects, additional damage instances, collision changes, and new child attackers.

The twenty `*-attack-master.png` files are the unmodified 2304×1536 generation outputs. `manifest.json` records every master, proposal image, delivery class, atlas path, region, content size, runtime byte size, and SHA-256 hash.

## Deterministic Processing

Run the following command from the repository root:

```bash
python3 scripts/process-choir-attack-vfx.py
```

The processor preserves each master, writes a reduced proposal plate under `docs/concepts/choir-attack-vfx/`, slices the master into three equal source columns, trims transparent margins, preserves aspect ratio, rotates only vertically authored physical ranged payloads to the engine's horizontal canonical direction, and packs the results into three 960×768 WebP atlases under `game/art/city/enemies/choir-attacks/`.

Each atlas uses five columns, four rows, and 192×192 cells. Cell order exactly matches `EnemyArchetypeCatalog.DISTRICT_VARIANT_IDS`, with IDs 1–5 in row one, 6–10 in row two, 11–15 in row three, and 16–20 in row four. The three atlases contain sixty unique visual regions while avoiding sixty separate runtime texture imports.

| Atlas | Phase | Source bytes |
|---|---|---:|
| `district-projectile-vfx.webp` | Physical projectile or presentation-only payload | 88,382 |
| `district-impact-vfx.webp` | Physical impact or presentation-only completion | 245,380 |
| `district-attack-vfx.webp` | Anticipation, muzzle, scan, brace, or channel | 144,400 |
| **Total** | Sixty atlas regions | **478,162** |

## Runtime Boundary

Only the three WebP atlases belong to the Godot runtime. The 2304×1536 masters and proposal plates remain under `docs/` and are not packaged by Godot. Ranged variants continue to use existing bullet, shell, or rocket partitions and collision radii. Support and melee payloads remain actor-owned cosmetic sprites with no physics projectile, targetability, collision, status, or independent lifetime.
