# Kill-Combo Combat Herald Asset Provenance

**Production date:** 2026-08-27
**Visual generator:** GPT Image 2 (`gpt-image-2`)
**Audio method:** GPT Image 2 anchor → image-conditioned audio-bearing video carrier → deterministic WAV extraction
**Runtime targets:** Godot 4.7.2, GL Compatibility, non-threaded Web

## Visual direction

The six insignias extend the established Proto Scroller UI language captured in `docs/KILL_COMBO_VISUAL_REFERENCE_NOTES.md`: dark gunmetal armor, antique-gold mechanical framing, cyan-white photon filaments, restrained red warning accents, and centered orthographic medallion silhouettes. Generated artwork contains no player-facing text; Godot supplies localized titles.

Each tier prompt requested a materially distinct count geometry:

| Tier | Generated geometry | GPT Image 2 source | Runtime derivative SHA-256 |
|---|---|---|---|
| Double Kill | Twin opposing armored vanes and split corona | `docs/combo-feedback-concepts/double_kill.png` | `1ea0a20ed8950252877f1baed5d96535eefa913f0d9df70922dc66520f499483` |
| Triple Kill | Three major reactor points and concentric pulses | `docs/combo-feedback-concepts/triple_kill.png` | `f517f0742c20ec478b89879f8d1b7525a4ff4778c079e7351cad233734839a29` |
| Overkill | Four heavy vanes and warning-red core | `docs/combo-feedback-concepts/overkill.png` | `4bd3ebca483dd6a3ae30ca7ab7895f42e7deda45689a6ce8f7970c066ea60deb` |
| Unstoppable | Five-segment crown and white-hot center | `docs/combo-feedback-concepts/unstoppable.png` | `21c8e8901bc82414ad24b88bff87e46dde7824752c8ab2cd49da15486a96a36d` |
| Annihilation | Seven-part broken orbital cage | `docs/combo-feedback-concepts/annihilation.png` | `86c85b8c4074032f792760db8feea4fda1b30f71954b42b4300318b87155037f` |
| Extinction Event | Final-tier radial singularity seal | `docs/combo-feedback-concepts/extinction_event.png` | `c8cb5e5caba01855f26ab81aa04b603f27abc9dad9f1bca2d676b5ccc55c971c` |

The transparent generation route used hot pink as a temporary removal color. The tool preserved its raw pre-alpha records as `*_original.png`. `scripts/process-combo-herald-assets.py` removes any residual pink/magenta pixels without touching authored red accents, trims the surviving silhouette, centers it within a transparent 2048×2048 working canvas, and downsamples with Lanczos to a 512×512 optimized runtime PNG under `game/art/ui/combo_herald/`.

Representative 512×512 inspection passed: the Double Kill twin silhouette and Extinction Event radial apex remain distinct at HUD scale; temporary chroma artifacts are absent; alpha boundaries and negative space are clean.

## Carrier anchor

`docs/combo-feedback-concepts/orbital_herald_carrier_anchor.png` was generated with GPT Image 2 at 2560×1440. It depicts an original mechanical orbital command core in the same gunmetal/gold/cyan/red visual language. It contains no humanoid likeness, words, logos, or third-party marks.

- SHA-256: `608707e86df1833de8e86676cba3ebcd7a97b92fb5ef4ec971d463e8ad347eec`

## Original announcer direction

The voice brief requested an original deep adult male bass-baritone **orbital combat herald** with controlled theatrical authority, subtle synthetic command-channel resonance, precise consonants, and intensity rising by tier. Prompts explicitly prohibited music, crowds, ambience, extra words, and imitation of named performers or commercial game announcers.

The requested phrases were:

- “DOUBLE KILL.”
- “TRIPLE KILL.”
- “OVERKILL.”
- “UNSTOPPABLE.”
- “ANNIHILATION.”
- “EXTINCTION EVENT.”

Automated speech-to-text recognized every requested phrase from its carrier before deterministic trimming. The concise record is stored at `docs/combo-feedback-carriers/transcripts.txt`.

## Video-carrier lineage

| Runtime cue | Carrier model | Carrier file | Carrier SHA-256 | Final duration | Runtime WAV SHA-256 |
|---|---|---|---|---:|---|
| Double Kill | Gemini Omni Flash Preview | `double_kill.mp4` | `27be5137ae7f5140f689c3261d863af751992c22754cb17ca7f798f1eefdcd5d` | 1.30 s | `1656a2c123c5fdf506e15a182b94329d6520cee01bab13aa294a70647904b2dc` |
| Triple Kill | Gemini Omni Flash Preview | `triple_kill.mp4` | `86ed1a45cbae0629ca01517c05a58badba88a8acd84cb503a9d0ee89353224c3` | 1.84 s | `7309f462b566943942fe3f0e9d4c33cf30f089c72b8746903848c311bd6c0e39` |
| Overkill | Gemini Omni Flash Preview | `overkill.mp4` | `b6aecb509b49d633998a313450b9ec37f9515b52d15b982bc36cb60158d6125d` | 1.48 s | `ec46974f043468ad9291d63b494e2af52a0173f6003de29963a1a7c30ca0da45` |
| Unstoppable | Veo 3.1 Fast | `unstoppable.mp4` | `a213e875b74a3ee7adb6b3c715b1a86a9aef53ae479215ea83ae4ccd3c55dd92` | 2.14 s | `f88260005b64f8aee224fa0b0e2424230d43d1291c509c3b700e47c7f9962918` |
| Annihilation | Gemini Omni Flash Preview | `annihilation.mp4` | `62472ce7af43fcd87a6eb42fe8b528d79690bacd881f2b1269ebf8989b1917b0` | 1.96 s | `cdb0a33bfc1c57d242c009b5a81f7f8438bcb44856c6e8e6898349d643550afb` |
| Extinction Event | Veo 3.1 Fast | `extinction_event.mp4` | `c002c880b01bab6e4a9127e4e0dde6184d07f703ec75c67713b7aed933d1038a` | 2.82 s | `bfec8830535cb8ecd53d31e95c8ec7b4bd54c8327b1fa5e4644a2428ee60924a` |

Gemini generation capacity was unavailable for the two final calls, so the policy-compliant secondary model generated the Unstoppable and Extinction Event carriers from the same GPT Image 2 anchor and original voice brief.

## Deterministic audio processing

`scripts/process-combo-herald-audio.sh` extracts each carrier’s audio, trims to its speech-verified phrase window, resets timestamps, applies a 10 ms fade-in, normalizes conservatively to `-16 LUFS` with `-1.5 dBTP` ceiling, adds a 120 ms tail pad, and writes 48 kHz mono 16-bit PCM WAV. Only the WAV files under `game/audio/voice/combo/` are runtime dependencies; carrier MP4s remain provenance records.

## Rebuild commands

```bash
python3 scripts/process-combo-herald-assets.py
scripts/process-combo-herald-audio.sh
godot --headless --path game --import
```
