# Animated Boss Sprite Asset Manifest

**Generated:** 2026-08-27

**Pipeline:** GPT Image 2 keyframes → Veo 3.1 locked-camera carriers → Manus `video-to-sprites` extraction → compact WebP runtime atlases

All five atlases use a uniform eight-column by four-row layout. Rows are `E_moving`, `W_moving`, `E_attacking`, and `W_attacking`; every row contains eight bottom-centered frames. Source carriers are four seconds, 720p, audio-disabled, first/last-keyframe locked, and keyed against `#FF00FF`. Lossless masters, extracted frames, and carrier videos remain outside the repository at `/home/ubuntu/proto-scroller-art-masters/boss-sprites/`.

| Boss | Runtime atlas | Dimensions | Cell | Bytes | SHA-256 | Direction production | Signature attack |
|---|---|---:|---:|---:|---|---|---|
| SETTLEMENT ENGINE S-04 | `settlement-engine-s04-atlas.webp` | 2512×780 | 314×195 | 439,630 | `14af061156d309f4bbeeafdb033949b00748ee6b6b5bbe0a212e1b3398c4ca5a` | Independent E/W carriers | `FORECLOSURE_STAMP` |
| SAMARITAN-15 | `samaritan-15-atlas.webp` | 2768×836 | 346×209 | 552,632 | `370bea81cdf2aa3f8ee8661df807adaf59610996a17e095b137cd24b8ac70bfc` | W mirrored from complete E render | `BLACKOUT_HARVEST` |
| MIMESIS-04 | `mimesis-04-atlas.webp` | 2976×748 | 372×187 | 644,320 | `335280889d0933bc92ff55e0f45ffe34bc392850b9c6d8a22d0a85f71a32fadf` | W mirrored from complete E render | `ARMED_AFTERIMAGE` |
| CANTOR-31 / PALE ENGINE | `cantor-31-atlas.webp` | 2880×848 | 360×212 | 546,330 | `c2ac2aac49798f5846631f80794bb74f628572b4fde1ff99b3d7d588875e9f0f` | W mirrored from complete E render | `COMPRESSION_PSALM` |
| CHOIR Prime | `choir-prime-atlas.webp` | 3072×864 | 384×216 | 774,062 | `18896e73917006c19168ee17e833e2b379aa9d40d0dc246f62d35cef5c8088bb` | Independent E/W carriers | `CROWN_RADIAL_VERDICT` |

## Runtime Contract

`BossAnimationCatalog` preloads one atlas per boss. `BossRig2D` reuses its existing part-zero `Sprite2D` as a filtered region renderer and derives cell size from the atlas grid. The moving state loops at 6 FPS. Attack frames partition into telegraph 0–2, active 3–4, and recovery 5–7 and are selected by the existing controller-stage signals. `CommandBossSession` derives visible direction from the live player position. No animation frame moves sockets, hurt regions, damage footprints, safe lanes, support actors, evidence, wreck receivers, or campaign state.

S-04 and CHOIR Prime use separately generated east and west carriers because their world-semantic archive/pylon architecture is not mirror-safe. SAMARITAN, MIMESIS, and CANTOR derive west by mirroring the complete composited east frame so all asymmetrical machinery flips as one presentation while mechanical world-space geometry remains unchanged.

## Generation Masters

The external master tree stores seven GPT Image 2 anchors, fourteen Veo 3.1 MP4 carriers, twenty keyed sequence manifests, individual transparent frames, five lossless master atlases, and `carrier_inventory.tsv`. These masters are intentionally excluded from Git and Web exports.
