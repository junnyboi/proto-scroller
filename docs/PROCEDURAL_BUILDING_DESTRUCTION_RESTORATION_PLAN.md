# Procedural Building Destruction Restoration Plan

**Status:** WP7 implemented; fresh Web release pending
**Engine:** Godot 4.7.2 stable, GL Compatibility, non-threaded Web export  
**Target branch:** `main`  
**Applies to:** all 25 district facade variants through the six-instance streamed building pool

## Objective

Restore the original damage language in which each building retains its authored facade while individual structural sections are progressively scarred, hollowed, and darkened by deterministic runtime geometry. Destroyed cells must not be replaced by a facade-resampled cross-section layer or any bespoke destroyed-building image. Cracks, broken plumbing, dangling wires, sparks, water spray, shallow rubble, material debris, support transfer, chain collapse, passage opening, persistence, and pooling must remain intact.

## Diagnosis

The unwanted presentation is owned by `BuildingRubbleEdge2D`. Its current shader samples the intact facade texture into a second `HollowFacade` sprite and reconstructs selected shell bands after a cell is destroyed. Although intended to preserve source alpha, the result visually reads as a large replacement cross-section laid over the original building. The layer is added to every one of the six cells in every pooled building and is reconfigured for all 25 variants, so the defect is systemic rather than asset-specific.

A second defect exists in the damage lifecycle. `Destructible2D.receive_damage()` records a procedural pattern only while health remains above zero. A fatal single hit therefore skips final contour generation. `_apply_stage()` then hides `BuildingDamagePattern2D` and culls its cable and pipe attachments when the cell enters the destroyed state. This makes some failed sections appear insufficiently damaged and leaves the cross-section renderer as the dominant visual.

The district catalog also retains two obsolete legacy textures, `building_intact.png` and `building_damaged.png`, as unused preload constants. All 25 production variants already point to their own facade for both intact and procedural fracture sampling, so those two images and imports are dead runtime art. The shared `building_rubble.png` remains active and is not cross-section art; it provides the shallow nonblocking rubble bed at the foot of a failed cell.

## Target Architecture

| Layer | Intact state | Damaged state | Destroyed state |
|---|---|---|---|
| Authored facade sprite | Visible | Visible | Visible outside the procedural cavity |
| Procedural damage pattern | Hidden | Visible, moderate darkening and staged cracks | Visible, deep alpha-clipped cavity, final crack network, wires and broken pipe |
| Cross-section facade reconstruction | Absent | Absent | Absent |
| Shared shallow rubble strip | Hidden | Hidden | Visible |
| Material burst and physical debris | Inactive | Damage attachment effects only | One pooled material burst plus bounded physical chunks |
| Collision and hurtbox | Enabled | Enabled | Disabled according to the existing passage contract |

`BuildingDamagePattern2D` becomes the sole persistent facade-damage presenter. Its polygon continues to be generated deterministically from variant ID, cell coordinate, attack identity, impact position, material, and severity. A shared canvas shader darkens only sampled facade texels inside the generated polygon and discards source pixels below the alpha threshold. This prevents any rectangular or polygonal dark mask from painting transparent background regions while preserving a visually deep cavity.

The procedural contour is regenerated at severity 1.0 for every fatal hit, including one-shot kills, support failures, floor cascades, and steel-support cascades. Destroyed cells retain both authored damage attachments. Legacy mutation states that mark a cell destroyed without stored pattern geometry receive a deterministic fallback cavity during restoration, preventing old runs from producing visually intact failed sections.

## Work Packages

### WP6 — Damage-progressive sprite hollowing

Move the shared cavity material from a facade-textured overlay polygon onto each cell's authored `IntactVisual` sprite. The material must preserve the untouched sprite at zero damage, then use normalized cumulative damage to expand one deterministic center-out alpha void without reallocating nodes or textures. A seed-stable angular boundary function must produce coarse structural bites and finer chips so the same jagged silhouette grows rather than popping to a new outline after every hit.

The surviving facade pixels must darken continuously with damage. At terminal destruction, the hollow reaches most of the center and lower middle, while conservative maximum extents preserve visibly jagged left and right structural rails plus a top lintel. The terminal remainder uses full cavity tint; transparent source pixels stay transparent at every stage. Cracks and cable/pipe attachments remain separate deterministic overlays above the eroded sprite.

Persistence stores normalized hollow progress and also reconstructs it from authoritative health when loading older mutations. Reconfiguration resets the shared material to pristine without replacing the per-cell material instance. All 25 facade variants inherit the behavior through the existing six-cell pooled path.

**Acceptance:** progressive damage produces strictly increasing `hollow_progress`, hollow extents, and darkening; zero damage leaves sprite alpha unchanged; terminal damage reaches progress `1.0`, fully darkens surviving facade pixels, removes the center and lower middle, preserves side and top margins, and retains final cracks plus both attachment details. The shader must perform alpha discard on `IntactVisual` rather than render a replacement facade polygon.

### WP7 — Severe interior VFX, destruction clouds, and impact-shaped cavities

Extend each existing `BuildingDamagePattern2D` with one prewarmed, code-rendered severe-damage child. It remains disabled below 62% cumulative damage, then renders deterministic additive interior fire glow, animated flame tongues, embers, and intermittent electrical arcs strictly inside the active cell. At terminal destruction, fire intensity increases while electrical arcs taper into less frequent residual discharges. The effect must inherit the cell's clipping and alpha-safe facade geometry rather than introduce opaque image backgrounds.

The existing fixed `BuildingSectionBurstPool` remains the only destruction-particle allocator. Each of its twelve prewarmed slots gains a dedicated falling-debris emitter, while the existing dust emitter becomes a broader, longer-lived destruction cloud. A destroyed section restarts fragments, falling debris, dust, and flash exactly once; restoring streamed state must not replay any emitter, and pool saturation must continue recycling the oldest slot without node growth.

The authored-facade erosion shader receives a stable `impact_profile` parameter derived from the most recent accepted structural hit. Punches (`jab_cross` and `punch_shockwave`) produce horizontally biased, blunt cavities with directional side tearing. Missiles and rockets produce rounded blast craters with radial chips. Ground smashes produce low, wide, vertically compressed cavities that breach the lower middle aggressively. Unknown, chain-reaction, and legacy events retain the current balanced generic cavity. The selected profile is captured and restored with cell mutation state so streamed facades preserve their last impact silhouette.

| Attack family | Profile | Cavity behavior |
|---|---|---|
| Jab/cross and punch shockwave | `punch` | Wide horizontal crush, directional side notch, moderate vertical loss |
| Missile and rocket | `missile` | Rounded radial crater, stronger high-frequency edge chipping |
| Ground smash | `ground_slam` | Very wide lower cavity, shallow vertical radius, early bottom breach |
| Chain, support, legacy, or unknown | `generic` | Existing balanced center-out jagged erosion |

**Acceptance:** severe nonterminal cells visibly expose animated fire and electrical activity without creating nodes after warm-up; destroyed cells trigger bounded falling debris plus an expanded dust cloud exactly once; punch, missile, and ground-smash events set distinct shader profiles and distinct shape parameters; capture/restore preserves the chosen profile; pooled reset returns every cell to generic profile with severe effects disabled; all 25 facade variants continue sharing the same implementation.

### WP0 — Plan and contract lock

Document the defect, desired layer model, lifecycle changes, asset cleanup, persistence behavior, and all-building acceptance criteria before code changes. Reconcile the plan with `DISTRICT_DESTRUCTION_DESIGN.md` and `DISTRICT_DESTRUCTION_IMPLEMENTATION_PLAN.md`, which already define the 25-facade roster and require runtime-generated cracks, pipes, cables, and hollowing.

**Completion:** plan committed and pushed to shared `main` before implementation.

### WP1 — Remove cross-section reconstruction

Delete `BuildingRubbleEdge2D` and its UID. Remove creation, reconfiguration, neighbor-edge refresh, and all test dependencies from `StructuralBuilding2D`. No substitute destroyed-building sprite or cross-section texture will be introduced.

**Acceptance:** no runtime or test reference to `BuildingRubbleEdge2D`, `RubbleEdgeVisual`, `HollowFacade`, cross-section shell sampling, or its shader remains.

### WP2 — Make procedural damage authoritative through destruction

Extend `BuildingDamagePattern2D` with an alpha-clipped cavity material and an explicit destroyed-stage contract. Preserve the authored facade beneath the procedural overlay. Apply moderate darkening while damaged and stronger darkening after failure. Keep crack paths visible, force cable and pipe detail at fatal severity, retain attachment animation, and preserve capture/restore behavior.

Update `Destructible2D` so fatal damage is recorded before `_break()`, the procedural pattern remains visible after destruction, and the intact facade remains visible beneath it. Add deterministic fallback pattern generation when restoring a destroyed legacy state with no contour.

**Acceptance:** fatal one-shot, accumulated damage, support failure, floor collapse, steel collapse, and restored destruction all produce a nonempty procedural contour; destroyed cells retain two damage details; transparent facade pixels remain unaffected by cavity darkening.

### WP3 — Apply and prove the contract across all 25 buildings

Use the existing district catalog and pooled reconfiguration path rather than per-building branches. Extend the all-variant regression to apply every variant, destroy representative cells, verify nonempty deterministic patterns, confirm alpha-clipped cavity materials, ensure no cross-section nodes exist, retain one cable and one broken-pipe attachment set per cell, and prove cell/node identities remain stable across reconfiguration.

Retain all existing material layouts, facade sizes, mutation schema compatibility, collision teardown, walk-through passage behavior, section bursts, physical debris, and chain reactions.

**Acceptance:** all five districts and 25 variants share the same procedural destruction pipeline with no new active-node growth and no variant-specific destroyed art.

### WP4 — Remove unused art and reconcile documentation

Delete the unused legacy `building_intact.png` and `building_damaged.png` files plus imports. Remove their preload constants from `CityDistrictCatalog`. Keep all 25 authored facade images, `building_rubble.png`, cable/pipe details, and material-specific burst/debris assets because they remain active.

Update the district design/implementation records, building-destruction VFX plan, README, and this plan so “rubble edges” or cross-section reconstruction is not presented as the current architecture.

**Acceptance:** repository search finds no runtime reference to the deleted files; catalog validation still resolves all 25 production facade, damage, and rubble resources.

### WP5 — Integration, export, and WebDev synchronization

Run focused import and destruction regressions only, per the release-gate override. Commit the implementation, integrate concurrent upstream changes semantically, and push shared `main` without rewriting history. Create a fresh Godot 4.7.2 Web export from the final tree. Upload and remap both WASM and PCK in the existing `proto-scroller` WebDev project, preserve its fullscreen responsive iframe and leaderboard service, update `PLAN.md`, `STRUCTURE.md`, `MEMORY.md`, and `ASSETS.md`, save a checkpoint, and publish through the existing project lifecycle.

## Focused Verification Matrix

| Contract | Evidence |
|---|---|
| Cross-section removal | Static search and scene-tree assertions find no cross-section class, node, shader, or reference |
| Alpha safety | Cavity shader discards low-alpha source texels and the procedural renderer no longer draws an unmasked dark polygon |
| Fatal completeness | One-shot destruction generates a full-severity contour before stage transition |
| Damage details | Destroyed cells retain dangling cables and broken plumbing; effects stay bounded and pooled |
| All-building coverage | Every one of the 25 variants reconfigures the same six cells and produces procedural destroyed state |
| Persistence | Destroyed state with a stored pattern restores exactly; legacy destroyed state without a pattern synthesizes a deterministic fallback |
| Gameplay preservation | Each failed cell disables only its own hurtbox/collider; passage opens after all three lower bays fail, while support/floor/steel chains and burst/debris paths remain unchanged |
| Cleanup | Unused legacy intact/damaged art is removed; active facade, rubble, attachment, and burst assets remain |
| Delivery | Source is pushed; fresh HTML/JS/WASM/PCK are produced; both WASM and PCK are remapped into the existing WebDev checkpoint |

## Risks and Controls

The principal visual risk is drawing dark geometry over transparent facade padding. The alpha-clipped shader uses the same facade texture and atlas region as the intact sprite, discarding transparent source texels before darkening. The principal persistence risk is an old destroyed mutation without contour data; deterministic fallback generation prevents visually intact failures without changing the mutation schema. The principal runtime risk is node growth; the restoration deletes one child node per cell and adds no replacement nodes beyond material reuse on the existing `Polygon2D`. The principal package risk is reduced rather than increased because obsolete legacy textures and the cross-section script are removed.

## Completion Record

The implementation deletes `BuildingRubbleEdge2D` and its UID, removes all construction/reconfiguration/neighbor-edge code, and makes `BuildingDamagePattern2D` authoritative in both damaged and destroyed states. Fatal hits now record severity-1 procedural geometry before breaking the cell. The cavity shader discards low-alpha facade texels before darkening; final cracks, cables, broken plumbing, sparks, and water spray persist after failure. A deterministic fallback pattern repairs legacy destroyed states without stored contour data.

The work also corrected a pooled-state reset indentation defect that previously skipped `Destructible2D.restore_stream_state()` whenever the incoming cell array was empty. All six cells now reset on every variant reconfiguration, preventing failed state from leaking between facade identities.

The obsolete `building_intact.png`, `building_damaged.png`, both import files, and the cross-section renderer files were removed. The 25 production facades, shared shallow rubble, cable/pipe attachments, material burst textures, and physical debris remain active.

Four targeted Godot 4.7.2 regressions passed with **2,932 assertions**: alpha-safe procedural destruction with persistent details; natural passage opening; stable pooled reconfiguration across all 25 variants; and fatal destruction of all 150 variant cells with nonempty contours, final cracks, two details, strong cavity darkening, and no cross-section node.

The implementation was integrated non-destructively with the concurrent boss-combat release and pushed as source revision `48b5e1ba5146188383f7b505c5898b514b61f0ce`; the fresh export record was pushed as `43b711c1a8d8ef67c281a06ab2a660917d54d72c`. A fresh Godot 4.7.2 Web export produced a **39,514,754-byte WASM** with SHA-256 `fc74679e3b97f76878947fcd4fbe1268cbfa6188182a2e33bbc3f5dc9bfa57d0` and a **16,103,384-byte PCK** with SHA-256 `6bc0069f3e8cbb721e35e037b8e1db7f9efaeb4b8a691fe5213a81677f87a730`.

The existing `proto-scroller` WebDev project now maps `/manus-storage/game-43b711c_278ae8cd.wasm` and `/manus-storage/game-43b711c_87833a7b.pck`, preserves the fullscreen dynamic iframe and concurrent leaderboard/boss systems, and is sealed at checkpoint `f3656c8b`.

The progressive extension moves the per-cell shader onto `IntactVisual` itself. Cumulative normalized damage now increases one stored `hollow_progress` value, drives smooth center-out alpha erosion, and darkens every surviving facade texel. The shader normalizes atlas coordinates to the active 3×2 cell region, combines three deterministic angular frequencies into coarse bites, chips, and notches, and opens the lower middle near terminal failure. At progress `1.0`, material-aware extents remove most of the center while preserving dark jagged side rails and at least a narrow top lintel. Crack strokes now radiate outward from the cavity boundary instead of floating across the transparent opening.

Progress is captured with the mutation state and reconstructed from authoritative health for older saves. The material instance remains bound during all 25 facade reconfigurations and resets to an untouched zero-progress sprite on pooled reuse. Four focused Godot 4.7.2 tests passed with **4,316 assertions**, covering cumulative growth, full darkening, lower breach logic, nonterminal persistence, all 150 terminal cell states, per-cell atlas normalization, stable node reuse, and the prior alpha-safe/detail contract.

The implementation was merged with concurrent projectile-impact work and pushed as source `172fa284e23f0620ea741a283b3e47438588e5a1`. Its fresh Godot 4.7.2 Web export produced a **39,514,754-byte WASM** with SHA-256 `fc74679e3b97f76878947fcd4fbe1268cbfa6188182a2e33bbc3f5dc9bfa57d0` and a **16,108,216-byte PCK** with SHA-256 `038a25b7b362b3d6171ccc15cf1a8f28cdc6115596693ad8476103d5afdcc78b`.

After compatible district-weather work landed concurrently, the combined runtime was re-exported from `9013239bef6a2090c0fec61f1b5428c1fcf8fb66` and its generated shell was preserved at `7a45ca0beadc94dd8dac9d544daf781ae901c08c`. The existing `proto-scroller` WebDev project now maps `/manus-storage/game-7a45ca0_8223db74.wasm` and `/manus-storage/game-7a45ca0_9d4cb6df.pck` while preserving the fullscreen dynamic iframe, responsive title scheduler, local worklets, database leaderboard, repaired bosses, projectile-impact variation, and district weather. The final PCK is 16,121,152 bytes with SHA-256 `e5b93ac52b62c0e6e4dfeeb14fe34619c0d2d48d65f39015964f2f5f994fc49e`; the release is sealed at checkpoint `54e49118`.

WP7 adds one fixed `BuildingSevereDamageFx2D` child to every prewarmed damage pattern. The original geometric flame tongues and electrical scribbles were replaced by a two-second, 24-frame transparent fire loop generated from a GPT Image 2 anchor through a locked-camera Veo 3.1 carrier and the Manus video-to-sprites pipeline. The fixed child now owns one pooled `AnimatedSprite2D` backed by a shared 8×3 WebP atlas; no texture, frame resource, or node is created when damage occurs.

Every damaged section deterministically selects **exactly one** persistent accent: generated fire, one dangling cable, or one broken pipe, in addition to its cracks and hollowed facade. Fire activates only for its selected sections at 62% cumulative damage; cable and pipe sections never layer on top of it or each other. Complete destruction immediately stops particles and animation, hides all three accent types, clears the persisted detail mask, and leaves only the terminal hollow, jagged dark facade rails, cracks, shallow rubble, and bounded destruction burst.

The cavity shader now persists one of four attack profiles. Jab/cross and punch shockwaves widen and flatten the cavity with a directional side tear; missiles and rockets use a rounded crater with denser radial chips; ground smashes shift the hollow downward and widen the lower breach; chain and legacy damage remain generic. The selected profile and direction survive stream capture/restore and reset to generic during pooled reuse.

Each of the twelve existing `BuildingSectionBurst2D` slots now includes a dedicated long-lived falling-debris emitter. Its dust emitter was expanded into a broader cloud while preserving material-specific concrete, glass, and steel counts, gravity, color, and scale. Destruction restarts fragments, falling debris, dust, and flash exactly once and still recycles the oldest fixed slot under saturation.

Nine focused Godot 4.7.2 tests passed with **283 assertions** across the new profile/VFX contract, existing material-aware section bursts, and the complete runtime-budget retry/saturation suite. Repository-wide release certification remains intentionally skipped under the project override.

The follow-up fire replacement and accent-lifecycle regression passed **3 of 3 tests with 63 assertions**. It proves all six resident facade sections hold one accent at severe damage, at least one deterministic section uses the generated 24-frame fire animation, no arc renderer remains active, node counts remain fixed, and terminal destruction culls the selected fire/wire/pipe without replaying or reallocating.

## WP8 — Natural terminal debris density

Terminal rubble no longer stretches the same authored strip across every full cell or anchors upper-floor collapse to street level. Each cell derives a stable presentation from its facade seed and structural material: concrete retains the fullest pile, steel is intermediate, and glass is sparse. Width is bounded to 52–87% of the bay, opacity remains below 90%, rotation is limited to ±1.8 degrees, and a small horizontal offset prevents visible repetition. Every pile settles at the bottom of its own destroyed section, so upper-floor material rests on the floor beneath the cavity while ground-row material remains street-supported.

The transient fixed-pool burst was reduced from **38 to 27 fast fragments**, **30 to 19 falling pieces**, and **29 to 19 dust particles** across one simultaneous concrete/glass/steel comparison. Remaining debris has greater size variance, falling pieces use a narrower spread with 30% stronger gravity and lower launch velocity, and dust opacity is reduced per material. The pool size, macro gameplay debris, collision behavior, and saturation/recycling contract are unchanged.

Focused Godot 4.7.2 checks passed: the complete section-burst script passed **3 of 3 tests with 56 assertions**, and the all-25-facade terminal contract passed **1 of 1 test with 3,376 assertions**. Deterministic Xvfb galleries passed at **1280×720** and **720×1280** for all five districts, the tuned transient burst passed in both orientations, and the mixed damage-detail frame passed at 1280×720. Visual inspection accepted the result: cavity silhouettes remain dominant, debris stays inside the owning bay, and no transparent facade background is contaminated.
