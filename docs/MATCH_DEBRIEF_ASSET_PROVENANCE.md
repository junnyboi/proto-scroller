# After-Action Dossier Asset Provenance

**Production date:** 2026-08-27
**Generator:** Manus built-in image generation
**Model:** `gpt-image-2`
**Processing:** deterministic Pillow + OpenCV cleanup in `scripts/process-match-debrief-assets.py`

## 1. Asset Inventory

| Asset | Purpose | Dimensions | SHA-256 |
|---|---|---:|---|
| `docs/match-debrief-concepts/after-action-dossier-landscape.png` | Landscape product/UI concept | 2560×1440 | `34077a33e1961bf2e06aa09aa07b33c05998ee7aefa52a2e75c5a513f06acf00` |
| `docs/match-debrief-concepts/after-action-dossier-portrait.png` | Portrait product/UI concept | 1440×2560 | `123503fd0703509ce8431d1a03587947c14b004d367089f9517ff7e03cdf7c60` |
| `docs/match-debrief-concepts/after-action-dossier-crest-source.png` | GPT Image 2 crest source with transparent-background generation contract | 1920×1920 | `2fee7ba39a69fe74d0318dba109bc9d3837baa17cc483e5cd952e71aaa687e26` |
| `docs/match-debrief-concepts/after-action-dossier-crest.png` | Clean transparent concept crest | 1024×1024 | `d17b2f196b5ef9b84ab51837cecab9459e2c7bd6fc02a3adc7881a2a61f38592` |
| `game/art/ui/match_debrief/dossier_crest.png` | Bounded transparent runtime crest | 256×256 | `5bfe0e866a77a22368475e850b0cf4e61428dc5809a6aac5c7d3c12f0ee7ff15` |

## 2. Generation Briefs

The landscape brief requested a high-fidelity 16:9 **After-Action Dossier** with a military black-lab forensic-terminal aesthetic, hard rectangular panels, Proto Scroller’s navy/cyan/amber/red palette, score and grade hierarchy, highest combo, career record, weapon affinity, enemy kill matrix, and footer actions. A real 1280×720 Proto Scroller combat screenshot was used only as a style and atmosphere reference.

The portrait brief requested the same information architecture reorganized into a 9:16 mobile stack with large touch targets and explicit safe-area intent. A real 720×1280 Proto Scroller combat screenshot was used only as a style and scale reference.

The crest brief requested one centered, orthographic, text-free reactor/crosshair/evidence-file emblem with dark gunmetal, cyan circuits, an amber core, restrained red warnings, and a neon-green temporary background selected for deterministic removal.

## 3. Deterministic Processing

Run:

```bash
python3 scripts/process-match-debrief-assets.py
```

The script preserves generated pixels while removing residual neon-green chroma, retaining the largest connected visible component, normalizing transparent padding into a square canvas, and producing Lanczos-resampled 1024×1024 and 256×256 PNG derivatives. It does not draw, repaint, synthesize, or add any new visual content.

## 4. Runtime Use

Only `game/art/ui/match_debrief/dossier_crest.png` is referenced by the Godot runtime. The two UI mockups and 1024px crest are design/proposal artifacts. The generated text and illustrative enemy icons in mockups are not treated as game data; localized Godot controls and actual run telemetry remain authoritative.

## 5. Licensing and Originality Notes

Prompts explicitly excluded real-world military insignia, copyrighted franchise branding, letters, numbers, and skull iconography from the crest. The work was generated specifically for Proto Scroller and does not intentionally reproduce a third-party logo or game interface.
