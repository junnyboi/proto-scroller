# Boss Attack Telegraph Readability Remediation Plan

**Author:** Manus AI

**Status:** Implemented, focused-verified, and responsive-visual-certified on 2026-08-28

**Engine:** Godot 4.7.2-stable with matching non-threaded Web templates

**Scope:** All five campaign bosses, with an explicit rendering repair for Settlement Engine S-04

## Objective

Make every boss attack warning immediately legible to a player who already understands ordinary enemy warnings. Boss projectile attacks will use the same warm danger palette, visible-origin line, target badge, progress arc, firing pulse, damage-based intensity, and size-based stroke scaling as ordinary shell and rocket attacks. Boss-specific environmental or narrative overlays will remain visually subordinate and collisionless. Settlement Engine S-04 will additionally expose its cyan particle convergence, growing core sphere, countdown ring, and released shockwave above the boss and world scenery in both landscape and portrait play.

## Investigation findings

The current visual baseline reproduced the user report. The landscape charge and release captures contained **no visible S-04 charge particles, no blue core sphere, and no released shockwave**, even though runtime snapshots reported each child as visible and active.

The primary defect is hierarchical rather than numerical. `BossUtilityPool` parents every `BossAttackArea2D` under `BossStructuralAdapter`. The adapter hides itself whenever a fallback structural conductor is unnecessary. Godot propagates that hidden state to all descendants, so S-04's radial VFX and the lane/line areas can be fully culled while their own `visible` flags, particle emitters, timers, collision, audio, and tests continue to report healthy state. Raising opacity would therefore have been a highly enthusiastic no-op.

A second mismatch affects later bosses. `BossProjectileVolley` uses rig weapon-socket positions as telegraph origins, while ordinary enemies deliberately draw warnings from the visible center/grounded center of the attacker and preserve the authored socket only for projectile spawn. Multi-shot boss paths also use a bespoke extra-path renderer and then fall through to the ordinary renderer for the first path. This produces mixed line grammars and makes volley intent harder to parse.

A third clarity problem is semantic competition. Boss lane, line, echo, and safe-zone overlays use cyan/magenta/orange authored plates that can visually compete with the warm ordinary-enemy danger telegraph, despite most of those boss areas being non-damaging navigation or narrative cues. Their hierarchy must clearly distinguish **projectile danger**, **environmental route information**, and **safe space**.

## Visual language contract

| Information | Required presentation |
|---|---|
| Boss shell/rocket danger | Exact ordinary-enemy shell or rocket grammar: visible boss center to impact target, warm danger line, target badge, closing progress arc, accelerating brightness pulse, damage intensity, and boss-size stroke scaling. |
| Multi-shot volley | One complete ordinary-enemy path per promised projectile. No separate bespoke dashed-only secondary language and no duplicated first path. |
| Projectile spawn | Preserve authored boss socket origins and ballistic direction; telegraph-origin normalization must not move projectiles. |
| Environmental danger area | Subordinate cool outline with sparse corner/notch marks; no warm orange stripes or ordinary-enemy target badge. It must not masquerade as a projectile warning. |
| Safe/dry lane | White-cyan outlined safe space with a restrained center chevron; never use the warm danger palette. |
| Composition echo/history | Low-alpha cool presentation only, collisionless and clearly below active danger warnings. |
| S-04 charge | Cyan-blue inward particles, a growing additive core sphere, a warm countdown reticle around the core, and an obvious final pre-release pulse. |
| S-04 release | One expanding bright cyan-white annulus whose visible band matches the damaging contact band, rendered above boss art and scenery. |

## Implementation work packages

### WP1 — Separate combat presentation from structural visibility

Add one prewarmed `BossAttackPresentationRoot` to `BossUtilityPool`. Parent all lane, line, and radial attack areas to this root rather than `BossStructuralAdapter`. Give the root absolute canvas ordering above boss art and ordinary world scenery while leaving the global `TelegraphPresenter2D` above it for target warnings. Keep the root permanently visible and preserve all fixed-capacity, generation cleanup, collision, and floating-origin behavior.

**Acceptance:** attack areas remain render-visible whether the structural adapter is bound, unbound, or hiding fallback conductors. S-04 VFX are visible at the core in both supported orientations.

### WP2 — Normalize boss projectile telegraphs to ordinary enemy grammar

Refactor `TelegraphPresenter2D` so shell and rocket path drawing is shared by ordinary enemies and boss volleys. Boss volleys will draw every promised path through that same helper and stop before the generic fallback can duplicate the first path. `BossProjectileVolley` will reserve warning paths from one visible boss presentation center while retaining rig sockets in the projectile reservation arrays.

**Acceptance:** each promised shell/rocket has one target badge and one complete ordinary-style path; all paths originate from the visible boss center; committed projectiles still spawn from their authored sockets.

### WP3 — Clarify environmental overlays and S-04 countdown

Replace the striped orange/cyan boss-area treatment with a quieter role-specific overlay. Danger areas use a low-alpha cool field and bounded outline/notches; dry lanes use a white-cyan safe outline and chevron; echoes remain presentation-only. S-04 adds an ordinary-danger-language countdown ring around its blue energy core while keeping the gathered energy and released annulus cyan-blue. Increase the annulus contrast and keep its visible thickness synchronized with contact damage.

**Acceptance:** environmental overlays do not compete with projectile warnings; safe lanes cannot be mistaken for danger; the S-04 charge and release remain identifiable without relying on color alone.

### WP4 — Focused regression and visual evidence

Extend focused tests to cover attack-root visibility independence, absolute z-order, boss visible-center warning origins, one complete path per volley shot, socket-preserving projectile spawn, S-04 countdown progress, VFX state, and collision-band synchronization. Update the vertical-slice visual scenario so it cannot stall while searching for a Residential attack and capture S-04 charge/release plus representative later-boss projectile warnings at 1280×720 and 720×1280.

**Acceptance:** direct import/parser pass succeeds; affected focused suites pass; image captures visibly show the charge particles, sphere, countdown, released shockwave, and ordinary-style boss projectile paths. Repository-wide release certification remains skipped under the explicit project override.

### WP5 — Shared-main integration and Web release

Re-fetch and semantically merge any concurrent shared-main changes without rewriting history. Run a lightweight focused post-merge pass, push the combined tree to `main`, export a fresh Godot 4.7.2 Web bundle, upload and remap both WASM and PCK in the existing `proto-scroller` WebDev project, preserve its pure fullscreen iframe and custom title/media shell, update durable release records, restart, save a checkpoint, and publish when the tool is available.

### WP6 — Dark-background contrast and S-04 release wake

Raise the luminance and alpha floor of the shared `TelegraphPresenter2D` danger treatment without changing threat ranking, pulse cadence, target snapshots, line geometry, or projectile authority. Increase the warm path and badge opacity at the beginning of a warning so attacks remain readable against near-black skyline, facade, rain, and boss silhouettes; retain the red-white extreme-threat interpolation and final firing peak. Raise the resting outline contrast of boss environmental areas modestly while keeping their cool palette subordinate to projectile danger and preserving white-cyan safe lanes.

Add four prewarmed, non-colliding shockwave echo sprites behind S-04's leading annulus. Each echo samples an earlier radius at a fixed temporal interval and fades progressively inward. The bright 92-pixel leading band remains the only damage authority; the wake is thinner, bluer, and lower-alpha so it communicates velocity and direction without implying a larger hitbox. Expose fixed trail count, visible count, and spacing in the existing snapshot for focused verification.

**Acceptance:** warning paths and target badges remain conspicuous over the darkest district frames in landscape and portrait; threat intensity ordering and extreme red-white behavior remain intact; S-04 presents one bright collision-matched leading band with a visibly fading inward wake; the trail allocates no nodes after warm-up and never changes collision or damage; representative S-04, SAMARITAN, Mimesis, and Cantor telegraph/release screenshots are captured and inspected before release.

## Completion evidence

The first repaired 1280×720 capture verified that moving attack surfaces out of the structural adapter makes the S-04 charge and release unmistakably visible. The capture now shows dozens of converging motes, a large core sphere, a warm enemy-language countdown ring, and a released annulus whose broad translucent band matches the contact thickness. The first pass exposed an undesirable inherited green bias in the reused player photon texture. The final alpha-and-luminance shader pass corrected it while retaining visible internal filaments: both gathered particles and the sphere are now cyan-blue rather than green or flat-filled.

The 720×1280 review confirmed that the charge and released band remain conspicuous at mobile scale, but the wide boss was framed too far right in the certification scenario, clipping part of the core reticle. The runtime VFX is correctly boss-centered; the self-test camera setup will move the player closer for portrait evidence so the full boss-centered cue is visible rather than certifying a needlessly adversarial crop.

Representative Mimesis and Cantor captures verified the new hierarchy: warm shell lines and target badges sit above the cool boss-specific geometry, and Cantor's cyan/white safe lanes remain visually distinct from projectile danger. The first gallery pass moved the camera after the attack had already snapshotted its target, placing some target badges near the old screen edge. The final visual scenario will begin a fresh post-framing telegraph so every captured line terminates on the currently visible player position.

The retargeting attempt exposed a second scenario defect: each controller `advance()` call handles only one state transition, so passing the sum of telegraph, active, and recovery durations committed and cancelled the current volley without beginning the next warning. The gallery helper now advances the three stages separately, guaranteeing capture of a fresh mid-telegraph volley after camera framing.

The final representative landscape captures are accepted. Mimesis shows one warm, pulsing ordinary-style shell line from its visible core to a badge on the player. Cantor shows three individually promised white-gold shell lanes from the same visible core to three nearby target badges, while the white-cyan ground rectangles remain unmistakably safe navigation space. Boss-specific scenery and echoes no longer obscure the danger contract.

The final 720×1280 S-04 captures are also accepted. The reframed charge shows the complete orange countdown circumference, detailed cyan-blue core, and converging particles above the boss. The release capture shows the annulus crossing the portrait viewport with a clear inner safe opening and a broad luminous contact band. No S-04 attack state is now dependent on scenery transparency or structural-adapter visibility.

Portrait Mimesis and Cantor captures retain the same semantics at mobile scale: visible-core origins remain on-screen, every warm path terminates at an individual badge around the player, and white-cyan safe geometry is separated by shape, color, and layer. Final Godot 4.7.2 focused execution passed **7 selected contracts / 215 assertions** across attack-root ownership, S-04 charge/release, SAMARITAN, Mimesis, Cantor, CHOIR Prime, and the unchanged ordinary tank-warning baseline. Both vertical-slice and escalation visual scenarios completed all checks in 1280×720 and 720×1280. The intentionally skipped repository-wide gate was not used as a substitute for this task-focused evidence.

The dark-background contrast pass raises shared warning RGB by 16 percent and post-intensity alpha by 22 percent, while increasing the opening opacity of paths, badges, progress surfaces, and support marks. It does not alter damage-derived ranking, the 4-to-32-percent firing pulse, red-white extreme-threat interpolation, target snapshots, path count, or projectile authority. Cool boss-area outlines received a smaller resting contrast increase, and safe lanes remain pale cyan-white rather than adopting the warm danger palette.

S-04 now renders four fixed earlier-radius wake samples at 65-millisecond spacing behind the collision-authoritative annulus. Each echo is prewarmed, normal-blended, progressively thinner, bluer, and more transparent than the leading 92-pixel band. An initial additive pass was rejected in visual review because it flooded the frame with cyan; the accepted pass restores normal blending, preserves the road and boss silhouettes, and leaves the outer contact band as the brightest surface. The snapshot exposes trail count, visible count, and spacing without changing collision or damage.

Final 1280×720 and 720×1280 captures accept S-04 charge/release, SAMARITAN, Mimesis, and Cantor against near-black facades and skyline. S-04 retains a visibly open safe interior and readable inward wake; Mimesis and Cantor retain prominent warm paths and individual target badges; subordinate cyan history and safe geometry remain distinct. Godot 4.7.2 script checks passed, and **17 focused tests / 530 assertions** passed across shared warning behavior, S-04 trail/collision, 25 restart loops, and authored boss-area reset/geometry contracts. Repository-wide certification remains intentionally skipped under the release override.
