# Settlement Engine Shockwave VFX Provenance

The production texture `settlement-shockwave-ring.webp` was created on 2026-08-28 for Settlement Engine S-04's traveling ground-shockwave attacks.

The source candidates were generated with **GPT Image 2** as centered, non-directional industrial energy rings on native transparent backgrounds. Candidate A was selected for its thin jagged pressure front, white-hot core, amber plasma, and restrained cyan interference. Candidate B was rejected because its heavier mass and internal low-alpha artifacts would reduce combat readability.

The selected 1,920×1,920 PNG was alpha-cleaned deterministically. The pipeline trimmed transparent padding, retained only pixels inside the physical ring annulus, attenuated low-luminance residuals, resized the accepted detail-only derivative to 192×192, and encoded a compact alpha WebP. Direct alpha inspection confirmed true zero-alpha pixels inside the ring. The final runtime source is **13,426 bytes** with SHA-256 `b0757bf36568d2cd8cae88e06e6dac5d14a8a3be7cc0a01e3f2e51f9df619047`.

Godot scales this texture over deterministic elliptical front geometry. The image contributes high-frequency energy detail only; telegraph timing, wave count, release delay, travel radius, collision, damage deduplication, and fading remain code-owned.

Candidate masters and the deterministic cleanup script remain outside the repository at `/home/ubuntu/work/proto-scroller-quest/boss-shockwave-vfx/`.
