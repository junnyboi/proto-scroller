# Project CHOIR Runtime Boss Art

The five canonical bosses now render from video-derived transparent WebP atlases in `animated/`. The pipeline began with the approved character plates in `docs/concepts/district-bosses/` and the original GPT Image 2 static runtime sprites, generated fresh hot-pink keyframes with **GPT Image 2**, created locked-camera audio-disabled motion carriers with **Veo 3.1**, and extracted normalized frames through Manus `video-to-sprites`.

| Boss | Runtime atlas | Source concept |
|---|---|---|
| SETTLEMENT ENGINE S-04 | `animated/settlement-engine-s04-atlas.webp` | `docs/concepts/district-bosses/01-business-settlement-engine-s04.jpg` |
| SAMARITAN-15 | `animated/samaritan-15-atlas.webp` | `docs/concepts/district-bosses/02-residential-samaritan15.jpg` |
| MIMESIS-04 | `animated/mimesis-04-atlas.webp` | `docs/concepts/district-bosses/03-entertainment-mimesis04.jpg` |
| CANTOR-31 / PALE ENGINE | `animated/cantor-31-atlas.webp` | `docs/concepts/district-bosses/04-military-cantor31-pale-engine.jpg` |
| CHOIR Prime | `animated/choir-prime-atlas.webp` | `docs/concepts/district-bosses/05-royal-choir-prime.jpg` |

Every atlas contains four eight-frame rows: east moving, west moving, east attacking, and west attacking. S-04 and CHOIR Prime use independently generated directional carriers to preserve world-semantic archive and named-pylon placement. SAMARITAN, MIMESIS, and CANTOR derive west by mirroring the complete rendered east frame. Runtime art is compact lossy WebP with exact alpha; lossless atlases, individual frames, anchors, and carrier MP4s remain outside source at `/home/ubuntu/proto-scroller-art-masters/boss-sprites/`.

The original static sprites remain beside this file as archival identity references. They are no longer loaded by `BossRig2D`.

The animated art reuses one prewarmed `BossRig2D`; mechanical weak points, sockets, pylons, markers, hurt regions, telegraphs, attack areas, and wreck receivers remain separate Godot nodes rather than baked image labels. Animation changes presentation only and cannot alter damage timing, collision geometry, evidence, pooling, retries, or campaign progression. Exact runtime dimensions, hashes, and pipeline provenance are recorded in [`animated/ANIMATION_ASSET_MANIFEST.md`](animated/ANIMATION_ASSET_MANIFEST.md).
