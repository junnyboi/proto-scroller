# Double Punch Impact SFX Provenance

The source was regenerated for Proto Scroller on 2026-08-25 with Manus built-in carrier-video sound generation. The original carrier depicted exactly two forceful heavyweight punches landing on a dense leather punching bag, with a prompt requesting synchronized close-miked leather slaps, low-frequency body thumps, short air displacement, and no music, voices, crowd, metallic clang, explosion, or prolonged ambience. No artist, song, or existing work was referenced.

The carrier audio was extracted, trimmed to 1.08 seconds around the two contact events, converted to 48 kHz mono PCM16, high- and low-pass filtered, reinforced at 85 Hz and 180 Hz, dynamically compressed, peak-controlled, and faded before a separate bag-rebound transient. The result has two visually distinct waveform clusters separated by 0.66 seconds. Godot imports the runtime stream with QOA compression to preserve the Web PCK budget. Source file SHA-256: `88d85d09eb2409e801d2088ce74ad86fb567971f78ce96cc2dd7930666050b50`.

Runtime use: `RobotAnimationPresenter.DOUBLE_PUNCH_IMPACT_SFX`, Mechanics bus, signature priority.
