# Project CHOIR Boss Runtime Asset Manifest

**Generated:** 2026-08-27

**Engine:** Godot 4.7.2 stable, GL Compatibility, non-threaded Web export

**Runtime source total:** 5,218,716 bytes

**Measured Web PCK:** 16,650,088 bytes

**PCK ceiling:** 16,777,216 bytes

**Remaining PCK headroom:** 127,128 bytes

The five canonical animated boss atlases began with **GPT Image 2** keyframes and locked-camera Veo carriers; the five instrumental themes were generated with **Lyria 3 Pro**. Concept plates and superseded static sprites remain outside the Web PCK. Runtime art is stored as transparent WebP atlases; music is loop-enabled mono Ogg Vorbis at 32 kHz. `BossMusicDirector` reuses one prewarmed player, switches themes by canonical boss ID, preserves music-bus user settings, and restores the city-pressure bed after the encounter.

| Boss | Runtime art | Art bytes | Art SHA-256 | Runtime music | Music bytes | Duration | Music SHA-256 |
|---|---|---:|---|---|---:|---:|---|
| SETTLEMENT ENGINE S-04 | `animated/settlement-engine-s04-atlas.webp` | 439,630 | `14af061156d309f4bbeeafdb033949b00748ee6b6b5bbe0a212e1b3398c4ca5a` | `settlement-engine-s04.ogg` | 216,798 | 43.00 s | `cbcb96809a9668955ff8e7fd6f21c7d8af9ea82aee99b624775d5b4c97532570` |
| SAMARITAN-15 | `animated/samaritan-15-atlas.webp` | 552,632 | `370bea81cdf2aa3f8ee8661df807adaf59610996a17e095b137cd24b8ac70bfc` | `samaritan-15.ogg` | 315,495 | 66.20 s | `958eafe78d7edd0f52a4571b991bee3ba50d0ce3e86a4ba4d7b8e6841311a5bd` |
| MIMESIS-04 | `animated/mimesis-04-atlas.webp` | 644,320 | `335280889d0933bc92ff55e0f45ffe34bc392850b9c6d8a22d0a85f71a32fadf` | `mimesis-04.ogg` | 228,550 | 41.90 s | `10aab4fbbe104a2bcb44d05634737c1724d8cabde6f85ae9cd1028fd3d0d8539` |
| CANTOR-31 / PALE ENGINE | `animated/cantor-31-atlas.webp` | 546,330 | `c2ac2aac49798f5846631f80794bb74f628572b4fde1ff99b3d7d588875e9f0f` | `cantor-31.ogg` | 354,924 | 66.80 s | `25870516f678a4766333284b84be06f3e7cb83c6684dfdf8549103c5890e5a0a` |
| CHOIR PRIME | `animated/choir-prime-atlas.webp` | 774,062 | `18896e73917006c19168ee17e833e2b379aa9d40d0dc246f62d35cef5c8088bb` | `choir-prime.ogg` | 199,916 | 44.10 s | `db3b3ad6d71421c6d88323f58ac04e619e8fa94a616d93fb56b9381054f95ed3` |

## Encounter splash

The shared encounter herald uses `game/art/ui/boss_fight/boss-fight-splash.webp`, a 1,344×576 transparent GPT Image 2 typography asset containing only the exact words **BOSS FIGHT**. The runtime file is 295,302 bytes with SHA-256 `893be721d4b59a440c2293bad2d9ab1421a253eeed66938f506129659ca8b4b0`. Its original generated alternatives and lossless masters remain outside the source repository under `/home/ubuntu/proto-scroller-art-masters/boss-fight/`.

The synchronized 1.18-second voiceover SFX is documented in `game/audio/voice/PROVENANCE.md`. Its industrial impact bed was extracted from a three-second image-conditioned Gemini Omni sound carrier generated from the selected GPT Image 2 typography anchor; the carrier is not shipped in the PCK.

## Settlement Engine shockwave

Settlement Engine S-04's three replacement attacks use `attacks/settlement-shockwave-ring.webp`, a **192×192**, **13,426-byte** alpha WebP with SHA-256 `b0757bf36568d2cd8cae88e06e6dac5d14a8a3be7cc0a01e3f2e51f9df619047`. GPT Image 2 supplied the energy detail; deterministic cleanup retained only the physical annulus. Godot scales that detail across one to three bounded, traveling road-plane pressure fronts while retaining exact telegraph, collision-band, dodge, and damage authority. Complete provenance is recorded in `attacks/PROVENANCE.md`.

## Defeat spectacle

Every boss body defeat triggers one fixed-budget 2.95-second barrage: 12 timed explosion sprites, 10 timed fireworks, eight explosion particle emitters with 34 particles each, six firework emitters with 46 particles each, one positional sound player, and one camera kick. The **22 sprites, 14 emitters, and 548 particles** are prewarmed once in `BossUtilityPool`; generation cleanup never interrupts the body-to-wreck celebration, and retries stop any prior playback before reusing the same nodes.

The two particle textures were generated with **GPT Image 2**. `defeat_fx/boss-explosion-burst.webp` is 21,630 bytes with SHA-256 `30263eb98d01c874373ad6a6589e8efeb0d95b0e9c13c6855320d220c2a53ca7`; `defeat_fx/boss-firework-burst.webp` is 24,008 bytes with SHA-256 `f3890a7fec7e66cecb59db0900a21f57c23caac1e9467d05cabc8ef9bd3b8357`. The positional carrier-derived SFX is 14,795 bytes with SHA-256 `7c98b864e353207d847f858547aacc52fd35ea5718e0e867e3c407fe24e9361b`. Complete carrier and mastering provenance is recorded in `game/audio/sfx/boss/PROVENANCE.md`.

## Export Evidence

| Artifact | Bytes | SHA-256 |
|---|---:|---|
| `game.html` | 17,891 | `b5f1518f5bb5a33628e8d350a075878363b76c7d6962d756c8376a0a8b9a1fed` |
| `game.js` | 279,995 | `9b24675ee72bfd4b2427106b651ce7648e2900350f91ce6c32e2f5e23b4ed11d` |
| `game.wasm` | 39,514,754 | `fc74679e3b97f76878947fcd4fbe1268cbfa6188182a2e33bbc3f5dc9bfa57d0` |
| `game.pck` | 16,650,088 | `955f00db65298150adfd520fc91d95b0dd88bd002b75bf7650da16d3b71677b5` |
