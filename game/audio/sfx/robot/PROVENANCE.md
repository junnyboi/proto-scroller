# Robot mechanics SFX provenance

The shipped robot cues were extracted from approved generated-video audio carriers because the built-in Mirelo sound-effect endpoint was unavailable in this session. Carrier files remain outside the export tree under `/home/ubuntu/proto-scroller-art-masters/robot-audio/v1/` and are not committed.

| Shipping cue | Carrier | Carrier SHA-256 | Extraction window | Shipping SHA-256 |
|---|---|---|---|---|
| `robot_footstep.wav` | `robot_footstep_carrier.mp4` | `d016ef61851e6095ade18bd2b2fc9951cd23b68b812ba997c8a0ccfb9b33a2cf` | `1.44–2.32 s` | `ff211252427aa3fd712cbb518777f7c47c17617c67a2c1c222654f3666e7d596` |
| `robot_servo.wav` | `robot_mechanics_carrier.mp4` | `0848869aca5f4005482e1b6edd997ee3f6f1622e604745957e90ee2a7326ed55` | `5.38–6.24 s` | `8440ce660258e84a650451e5a8bb0128c06d3d38cdeac6508776cbc0a7e3ee46` |
| `robot_dodge_servo.wav` | `dodge_servo_carrier.mp4` | `7acd5fe6a102ac9b16c6ba600c64828a8bb43e7d0ff0f302d272b2de3358b239` | `1.08–1.21 s` | `53fb47e79e346d1fcfa74ba683a252f84133ca0ace3b305ed4c7076cc5055824` |

All outputs preserve their carrier's original **48 kHz** rate and ship as mono **PCM16 WAV**. Deterministic post-processing uses stereo-to-mono summing, filtering and emphasis matched to each cue, compression, short edge fades, and peak limiting. The dodge cue deliberately emphasizes 3.4–7.6 kHz so it reads separately from the bass-heavy footsteps and attack mechanics. No synthesized audio, music generator, or image-generated audio ships.

The runtime owns exactly four prewarmed positional voices. Walk servos fire at frames **2** and **15**, foot contacts at frames **5** and **18**, attack windup at frame **0**, piston impact at the authored gameplay commit frame **11**, and the high-pitched dash actuator fires synchronously from `dodge_started`. Alternate pitch and velocity-aware gain provide variation without random timing or additional voices.
