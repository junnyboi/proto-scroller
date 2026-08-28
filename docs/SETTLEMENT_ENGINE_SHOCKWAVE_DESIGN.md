# Settlement Engine S-04 Core Shockwave Design

**Author:** Manus AI

**Status:** Implemented, focused-verified, and release-managed

**Scope:** Remove Settlement Engine S-04's existing attack patterns and amber multi-front telegraphs. Replace them with one readable, repeatable charge-and-release attack centered on the visible core of the boss sprite.

## Design Intent

Settlement Engine S-04 now communicates one combat promise: **energy gathers at the core, the core becomes critically bright, and one shockwave leaves that exact point**. The presentation intentionally mirrors the player's charged melee language so the mechanic is immediately legible without range rails, ghost rings, spoke counters, pattern rotations, or a separate telegraph vocabulary.[1] [2]

> **Core readability rule:** every cyan photon moves toward the same growing blue sphere that becomes the origin of the damaging shockwave.

The redesign preserves the boss's armor and body phases, support-soldier cap, archive objective, optional structural transactions, animation rig, damage scaling, grounded rubble, evidence outcome, retry state, and campaign progression. A later campaign-wide revision removes the corpse finisher: the completed 2.95-second destruction spectacle now commits rubble and progression automatically.[3]

## Single Attack Cycle

| Stage | Duration | Presentation | Damage state |
| --- | ---: | --- | --- |
| **Charge** | 1.45 s | Seventy-two cyan-blue photon motes converge from a 300-pixel sphere into the boss's visible `CORE` socket. A blue energy sphere grows from 54 to approximately 238 pixels while a 1.45-second carrier-derived electrical rise accelerates toward release. | Harmless. The particles, sphere, and rising cue are the complete telegraph. |
| **Release** | 1.05 s | The incoming motes, core sphere, and charge cue stop at one state boundary. One cyan-white circular shockwave expands from the same core to a 900-pixel radius, accompanied by a one-second pressure cue and one restrained 10-unit camera impulse. | Only contact with the moving ring band inflicts damage. |
| **Recovery** | 0.75 s | The shockwave is culled and the boss completes its recovery animation. | Harmless. S-04 may replenish its bounded support squad. |

The same cycle repeats during armored, exposed, and final-health combat. There is no hidden alternate pattern and no phase-dependent change in front count. The HUD exposes only **CORE SHOCKWAVE // CHARGING**.

## Visual Language

The charge reuses the exact player photon source assets rather than introducing another visual dialect or increasing the Web package budget. `photon_core_orb.png` supplies both the converging motes and the energy sphere. `photon_release_shockwave.png` supplies the expanding release surface. S-04 shifts both toward saturated cyan and electric blue, scales the core far beyond the player's chest orb, and keeps all movement code-owned.[2] [4]

The prior dedicated ring texture, amber range fill, road-plane ellipse, range rail, ghost fronts, countdown spokes, delayed extra fronts, and red-white terminal strobe are removed. No generated image replaces them because the requested player-style photon assets already exist in the shipped runtime and provide stronger visual continuity.

Two compact positional cues provide the requested synchronized audio language. The 1.45-second charge begins with the harmless telegraph and is stopped at the release boundary; the one-second shockwave cue begins on that same boundary. Both cues were extracted from separate GPT Image 2-conditioned sound carrier videos and route through the existing SFX bus. No speech, melody, or background music is present.[2]

## Damage and Collision Contract

The active shockwave is a true circular contact band centered at the visible boss core. Collision compares the player's world position with the current ring radius rather than treating the complete interior as dangerous. Standing inside a ring that has not reached the player is safe; standing behind a ring that has passed is safe; touching the visible leading band is dangerous.

| Parameter | Value |
| --- | ---: |
| Shockwave count | 1 |
| Maximum radius | 900 px |
| Travel duration | 1.00 s |
| Contact-band thickness | 92 px |
| Base damage | 66 |
| Global hostile-output multiplier | 0.75 |
| Effective cycle-one damage | 49.5 |
| Damage deduplication | Once per attack activation |
| Dodge interaction | Timed dodge invulnerability rejects contact damage |

The attack remains a hazard-tagged enemy event and continues to apply the central New Game+ cycle multiplier before the global hostile-output multiplier. The attack does not use `FLAG_UNBLOCKABLE`; the player's authored 0.30-second dodge window remains valid counterplay.[1] [5]

## Runtime Architecture

`BossVerticalSliceController` now exposes only `CORE_SHOCKWAVE` for S-04 in every combat state. It anchors the pooled `BossAttackArea2D` at `BossRig2D.socket("CORE").global_position`, configures one 1,800-pixel-diameter release, and retains the existing recovery-driven infantry replenishment.[1] [3]

`BossAttackArea2D` prewarms one `CPUParticles2D`, one energy-core sprite, one release sprite, and two positional audio players only for its radial role. The existing fixed radial utility slot is reused, so the attack creates no combat-time nodes. The attack surface emits one `core_shockwave_released` signal after starting the release cue; `CommandBossSession` converts that exact boundary into a restrained vertical impulse through the existing `CameraRig`. Generation cleanup, retry, armor transitions, body defeat, and recovery stop all charge/release presentation.[2] [3] [6]

## Implementation Phases

| Phase | Work package | Completion contract |
| --- | --- | --- |
| **1. Pattern collapse** | Remove all three former pattern identifiers, phase rotations, delayed fronts, and obsolete localization. | S-04 catalog and runtime expose one attack identifier. |
| **2. Charge presentation** | Reuse the player's photon orb for cyan converging particles and a massive core sphere at the visible boss socket; start the 1.45-second rising cue with the telegraph. | Charge audiovisuals remain non-damaging and terminate exactly at release. |
| **3. Release authority** | Emit one expanding blue-white ring from the same core, start the one-second pressure cue, apply one restrained camera impulse, and bind damage to its moving contact band. | Sound and camera feedback fire once at the active boundary; contact damages once per activation and timed dodge rejects it. |
| **4. Cleanup and continuity** | Remove the dedicated old ring asset and update tests, self-tests, manifests, and combat documentation. | No old pattern or texture reference remains; all newer boss and campaign systems survive. |
| **5. Release synchronization** | Integrate shared `main`, fresh-export with Godot 4.7.2, remap both WASM and PCK, checkpoint, and publish the existing WebDev project. | Source, Web export, and deployed fullscreen iframe identify the same final revision. |

## Acceptance Criteria

| Area | Acceptance criterion |
| --- | --- |
| Attack replacement | S-04 exposes only `CORE_SHOCKWAVE`; no old first-boss pattern can be selected. |
| Telegraph simplicity | Only converging cyan photons and the growing blue core sphere warn the player. |
| Core anchoring | Charge sphere and release share the rig's visible `CORE` socket in landscape and portrait. |
| Visible release | One cyan-white ring expands continuously from the core to its authored radius. |
| Collision fidelity | Only the moving ring band damages, at most once per activation. |
| Counterplay | Dodge invulnerability prevents damage when the visible ring crosses the player. |
| Audio synchronization | Charge audio starts with the telegraph and release audio replaces it on the exact active-state boundary. |
| Camera restraint | Exactly one 10-unit impulse reaches `CameraRig` at release; charge, contact, and recovery add none. |
| Pooling | The existing one-slot radial utility pool owns all charge and release nodes. |
| Continuity | Support cap, armor/body damage, archive, grounded rubble, evidence, retry, and later bosses remain unchanged; post-spectacle completion now requires no extra attack. |
| Cleanup | Old multi-front identifiers, locale labels, test assertions, dedicated ring texture, and provenance references are absent. |
| Deployment | The final shared source is freshly exported and both WebDev runtime payloads are remapped. |

The focused Godot 4.7.2 pass completed **26 tests and 1,160 assertions** across the vertical slice, campaign gates, and runtime budget after the audiovisual update. It proves the 1.45-second timing, exact core-socket anchoring, 72-particle charge, separate cue ownership, exact charge-to-release handoff, single 10-unit camera impulse, one released front, ring-band-only damage, dodge rejection, per-activation deduplication, recurring support cap, boss-campaign continuity, and fixed post-warm node shape. After semantic integration of the concurrent title-controls cleanup, a lightweight combined pass completed **28 tests and 2,900 assertions** across the vertical slice, title screen, and bilingual localization. Repository-wide release certification remains intentionally skipped under the project override.

## References

[1]: ../game/scripts/siege/boss_vertical_slice_controller.gd "Settlement Engine vertical-slice attack controller"
[2]: ../game/scripts/siege/boss_attack_area_2d.gd "Pooled boss charge and shockwave presenter"
[3]: ../game/scripts/siege/command_boss_session.gd "Campaign boss session and animation integration"
[4]: ../game/scripts/player/robot_animation_presenter.gd "Player photon charge visual language"
[5]: ../game/scripts/player/giant_robot_controller.gd "Player dodge invulnerability and damage acceptance"
[6]: ../game/scripts/siege/boss_utility_pool.gd "Fixed-capacity boss utility pool"
