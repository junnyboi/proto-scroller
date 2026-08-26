# Final Weapon Shop Asset Provenance

All static weapon-shop UI and transaction-effect artwork in this directory was generated on **2026-08-26** with **GPT Image 2** (`gpt-image-2`) under the accepted visual direction in `docs/WEAPON_SHOP_SYSTEM_PROPOSAL.md` and the production contract in `docs/WEAPON_SHOP_NG_PLUS_IMPLEMENTATION_PLAN.md`.

The source set contains five 2560×1440 district backplates, five 1920×1920 transparent operator portraits, five 2560×1440 transparent three-product atlases containing all fifteen catalog modules, a transparent confirmation frame, transparent before/after preview frame, Rampage Credit sigil, upgrade-success burst, repair-success burst, and New Game+ insignia. The backplates were guided by the accepted district concept paintings. Generated artwork contains no runtime text; all words and values remain localized Godot controls.

`prepare_runtime_assets.py` is the deterministic source-to-runtime pipeline. It darkens and resizes backplates to 1280×720, contains portraits at 512×512, slices each product atlas into its catalog-ordered thirds and contains the result at 256×256, resizes shared graphics, and encodes lossless-alpha WebP derivatives under `game/art/ui/weapon_shop/`. The 31 runtime files total **1,211,952 bytes**, below the 1.5 MiB art budget in the implementation plan.

The visual QA contact sheets and findings verify five distinct, UI-safe backplates; five complete transparent character silhouettes; exactly fifteen separated, text-free module objects; clean transparent frame wells; and distinct upgrade, repair, credit, and cycle iconography. Temporary non-transparent originals emitted during alpha extraction were deleted after the transparent masters were validated.

The two 2560×1440 carrier anchors in `audio-carriers/` were also generated with GPT Image 2. They depict the exact pre-action moments for a weapon-module latch and giant-armor nanoweld repair and were used only to generate synchronized SFX carriers.
