# District Chimera Enemy Implementation Plan

**Project:** Proto Scroller  
**Engine:** Godot 4.7.2  
**Feature:** Twenty additional district-specific Project CHOIR enemy variants  
**Status:** Implementation in progress  
**Canonical design:** [District Chimera Enemy Proposal](DISTRICT_CHIMERA_ENEMY_PROPOSAL.md)

## 1. Objective

This plan implements the approved twenty-enemy Project CHOIR roster as a **data-driven extension of the existing fixed procedural combat runtime**. The implementation must preserve the current twenty-six base archetypes, five prewarmed family pools, shared projectile pools, fixed body and wreck budgets, authored six-act encounter decks, and the public Web deployment architecture.

The completed system will expose three explicit cardinalities: **26 base procedural archetypes**, **20 district variants**, and **46 total spawnable procedural IDs**. Each spatial district receives exactly four variants. Runtime selection is deterministic and takes place after the existing legacy Project CHOIR hybrid substitution, before threat calculation, progression copies, reservation ledger admission, and pending spawn construction.

## 2. Non-Negotiable Constraints

The implementation must not add live enemy pools, projectile pools, remains pools, independent decoy actors, persistent hazards, carrier payload types, traversal gates, or branch-history rewrites. The five procedural family capacities remain infantry 24, light 6, heavy 8, air 8, and siege 4. The soldier body budget remains 8 and the wreck budget remains 4.

All variants reuse existing behavior semantics. Repair affects one nearest damaged non-self ally within 520 pixels for exactly 22 health. `scan` applies the existing three-second target mark. `choir_ring` applies the existing four-second target mark. Ground-pass variants reuse existing pass, commit, turn, and recovery behavior. Artillery variants fire one ordinary shared-pool shell with no persistent field or second explosion.

The user's release-gate override applies. This plan does not run `verify.sh`, `verify.sh --full`, the repository-wide GUT directory, repeated stabilization loops, or release-certification matrices. Each work package uses only narrowly focused parse, catalog, resolver, runtime, and integration checks needed to catch obvious regressions.

## 3. Architecture

### 3.1 Catalog Layer

`EnemyArchetypeCatalog.PROCEDURAL_IDS` remains unchanged at twenty-six entries. The catalog adds `DISTRICT_VARIANT_IDS`, `ALL_SPAWNABLE_IDS`, and a five-district `DISTRICT_VARIANTS` map containing exactly four IDs per district. A second dictionary stores shallow immutable overlays. Every overlay declares `base_archetype_id`; `profile()` returns a flattened deep copy of the base profile with the overlay applied.

Canonical helpers centralize inherited identity. `canonical_id()` returns the base ID for a district variant and the input ID for an ordinary archetype. Family, reservation key, presentation scale, human classification, vehicle classification, threat, XP, airborne status, and remains routing consume flattened profiles or canonical classification rather than maintaining twenty new hard-coded branches.

### 3.2 Encounter Resolution

`HybridEncounterResolver` retains the current district-aware six-hybrid pass. It then performs a deterministic district-variant pass using stable inputs: run seed, spatial district, act index, beat index, and entry index. A variant is eligible only when it shares the final entry's family and does not increase the final beat above the authored maximum threat. Business skips the legacy hybrid pass but still executes the variant pass.

The authored `DistrictBeat` remains immutable. The resolver deep-copies it once, performs both substitutions, and exposes traces that distinguish the legacy hybrid result from the final concrete district variant. `DistrictResponseDirector` uses only the final beat for authored/resolved threat, progression-copy planning, reservation ledger counts, elite assignment, and pending spawn records.

### 3.3 Pooled Actor Layer

`ProceduralEnemy` stores both concrete `archetype_id` and canonical `base_archetype_id`. It configures exclusively from the flattened profile and publishes both identities as metadata. Existing movement, attack, projectile, telegraph, repair, marking, armor, carrier, remains, and animation paths remain shared.

The reset contract clears cooldown, state time, animation phase, attack kick, pass side, child count, attack sequence, ablative armor, extra projectile reservations, visual transform, visual modulation, and concrete/canonical metadata on every reuse. Variant cosmetics remain baked into the single sprite texture; they do not create targetable or independently simulated children.

### 3.4 Narrative and Containment Layer

Narrative first-contact logic canonicalizes concrete IDs before comparing against the existing six Project CHOIR identities. The Entertainment containment release resolves a deterministic district-compatible concrete light variant while preserving idempotence, stable building/cell identity, and the existing fixed light-family pool. No streamed building reference survives the callback.

### 3.5 Art and Packaging

The twenty cleaned proposal concepts live in `docs/concepts/district-enemies/`. GPT Image 2 production masters live outside the runtime under `docs/story-concepts/production-sources/chimera-variants/`. Deterministic processing creates compact transparent runtime PNGs numbered `27` through `46` under `game/art/city/enemies/archetypes/`. Runtime files are bounded to 320–448 pixels on their longest dimension.

A fresh Godot 4.7.2 Web export after source integration is the only authoritative package-size measurement. The final PCK must remain at or below 16 MiB. If the first export exceeds the cap, runtime textures will be downscaled in one deterministic pass while proposal concepts and GPT masters remain untouched.

## 4. Work Packages

| Work package | Status | Deliverable | Focused check | Source milestone |
|---|---|---|---|---|
| WP0 — Proposal and assets | Completed | Canon proposal, twenty embedded GPT Image 2 concepts, masters, processor, provenance | 20/20 concepts and runtime outputs; alpha and dimensions inspected | Commit and push documents/assets |
| WP1 — Catalog and identity | Completed | 26/20/46 catalog contract, overlays, canonical helpers, concrete textures | Catalog cardinality and profile validity tests | Commit and push catalog layer |
| WP2 — Deterministic encounter integration | Completed | Hybrid-then-variant resolver, Business support, director trace and final-beat accounting | Resolver determinism, immutability, family/threat safety | Commit and push resolver/director layer |
| WP3 — Runtime and narrative integration | Completed | Concrete/base identity, reset hardening, narrative canonicalization, containment selection | Shell reuse, support values, narrative/containment focused tests | Commit and push runtime layer |
| WP4 — Gallery and focused regression | Completed | Exactly-20 district gallery/selftest, targeted tests, plan completion record | Touched-script parse and focused GUT/selftests only | Commit and push final source |
| WP5 — Web export and deployment | Pending | Fresh Web export, immutable WASM/PCK remap, WebDev checkpoint, public deploy | Direct artifact existence/size and lightweight HTTP/runtime smoke | Checkpoint and deploy existing WebDev project |

## 5. WP0 — Proposal and Asset Production

WP0 converts the approved roster into the canonical proposal, embeds one concept per enemy, preserves the raw GPT Image 2 sources outside the game runtime, and derives the compact runtime textures. The proposal documents lore origin, silhouette, family, health, threat, inherited base, behavior, telegraph, player response, spawn strategy, reuse constraints, and district escalation for every entry.

**Files:** `docs/DISTRICT_CHIMERA_ENEMY_PROPOSAL.md`, `docs/concepts/district-enemies/*.png`, `docs/story-concepts/production-sources/chimera-variants/*`, `scripts/process-district-enemy-assets.py`, and runtime textures `game/art/city/enemies/archetypes/27-*.png` through `46-*.png`.

**Exit criteria:** exactly twenty unique concept files, exactly twenty source masters, exactly twenty compact runtime files, clean alpha, bounded runtime dimensions, embedded relative links, and explicit GPT Image 2 provenance.

## 6. WP1 — Catalog and Canonical Identity

WP1 adds the exact roster IDs and flattened profile overlays. Each overlay selects an existing base archetype whose family and behavior already implement the approved combat role. Overlay values may change display name, texture, health, movement/range scalars, attack cadence, anticipation, damage, XP, threat, display/collision tuning, and district weight, but may not change the inherited reservation family.

**Primary files:** `game/scripts/encounter/enemy_archetype_catalog.gd`, `game/scripts/encounter/enemy_spawn_entry.gd`, and `game/test/test_enemy_archetypes.gd`.

**Exit criteria:** 26 base IDs remain unchanged; 20 variant IDs are unique; 46 all-spawnable IDs are unique; every district owns exactly four variants; every overlay resolves to a valid base, family, texture, behavior, movement style, attack style, projectile kind, remains family, threat, and presentation scale; no pool capacity changes.

## 7. WP2 — Deterministic Encounter Integration

WP2 updates `HybridEncounterResolver` and `DistrictResponseDirector`. The resolver must not return early for Business. It performs the six-hybrid pass where eligible and then attempts at most one district variant per eligible final entry, using a stable rotated candidate order and family match. Mutual readability rules prevent duplicate local markers, duplicate artillery heavies, and Entertainment Siren/Lantern stacking where the resolver can detect them from the final composition.

**Primary files:** `game/scripts/encounter/hybrid_encounter_resolver.gd`, `game/scripts/siege/district_response_director.gd`, `game/test/test_project_choir_enemies.gd`, `game/test/test_encounter_director.gd`, and `game/test/test_district_pressure.gd`.

**Exit criteria:** authored resources remain byte-stable; same inputs yield identical concrete beats and traces; a different seed can vary only within the district allowlist; Business receives variants but no legacy hybrid; final family and threat are reservation-safe; all final planning uses the resolved concrete beat.

## 8. WP3 — Runtime and Narrative Integration

WP3 teaches `ProceduralEnemy` and narrative systems about canonical and concrete identity without adding actor classes. It strengthens the pooled reset contract and adds a compact debug snapshot for targeted reuse assertions. The existing damage, support, mark, projectile, animation, death, and remains code remains authoritative.

**Primary files:** `game/scripts/actors/procedural_enemy.gd`, `game/scripts/narrative/project_choir_runtime.gd`, `game/scripts/narrative/narrative_director.gd`, `game/test/test_project_choir_narrative.gd`, `game/test/test_airborne_enemy_wrecks.gd`, and `game/test/test_runtime_budget.gd`.

**Exit criteria:** concrete IDs retain canonical base metadata; variant profiles configure on existing shells; old→variant→old reuse leaves no state; `scan`, `choir_ring`, and repair values remain unchanged; containment remains bounded and idempotent; variant airborne units use the fixed crash-wreck path; runtime capacities remain unchanged.

## 9. WP4 — Gallery and Focused Regression

WP4 adds a separate exactly-twenty district gallery rather than expanding the existing twenty-six-archetype variety lane. The gallery groups four variants per district and reports concrete ID, canonical base, family, texture, bounds, and facing. It runs headlessly and can render landscape and portrait layouts when a lightweight visual check is useful.

**Primary files:** add the directly executable `game/selftest/district_enemy_variant_gallery_scenario.gd` and its Godot UID; keep `game/selftest/enemy_variety_scenario.gd` unchanged as the twenty-six-base contract.

**Focused checks:** Godot import, `gdlint` for touched scripts, touched-script parse/check, selected GUT cases for catalog/resolver/director/narrative/remains/budget, and the new twenty-variant gallery in headless landscape and portrait layouts. The unchanged enemy-variety scenario remains the twenty-six-base contract but is not expanded or rerun as a release gate. No repository-wide verification gate is run.

## 10. WP5 — Web Export and Existing WebDev Synchronization

After final source integration, WP5 performs a fresh non-threaded Web export with Godot 4.7.2. The expected HTML, JavaScript, WASM, and PCK artifacts must exist and be nonempty. The PCK is measured against the 16 MiB cap. The existing `/home/ubuntu/proto-scroller` WebDev project is reused; no replacement project is created.

The exported HTML/JavaScript shell is refreshed when changed. The exact final WASM and PCK are uploaded and remapped as immutable WebDev objects even if the engine WASM checksum is unchanged. The fullscreen, borderless, zero-margin iframe host, title behavior, scheduler, worklets, and trusted-input handoff remain intact. `PLAN.md`, `STRUCTURE.md`, `MEMORY.md`, and `ASSETS.md` are updated with source revision, artifact hashes and byte sizes, checkpoint, and deployment URL.

Per the release-gate override, WebDev work uses direct build/check commands and a lightweight preview/public request smoke rather than a release-certification matrix. A fresh checkpoint is saved and the existing public site is deployed.

## 11. Focused Test Matrix

| Area | Focused evidence |
|---|---|
| Catalog | Exact 26/20/46 cardinality; five districts × four; valid bases, textures, families, profiles, classifications, and remains |
| Resolver | Same-seed determinism; alternate-seed variation; Business variants; hybrid-first ordering; deep-copy immutability; family/threat safety |
| Director | Final resolved beat used before threat, progression copies, reservation ledger, and pending spawns |
| Pools | Existing family capacities unchanged; shells reused; no post-warm creation; no reservation leak |
| Support | Repair remains 22 health / 520 pixels / one target; scan remains 3 seconds; choir ring remains 4 seconds |
| Narrative | Concrete IDs canonicalize; first-contact dedupe remains stable; containment release remains bounded and idempotent |
| Remains | Infantry uses fixed bodies; vehicle/air variants use four fixed wreck slots; airborne variants crash through existing path |
| Art | Twenty proposal concepts and twenty compact alpha runtime textures; 320–448-pixel maximum dimension |
| Packaging | Fresh Godot 4.7.2 Web export; HTML/JS/WASM/PCK present; PCK ≤16 MiB |
| WebDev | Existing project reused; immutable WASM/PCK remapped; checkpoint saved; public deployment refreshed |

## 12. Completion Record

This section will be updated after each work package with commit IDs, focused checks, artifact sizes, checkpoint information, and any deviations. A work package is complete only after its implementation is pushed to shared `main` without rewriting history.

| Work package | Completion | Commit / checkpoint | Focused evidence | Notes |
|---|---|---|---|---|
| WP0 | Completed | `88e2fe9d480bd2929942c4289853add7320f9f27` | 20 proposal concepts, 20 GPT Image 2 masters, 20 transparent runtime sprites; runtime PNG total 2,831,759 bytes; visual contact sheet inspected | Proposal embeds every concept; source masters remain outside `game/`; runtime derivatives are 320–448 pixels maximum dimension. |
| WP1 | Completed | `124990d992f619b47f092aae22983a5e6021a28f` | Focused catalog filters: 3/3 tests and 632 assertions passed; Godot 4.7.2 imported all 20 textures without catalog or spawn-entry parse errors | Base behavior-signature uniqueness remains scoped to the original 26; overlays intentionally reuse those behaviors. The inherited isolated Reclaimed Breacher TTK expectation remains outside WP1 and was not altered. |
| WP2 | Completed | `5dd1e5446a86ee57a90ce7b80614c987a80e0581` | Five staged resolver/director tests passed, including all five district allowlists, 40-seed roster coverage, Business variant injection without legacy hybrids, deep-copy determinism, family/threat preservation, and reservation-before-pending tracing | The focused CHOIR file passed 7/8 tests; its only failure was the pre-existing Reclaimed Breacher frontal-brace mismatch, scheduled for correction in WP3 where pooled actor identity is updated. |
| WP3 | Completed | `3ff2afeaeacc58c39a62dc52aa256941ec782d56` | 13 focused tests and 287 assertions passed: complete CHOIR runtime file, exact repair/mark values, canonical first-contact dedupe, deterministic concrete containment, old→variant→old reset, and all 12 airborne flattened profiles | Reclaimed Breacher frontal bracing was corrected while leaving Covenant Warden's shield presentation-only. Glassback Double canonicalizes to Ossuary Crawler for the existing bounded containment and narrative contract. |
| WP4 | Completed | `45868d6e3e2008077b61821490b2e575826ef701` | Final selected GUT regression: 10/10 tests and 817 assertions passed. The direct gallery passed 64/64 checks in both 1280×720 and 720×1280 headless layouts, with exactly 20 cards and four per district. | Headless mode intentionally skipped image capture; no Xvfb or screenshot certification was run under the release-gate override. `enemy_variety_scenario.gd` remains unchanged at 26 base archetypes. |
| WP5 | Pending | — | — | — |
