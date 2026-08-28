# Project CHOIR Boss Runtime Asset Manifest

**Generated:** 2026-08-27

**Engine:** Godot 4.7.2 stable, GL Compatibility, non-threaded Web export

**Runtime source total:** 20,017,608 bytes

**Measured 2× Web PCK:** 27,106,300 bytes

**Legacy presentation ceiling:** 16,777,216 bytes

**Explicit 2× fidelity override:** 10,329,084 bytes above the legacy presentation ceiling

The five canonical animated boss atlases began with **GPT Image 2** 2560×1440 keyframes and locked-camera 1280×720 Veo carriers; the five instrumental themes were generated with **Lyria 3 Pro**. Every atlas cell is exactly twice its predecessor in both axes while the on-screen display envelope remains unchanged. Concept plates and generation masters remain outside the Web PCK. Runtime art is stored as transparent high-quality WebP atlases; music is loop-enabled mono Ogg Vorbis at 32 kHz. `BossMusicDirector` reuses one prewarmed player, switches themes by canonical boss ID, preserves music-bus user settings, and restores the city-pressure bed after the encounter. All five preloaded boss themes are explicitly retained by the Web preset; excluding their directory leaves the preloaded runtime script unable to compile.

| Boss | Runtime art | Art bytes | Art SHA-256 | Runtime music | Music bytes | Duration | Music SHA-256 |
|---|---|---:|---|---|---:|---:|---|
| SETTLEMENT ENGINE S-04 | `animated/settlement-engine-s04-atlas.webp` | 2,919,740 | `fdc743acd7cdd381084444ec03fc4a0cacf1aae0c335b64d23a35359d7a98d16` | `settlement-engine-s04.ogg` | 216,798 | 43.00 s | `cbcb96809a9668955ff8e7fd6f21c7d8af9ea82aee99b624775d5b4c97532570` |
| SAMARITAN-15 | `animated/samaritan-15-atlas.webp` | 3,269,904 | `aeba07697d7a12987f92fdbb0d901ec39e5c4b8e37fed07c0d5795d6cf479a19` | `samaritan-15.ogg` | 315,495 | 66.20 s | `958eafe78d7edd0f52a4571b991bee3ba50d0ce3e86a4ba4d7b8e6841311a5bd` |
| MIMESIS-04 | `animated/mimesis-04-atlas.webp` | 4,020,566 | `4bcb21658e081f85395b2fde76b94fb0c3e86c370bc7cb8c67d2bd7f5b12e975` | `mimesis-04.ogg` | 228,550 | 41.90 s | `10aab4fbbe104a2bcb44d05634737c1724d8cabde6f85ae9cd1028fd3d0d8539` |
| CANTOR-31 / PALE ENGINE | `animated/cantor-31-atlas.webp` | 3,216,424 | `0490f2c784cae6bf08d1394591cc1453ca1f54a2563576055fe5c3b3cb1d0822` | `cantor-31.ogg` | 354,924 | 66.80 s | `25870516f678a4766333284b84be06f3e7cb83c6684dfdf8549103c5890e5a0a` |
| CHOIR PRIME | `animated/choir-prime-atlas.webp` | 4,329,232 | `efb37efbe92cf9648fe638af5ed5189b8390a1a4ccf095df6bcc5c42002efce8` | `choir-prime.ogg` | 199,916 | 44.10 s | `db3b3ad6d71421c6d88323f58ac04e619e8fa94a616d93fb56b9381054f95ed3` |

## Encounter splash

The shared encounter herald uses `game/art/ui/boss_fight/boss-fight-splash.webp`, a 1,344×576 transparent GPT Image 2 typography asset containing only the exact words **BOSS FIGHT**. The runtime file is 295,302 bytes with SHA-256 `893be721d4b59a440c2293bad2d9ab1421a253eeed66938f506129659ca8b4b0`. Its original generated alternatives and lossless masters remain outside the source repository under `/home/ubuntu/proto-scroller-art-masters/boss-fight/`.

The synchronized 1.18-second voiceover SFX is documented in `game/audio/voice/PROVENANCE.md`. Its industrial impact bed was extracted from a three-second image-conditioned Gemini Omni sound carrier generated from the selected GPT Image 2 typography anchor; the carrier is not shipped in the PCK.

## Settlement Engine shockwave

Settlement Engine S-04's single **Core Shockwave** adds no dedicated texture. It reuses the player's existing `art/player/vfx/photon_core_orb.png` (**96,541 bytes**, SHA-256 `40c00024feb729d1c7701860c75a38445432707e8449f7d676988d5af66ba7d8`) for 72 converging cyan particles and a massive core sphere, then reuses `art/player/vfx/photon_release_shockwave.png` (**282,040 bytes**, SHA-256 `ec3108f63584358bbba7744c42ad6b872ef468a44eac5bbdb8eafc0cc8ce4cee`) for one outward release. Godot retains exact socket anchoring, charge timing, contact-band collision, dodge, damage deduplication, and cleanup authority. The obsolete 13,426-byte dedicated amber ring and its standalone provenance record were removed.

## Defeat spectacle

Every boss body defeat triggers one fixed-budget 2.95-second barrage: 12 timed explosion sprites, 10 timed fireworks, eight explosion particle emitters with 34 particles each, six firework emitters with 46 particles each, one positional sound player, and one camera kick. The **22 sprites, 14 emitters, and 548 particles** are prewarmed once in `BossUtilityPool`; generation cleanup never interrupts the body-to-wreck celebration, and retries stop any prior playback before reusing the same nodes.

The two particle textures were generated with **GPT Image 2**. `defeat_fx/boss-explosion-burst.webp` is 21,630 bytes with SHA-256 `30263eb98d01c874373ad6a6589e8efeb0d95b0e9c13c6855320d220c2a53ca7`; `defeat_fx/boss-firework-burst.webp` is 24,008 bytes with SHA-256 `f3890a7fec7e66cecb59db0900a21f57c23caac1e9467d05cabc8ef9bd3b8357`. The positional carrier-derived SFX is 14,795 bytes with SHA-256 `7c98b864e353207d847f858547aacc52fd35ea5718e0e867e3c407fe24e9361b`. Complete carrier and mastering provenance is recorded in `game/audio/sfx/boss/PROVENANCE.md`.

## Export Evidence

| Artifact | Bytes | SHA-256 |
|---|---:|---|
| `game.html` | 17,891 | `8ce8bcc864b082e531da82f744ce5678ab37c85e9755fc536f1d070ccfd049b2` |
| `game.js` | 279,995 | `9b24675ee72bfd4b2427106b651ce7648e2900350f91ce6c32e2f5e23b4ed11d` |
| `game.wasm` | 39,514,754 | `fc74679e3b97f76878947fcd4fbe1268cbfa6188182a2e33bbc3f5dc9bfa57d0` |
| `game.pck` | 27,106,300 | `d7f1fdacbd72d55a5d63f55ed62dd3ddba08ab60fdb5f6167bc15535b2bf6cc0` |
