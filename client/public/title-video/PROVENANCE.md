# Cinematic Title Background Provenance

## Purpose

These silent title-screen loops animate the existing title composition as **idle → ground smash → idle**. The original static title artwork remains the orientation-specific preload and decoder-failure fallback.

## Visual references

| Orientation | Canonical reference | GPT Image 2 idle reference SHA-256 |
|---|---|---|
| Landscape | `game/art/ui/title_screen/command_deck_landscape.jpg` | `b909a862fbdf09edf392e7b40c6715316bc9a649dc25014afaf720fbaaf1c21d` |
| Portrait | `game/art/ui/title_screen/command_deck_portrait.jpg` | `44fd52a383ab9d41f85b80f1165b6b5669c6bc816b32d7f14e09eada1fbfe3ac` |

GPT Image 2 created precision-matched idle keyframes while retaining the robot identity, ruined megacity, lighting, and orientation-specific UI-safe space. Those keyframes were supplied as identical first and last frames to enforce a closed loop.

## Video generation

Both loops were generated with **Veo 3.1**, silent, eight seconds, 1080p, with a locked camera and identical first/last keyframes. The prompt required one grounded mechanical smash, restrained dust and sparks, no cuts, no camera motion, no text, and a mechanical return to the exact opening pose.

| Orientation | Generated master | Master SHA-256 |
|---|---|---|
| Landscape | 1920×1080, H.264, 24 fps, 8.0 s | `d50ecd28f9ef7542f2a1d4d21b44f69f27e77ebaab353a100b880d4dd2bb01fe` |
| Portrait | 1080×1920, H.264, 24 fps, 8.0 s | `dc3308e7480c57e63aa927d048a1d8df8a71b0cff5ef0476eefa0734bf21397e` |

## Web masters

The shipping masters were deterministically resized and compressed with FFmpeg while retaining 24 fps, H.264 High Profile, YUV 4:2:0, no audio, and fast-start metadata:

```bash
ffmpeg -i <master> -an -vf 'scale=<target>:flags=lanczos,fps=24' \
  -c:v libx264 -preset slow -crf 27 -profile:v high -level 4.0 \
  -pix_fmt yuv420p -movflags +faststart <shipping.mp4>
```

| File | Geometry | Bytes | SHA-256 |
|---|---:|---:|---|
| `title-loop-landscape.mp4` | 1280×720 | 1,415,095 | `9d1a90b166d071f0e60a0b519ebb2bc9479988d4c99fa25e2d534fd73b161f83` |
| `title-loop-portrait.mp4` | 720×1280 | 1,364,828 | `cd6fabaa3ccb231fb3a992db0a00c55f08c4cae1f0a89206958fb36392096c75` |

## Runtime behavior

The Web host chooses the matching orientation before activation and locks that source when the trusted **Begin Expedition** action occurs. The measured ground-contact/spark frames are **frame 88 at 3.666667 seconds** in landscape and **frame 66 at 2.750000 seconds** in portrait. A `requestAnimationFrame` scheduler samples live video time, compensates for bounded Web Audio output latency, and commits sample-zero production music on the corresponding impact; telemetry is published at `window.__PROTO_SCROLLER_TITLE_MUSIC_SYNC__`. Rotation can switch sources before activation but cannot replace the locked source afterward. The impact remains visible for **350 ms** before title fade-out. Playback or scheduling failure uses a bounded audible fallback so launch is never stranded. Native builds continue to use the canonical static artwork and immediate music startup.
