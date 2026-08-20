# Voice cue provenance

The shipped `dodge_ready.wav` was generated with the built-in Manus speech service using the **Kore** voice and the prompt below. It announces the exact cooldown transition once per completed dodge recharge.

> Speak in English with a firm, concise onboard combat-computer tone. Deliver the line briskly and clearly, with no preamble and no trailing commentary: Dodge ready.

| Field | Value |
|---|---|
| Service | Built-in Manus speech generation |
| Voice | `Kore` |
| Language | `en-US` |
| Generated source SHA-256 | `11c583de70702be2eefc1871a670fe355b7e64d3d1ca593957a2ce94b415819e` |
| Generated source format | 24 kHz, mono, PCM16 WAV |
| Shipping SHA-256 | `de0a35f18cdd6d9aef5a0ca197dce87270ebd9391480f13bf55764d8ed4ce42a` |
| Shipping format | 48 kHz, mono, PCM16 WAV, approximately 1.0 second |
| Processing | Leading and trailing silence trim, 40 ms tail pad, 48 kHz PCM16 conversion |
| Verification | Speech-to-text transcription: `Dodge ready` |

The generated source and transcription evidence remain outside the committed export tree. The runtime uses one dedicated, prewarmed non-positional status voice so the announcement is not recycled by footsteps, servos, or attack impacts.
