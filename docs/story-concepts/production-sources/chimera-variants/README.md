# District Chimera Variant Asset Provenance

## Generation

All twenty source images in this directory were generated specifically for Proto Scroller with **GPT Image 2** on 2026-08-27. Each request used the approved district-roster description, requested an isolated side-view production sprite, used `#FF00FF` as the temporary removable background, and referenced the existing Project CHOIR concept language in:

- `docs/story-concepts/02-reclaimed-breacher.jpg`
- `docs/story-concepts/03-choir-siren.jpg`
- `docs/story-concepts/04-seraph-carrier.jpg`

The generation constraints required recognizable human, rescue, medical, or civic origins; containment glass; synthetic membrane; cyan memory light; and a tragic engineered-horror tone. Prompts explicitly prohibited exposed-organ gore, comedy zombies, fantasy mutation, environmental scenery, hidden silhouettes, and non-production typography.

## Source and Derivative Contract

Files named `01-…-source.png` through `20-…-source.png` are lossless GPT Image 2 production masters and remain outside the Godot runtime. `roster-design.json` preserves the structured approved design used to generate the proposal and implementation data.

The deterministic processor `scripts/process-district-enemy-assets.py` removes residual magenta chroma, trims transparent margins, and emits two derivatives per source:

1. A cleaned proposal concept under `docs/concepts/district-enemies/` with a maximum dimension of 1100 pixels.
2. A compact Godot runtime sprite under `game/art/city/enemies/archetypes/`, numbered `27` through `46`, with a maximum dimension from 320 to 448 pixels according to silhouette class.

The proposal concepts are documentation artifacts. Only the numbered runtime derivatives are imported into `game/` and therefore contribute to the Web PCK.

## Roster Order

| Source | Runtime | Enemy |
|---:|---:|---|
| 01 | 27 | Covenant Warden |
| 02 | 28 | Mercy Recovery Cart |
| 03 | 29 | Testament Kite |
| 04 | 30 | Receivership Ambulance |
| 05 | 31 | Intake Shepherd |
| 06 | 32 | Evacuation Litter |
| 07 | 33 | Rainvault Pressure Ward |
| 08 | 34 | Balcony Recall Beacon |
| 09 | 35 | Memorial Usher |
| 10 | 36 | Glassback Double |
| 11 | 37 | Recall Lantern |
| 12 | 38 | Marquee Anesthetist |
| 13 | 39 | Suture Marshal |
| 14 | 40 | Mercy Raker |
| 15 | 41 | Revetment Ward |
| 16 | 42 | Triage Kite |
| 17 | 43 | Privy Chirurgeon |
| 18 | 44 | Laureate Courser |
| 19 | 45 | Ninefold Witness |
| 20 | 46 | Regency Conservator |
