# Building Destruction VFX Generation Notes

GPT Image 2 produced five 1920×1920 source images using the Orison Custody Vault as the visual-style reference: concrete macro chunk, glass macro shard, torn steel macro fragment, demolition dust puff, and cyan-white impact flash.

The silhouettes, material reads, and dystopian industrial finish are suitable. The temporary magenta removal background left visible fringe and horizontal residual lines in preview, so runtime production requires deterministic connected-component isolation, chroma cleanup, transparent trim, square padding, and downscaling. The processing pass must preserve internal dark shading and translucent glass while removing only border-connected background residue.
