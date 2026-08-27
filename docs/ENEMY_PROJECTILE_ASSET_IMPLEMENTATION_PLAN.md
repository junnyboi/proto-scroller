# Enemy Projectile and Emission Asset Implementation Plan

**Document status:** Planned  
**Scope baseline:** exhaustive discovery of 55 enemy/boss roster entries, 16 mechanical/presentation families, and 27 implementation items
**Target runtime:** Godot, GL Compatibility, non-threaded Web export  
**Package gate:** `game.pck <= 16,777,216` bytes  
**Primary rule:** visual assets are presentation only. Existing code-owned collision, targeting, timing, damage, reservation, pooling, spawn accounting, save/restore, and world-origin rebasing remain authoritative.

## 1. Executive summary

The hostile-emission audit is complete. It covers the three base enemies, every one of the 26 `EnemyArchetypeCatalog.PROCEDURAL_IDS`, all 20 district chimera IDs added concurrently, the definition-less legacy command-boss `TankEnemy`, and all five authored campaign bosses: **55 roster entries with no unmapped enemy**. District variants deliberately inherit their canonical base archetype’s emission family, preventing cosmetic duplication from fragmenting the fixed projectile and telegraph contracts. The implementation replaces procedural circles, generic support cues, generic striped rectangles, and empty `Node2D` records with a coherent cream–charcoal–cyan industrial asset language while retaining amber as the anticipation/commitment channel and red as the armed-damage channel.

The work is organized by **mechanical delivery family**, not by narrative attack name. Lobber and Basilisk remain straight shells rather than receiving false ballistic art; Kestrel remains a direct rocket rather than a falling bomb; Cinder receives no flame cone; Longbow and Pale Engine receive no rail/spinal beam; rockets do not gain homing, explosions, or splash. Likewise, support, melee, carrier, history-mine, and boss-utility art remains non-colliding unless an existing code-owned `BossAttackArea2D` rectangle is already armed.

A new centralized `ProjectileVisualCatalog` will be the sole mapping from projectile visual key to texture, source/display dimensions, pivot/orientation, optional procedural trail policy, and collision-independent draw parameters. It will distinguish the direct rocket from the spread-salvo rocket without changing the shared `rocket` pool partition or `damage_type`. Support and boss presentation metadata will remain data-driven but outside the projectile catalog, because they are not `Projectile2D` objects. All runtime resources are preloaded or attached during prewarm; no shot or support action may create a texture, node, material, tween, particle system, or collision object on demand.

Delivery is staged so the lowest-risk pooled projectile replacements land first, followed by telegraph metadata, non-projectile VFX pools, carrier presentations, and finally boss-area/utility art. Each work package has a feature flag and a procedural fallback. The release gate requires focused mechanical tests, allocation and cleanup tests, deterministic visual captures in landscape and portrait, a clean Web export and browser smoke test, alpha/fringe inspection, and the 16 MiB PCK cap.

## 2. Scope, inventory, and counting convention

| Measure | Count | Meaning |
|---|---:|---|
| Enemy/boss roster entries | 55 | Every discovered base, procedural, district-variant, legacy-command, and authored campaign boss entry |
| Delivery/presentation families | 16 | Families listed in the discovery and represented by a design record |
| Proposed shipping asset files | 27 | Individual runtime PNG/WebP files; atlases count as one file, multi-file families count per file |
| Current discovery failures | 0 | The supplied `Failures` array is empty |
| Unmapped roster entries | 0 | Every roster entry belongs to at least one family |

The 27-file count is: four projectile bodies; one target-mark glyph; one repair pulse; two no-op support overlays; one Nemesis lance; four CHOIR contact textures; one conventional deployment atlas; one Seraph payload atlas; one boss lane substrate; one boss beam; one afterimage; seven boss utility sprites; and one CHOIR pylon replacement.

Environmental hazards from `EnvironmentalHazardCatalog` are expressly outside this plan because they are world-owned and have no enemy emitter. Enemy body sprites are also outside scope except where an existing body sprite is reused as a CHOIR composition echo.

## 3. Complete enemy-to-projectile/emission matrix

“Projectile” in this matrix means the enemy-owned hostile/support presentation family; the **delivery** column states whether a pooled projectile actually exists.

| Roster key / display identity | Family or families | Delivery and collision authority | Planned asset treatment |
|---|---|---|---|
| `soldier` — SoldierEnemy | `straight_bullet` | One pooled bullet; 5 px code-owned circle | Shared tracer texture, 36×12 display |
| `tank` — TankEnemy | `straight_shell` | One pooled shell; 9 px code-owned circle | Shared heavy shell, 36×18 display |
| `helicopter` — HelicopterEnemy | `single_rocket` | One pooled direct rocket; 7 px circle | Direct rocket, 42×16 display |
| `needle` — NEEDLE SPOTTER DRONE | `target_mark_support` | No projectile/collision; applies 3 s mark | Directional scan-ring glyph |
| `bulwark` — BULWARK RIOT TROOPER | `straight_bullet` | One pooled bullet; 5 px circle | Shared tracer |
| `jackal` — JACKAL RECON BUGGY | `straight_bullet` | One pooled bullet; 5 px circle | Shared tracer |
| `lobber` — LOBBER GRENADIER | `straight_shell` | One straight pooled shell; no arc | Shared heavy shell; do not imply lob physics |
| `sapper` — SAPPER COMBAT ENGINEER | `repair_support` | No projectile; commit-time heal | Brief ally-local repair clamp pulse |
| `hound` — HOUND HUNTER DRONE | `straight_bullet` | One pooled bullet; 5 px circle | Shared tracer |
| `mule` — MULE APC | `conventional_reinforcement_deploy` | No projectile; pooled Soldier acquisition | Door/ramp and truthful payload atlas |
| `basilisk` — BASILISK MORTAR CARRIER | `straight_shell` | One straight pooled shell; no mortar arc | Shared heavy shell |
| `lancer` — LANCER MISSILE TEAM | `single_rocket` | One pooled direct rocket | Shared direct rocket |
| `static` — STATIC EW TRUCK | `noop_support_pulse` | No projectile; pulse attack is no-op; passive aura independent | Jammer wind-up overlay |
| `kestrel` — KESTREL BOMBER DRONE | `single_rocket` | One straight rocket to led/offset snapshot; no gravity | Shared direct rocket; no falling-bomb art |
| `rainmaker` — RAINMAKER MLRS | `rocket_spread_salvo` | Three independently pooled rockets; 7 px circles | Spread-salvo visual variant per rocket |
| `shrike` — SHRIKE ASSAULT VTOL | `single_rocket` | One pooled direct rocket | Shared direct rocket |
| `cinder` — CINDER FLAME TANK | `straight_shell` | One straight pooled shell; no flame cone | Shared heavy shell |
| `aegis` — AEGIS SHIELD PROJECTOR | `noop_support_pulse` | No projectile; pulse attack is no-op; 560 px passive aura independent | Shield wind-up overlay, not aura boundary |
| `longbow` — LONGBOW RAILGUN TANK | `straight_shell` | One straight pooled shell; no rail beam | Shared heavy shell |
| `hive` — HIVE DRONE CARRIER | `conventional_reinforcement_deploy` | No projectile; pooled Hound acquisition | Ventral bay and truthful payload atlas |
| `goliath` — GOLIATH SIEGE WALKER | `straight_shell` | One pooled shell | Shared heavy shell |
| `nemesis` — NEMESIS TITAN-HUNTER MECH | `conventional_melee_lance` | Direct point damage at ≤245 px; no intended projectile | Attached completion-only lance; resolve shell fallthrough |
| `leviathan` — LEVIATHAN COMMAND LANDSHIP | `rocket_spread_salvo` | Four independently pooled rockets | Spread-salvo visual variant per rocket |
| `reclaimed_breacher` | `choir_contact_melee` | Direct point damage; no projectile | Brace wedge plus hit-only footprint |
| `graft_runner` | `choir_contact_melee` | Mark-gated direct point damage; no projectile | Shallow leap arc plus hit-only footprint |
| `choir_siren` | `target_mark_support` | No projectile; applies 4 s mark and emits `choir_ring` | Larger CHOIR ring treatment from shared glyph |
| `ossuary_crawler` | `choir_contact_melee` | Direct point damage; no projectile | Downward trail plus hit-only footprint |
| `seraph_carrier` | `choir_incubation_payload` | No projectile; mark/event plus pooled Graft Runner acquisition | Bay/capsule/hatch/mark atlas |
| `pale_engine` | `straight_shell` | One straight pooled shell; no spinal beam | Shared heavy shell |
| `COMMAND_BOSS_TANK_LEGACY` | `straight_shell` | Active legacy TankEnemy shell | Shared heavy shell |
| `SETTLEMENT_ENGINE_S04` | `boss_lane_footprint`, `boss_line_beam`, `empty_boss_utility_placeholders` | Code-owned stationary rectangles plus collisionless utility records; no pooled bullets | Lane substrate, beam skin, archive/treasury utility |
| `SAMARITAN_15` | `boss_lane_footprint`, `boss_line_beam`, `empty_boss_utility_placeholders` | Code-owned rectangles plus collisionless cradle/clamp | Lane substrate, beam, cradle, clamp |
| `MIMESIS_04` | `boss_lane_footprint`, `boss_line_beam`, `armed_afterimage`, `empty_boss_utility_placeholders` | Code-owned rectangles; one history-derived 144×96 mine; collisionless utilities | Lane, beam, afterimage, cabinet, rubble |
| `CANTOR_31_PALE_ENGINE` | `boss_lane_footprint`, `boss_line_beam`, `empty_boss_utility_placeholders` | Code-owned rectangles and collisionless finite anchors/projections | Lane, beam, anchor, Seraph projection |
| `CHOIR_PRIME` | `boss_lane_footprint`, `boss_line_beam`, `choir_prime_testimony_projection` | Real mechanic rectangles; ECHO rectangle and pylons are presentation-only | Lane, beam, pylon replacement; reuse existing enemy echo sprites |

Authored campaign bosses hide the acquired `TankEnemy` authority and therefore do **not** emit the pooled straight shell. Only the definition-less legacy command-boss path does.

## 4. Current procedural placeholder audit

| Family | Current implementation | Why it is a placeholder | Migration boundary |
|---|---|---|---|
| Straight bullet | 5 px amber circle and dark line; generic amber line/dot warning | No physical round silhouette; all four emitters visually identical | Replace only `bullet` body draw; preserve telegraph and 5 px collision |
| Straight shell | 9 px orange-red circle and thick short trail; shell badge/solid line/target circle | “Lob,” mortar, flame, rail, siege, and spinal labels do not change motion | One shared shell body; preserve badge, line, circle, 9 px collision |
| Single rocket | 7 px orange circle and short trail; dashed line/arc/crosshair | No rocket body, homing, bomb fall, explosion, or splash | One direct rocket body; preserve straight snapshot motion |
| Rocket salvo | Same generic rocket circles, differentiated only by target offsets/speeds | No salvo-specific body/pod/smoke; one central warning only | Explicit visual variant; preserve three/four independent projectiles |
| Target mark | Generic support line and growing origin dot | Scan and CHOIR ring cannot be distinguished | Add support `variant`, not a new projectile kind |
| Repair | Generic support line toward player; ally briefly tints mint | Telegraph cannot identify commit-time healed ally; no confirmation effect | Keep pre-commit warning; add ally-local post-commit pulse only on success |
| Jammer/shield | Same generic support line/dot and 5.5% owner scale pulse | Neither attack completion has gameplay effect; no style identity | Owner-local wind-up only; never depict passive aura boundary |
| Nemesis lance | Whole-body lunge; shell warning and reservation; possible out-of-range shell fallthrough | No dedicated strike and current classification contradicts melee-only design | Resolve classification/fallthrough before enabling art |
| CHOIR contact | Generic line/dot and body lunge | No brace, leap, drop, or hit confirmation | Prewarmed visual-only pool; footprint only on committed hit |
| Conventional carriers | Generic support line/dot and body lift/squash | No door, bay, payload, or acquisition truthfulness | Prewarm overlays; show 0/1/2 payloads from actual acquisitions |
| Seraph carrier | Generic support line/dot and lift/squash | No bay, capsule, hatch, mark display | Fixed cosmetic pool synchronized to mark and successful child results |
| Boss lanes | Cyan translucent rectangle, four amber stripes, red armed rectangle, pale DRY | Generic substrate for all attacks | Nine-slice neutral plate beneath semantic procedural overlays |
| Boss lines | Same rectangle code; stripes cover only first ~200 px | No coherent full-span beam or endpoint treatment | Explicit line-beam role; never skin ECHO or ground lanes |
| MIMESIS afterimage | Eight cyan circle/crosshair markers plus selected 144×96 generic rectangle | No recorded-memory object identity | Texture on prewarmed markers; keep rectangle authoritative |
| Empty boss utilities | Visible flags on bare `Node2D` records | Archive, cradle, clamp, cabinet, rubble, anchors, and projections render nothing | Add one prewarmed `Sprite2D` child per existing record |
| CHOIR testimony | Existing pylon PNG and reused enemy sprites over 920×300 striped rectangle | Not empty, but pylon is a replaceable production asset and has three consumers | In-place neutral pylon replacement; preserve echo composition and ECHO collision-off state |

## 5. Visual language and readability grammar

The common material language is **soot charcoal/near-black structure, chipped warm cream ceramic, restrained cyan information/energy, and sparse oxidized metal**. The asset must read first by silhouette and value, then by hue. Fine scratches are optional and must not be the only distinguishing feature at runtime size.

| Semantic | Required treatment | Prohibited treatment |
|---|---|---|
| Anticipation/commitment | Existing amber/orange lines, badges, stripes, arcs, and dots remain authoritative | Recoloring warnings to cyan merely to match physical art |
| Armed damage | Existing red/vermilion fill, core, or thick boundary remains authoritative | Baked red in neutral source assets; using red on no-op/support art |
| Safe/informational memory | Hollow/translucent cyan, cream/charcoal containment, open center | Solid cyan disks or full-screen bloom that resemble hazards |
| Hostile physical projectile | Compact high-contrast cream/charcoal body; small warm cue; cyan subordinate | Cyan-dominant rounds that resemble player machine-gun fire |
| Support | Open, discontinuous, owner- or recipient-local shapes | Full circles, exact-radius domes, collision-looking borders, damaging explosions |
| Conventional technology | Geometric, manufactured, restrained, no biological/cathedral ornament | CHOIR tendrils, crowns, reliquary figures, or mauve flesh |
| CHOIR technology | Bone/cream fragments, black cable/tendon language, surgical cyan | Gore, broad magenta, or motifs that erase mechanical readability |
| Collision boundary | Code/procedural overlay only | Deriving a shape from texture alpha or opaque bounds |

All projectile source art faces +X and rotates to `velocity.angle()`. Stationary boss lanes and beams remain world-horizontal and directionless. Vertical Seraph/drop art remains top-to-bottom regardless of actor facing. Alpha glows stay inside the declared visual envelope so they do not advertise reach beyond code-owned collision.

## 6. Production briefs and exact dimensions

The following entries preserve the supplied production intent. “Source” is the cleaned runtime source shipped under `res://`; larger generation masters are archived outside export unless explicitly stated.

### A01 — Straight bullet tracer (`straight_bullet_tracer.png`)

**Brief.** A single hostile machined dart: cream-hot needle tip, chipped charcoal collar, attached narrow cyan-white wake, hard silhouette, sparse dry-brush wear, no casing, muzzle flash, impact, detached particles, background, shadow, text, or aim line. Canonical nose-right, core-centered pivot.  
**Dimensions.** Generation master: native high resolution, archived; shipping source **96×32 RGBA**; visible marks approximately x=4–92, axis y=16; runtime **36×12**, centered; collision remains **radius 5**.  
**Animation.** Static texture rotated to velocity; no shader, particles, child allocation, or flicker initially.  
**Primary path.** `game/art/enemies/projectiles/straight_bullet_tracer.png`.

### A02 — Heavy straight shell (`straight_shell.png`)

**Brief.** Compact brutalist sabot/obelisk shard with faceted nose, thick cream/charcoal body, pinched collar, two small fins, restrained cyan seam, tiny warm hostile glint. It must not resemble a rocket, rail beam, grenade, flame blob, or arcing shell. No baked smoke/trail.  
**Dimensions.** Shipping/source master **256×128 RGBA**; runtime body **36×18** centered, with optional separate trail yielding at most ~45 px total visual length; collision remains **radius 9**.  
**Path.** `game/art/combat/projectiles/straight_shell.png`.

### A03 — Single direct rocket (`enemy_direct_rocket.png`)

**Brief.** A compact 3:1 direct rocket with blunt wedge nose, cream-armored charcoal fuselage, pinched tail, readable fins, tiny cyan sensor, and compact amber exhaust aperture. No bomb silhouette, long plume, explosion, smoke cloud, homing cue, crosshair, or scenery.  
**Dimensions.** Shipping/source **256×96 RGBA**, content about 196×58 with ≥24 px padding, pivot (128,48); runtime **42×16** centered; collision remains **radius 7**.  
**Path.** `game/art/city/projectiles/enemy_direct_rocket.png`.

### A04 — Spread-salvo rocket (`hostile-spread-rocket.png`)

**Brief.** One narrow siege rocket, not a composite volley: pointed long nose, stout charcoal motor, chipped cream bands, small fins, cyan guidance slits, compact orange-white exhaust. It is instanced three or four times.  
**Dimensions.** Generation **1536×576**; shipping **192×72 RGBA** with ≥8 px padding; runtime **36×14**, maximum **40×16** with deterministic exhaust flicker; collision remains **radius 7 per independent rocket**.  
**Path.** `game/art/city/projectiles/hostile-spread-rocket.png`.

### A05 — Target-mark scan/CHOIR ring (`target_mark_support.png`)

**Brief.** Hollow fractured double scanner ring with four cream arcs, charcoal radial clamps, cyan seams, and one +X directional spur. At least 55% of the center remains transparent. It must read as surveillance/support, not a crosshair, shield, explosion, projectile, or collision radius.  
**Dimensions.** Source **256×256 RGBA**, pivot (128,128), content inside ~220×220. Needle runtime **46×46 → 66×66**; CHOIR Siren **92×92 → 132×132**; optional afterglow may reach **148×148** only in a prewarmed slot.  
**Path.** `game/art/presentation/target_mark_support.png`.

### A06 — Repair support pulse (`repair-support-pulse.png`)

**Brief.** An open asymmetric repair clamp: narrow source tail, two blunt cream/charcoal jaws, three cyan stitch bars, and a few mint splinters. No medical cross, continuous tether, shield ring, bullet, or impact explosion. Shown only at the actual ally selected at commit.  
**Dimensions.** Source **256×128 RGBA**, motif within ~224×88 and ≥8 px padding; runtime **72×36**, peak ≤**82×41**, duration **0.20 s**.  
**Path.** `game/art/city/enemies/effects/repair-support-pulse.png`.

### A07 — Static jammer wind-up (`jammer-pulse.png`)

**Brief.** Thin broken 1.75:1 horizontal oval carrier wave, sawtooth crown, clipped interference wedges, cream dielectric fragments, sparse cyan sparks, open center. It is an owner-local anticipation motif, not a world field.  
**Dimensions.** Generation **1024×1024**; shipping **512×512 RGBA**, Godot import capped at **256–288 px**; runtime approximately **320×184**.  
**Path.** `game/art/city/effects/support/jammer-pulse.png`.

### A08 — Aegis shield wind-up (`shield-pulse.png`)

**Brief.** Heavier broken 1.55:1 ellipse with two incomplete shield ribs, broad lower brackets, and compact cyan capacitor core. Keep center open and perimeter discontinuous; never depict the mechanical 560 px aura boundary.  
**Dimensions.** Generation **1024×1024**; shipping **512×512 RGBA**, import capped at **256–288 px**; runtime approximately **400×256**.  
**Path.** `game/art/city/effects/support/shield-pulse.png`.

### A09 — Nemesis direct melee lance (`nemesis_melee_lance.png`)

**Brief.** Attached conventional penetrator: transparent inboard lead-in, charcoal mechanical root, cream armored taper, narrow cyan-white core, one chisel/needle tip. No free projectile, beam bar, sweep, multiple points, broad cone, CHOIR biology, or impact burst.  
**Dimensions.** Generation/master **1024×256 RGBA**; shipping derivative **512×128**; runtime canvas **245×61**, visible root starts x≈48 and tip ends x≈240–242. No collision shape; Nemesis body remains **82×215**.  
**Path.** `game/art/city/enemies/attacks/nemesis_melee_lance.png`.

### A10–A13 — CHOIR contact set

**A10 Brace.** Squat owner-heavy compression wedge tapering to compact contact tooth. Source **512×256**; runtime up to **300×120**.  
**A11 Leap.** Broken shallow cream/black arc with cyan lock filament and clear negative space below. Source **512×256**; runtime up to **360×175**, apex 70–95 px.  
**A12 Drop.** Narrow top-to-bottom claw/spear trail. Source **256×512**; runtime **120–150×230**.  
**A13 Footprint.** Low compact cracked-bone contact crown, never an AoE ring. Source **512×256**; runtime **220×84** for crawler or **150×64** for runner/breacher.  
**Shared generation master.** **1536×1024 RGBA**, archived outside export.  
**Paths.** `game/art/presentation/choir_contact_brace.png`, `choir_contact_leap.png`, `choir_contact_drop.png`, and `choir_contact_footprint.png`.

### A14 — Conventional reinforcement deployment atlas

**Brief.** Modular conventional kit: four Mule ramp states, one Soldier payload, four Hive bay states, one Hound pod/trail, and one neutral dispatch puff. Large readable cutouts, no carrier hull baked into frames, no target marker, projectile arc, explosion, CHOIR biology, or fixed payload count.  
**Dimensions.** Generation **2048×1024**; runtime atlas **1024×512 RGBA**, nominal 256×256 door/bay cells with ≥16 px bleed and a pivot manifest. Runtime: Mule overlay ≤**150×120**, Soldier ~**54×96**; Hive bay ≤**145×80**, Hound pod/trail ~**110×70**; puff ≤**90×60**.  
**Path.** `game/art/city/enemies/deployment/conventional-reinforcement-deploy.png` plus manifest.

### A15 — Seraph incubation payload atlas

**Brief.** Modular CHOIR kit: closed/charged/split reliquary capsule, narrow biological descent trail, belly-bay glow, low hatch crown, and broken thorn target-mark halo. Bone-cream, charcoal, surgical cyan, restrained mauve membrane; never a bomb, explosion, or damaging impact.  
**Dimensions.** Generation **1024×1024**; shipping atlas **512×512 RGBA** with ≥12 px gutters. Runtime: capsule **56×88**, split ≤**86×92**, bay **112×48**, trail **18–26×≤130**, impact **132×66**, mark **118–136 diameter** with 3–5 px ring.  
**Path.** `game/art/city/enemies/effects/choir-incubation-payload.png`.

### A16 — Boss lane substrate (`boss-lane-footprint.png`)

**Brief.** Neutral nine-slice industrial interdiction plate: square-ended charcoal rails, cream clamp blocks, inset cyan conduits, broad negative space. Do not bake red, amber warning stripes, safe white, scenery, smoke, or details outside the rectangle.  
**Dimensions.** Generation **1536×1024**; shipping **1024×256 RGBA**, 64 px protected caps and repeat-safe center, meaningful detail in central 1024×192. Runtime fits exact controller footprint, from **210×104** through **430×154**; ground portion of Compression Psalm **260×112**. The separate **780×52** line component uses the beam asset, not this substrate.  
**Path.** `game/art/bosses/boss-lane-footprint.png`.

### A17 — Boss horizontal beam (`boss-line-beam.webp`)

**Brief.** Symmetric stationary industrial judgment line: cream-white core, broken charcoal conductor rails, ivory clamps, sparse cyan filaments, compact mirrored electrode caps. No emitter-side bias, projectile heading, sweep, scenery, smoke, warning stripes, or baked red state.  
**Dimensions.** Source/master **1024×128 straight-alpha RGBA**, 64 px caps and 896 px repeatable center; runtime exact footprints **720×44**, **760×48**, **430×48**, **720×54**, **780×52**, or **780×58**, cap display 24–32 px.  
**Path.** `game/art/bosses/boss-line-beam.webp` (quality ~84 only after alpha QA; PNG fallback permitted).

### A18 — MIMESIS recorded afterimage (`mimesis-armed-afterimage.webp`)

**Brief.** Directionless 3:2 memory reliquary/cassette: blunt charcoal body, two cream crescent clamps, short under-cables, compact cyan aperture with nested recorded contours. No crosshair, red/amber state, projectile nose, lane length, or detached wisps.  
**Dimensions.** Generation **1536×1024**; cleaned working source **512×384** (or optimized **256×192** derivative). History display **48×32**, selected history **60×40**, selected-mine presentation ≤**120×72** inside unchanged **144×96** collision rectangle.  
**Path.** `game/art/siege/mimesis-armed-afterimage.webp`.

### A19–A25 — Boss utility sprites

All seven use separate **1024×1024 generation masters**, static single-frame shipping PNGs, bounded cyan glow, true alpha, no red/magenta damage language, text, people, scenery, shadows, or collision.

| ID | Utility brief | Shipping source | Runtime maximum | Path suffix under `game/art/bosses/utilities/` |
|---|---|---:|---:|---|
| A19 | Tall reinforced archive/treasury reliquary with side pincers | 256×256 | 128×112 | `boss-archive-treasury-bracket.png` |
| A20 | Oval evacuation cradle in low protective fork with intact cyan chamber | 256×256 | 152×112 | `boss-evacuation-cradle.png` |
| A21 | Low opposing extraction jaws with empty center and cyan lock | 256×128 | 144×64 | `boss-extraction-clamp.png` |
| A22 | Upright battered analog cabinet, chunky controls, side cable loop, no labels | 256×256 | 104×136 | `boss-show-control-cabinet.png` |
| A23 | Low irregular cream rubble, charcoal rebar/cables, cyan grounding contact | 256×128 | 184×64 | `boss-rubble-bed.png` |
| A24 | Squat tri-prong freight/reclamation hardpoint with circular cyan socket | 256×256 | 104×80 | `boss-freight-reclamation-anchor.png` |
| A25 | Airy translucent Seraph side-profile schematic in projector yoke | 256×256 | 176×112 | `boss-seraph-production-projection.png` |

### A26 — CHOIR testimony pylon (`choir-pylon.png`)

**Brief.** Upright neutral pylon/reliquary with needle crown, cream shoulder fins, narrow cyan glass nave, dark cable rails, circular lower conductor, and flared plinth. No baked gold, attack stripes, red, projectile streak, or composite enemies.  
**Dimensions.** Generation **1536×2304**; runtime derivative no larger than **256×512-class** while preserving current centered pivot/aspect. Effective uses: inactive ~**80×174** at scale 0.34, active ~**94×205** at 0.40, rig weak point fit **72×72** (~33×72), fallback conductor scale 0.22 (~52×113).  
**Path.** Preserve `game/art/finale/choir-pylon.png` unless all three preload consumers migrate together.

### A27 — CHOIR testimony composition assets (reuse-only ledger entry)

No new composite texture is produced. Existing archetype textures remain separately pooled and fitted to **78×112**, **112×100**, **92×92**, **132×104**, or **154×142**, with the presentation-only ECHO footprint fixed at **920×300** at center+(0,-126). This ledger item tracks integration/QA of reused assets, not a 28th shipping file.

## 7. Transparent asset pipeline

1. **Generate outside `res://`.** Store untouched high-resolution masters, prompt text, model/version, generation date, seed/request ID when available, and source checksum under an external art archive. Never place 1024–2304 px masters in the Web-exported project tree.
2. **Reject before cleanup.** Reject any candidate containing text, glyphs, logos, UI, backgrounds, ground planes, cast/contact shadows, opaque mattes, detached noise, unsupported perspective, accidental composite objects, or mechanics not present in code.
3. **Alpha isolate.** Convert to sRGB 8-bit straight RGBA. Remove generated matte; make fully transparent pixels RGB-clean; retain deliberate translucent emission only near the object. No premultiplied alpha.
4. **Normalize orientation and registration.** Projectile noses point +X with the gameplay pivot at the collision/body center. Attached effects preserve actor-side registration. Floor utilities use bottom-center pivots. Vertical drops remain top-to-bottom. Record pivot coordinates in metadata.
5. **Deterministic crop/downsample.** Use one documented Lanczos downsample from generation master to the exact source canvas. Do not repeatedly resample. Restore required safety padding after trim. Preserve atlas gutters and nine-slice caps.
6. **Small-size review.** Review at exact runtime dimensions at 1×, not only enlarged. Test over dark city, pale destruction, cyan CHOIR effects, amber telegraphs, and red armed hazards. Reject fine-detail-dependent candidates.
7. **Alpha QA.** Composite over black, white, neutral gray, cream, and cyan checkerboards. Fail black/white/magenta fringe, opaque corner pixels, clipped glow, detached subpixel islands, or bounding-box rectangles.
8. **Encode.** Default to lossless PNG. Use transparent WebP only for A17/A18 or A26 after side-by-side Web importer validation. Do not use lossy compression for 12–18 px projectile silhouettes unless artifact-free.
9. **Godot import.** `fix_alpha_border=true`, `premult_alpha=false`, mipmaps off, no normal maps, no runtime `ImageTexture`, and Web-compatible non-VRAM settings where existing boss art uses them. Apply explicit `size_limit` only where the brief calls for 256–288 or 512.
10. **Package audit.** Confirm only shipping derivatives and `.import` metadata enter PCK. Record source bytes, imported bytes if measurable, PCK delta, and checksum in the provenance manifest.
11. **Visual capture and sign-off.** Capture all cardinal/diagonal projectile directions, both facings, landscape/portrait, telegraph/armed/DRY states, pool saturation, and reset/reuse scenes before marking an asset complete.

## 8. Godot architecture

### 8.1 Centralized projectile visual catalog

Add `game/scripts/combat/projectile_visual_catalog.gd` as a static typed catalog (or immutable `Resource` loaded once) with one entry per physical projectile visual key:

```gdscript
class_name ProjectileVisualCatalog

enum TrailMode { NONE, PROCEDURAL_LINE, EXHAUST_FLICKER }

const SPECS := {
    &"enemy_bullet": {
        "texture": preload("res://game/art/enemies/projectiles/straight_bullet_tracer.png"),
        "source_size": Vector2i(96, 32),
        "display_size": Vector2(36, 12),
        "collision_radius_contract": 5.0,
        "canonical_angle": 0.0,
        "trail_mode": TrailMode.NONE,
    },
    &"enemy_shell": { /* 256×128, 36×18, radius 9 */ },
    &"enemy_rocket_direct": { /* 256×96, 42×16, radius 7 */ },
    &"enemy_rocket_salvo": { /* 192×72, 36×14, radius 7 */ },
}
```

The catalog must expose `spec(key)`, `has(key)`, and a debug validator that checks texture loadability, declared dimensions, positive display size, and expected collision-radius contract. The radius field is **assertion metadata only**; the catalog may never assign collision geometry.

`Projectile2D.activate(...)` receives a `visual_key: StringName` or derives a backward-compatible default from `damage_type`. The authoritative mapping is:

| Damage/pool contract | Visual key |
|---|---|
| hostile `bullet` | `enemy_bullet` |
| hostile `shell` | `enemy_shell` |
| hostile `rocket`, ordinary caller | `enemy_rocket_direct` |
| hostile `rocket`, Rainmaker/Leviathan explicit variant | `enemy_rocket_salvo` |
| player `machine_gun` | Existing player branch, unchanged |

`Projectile2D._draw()` applies a local transform rotated by `velocity.angle()`, draws the catalog texture in the declared centered rectangle, and draws only the declared optional non-colliding procedural trail. It must not add a `Sprite2D`, texture load, shader, or allocation per activation. `deactivate()` resets `visual_key`, rotation/draw state, modulation, exhaust phase, source, mask, velocity, lifetime, and visibility.

### 8.2 Telegraph presentation metadata

Extend the fixed-capacity record in `TelegraphPresenter2D` with backward-compatible fields: `presentation_variant`, `visual_key`, and optional `style_data`. `kind` remains `support`, `bullet`, `shell`, or `rocket` for reservation semantics. Support variants (`scan`, `choir_ring`, `repair`, `jammer_pulse`, `shield_pulse`, `deploy`, `drone_launch`, `incubation_drop`, `shock_brace`, `marked_leap`, `drop_lunge`, `melee_lance`) must never enter projectile reservation logic.

Textures used directly by `_draw()` are preloaded once. Completion-only records require a declared fixed capacity and deterministic deny/recycle behavior. A decorative effect may be dropped under saturation, but gameplay completion may not be delayed or denied unless the family design explicitly requires an atomic VFX reservation (CHOIR contact package).

### 8.3 Prewarmed visual-only pools

Add bounded pools only where static record drawing is insufficient:

- `ChoirContactVfxPool2D`: ≤12 slots, bound to telegraph owner/style/generation/cached endpoints.
- `ChoirPayloadEffectPool`: fixed bay/capsule/impact/mark slots; all nodes precreated.
- Actor-owned Nemesis lance and conventional deployment child nodes created during procedural family prewarm.
- Boss area lane/beam presentation children and all boss utility `Sprite2D` children created in `BossUtilityPool._prewarm()`.

Every pool implements `reserve/acquire/cancel_owner/release/release_all/rebase_cached_world_state/snapshot` as applicable and exposes active/capacity/post-warm-creation counters for tests.

### 8.4 Boss presentation roles

`BossAttackArea2D` receives an explicit presentation role such as `GENERIC`, `LANE_PLATE`, `LINE_BEAM`, or `ECHO_PRESENTATION`. Controllers assign roles from an audited attack allowlist. Role changes never touch `footprint_size`, `CollisionShape2D`, state timing, attack ID, mask, or monitoring. The ECHO role is permanently presentation-only.

`BossUtilityPool` gives each prewarmed utility record one `Sprite2D` and a role/state reset API. Shared indices must clear texture, modulate, scale, visibility, and role on encounter cleanup to prevent cross-boss leakage.

### 8.5 Feature flags and fallback

Add project settings or constants:

- `enemy_visuals/use_authored_projectiles`
- `enemy_visuals/use_authored_support`
- `enemy_visuals/use_authored_carriers`
- `enemy_visuals/use_authored_boss_areas`
- `enemy_visuals/use_authored_boss_utilities`

Disabled flags use the current procedural draw/fallback path without altering mechanics. Missing/invalid catalog entries log once and fall back procedurally; they must never suppress an attack.

## 9. Migration steps

1. Capture baseline test results, PCK bytes, node counts, pool capacities, screenshots, and checksums of current pylon/echo assets.
2. Add `ProjectileVisualCatalog` and tests with all feature flags off; no visual output changes.
3. Extend `Projectile2D` activation/reset APIs and pool tests to carry `visual_key`; retain procedural rendering as fallback.
4. Import A01–A04 and enable one projectile family at a time behind the projectile flag.
5. Extend telegraph records with presentation variants while preserving `kind` reservation semantics and legacy defaults.
6. Import A05–A08; implement target-mark and no-op support drawing, then the bounded repair completion record.
7. Resolve the Nemesis mechanical caveat: create a non-projectile melee telegraph classification and eliminate/document the out-of-range shell fallthrough. Only then import/enable A09.
8. Add/prewarm `ChoirContactVfxPool2D`, import A10–A13, and gate hit footprint on an explicit committed-hit result.
9. Prewarm actor-owned deployment nodes; import A14; feed actual successful acquisitions to the visual count.
10. Add/prewarm `ChoirPayloadEffectPool`, import A15, synchronize mark art to `target_mark_remaining`, and feed actual deployment outcomes or explicitly approve paired-clutch abstraction.
11. Add boss presentation roles and A16/A17 without changing area geometry; audit every attack ID and exclude ECHO records.
12. Add A18 to MIMESIS marker presentations with complete texture/state reset before CHOIR reuse.
13. Add utility `Sprite2D` children during boss pool prewarm; import A19–A25 and map role/state per controller.
14. Replace A26 in place, verify all three consumers, and run CHOIR finale/weak-point/fallback-conductor captures. Keep composition assets separate.
15. Run focused tests after each package; then full `game/verify.sh --full`, Web export, Chromium smoke, log scan, PCK gate, and provenance update.
16. Remove no procedural fallback until two clean release candidates have shipped; the default may switch to authored art while rollback remains available.

## 10. Sequential work packages

| WP | Scope | Depends on | Exit criteria |
|---|---|---|---|
| WP0 Baseline and provenance | Record PCK, tests, screenshots, pool/node counters, current asset hashes | None | Reproducible baseline committed |
| WP1 Catalog foundation | `ProjectileVisualCatalog`, validation, feature flags, backward-compatible `visual_key` | WP0 | Flags off are mechanically/visually baseline-equivalent |
| WP2 Straight projectile art | A01 bullet and A02 shell | WP1 | Four-direction tests; collision/pool values unchanged |
| WP3 Rocket art | A03 direct and A04 salvo variant | WP2 | Direct/salvo isolation; 1/3/4 counts exact |
| WP4 Telegraph metadata | Variant fields and non-projectile classification tests | WP1 | Support variants reserve zero projectiles |
| WP5 Support VFX | A05–A08 target mark, repair, jammer, shield | WP4 | Mark/heal/aura/no-op contracts and cleanup pass |
| WP6 Conventional melee | Nemesis classification/fallthrough decision and A09 | WP4 | At 245+epsilon: zero melee and zero shell under accepted melee-only contract |
| WP7 CHOIR contact | Pool and A10–A13 | WP4 | Exact one-hit/whiff behavior; no stale slot/allocation |
| WP8 Conventional carriers | A14 and actor-owned prewarmed overlay | WP4 | Visible payload count equals successful acquisitions |
| WP9 Seraph payload | A15 and fixed payload/mark presenter | WP5, WP7 | Five-second mark and actual/approved paired payload truth pass |
| WP10 Boss area skins | Roles plus A16/A17 | WP0 | Exact rectangle geometry/state; ECHO excluded |
| WP11 MIMESIS afterimage | A18 and marker reset | WP10 | Eight markers, one 144×96 mine, CHOIR reuse clean |
| WP12 Boss utilities | A19–A25 and role/state mapper | WP10 | Seven roles visible, collisionless, restore-safe |
| WP13 CHOIR pylon | A26 replacement and A27 reuse QA | WP10–WP12 | Five pylons, three consumers, five echoes, no ECHO collision |
| WP14 Integration hardening | Full tests, captures, Web export, package/provenance ledger | All | All acceptance gates green; rollback rehearsed |

## 11. Regression and acceptance criteria

### 11.1 Universal mechanical invariants

- Visual pixels, texture bounds, scale, pivot, rotation, atlas region, glow, and alpha never define collision, damage, range, target mask, speed, lifetime, aim, spawn position, or safe-lane geometry.
- Bullet/shell/rocket collision radii remain **5/9/7 px**, lifetime remains **2.5 s**, motion remains `direction.normalized() * speed`, and first contact still emits one event then recycles.
- Projectile capacities remain bullet 16, shell 4, rocket 4, player bullet 8, total 32 where currently tested. Telegraph records remain 12. Boss areas remain three lane and two line records.
- Reserve-before-telegraph, atomic cancellation, reservation consumption, partition-local oldest-active behavior, and zero post-warm node creation remain unchanged.
- Cached telegraph origin/target and active presentation positions rebase exactly once under floating-origin shifts.
- Death, deactivate, release, cull, `release_all`, retry, continue-cycle, generation cleanup, and pooled reacquisition leave no stale texture, transform, modulation, timer, reference, collision, or reservation.

### 11.2 Projectile-family acceptance

- Soldier/Bulwark/Jackal/Hound retain speeds/damage/cadence/anticipation: 720/8/0.95/0.38; 690/7/1.45/0.48; 820/6/1.10/0.40; 850/9/1.20/0.40.
- Shell labels remain cosmetic: no gravity, homing, splash, piercing, spread, alternate motion, or per-profile visual split. Legacy command boss fires; authored bosses do not.
- Helicopter/Lancer/Kestrel/Shrike remain 440/520/430/560 px/s; Kestrel keeps x lead ×0.35 and +85 y snapshot but no ballistic fall.
- Rainmaker atomically reserves/emits three; Leviathan four. Offsets, speed multipliers, 0.72 damage extras, unique IDs, and one central telegraph remain exact.
- Projectile art points along velocity in right, left, up, down, and diagonal tests with no pivot wobble.

### 11.3 Support, melee, and carrier acceptance

- Needle applies 3.0 s; Siren 4.0 s and one `choir_ring`; max-refresh and 1.15 marked aura remain exact. The signal still has no assumed production listener.
- Sapper heals only the nearest valid ally strictly inside 520 px by 22, at commit time; no eligible target produces no completion sprite.
- Static/Aegis timed pulses remain no-op. Static’s continuous 0.82 attack-interval multiplier and Aegis’s 0.65 incoming-damage multiplier inside 560 px remain attack-independent.
- Nemesis at distance ≤245 produces exactly one `lance` event, amount 30 before multipliers and impulse 520; the accepted migration produces no projectile at any range.
- CHOIR contact attacks preserve preferred range +45 checks, damage 24/18/22, anticipation 0.72/0.44/0.52, intervals 1.65/1.25/1.45, 420 impulse, Graft mark gate, and Breacher frontal mitigation.
- Mule/Hive preserve exact offsets `-facing*(120+78n)`, Hive +35 y, request two each attack, lifetime cap four, and actual 0/1/2 visible payload truth.
- Seraph preserves five-second mark, one `seraph_payload`, no projectile, +35 y and 120+78n offsets, and current executable maximum six children under the global ×2 tuning unless product deliberately changes mechanics in a separate change.

### 11.4 Boss acceptance

- `BossAttackArea2D`: HIDDEN invisible; TELEGRAPH/DRY collision disabled/mask 0/monitoring false; ARMED only enables exact rectangle with robot mask. Collision layer stays 0.
- All listed lane sizes/positions and six beam sizes/positions remain exact. DRY lanes remain hollow and never arm.
- Beam timing remains 0.85 telegraph, 0.55 active, 0.75 recovery, with CHOIR royal recovery returning to non-colliding TELEGRAPH as currently authored.
- MIMESIS keeps 64 px quantization, 3 s expiry, eight records, existing selection formula, and exactly one 144×96 area on `lane_damage_areas[2]`.
- Utility records remain exactly three anchors/four projections; all gain children only during prewarm and remain collisionless.
- CHOIR retains five pylon IDs/offsets, active/inactive scale/tint, sever groups [0,1], [2,3], [4], five testimony compositions, one real mechanic, one ECHO projection, and zero ECHO collision.

### 11.5 Visual and accessibility acceptance

- Each asset is recognizable at declared runtime size at 1280×720 and 720×1280, against dark and pale captures and at 75% Web canvas scale.
- Hostile projectile silhouettes remain distinguishable from the cyan player machine-gun round in mixed-fire captures.
- Amber anticipation, red armed state, and pale/hollow DRY state remain distinguishable in grayscale and common color-vision simulations by line style, fill, width, and silhouette—not hue alone.
- No asset obscures the player, target endpoint, safe gap, owner silhouette, HUD, or authoritative warning for longer than its approved envelope.
- Transparent corners are fully clear; no matte, fringe, shadow rectangle, detached pixels, clipped cap, atlas bleed, or mip shimmer is visible.

### 11.6 Performance and Web acceptance

- No post-warm node/texture/material growth across at least 100 ordinary acquire/attack/release cycles and 25 boss restart/restore cycles.
- No particles, dynamic lights, GDExtensions, thread dependency, runtime image decoding, or unsupported shader feature is introduced.
- GL Compatibility Web export succeeds with thread and extension support disabled; browser console/network/log scan is clean.
- Every expected shipping resource is present in PCK and no generation master is packaged.
- Final `game.pck` is **≤16,777,216 bytes**. Record per-work-package and final PCK deltas.

## 12. Web export and package risks

| Risk | Impact | Mitigation |
|---|---|---|
| `art/effects/*` exclusion | Asset works in editor but disappears in Web | Use proposed included paths or deliberately amend/export-test the preset |
| Oversized generation masters | PCK/memory budget breach | Archive outside project; package only 96–1024 px derivatives |
| Lossy alpha on tiny rounds | Dark/cream/cyan fringes and poor aim read | Prefer PNG, `fix_alpha_border`, no mipmaps, browser inspection |
| Large transparent atlases | Download/decode/overdraw cost | Tight packing, bounded 512/1024 atlas, gutters, no duplicate frames |
| First-use loads/allocations | Web hitch/GC spikes | Script-scope preload and prewarm all nodes/materials |
| Shader incompatibility | Pink/fallback/missing effect | Prefer code modulation; minimal CanvasItem shader only after Web compile test |
| Shared pool state leakage | Wrong rocket, afterimage, utility, or pylon on reuse | Full visual-state reset and generation-token tests |
| Beam/lane role overreach | False hazards, especially 920×300 ECHO | Explicit presentation role/attack allowlist; fallback generic draw |
| Cyan-dominant hostile art | Confusion with friendly/player fire | Warm cue, cream/charcoal mass, unchanged amber warning, mixed-fire QA |
| Fine detail collapse | Indistinct 12–18 px silhouettes | Judge 1× derivative; favor large value blocks; reject noisy candidates |
| Package headroom erosion | Late integration failure | Measure PCK after every WP; keep a 10% safety reserve below hard cap where possible |

## 13. Rollback strategy

1. Keep current procedural draw branches and generic support rendering intact behind feature flags through at least two release candidates.
2. Each work package is one independently revertible commit containing assets, catalog/metadata, tests, and provenance update. Avoid cross-package mechanical refactors.
3. Missing or invalid projectile specs fall back to the previous circle/trail branch and log once; attacks still fire.
4. Support and boss presentation failures fall back to the generic line/dot or generic rectangle. Gameplay state and collision continue without the authored texture.
5. Keep A26 at the existing pylon resource path for the lowest-risk rollback. If converting extension, land a separate migration commit and retain the prior PNG until all three consumers pass.
6. Preserve old `.import` settings in version control. A rollback restores asset plus import metadata together.
7. Before release, rehearse disabling each feature group in an exported Web build and verify mechanical signatures, package loading, and cleanup still pass.
8. If the PCK cap fails, rollback in this order: optional WebP/PNG encoding experiment; cosmetic completion afterglows; utility projection fidelity; boss substrate; support overlays. Do not remove warnings or alter mechanics to save bytes.
9. If visual/collision perception fails, revert the authored family while retaining catalog infrastructure and tests; do not resize collision to match art.

## 14. Asset provenance requirements

Every generated or materially edited shipping asset must have a provenance record in a machine-readable manifest and a human-readable runtime asset manifest. Required fields:

| Field | Requirement |
|---|---|
| `asset_id` | Stable A01–A27 identifier |
| `family_id` | One of the 16 audited family IDs |
| `runtime_path` | Exact `res://` path |
| `status` | `planned`, `generated`, `cleaned`, `integrated`, `accepted`, or `rolled_back` |
| `brief_version` | Plan revision/hash used for generation |
| `generator` | Model/product name and version, e.g. GPT Image 2 |
| `request_id` / `seed` | Record when the service exposes it; otherwise `not_provided` |
| `generated_at_utc` | ISO-8601 timestamp |
| `operator` | Human/service account responsible |
| `prompt_sha256` | Hash of the exact production prompt |
| `master_uri` | External archive location; never a Web runtime dependency |
| `master_dimensions` | Exact generation/master dimensions |
| `runtime_dimensions` | Exact shipped source dimensions |
| `display_dimensions` | Exact or enumerated runtime display bounds |
| `orientation` / `pivot` | Canonical axis and registration point |
| `alpha_process` | Isolation, matte removal, straight-alpha confirmation |
| `downsample_process` | Tool/version/filter and crop/padding recipe |
| `manual_edits` | Cleanup, paintover, compositing, atlas packing |
| `license_and_rights` | Generation terms, third-party inputs, reuse permission |
| `source_sha256` | Shipping source checksum |
| `import_settings` | Compression, quality, alpha-border, premultiplied flag, mipmaps, size limit |
| `imported_resource_uid` | Godot UID when applicable |
| `source_bytes` | Runtime source file size |
| `pck_delta_bytes` | Measured package change |
| `review_captures` | Paths/URLs for 1×, dark/light, landscape/portrait captures |
| `reviewers` / `approved_at_utc` | Art, gameplay, accessibility, and technical sign-off |
| `mechanical_contract_test` | Test names protecting collision/delivery behavior |
| `rollback_asset` | Prior path/hash or procedural fallback identifier |
| `notes` | Known compromises, especially paired-clutch or shared-consumer behavior |

For reused A27 composition textures, provenance points to the existing archetype asset records and records only fit bounds, tint, testimony mapping, and QA evidence; do not duplicate ownership claims.

## 15. Failures and coverage gaps

### Discovery failures

**None.** The supplied failures list is empty, all 55 roster entries are mapped, and all 16 family design records were successfully produced.

### Explicit coverage exclusions

- `EnvironmentalHazardCatalog` is excluded because its hazards are world-owned, not enemy-emitted. It requires a separate asset plan.
- Enemy body sprites are excluded except as existing CHOIR echo inputs; this plan addresses hostile/support emissions, attack presentation, and empty boss records.
- No new impact/explosion asset is planned for enemy rockets or shells because current mechanics recycle on contact and do not own splash or lingering impact behavior.

### Known implementation gaps that must be resolved or consciously accepted

1. **Nemesis classification/fallthrough.** `lance_thrust` currently uses the shell telegraph/reservation and may fire a shell on an out-of-range completion. WP6 must make this a dedicated non-projectile melee path or explicitly reject the melee-only design; this plan’s acceptance target is no shell fallthrough.
2. **Seraph count discrepancy.** Narrative design says a three-Runner batch, but the executable applies the global ×2 tuning to the authored limit and may permit six. Art must use three paired clutches or consume actual successful deployment results; a separate gameplay change is required to make the count literally three.
3. **Seraph event payload.** `seraph_payload` currently exposes only event ID and source, not successful count/positions. Truthful VFX needs an internal result callback that does not change public event meaning.
4. **Support origin mismatch.** Generic support telegraphs use `attack_telegraph_origin()` while some callers calculate a different lower/muzzle origin. Bay/socket art must use explicit presentation anchors without silently changing warning snapshots.
5. **CHOIR ring signal.** `choir_ring` has no production listener. The mark timer, not the signal, enables Graft Runner; visual integration must not invent side effects.
6. **Boss catalog utility declarations.** `SAMARITAN_15` uses `line_areas[0]` while catalog requirements omit line areas. MIMESIS declares two lane areas but uses global index 2. Audit and test declarations before tightening allocation; do not change mechanics merely for art.
7. **BossAttackArea2D damage callback.** The area arms collision/monitoring but does not itself contain an inferred damage callback. This plan preserves observed collision presentation and makes no claim that texture integration completes a separate damage-delivery system.
8. **Repair health notification.** Sapper directly changes health and may not emit a health-changed signal. Art work must not alter that contract; UI notification is separate scope.
9. **Pylon multi-consumer coupling.** One pylon texture serves finale pylons, boss weak point, and structural fallback conductors. Aspect, pivot, or extension changes require all-consumer validation.
10. **A27 is reuse-only.** No bespoke composition-echo atlas is planned. Existing enemy body assets remain the production sources by design.

## 16. Completion ledger

All entries are initially **Planned**. An item may move to Accepted only after source, import, integration, focused tests, captures, Web smoke, package measurement, provenance, and rollback evidence are complete.

| ID | Asset / integration item | Family | Runtime path | Status |
|---|---|---|---|---|
| A01 | Straight bullet tracer | `straight_bullet` | `game/art/enemies/projectiles/straight_bullet_tracer.png` | **Accepted** |
| A02 | Heavy straight shell | `straight_shell` | `game/art/combat/projectiles/straight_shell.png` | **Accepted** |
| A03 | Direct rocket | `single_rocket` | `game/art/city/projectiles/enemy_direct_rocket.png` | **Accepted** |
| A04 | Spread-salvo rocket | `rocket_spread_salvo` | `game/art/city/projectiles/hostile-spread-rocket.png` | **Accepted** |
| A05 | Target-mark scan/CHOIR ring | `target_mark_support` | `game/art/presentation/target_mark_support.png` | **Accepted** |
| A06 | Repair pulse | `repair_support` | `game/art/city/enemies/effects/repair-support-pulse.png` | **Accepted** |
| A07 | Jammer wind-up | `noop_support_pulse` | `game/art/city/effects/support/jammer-pulse.png` | **Accepted** |
| A08 | Shield wind-up | `noop_support_pulse` | `game/art/city/effects/support/shield-pulse.png` | **Accepted** |
| A09 | Nemesis melee lance | `conventional_melee_lance` | `game/art/city/enemies/attacks/nemesis_melee_lance.png` | **Accepted** |
| A10 | CHOIR brace | `choir_contact_melee` | `game/art/presentation/choir_contact_brace.png` | **Accepted** |
| A11 | CHOIR leap | `choir_contact_melee` | `game/art/presentation/choir_contact_leap.png` | **Accepted** |
| A12 | CHOIR drop | `choir_contact_melee` | `game/art/presentation/choir_contact_drop.png` | **Accepted** |
| A13 | CHOIR contact footprint | `choir_contact_melee` | `game/art/presentation/choir_contact_footprint.png` | **Accepted** |
| A14 | Conventional deployment atlas and manifest | `conventional_reinforcement_deploy` | `game/art/city/enemies/deployment/conventional-reinforcement-deploy.png` | **Accepted** |
| A15 | Seraph incubation atlas | `choir_incubation_payload` | `game/art/city/enemies/effects/choir-incubation-payload.png` | **Accepted** |
| A16 | Boss lane substrate | `boss_lane_footprint` | `game/art/bosses/boss-lane-footprint.png` | **Accepted** |
| A17 | Boss line beam | `boss_line_beam` | `game/art/bosses/boss-line-beam.png` | **Accepted** |
| A18 | MIMESIS afterimage | `armed_afterimage` | `game/art/siege/mimesis-armed-afterimage.png` | **Accepted** |
| A19 | Archive/treasury bracket | `empty_boss_utility_placeholders` | `game/art/bosses/utilities/boss-archive-treasury-bracket.png` | **Accepted** |
| A20 | Evacuation cradle | `empty_boss_utility_placeholders` | `game/art/bosses/utilities/boss-evacuation-cradle.png` | **Accepted** |
| A21 | Extraction clamp | `empty_boss_utility_placeholders` | `game/art/bosses/utilities/boss-extraction-clamp.png` | **Accepted** |
| A22 | Show-control cabinet | `empty_boss_utility_placeholders` | `game/art/bosses/utilities/boss-show-control-cabinet.png` | **Accepted** |
| A23 | Rubble bed | `empty_boss_utility_placeholders` | `game/art/bosses/utilities/boss-rubble-bed.png` | **Accepted** |
| A24 | Freight/reclamation anchor | `empty_boss_utility_placeholders` | `game/art/bosses/utilities/boss-freight-reclamation-anchor.png` | **Accepted** |
| A25 | Seraph production projection | `empty_boss_utility_placeholders` | `game/art/bosses/utilities/boss-seraph-production-projection.png` | **Accepted** |
| A26 | CHOIR testimony pylon replacement | `choir_prime_testimony_projection` | `game/art/finale/choir-pylon.png` | **Accepted** |
| A27 | Existing composition-echo integration/QA | `choir_prime_testimony_projection` | Existing catalog enemy textures; no new file | **Accepted** |

### Execution result

Agent 6 generated **26 GPT Image 2 runtime assets** for the 16 audited visual families and completed the reuse-only A27 integration. The final optimized runtime sources total **1,128,798 bytes**. The first merged Godot 4.7.2 Web export measured 17,590,236 bytes, 813,020 bytes above the 16 MiB ceiling; the planned one-pass Lanczos optimization reduced 13 presentation-only derivatives by 1,512,360 source bytes without changing display or gameplay geometry. The final PCK is **16,513,100 bytes**, leaving **264,116 bytes** of headroom. The initiative’s three focused suites passed with **15 tests and 417 assertions**. The semantic merge additionally passed the upstream telegraph suite with **8 tests and 212 assertions**, proving damage-scaled warnings and authored variants coexist. Full release-gate certification was intentionally skipped under the project-level release-gate override; direct import, focused regression, fresh export, source integration, and WebDev synchronization remain the delivery path.

## 17. Definition of done

The initiative is complete when all 27 ledger entries are Accepted; all 55 roster entries are covered by the audited family map; the centralized projectile catalog is the only authored projectile mapping; every support and boss visual remains mechanically subordinate; the project-approved focused regression passes; the Web package remains below 16 MiB; the provenance manifest is complete; and every authored family retains a procedural or generic rollback path without changing gameplay signatures. Full certification-only gates remain outside this task under the explicit project override.
