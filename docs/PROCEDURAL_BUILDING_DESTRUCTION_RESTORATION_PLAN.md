# Procedural Building Destruction Restoration Plan

**Status:** Implementation complete; source integration and deployment in progress
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
| Gameplay preservation | Hurtboxes/colliders disable, ground breach opens passage, support/floor/steel chains and burst/debris paths remain unchanged |
| Cleanup | Unused legacy intact/damaged art is removed; active facade, rubble, attachment, and burst assets remain |
| Delivery | Source is pushed; fresh HTML/JS/WASM/PCK are produced; both WASM and PCK are remapped into the existing WebDev checkpoint |

## Risks and Controls

The principal visual risk is drawing dark geometry over transparent facade padding. The alpha-clipped shader uses the same facade texture and atlas region as the intact sprite, discarding transparent source texels before darkening. The principal persistence risk is an old destroyed mutation without contour data; deterministic fallback generation prevents visually intact failures without changing the mutation schema. The principal runtime risk is node growth; the restoration deletes one child node per cell and adds no replacement nodes beyond material reuse on the existing `Polygon2D`. The principal package risk is reduced rather than increased because obsolete legacy textures and the cross-section script are removed.

## Completion Record

The implementation deletes `BuildingRubbleEdge2D` and its UID, removes all construction/reconfiguration/neighbor-edge code, and makes `BuildingDamagePattern2D` authoritative in both damaged and destroyed states. Fatal hits now record severity-1 procedural geometry before breaking the cell. The cavity shader discards low-alpha facade texels before darkening; final cracks, cables, broken plumbing, sparks, and water spray persist after failure. A deterministic fallback pattern repairs legacy destroyed states without stored contour data.

The work also corrected a pooled-state reset indentation defect that previously skipped `Destructible2D.restore_stream_state()` whenever the incoming cell array was empty. All six cells now reset on every variant reconfiguration, preventing failed state from leaking between facade identities.

The obsolete `building_intact.png`, `building_damaged.png`, both import files, and the cross-section renderer files were removed. The 25 production facades, shared shallow rubble, cable/pipe attachments, material burst textures, and physical debris remain active.

Four targeted Godot 4.7.2 regressions passed with **2,932 assertions**: alpha-safe procedural destruction with persistent details; natural passage opening; stable pooled reconfiguration across all 25 variants; and fatal destruction of all 150 variant cells with nonempty contours, final cracks, two details, strong cavity darkening, and no cross-section node. Final source revision, export identities, WebDev routes, and checkpoint will be recorded after integration and deployment.
