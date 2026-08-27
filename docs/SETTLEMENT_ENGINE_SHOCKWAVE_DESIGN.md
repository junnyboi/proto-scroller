# Settlement Engine S-04 Shockwave Combat Design

**Author:** Manus AI  
**Status:** Implemented; source integration and Web release pending  
**Scope:** Replace Settlement Engine S-04's current single static radial hazard with a readable suite of telegraphed, outward-traveling ground shockwaves; ground defeated boss rubble on the road center line.

## Design Intent

Settlement Engine S-04 should communicate industrial mass rather than abstract area damage. Its attacks therefore begin as visible pressure accumulating beneath the boss, disclose their wave count and reach before release, and then become bright physical fronts that propagate over the road. The player is attacked only when a traveling front intersects the robot, not merely because the robot stands somewhere inside a prefilled circular zone.

> **Core readability rule:** the telegraph previews the same concentric front count, delay sequence, and maximum reach that will become lethal after release.

The new system preserves the boss's existing armor/finisher structure, archive objective, support-soldier pressure, animation rig, damage multiplier, and campaign persistence. Only the first boss's offensive attack vocabulary is replaced.[1] [2]

## Shockwave Vocabulary

| Pattern | Combat phase | Telegraph | Released attack | Player response |
| --- | --- | --- | --- | --- |
| **Assessment Levy** | Armored opening | One amber range rail, one contracting charge ring, and a boss-centered ground flare | One fast white-hot pressure front expands to medium-long reach | Cross the front with a precisely timed dodge or stay outside its disclosed range |
| **Double-Entry Rupture** | Armored and exposed | Two concentric ghost rings and two countdown spokes | Two visible fronts release with a deliberate inter-wave delay | Avoid spending dodge recovery on the first wave if the second is approaching |
| **Compound Default** | Final exposed phase | Three concentric rails, accelerated pulse cadence, and red-white terminal strobe | Three increasingly fast fronts propagate to the widest reach | Reposition early, then time consecutive evasions through the compressed final cadence |

The attack sequence escalates by boss state. The armored phase alternates **Assessment Levy** and **Double-Entry Rupture**. The exposed phase alternates **Double-Entry Rupture** and **Compound Default**. Below one-third body health, **Compound Default** becomes the first choice and alternates with the double wave so the finale remains demanding without becoming an unbroken triple-wave loop.

## Telegraph-to-Release Language

During **TELEGRAPH**, the attack area renders a warm translucent range rail on the road plane, a bright boss-centered emitter ring, one ghost ring per future wave, and a number of radial countdown spokes equal to the front count. Ghost rings remain non-damaging. Brightness and cadence accelerate toward release.

At the **TELEGRAPH → ACTIVE** boundary, the range fill disappears, the authored pressure-ring texture flashes at the boss's ground contact point, and the first front begins expanding. Subsequent fronts remain visible as compressed launch rings until their configured release delays expire. Active fronts use a white-gold leading core, amber industrial fragments, restrained cyan interference, and a fading wake. The generated texture supplies high-frequency energy detail; deterministic Godot geometry controls exact position, radius, timing, collision, and alpha.

During **RECOVERY**, all shockwave fronts disappear immediately. This prevents stale collision or lingering warnings from crossing into the next attack and leaves the support-soldier deployment readable.

## Damage and Collision Contract

Each attack activation receives one unique root attack ID. A robot can be damaged at most once by that activation even when a multi-wave pattern contains two or three visible fronts. Collision is evaluated against a bounded radial band at the released front's horizontal road distance; the compressed vertical axis is presentation-only. Standing near the boss before a front reaches the robot is safe, standing behind an already-passed front is safe, and standing on the disclosed moving front is dangerous.

| Parameter | Assessment Levy | Double-Entry Rupture | Compound Default |
| --- | ---: | ---: | ---: |
| Fronts | 1 | 2 | 3 |
| Release delays | 0.00 s | 0.00 / 0.30 s | 0.00 / 0.24 / 0.48 s |
| Maximum radius | 760 px | 830 px | 900 px |
| Front travel duration | 0.82 s | 0.90 s | 0.96 s |
| Telegraph duration | 0.90 s | 1.05 s | 1.16 s |
| Active duration | 0.95 s | 1.24 s | 1.50 s |
| Base damage | 60 | 66 | 72 |

Damage remains multiplied by the existing enemy damage multiplier and is tagged as hazard damage. Unlike the superseded static radial pulse, the moving fronts respect the player's short dodge-invulnerability window because their escalating multi-wave timing is built around reading and crossing discrete pressure fronts.[3]

## Defeated Boss Rubble

The boss rubble bed is visually bottom-aligned so its lower edge rests exactly on `CityStreetChunk.ROAD_DIVIDER_Y`. Its horizontal position continues to follow the defeated wreck. This removes the previous floating presentation while preserving rubble scale, reward position, and pooled utility ownership.[4]

## Runtime Architecture

`BossAttackArea2D` remains the single prewarmed first-boss shockwave node. It gains a bounded traveling-front profile containing at most three fixed release delays, a front travel duration, vertical road-plane compression, and a leading-band thickness. It continues to own collision and damage deduplication. `BossVerticalSliceController` selects the pattern, durations, reach, and damage from the current first-boss phase. `BossUtilityPool` keeps the existing fixed capacity of one radial shockwave node, so the feature adds no per-attack node allocation.

The authored VFX texture is generated with GPT Image 2, alpha-cleaned deterministically, and imported as a compact Web texture. No additional animation atlas is required because the shockwave's visible motion comes from world-space radial propagation rather than frame animation.

## Acceptance Criteria

| Area | Acceptance criterion |
| --- | --- |
| Telegraph fidelity | Visible ghost-front count and reach match the released attack exactly |
| Attack replacement | S-04 exposes only the three new shockwave patterns; the former static full-disc hazard is not selected |
| Visible propagation | Every active attack shows one to three clearly expanding fronts centered at the boss's ground origin |
| Collision fidelity | Damage occurs only at a released front band and at most once per activation |
| Phase escalation | Armored, exposed, and final-health attack lists follow the pattern table above |
| Pooling | One prewarmed `radial_shockwave` node handles every front without runtime node creation |
| Rubble baseline | Defeated boss rubble lower edge equals the road middle line |
| Responsive presentation | Telegraph and released fronts remain legible in landscape and portrait captures |
| Deployment | The final source is pushed to shared `main`, freshly exported with Godot 4.7.2, and both WASM and PCK are remapped in the existing WebDev project |

The focused Godot 4.7.2 acceptance pass completed **28 tests and 1,023 assertions** across the first-boss vertical slice, boss campaign/finisher lifecycle, and localization contracts. It proves all three front counts and phase rotations, front-band-only damage, timed dodge crossing, per-activation deduplication, generated texture ownership, localized HUD labels, and rubble bottom alignment on the road divider. Full release-gate certification was intentionally skipped under the project release-gate override.

## References

[1]: ../game/scripts/siege/boss_vertical_slice_controller.gd "Settlement Engine and Samaritan vertical-slice controller"
[2]: ../game/scripts/siege/command_boss_session.gd "Boss session state and animation integration"
[3]: ../game/scripts/siege/boss_attack_area_2d.gd "Boss attack telegraph, collision, and damage area"
[4]: ../game/scripts/world/city_street_chunk.gd "City road and lane geometry"
