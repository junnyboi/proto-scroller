# Building Destruction VFX Asset Provenance

**Generated:** 2026-08-27
**Model:** GPT Image 2
**Purpose:** Material-specific macro debris and section-break particles for Proto Scroller

## Visual direction

All five images were generated against the existing `orison_custody_vault.png` facade as the style reference. Prompts requested isolated, orthographic, side-view game assets with no text, floor, cast shadow, environment, or extra objects. A temporary `#FF00FF` background was selected only for later alpha removal.

| Source concept | Runtime derivative | Intended use | Runtime SHA-256 |
|---|---|---|---|
| `concrete-chunk-source.png` | `concrete_chunk.png` | Textured concrete `DebrisBody2D` and micro-fragments | `7ae01a7461ba11e0fd9477b8dbeb68d574ac61f83a823a97fb7ff10cedc35285` |
| `glass-shard-source.png` | `glass_shard.png` | Textured glass `DebrisBody2D` and micro-fragments | `63ed58efcf385cabb216e094fb3369838b269d84e86e65093a8b593474d709b2` |
| `steel-fragment-source.png` | `steel_fragment.png` | Textured steel `DebrisBody2D` and micro-fragments | `a376dce095e188aa28df68624a4a1bf3f42b37a68528d6c4c409fc47aa812af8` |
| `dust-puff-source.png` | `dust_puff.png` | Expanding dust cloud particles | `8cbc17e5f4bdc2a95de4eeb1a73963e52683f45069ba5ba5c0f3debcb3f9b364` |
| `impact-flash-source.png` | `impact_flash.png` | Short cyan-white section-break flash | `41b428e1d551e712fed08b8a9df736787ae8c36d2cbf3bc773a6529284edb07c` |

## Source hashes

| Source | SHA-256 |
|---|---|
| Concrete chunk | `ab78092b9851c0a9624e9d8bfb8847df0dc331b6669aeb721d98e0a4305fd956` |
| Glass shard | `5fb93ec468d5f73c0e0274b02e717e57e9115e0c76479a5b16aeaa789aa4eb0b` |
| Steel fragment | `d6dd69f48a44dbffab6c48468c9de17a7b97846822dfd5cd7c54ba3dd8024292` |
| Dust puff | `6ceb320b35c83e264812b62460c54357e4f0f699a5b9bc472b33d5ab37318a36` |
| Impact flash | `21e5e69a79cd510c9c171bfa0a34f31f77fa83db33c4a9a219fc21e663175902` |

## Deterministic processing

`scripts/process-building-destruction-vfx-assets.py` performs the complete reproducible runtime conversion:

1. Load the canonical 1920×1920 GPT Image 2 PNG.
2. Remove magenta chroma and antialiased staging residue while preserving neutral shadows, cyan glass, and orange fracture highlights.
3. Select the largest authored connected component.
4. Trim transparent margins, pad to a square canvas, and resize to 128×128 with Lanczos resampling.
5. Zero fully transparent texels and save optimized RGBA PNG output.

The final runtime derivatives contain transparent margins, compact file sizes, no text, and no meaningful chroma residue. They are source-controlled alongside their deterministic rebuild script.
