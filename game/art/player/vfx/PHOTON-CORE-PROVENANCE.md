# Photon Core Visual Asset Provenance

The photon-core visual system was generated on **2026-08-25** with **GPT Image 2** using the canonical 1280×720 charged-smash gameplay render as its style reference. Prompts preserved the cream, bronze, and charcoal robot language, dark industrial setting, and amber photon-energy motif while explicitly excluding text, logos, labels, annotations, and watermarks.

| Runtime asset | Purpose | Processing | SHA-256 |
|---|---|---|---|
| `art/player/vfx/photon_core_orb.png` | Growing chest-core sphere, accelerating photon motes, and brief full-charge hit flash | Selected from two 1920×1920 generations; deterministic magenta-key cleanup; alpha crop; Lanczos downscale and transparent 256×256 padding | `40c00024feb729d1c7701860c75a38445432707e8449f7d676988d5af66ba7d8` |
| `art/ui/gameplay/photon_charge_meter_frame.png` | World-space charge meter chassis above the robot | Selected from two 2560×1440 generations; connected-background flood removal; deterministic magenta-residue cleanup; alpha crop; Lanczos downscale to 768×156 | `0445de73e2bcf32b96ef5d8ae9430d3695a32d55882edc9129c90ff88864a78f` |

Raw generations and cleanup scripts remain outside the repository under `/home/ubuntu/proto-scroller-art-masters/photon-core/v1/`. Runtime code uses the generated frame and orb directly; only progress width, transform, modulation, and timing are computed from gameplay state. No runtime texture allocation or generated media request occurs during play.
