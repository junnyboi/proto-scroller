# Tactical AI Voice Provenance

The original English tactical AI lines were regenerated together on 2026-08-24 with the same Manus text-to-speech voice (`Gacrux`) and performance direction: a mature, low-register, velvet-smooth female tactical AI with intimate confidence, restrained delivery, subtle synthetic poise, and crisp combat-system timing. The 2026-08-25 `fully_charged.wav` addition uses the same role and delivery direction. The Manus Gacrux endpoint failed on three attempts and two native voice-carrier requests reported capacity exhaustion, so this one line uses a mature US-English neural female fallback (`en-US-AriaNeural`) rather than silently omitting the required cue. No real person, brand character, or existing performance was referenced.

| Runtime File | Spoken Line | Duration | SHA-256 |
|---|---|---:|---|
| `air_target_acquired.wav` | “Air target acquired.” | 1.806 s | `dbadc3724e34219b04528cc2c735f1e495b4cbc448c352f0e6a5eec2bf5ddb40` |
| `target_lost.wav` | “Target lost.” | 1.310 s | `419a1b1d781564f6c3204cdf30ebd1c9eca4b325242b50355f038e06925cc88d` |
| `target_destroyed.wav` | “Target destroyed.” | 1.392 s | `aa6612e9d06a33f130def28a516acf14e1bfcf3082fdbbe6cd1d82f0e94c35e5` |
| `fully_charged.wav` | “Fully charged!” | 1.009 s | `cda9ffd18ddc71a719c053d0290ff264bda6e39f7effcbe6d51cc9b0984a77de` |

Each source is silence-trimmed, high- and low-pass filtered, lightly compressed, loudness-matched, and exported as 48 kHz mono PCM16. Godot imports runtime streams with QOA compression to preserve the Web PCK budget. Runtime routing remains on the `Voice` bus. Automated speech-to-text verified the new line as “Fully charged.” The full-charge announcement plays once upon reaching the two-second cap; it does not replay while the button remains held.
