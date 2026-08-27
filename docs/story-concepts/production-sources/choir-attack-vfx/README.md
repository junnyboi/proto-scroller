# District CHOIR Attack VFX Asset Provenance

## Generation

All twenty source triptychs in this directory were generated with **GPT Image 2** on 27 August 2026. Each generation used the corresponding approved district enemy concept as a visual reference and requested three isolated elements on a transparent background: a delivery payload, an impact or completion burst, and an anticipation or attack channel. The prompts explicitly prohibited text, gore spectacle, fantasy magic, hidden attacks, persistent hazards, control effects, additional damage instances, collision changes, and new child attackers.

The twenty `*_original.png` files are the raw 2304×1536 GPT Image 2 outputs retained by the transparent-background generation pipeline. The corresponding `*-attack-master.png` files are the alpha-cleaned production masters used by deterministic processing. `manifest.json` records every production master, proposal image, delivery class, atlas path, region, content size, runtime byte size, and SHA-256 hash.

## Deterministic Processing

Run the following command from the repository root:

```bash
python3 scripts/process-choir-attack-vfx.py
```

The processor preserves each master, writes a reduced proposal plate under `docs/concepts/choir-attack-vfx/`, slices the master into three equal source columns, trims transparent margins, preserves aspect ratio, rotates only vertically authored physical ranged payloads to the engine's horizontal canonical direction, and packs the results into three 360×288 WebP atlases under `game/art/city/enemies/choir-attacks/`.

Each atlas uses five columns, four rows, and 72×72 cells. Cell order exactly matches `EnemyArchetypeCatalog.DISTRICT_VARIANT_IDS`, with IDs 1–5 in row one, 6–10 in row two, 11–15 in row three, and 16–20 in row four. The three atlases contain sixty unique visual regions while avoiding sixty separate runtime texture imports. A first 192-pixel-cell export exceeded the hard Web package cap; the final 72-pixel cells retain every design while reducing imported texture area by approximately 86 percent.

| Atlas | Phase | Source bytes |
|---|---|---:|
| `district-projectile-vfx.webp` | Physical projectile or presentation-only payload | 21,998 |
| `district-impact-vfx.webp` | Physical impact or presentation-only completion | 51,784 |
| `district-attack-vfx.webp` | Anticipation, muzzle, scan, brace, or channel | 34,342 |
| **Total** | Sixty atlas regions | **108,124** |

## Runtime Boundary

Only the three WebP atlases belong to the Godot runtime. Their `.import` sidecars use lossy mode at quality 0.3 because initial lossless imports exceeded the hard 16 MiB PCK cap; this compression policy applies to no enemy-body, gameplay, UI, or legacy projectile texture. The 2304×1536 masters and proposal plates remain under `docs/` and are not packaged by Godot. Ranged variants continue to use existing bullet, shell, or rocket partitions and collision radii. Support and melee payloads remain actor-owned cosmetic sprites with no physics projectile, targetability, collision, status, or independent lifetime.
