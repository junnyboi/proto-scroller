# Project CHOIR Runtime Boss Art

These five transparent WebP assets were generated with **GPT Image 2** on 2026-08-26 from the approved plates in `docs/concepts/district-bosses/`. They are runtime presentation sprites, not concept art, and follow the side-view painterly industrial style of Proto Scroller.

| Boss | Runtime asset | Source concept |
|---|---|---|
| SETTLEMENT ENGINE S-04 | `settlement-engine-s04.webp` | `docs/concepts/district-bosses/01-business-settlement-engine-s04.jpg` |
| SAMARITAN-15 | `samaritan-15.webp` | `docs/concepts/district-bosses/02-residential-samaritan15.jpg` |
| MIMESIS-04 | `mimesis-04.webp` | `docs/concepts/district-bosses/03-entertainment-mimesis04.jpg` |
| CANTOR-31 / PALE ENGINE | `cantor-31.webp` | `docs/concepts/district-bosses/04-military-cantor31-pale-engine.jpg` |
| CHOIR Prime | `choir-prime.webp` | `docs/concepts/district-bosses/05-royal-choir-prime.jpg` |

The generated 2304×1536 masters remain outside the source repository under `/home/ubuntu/generated-raw/proto-scroller-bosses/images/`. Runtime files are deterministically alpha-cleaned, trimmed, fitted to a shared 512×384 transparent canvas, and encoded as quality-84 WebP. No boss art is procedurally drawn at runtime.

The art is intended for one reusable `BossRig2D`; mechanical weak points, pylons, markers, hurt regions, and telegraphs remain prewarmed Godot nodes rather than baked image labels. This preserves accessibility, collision accuracy, portrait/landscape parity, and fixed allocation.
