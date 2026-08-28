# Ground Enemy Attack Alignment Implementation Plan

## Problem statement

Ground-enemy attack feedback currently uses three independent origins:

1. `SoldierEnemy`, `TankEnemy`, and `ProceduralEnemy` calculate projectile origins from
   fixed offsets relative to the actor body.
2. `EnemyActor2D.begin_telegraph()` discards that origin for presentation and asks
   `attack_telegraph_origin()` for a second point. The humanoid branch deliberately
   places that point at the visible bottom of the sprite.
3. District-variant anticipation sprites use a third fixed local offset that does not
   account for the enemy texture's transparent margins, configured display scale, or
   facing direction.

The three coordinate contracts diverge most visibly for grounded humanoids and scaled
vehicles: the generic warning begins at the feet, the authored emission can appear above
the weapon, and the projectile launches from a different point again.

## Target contract

- Every grounded enemy exposes one forward weapon anchor derived from the visible
  alpha-bounded rectangle of its current sprite.
- The anchor sits just beyond the front visible edge in the current facing direction
  and at the vertical center of visible mass.
- The warning record, authored anticipation sprite, and launched projectile all use the
  exact same world-space anchor.
- Airborne enemies keep their existing authored launch sockets, while their district
  anticipation sprite still follows the exact projectile socket.
- A valid district attack phase is authoritative presentation. While it is visible, the
  generic `TelegraphPresenter2D` geometry is suppressed.
- An empty or invalid authored phase never suppresses the generic presenter, preserving
  the fallback for base enemies and procedural identities without replacement art.
- Pool capacity, attack timing, target selection, damage, projectile kinds, and impact
  behavior remain unchanged.

## Implementation work packages

### WP1 — Shared forward weapon anchor

Add a geometry resolver to `EnemyActor2D` that mirrors the cached visible content
rectangle for `flip_h`/`flip_v`, chooses the facing-side edge, uses its vertical center,
transforms the point through the animated `Visual`, and adds a small world-space forward
clearance. Make the telegraph presenter reserve the caller's committed origin rather
than recomputing another point.

Update the soldier, tank, and grounded procedural attack entry points to use the shared
anchor. Preserve the existing airborne procedural and helicopter sockets.

### WP2 — Sprite-first fallback-aware presentation

Validate the district attack phase before beginning the warning. Add an explicit
`authored_telegraph` style flag only when texture, region, and display-size metadata are
usable. Teach `TelegraphPresenter2D` to skip generic drawing for records carrying that
flag and expose a query used by regression tests.

Position the primary district anticipation sprite at the exact stored projectile origin.
Position actor-delivery payload art slightly farther forward on the same horizontal axis.
Keep all presentation nodes prewarmed and collisionless.

### WP3 — Focused regression coverage

- Prove direct `begin_telegraph()` calls preserve the supplied origin.
- Exercise every grounded base, procedural, and district identity in both directions.
- For each identity, prove the anchor is outside the visible front edge, vertically
  centered, and identical for telegraph and projectile activation.
- Prove all district replacements suppress generic drawing and center their primary
  anticipation sprite on the stored origin.
- Prove a legacy identity with no district attack phase retains generic fallback.
- Preserve reservation cleanup and fixed child-count assertions.

### WP4 — Verification and delivery

Run touched-file GDScript lint, a Godot import/parse pass, focused GUT suites for encounter
origins and district attack VFX, and the dedicated
`ground_enemy_attack_alignment_scenario.gd` representative attack render. Review the final
diff against pre-existing unrelated edits and exclude those user-owned changes from the
implementation.

## Acceptance criteria

The fix is complete when every grounded enemy identity passes the shared-origin matrix,
district attack sprites suppress duplicate generic geometry only when valid art exists,
fallback telegraphs remain active without replacement art, representative rendered attacks
originate in front of the attacker at center mass, and no focused parse, lint, pool, or
presentation regression remains.
