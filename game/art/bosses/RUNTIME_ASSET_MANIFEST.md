# Project CHOIR Boss Runtime Asset Manifest

**Generated:** 2026-08-27

**Engine:** Godot 4.7.2 stable, GL Compatibility, non-threaded Web export

**Runtime source total:** 1,571,351 bytes

**Measured Web PCK:** 11,504,828 bytes

**PCK ceiling:** 16,777,216 bytes

**Remaining PCK headroom:** 5,272,388 bytes

The five boss silhouettes were generated with **GPT Image 2** and the five instrumental themes with **Lyria 3 Pro**. Concept plates remain documentation-only. Runtime art is stored as trimmed transparent WebP; music is loop-enabled mono Ogg Vorbis at 32 kHz. `BossMusicDirector` reuses one prewarmed player, switches themes by canonical boss ID, preserves music-bus user settings, and restores the city-pressure bed after the encounter.

| Boss | Runtime art | Art bytes | Art SHA-256 | Runtime music | Music bytes | Duration | Music SHA-256 |
|---|---|---:|---|---|---:|---:|---|
| SETTLEMENT ENGINE S-04 | `settlement-engine-s04.webp` | 37,738 | `94d62151da5982da4a81915f6a3cc3d924df38342f29f0d85304a99252c1fe36` | `settlement-engine-s04.ogg` | 216,798 | 43.00 s | `cbcb96809a9668955ff8e7fd6f21c7d8af9ea82aee99b624775d5b4c97532570` |
| SAMARITAN-15 | `samaritan-15.webp` | 40,774 | `86752d8107c8f3cb296411def800af12c16e486edd6bc42b97111ee30c9d4356` | `samaritan-15.ogg` | 315,495 | 66.20 s | `958eafe78d7edd0f52a4571b991bee3ba50d0ce3e86a4ba4d7b8e6841311a5bd` |
| MIMESIS-04 | `mimesis-04.webp` | 60,524 | `7c224db0bf3f71fcb966969a6f0d73121c8ec7e7e3d169f2bfaae0f10715b818` | `mimesis-04.ogg` | 228,550 | 41.90 s | `10aab4fbbe104a2bcb44d05634737c1724d8cabde6f85ae9cd1028fd3d0d8539` |
| CANTOR-31 / PALE ENGINE | `cantor-31.webp` | 56,750 | `da58a783d57cc396688b454daab7b55bc1b1be42ee9139426d6775f161264d3c` | `cantor-31.ogg` | 354,924 | 66.80 s | `25870516f678a4766333284b84be06f3e7cb83c6684dfdf8549103c5890e5a0a` |
| CHOIR PRIME | `choir-prime.webp` | 59,882 | `53f4bd855074d7677dc0f92f588cc99172550530cfc938bf3be6601734056376` | `choir-prime.ogg` | 199,916 | 44.10 s | `db3b3ad6d71421c6d88323f58ac04e619e8fa94a616d93fb56b9381054f95ed3` |

## Encounter splash

The shared encounter herald uses `game/art/ui/boss_fight/boss-fight-splash.webp`, a 1,344×576 transparent GPT Image 2 typography asset containing only the exact words **BOSS FIGHT**. The runtime file is 295,302 bytes with SHA-256 `893be721d4b59a440c2293bad2d9ab1421a253eeed66938f506129659ca8b4b0`. Its original generated alternatives and lossless masters remain outside the source repository under `/home/ubuntu/proto-scroller-art-masters/boss-fight/`.

The synchronized 1.18-second voiceover SFX is documented in `game/audio/voice/PROVENANCE.md`. Its industrial impact bed was extracted from a three-second image-conditioned Gemini Omni sound carrier generated from the selected GPT Image 2 typography anchor; the carrier is not shipped in the PCK.

## Export Evidence

| Artifact | Bytes | SHA-256 |
|---|---:|---|
| `game.html` | 5,439 | `2ddf42055e4c5aaeb014251a09eb9e21d3ff658998a9c1ffefe9eb3ef7b77c3f` |
| `game.js` | 279,815 | `33c94cb3175f3333b82e2a3be5e8e86f77986f0aa2042b1631f6367a4e5bb6ba` |
| `game.wasm` | 39,514,754 | `fc74679e3b97f76878947fcd4fbe1268cbfa6188182a2e33bbc3f5dc9bfa57d0` |
| `game.pck` | 11,504,828 | `109a6d8f85980ff8e99720baa226401a4f5830a7a34a927cd635a40060fa429c` |
