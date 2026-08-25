# Robot mechanics SFX provenance

The shipped robot cues were extracted from approved generated-video audio carriers because the built-in Mirelo sound-effect endpoint was unavailable in this session. Carrier files remain outside the export tree under `/home/ubuntu/proto-scroller-art-masters/robot-audio/v1/` and are not committed.

| Shipping cue | Carrier | Carrier SHA-256 | Extraction window | Shipping SHA-256 |
|---|---|---|---|---|
| `robot_footstep.wav` | `robot_footstep_carrier.mp4` | `d016ef61851e6095ade18bd2b2fc9951cd23b68b812ba997c8a0ccfb9b33a2cf` | `1.44–2.32 s` | `ff211252427aa3fd712cbb518777f7c47c17617c67a2c1c222654f3666e7d596` |
| `robot_servo.wav` | `robot_mechanics_carrier.mp4` | `0848869aca5f4005482e1b6edd997ee3f6f1622e604745957e90ee2a7326ed55` | `5.38–6.24 s` | `8440ce660258e84a650451e5a8bb0128c06d3d38cdeac6508776cbc0a7e3ee46` |
| `robot_dash_warp_drive.wav` | `dash-warp-carrier.mp4` | `7d8d0a964d44920e45fd1fc15ab6c05c57275dc53d6c72063b0e6a89b39d93ea` | `0.00–1.70 s` | `c5a3fcb39aebc497135b208212bca5ee592ed7c52083ef525fd00b0fd8048203` |

All outputs preserve their carrier's original **48 kHz** rate and ship as mono **PCM16 WAV**. Deterministic post-processing uses stereo-to-mono summing, filtering and emphasis matched to each cue, compression, short edge fades, and peak limiting. The current dash cue uses a Lyria-generated source inside the required GPT Image 2 carrier pipeline; no procedural oscillator synthesis or image-generated audio ships.

The runtime owns exactly four prewarmed positional voices. Walk servos fire at frames **2** and **15**, foot contacts at frames **5** and **18**, attack windup at frame **0**, and the ground-slam impact fires at the authored gameplay commit frame **11**. The double-punch composite begins at frame **11** and contains a second impact exactly **250 ms** later for the opposite fist's frame-**14** extension. Both ground-slam and double-punch playback apply an exact **0.75 linear gain** (`−2.4987747322 dB`) after their existing impact gain, reducing perceived output by 25 percent without rewriting either approved source master. The warp-drive cue fires synchronously from `dodge_started`. Alternate pitch and velocity-aware gain provide variation without random timing or additional voices.

## Warp-drive dash cue

The 2026-08-25 Dash update follows the project-required carrier workflow. GPT Image 2 generated a 2560×1440 visual anchor from the canonical title art, depicting the cream-and-black robot crossing a cyan space-fold ring. Lyria generated the original non-verbal source from a three-second, timestamped sound brief: electromechanical ignition, rising Doppler fold, compact sub-bass displacement, and reverse-suction decay, explicitly excluding music, speech, alarms, gunfire, and generic explosions. Because all three native-audio video generators reported temporary capacity exhaustion, the approved anchor and generated audio were wrapped into a deterministic three-second H.264/AAC carrier before the shipping audio was extracted from that carrier.

The extracted carrier audio was trimmed and mastered to **1.70 seconds**, 48 kHz mono PCM16, with a 38 Hz high-pass, 14.5 kHz low-pass, compression, +3 dB gain, peak limiting, and a 400 ms tail fade. It measures approximately **−19.1 LUFS integrated** with a **−1.4 dBFS** peak, contains no clipped/flat samples, and produced an empty speech transcript. Anchor SHA-256: `53007910f295b14f4361498a375f0b4f41c7fc37d33c88a48340b2fb2784c298`. Lyria source SHA-256: `f96bce1fa01ee1dbd33e497a8f1cdb26a5e4e405f57d45ae70cb2de8d1934748`. Carrier-extracted PCM SHA-256: `0c259eaf8b7f5b215133a9c8b9d50c137cddb64889fd9a12123822b3abb83353`.
