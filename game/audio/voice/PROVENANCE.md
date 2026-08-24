# Tactical AI Voice Provenance

All active English tactical AI lines were regenerated together on 2026-08-24 with the same Manus text-to-speech voice (`Gacrux`) and performance direction: a mature, low-register, velvet-smooth female tactical AI with intimate, quietly alluring confidence, restrained delivery, subtle synthetic poise, and crisp combat-system timing. No real person, brand, character, or existing performance was referenced.

| Runtime File | Spoken Line | Duration | SHA-256 |
|---|---|---:|---|
| `air_target_acquired.wav` | “Air target acquired.” | 1.806 s | `dbadc3724e34219b04528cc2c735f1e495b4cbc448c352f0e6a5eec2bf5ddb40` |
| `target_lost.wav` | “Target lost.” | 1.310 s | `419a1b1d781564f6c3204cdf30ebd1c9eca4b325242b50355f038e06925cc88d` |
| `target_destroyed.wav` | “Target destroyed.” | 1.392 s | `aa6612e9d06a33f130def28a516acf14e1bfcf3082fdbbe6cd1d82f0e94c35e5` |

Each generated source was silence-trimmed, high- and low-pass filtered, lightly compressed, loudness-matched, and exported as 48 kHz mono PCM16. Godot imports the runtime streams with QOA compression to preserve the Web PCK budget. Runtime routing remains on the `Voice` bus. The destroyed line is selected only when an acquired target becomes dead; targets that leave the valid lock cone still use the regenerated loss line.
