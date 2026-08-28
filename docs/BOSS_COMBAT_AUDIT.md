# Proto Scroller Boss Combat Audit

**Audit date:** 2026-08-28

**Engine target:** Godot 4.7.2-stable

**Scope:** Settlement Engine S-04, SAMARITAN-15, MIMESIS-04, CANTOR-31 / Pale Engine, and CHOIR Prime

## Executive assessment

The five-boss campaign now shares one legible physical contract. Every animated boss rig renders at **150 percent scale**, and each atlas has its own alpha-bound calibration so the visible machine touches the road divider in moving and attack poses. Boss encounters still lease the six resident chunks, retain their structural snapshots, preserve retry ownership, and place the player-only arena boundary exactly 520 pixels to the boss's right flank—130 pixels beyond the common visible half-width. They no longer bind a random landmark facade: the resident building is reversibly hidden and non-colliding without mutating its destruction state, then restored when the lease ends.[1][2][3]

Settlement Engine S-04 now uses one player-style **Core Shockwave** in every combat phase. Cyan photon motes converge into a massive blue sphere at the visible boss core, then one circular cyan-white ring expands outward; only contact with that visible moving band can damage, and timed dodge invulnerability remains valid. The other four bosses no longer use hidden lane, line, or radial areas as live-body damage authority. Their existing footprints, dry lanes, pods, memory markers, freight anchors, pylons, and echoes remain navigation or narrative cues, while actual damage is delivered by enlarged hostile projectiles from the existing fixed `ProjectilePool`. Boss projectiles scale both their rendered envelope and collision radius by 1.5 and reset to 1.0 when returned to the pool.[4][5][6]

Every boss volley reserves its complete projectile requirement before presenting a warning. The reservation and one fixed telegraph record are canceled together if capacity is unavailable. A successful telegraph commits the promised shell or rocket sequence from visible rig sockets or an authored marker position. Recovery, armor-generation changes, retry, stop, body death, and Royal wreck transition release pending reservations, visible telegraphs, and in-flight boss shots. CANTOR's three-shell Rosary and CHOIR Prime's two-rocket Canon therefore cannot degrade into partial, untelegraphed attacks under pool pressure.[4][7]

Continuous district reinforcements now replace casualties while each live body remains active. SAMARITAN holds up to four Residential variants, MIMESIS three Entertainment variants, CANTOR four Military variants, and CHOIR Prime two Royal variants at once. These rosters are controller-owned, deterministic, retry-safe, and independent of singular narrative supports such as the Reclaimed Breacher, Graft Runner, and CHOIR Siren. Healer target selection explicitly excludes the hidden boss authority shell. All continuous reinforcement activity stops at body death, and Royal pressure is cleared before wreck and severance handling.[8][9][10][11]

## Universal defeat sequence

> **Keyboard:** Move with **A/D**, hold **Space** to charge the selected melee, and dodge with **Shift**. On touch devices, use the floating movement joystick, **SMASH**, and **DASH**.

| Stage | Required player action | Readable combat truth |
|---|---|---|
| **Armored** | Against **Settlement Engine S-04**, use any melee or equipped weapon; every accepted damage type reduces armor by its actual amount. Against bosses 2–5, reach at least 70 percent movement speed, align with the gold core, hold **Space/SMASH for 2.0 seconds**, and release. Repeat for three accepted connections. | Yellow is armor. A white boss flash confirms accepted damage. The four later bosses reject standing taps and ranged armor damage but never block normal player movement. |
| **Exposed body** | Use normal melee and equipped weapons while dodging visible pressure fronts or projectile trajectories and managing reinforcements. | Red is body health. The moving front, enlarged shell, or enlarged rocket is damage authority; legacy lane and echo graphics are presentation-only during bosses 2–5's live-body fights. |
| **Destruction spectacle** | No additional player action. Begin moving when ready to reclaim the camera. | The right wall drops at body death and the camera subtly reveals the newly open route. It holds while the robot remains stationary, then returns to normal follow when the player moves. The darkened final atlas frame remains visible through the fixed 2.95-second explosion-and-fireworks sequence; completion automatically creates rubble, scrap, repair drops, evidence, and salvage progression once. |

The active attempt suspends ordinary rear-wall and facade collision so the player can retreat and reposition to the left. A single invisible player-only wall sits just beyond the boss's right flank and prevents the robot from crossing the live machine. It disappears as soon as body health reaches zero. At the same boundary, the camera eases right by at most 220 world pixels toward the former wall, remains there while the robot is stationary, and returns at twice the pan speed once the robot has intentionally moved at least 18 pixels after the 0.75-second minimum reveal. Body defeat also triggers the pooled explosion-and-fireworks spectacle; the end of that sequence, not another attack, is the sole rubble and progression boundary.[1][12][13]

## Boss-by-boss field guide

### 1. Settlement Engine S-04 — The Fiduciary Saint

**Identity:** An accessible shockwave bruiser that teaches armor, spacing, and support control without the later moving-charge restriction.

| Phase | Abilities and pressure | Counterplay |
|---|---|---|
| **Armored** | **Core Shockwave** gathers 72 cyan-blue photon motes into a growing blue sphere at the visible core, then releases one expanding contact-damage ring. Each recovery summons four foot soldiers until eight are active, replacing casualties without exceeding the cap. | Use any melee or equipped weapon. Ground smash, tap jab-cross, bullets, shells, rockets, and impact damage all reduce armor by their actual accepted amount. Reposition while the sphere grows, then move or dodge through the visible ring. |
| **Exposed** | The same Core Shockwave repeats with identical charge and release timing; there is no hidden alternate pattern. | Clear soldiers when they crowd the approach, preserve the dodge for the release, then attack the exposed body during recovery. |
| **Final third** | Core Shockwave remains the only attack. Its damage still scales through the global enemy multiplier in New Game+. | Read the photon convergence rather than a new phase-specific symbol; evade the single ring and punish recovery. |
| **Defeat** | The S-04 atlas freezes and darkens during the destruction spectacle. | After 2.95 seconds it automatically becomes road-grounded rubble and releases two 150-HP repair cells. |

**How to take it down:** Damage the armor with any weapon, then continue with any normal damage source against the exposed body. Each accepted hit produces a brief white flash and updates the compact yellow/red bars. Cyan photons and a rising electrical cue gather into the growing core sphere for 1.45 seconds; at release, that sphere and charge cue disappear, the one-second pressure cue begins, one restrained camera impulse lands, and the visible cyan-white ring becomes damage authority. Cross the ring with movement or the 0.30-second dodge window, then use recovery to damage S-04 or thin the incoming soldiers. At zero body health, the destruction sequence finishes automatically and its rubble settles on the road divider before the completion record and repair drops.[1][3][10][12]

### 2. SAMARITAN-15 — The Last Evacuation

**Identity:** A rescue-pressure fight with protected pods, rotating evacuation language, and a one-at-a-time **Code-Blue Carousel** shell.

| Phase | Abilities and pressure | Counterplay |
|---|---|---|
| **Armored** | **Triage Sweep** and **Pressure Sentence** preserve their outer-lane and horizontal warning grammar, but damage arrives as one enlarged Rainvault shell fired from alternating left, upper, right, and core sockets toward a deterministic player snapshot. Pressure Sentence may still deploy one singular Reclaimed Breacher. | Use the warning path to reposition, destroy the Breacher if it crowds the core approach, and land three moving full-charge connections. |
| **Exposed / final third** | **Extraction Clamp** still targets one side pod. **Blackout Harvest** preserves a rotating dry lane and may deploy one singular Graft Runner. Every named pattern launches the visible shell rather than arming an invisible area. Up to four ordinary Residential variants rotate continuously: Intake Shepherd, Evacuation Litter, Rainvault Pressure Ward, and Balcony Recall Beacon. | Protect space around the pods, prioritize the special Runner or crowding artillery, and punish the boss after the shell passes. Optional pod loss affects the record, not the direct body route. |
| **Defeat** | Surviving pods are rescued automatically. | The completed spectacle creates rubble and two 150-HP repair cells without another input. |

### 3. MIMESIS-04 — The Afterimage Conductor

**Identity:** A memory-recognition fight whose cyan history and magenta selection now guide projectile origins instead of concealing area damage.

| Phase | Abilities and pressure | Counterplay |
|---|---|---|
| **Armored** | **Dead-Air Sweep** announces one enlarged Marquee shell. **Memory Blocking** atomically reserves two offset shells from opposite emitters. A successful Memory Blocking recovery can deploy one singular CHOIR Siren. | Move across the announced trajectories and land three moving full-charge core connections. Cyan history remains harmless presentation. |
| **Exposed** | **Armed Afterimage** selects one magenta memory marker and fires the shell from that world-space origin. The marker itself remains non-colliding. | Read the marker as the launch point, not as an instant damage rectangle. Enter the Siren's 118-pixel hollow center to restore its one paused weapon. |
| **Final third** | **Encore Impact** reserves three shells atomically and releases them from left, upper, and right sockets at 0.16-second intervals. Up to three ordinary Entertainment variants rotate continuously: Memorial Usher, Glassback Double, and Marquee Anesthetist. | Do not confuse cyan composition history with the three orange-red projectile paths. Clear artillery pressure before the next Encore reservation window. |
| **Defeat** | The STAGE continuity payload survives controller cleanup. | The completed spectacle creates rubble and three 150-HP repair cells without another input. |

### 4. CANTOR-31 / Pale Engine — The Export Surgeon

**Identity:** A production fight centered on the atomic **Suture Rosary**, marked pursuit, and finite freight reclamation.

| Phase | Abilities and pressure | Counterplay |
|---|---|---|
| **Armored / exposed** | **Suture Salvo** reserves three enlarged shells before warning, then launches left, upper, and right shots toward −120, 0, and +120-pixel player offsets. If three shell slots cannot be guaranteed, the complete Rosary is deferred with no partial telegraph. **Dispatch Harness** retains one marked Graft Runner and creates a freight anchor only after successful deployment. | Move after the target snapshot, destroy the marked Runner, and release each full-charge connection from a clear approach. |
| **Final third** | **Compression Psalm** becomes one slower visible shell. **Pale Reclamation** remains finite and consumes at most three freight anchors into two capped ablative records while also using a visible shell transaction. Up to four Military variants rotate continuously: Suture Marshal, Mercy Raker, Revetment Ward, and Triage Kite. | Track the projectile rather than legacy beam geometry. Deny visible anchors and thin the mixed ground/air roster before committing to a long charge. |
| **Defeat** | The ARSENAL export payload remains intact through the spectacle. | The completed sequence creates rubble and three 150-HP repair cells without another input. |

### 5. CHOIR Prime — The Last Sovereign

**Identity:** A final exam that retains five named pylons, district composition echoes, and evidence-dependent outcomes while every live-body testimony fires an atomic **Crown Canon**.

| Phase | Abilities and pressure | Counterplay |
|---|---|---|
| **Armored / exposed / final third** | Ledger, Nursery, Stage, Arsenal, and Crown testimonies keep their named warning footprints and non-colliding echoes. Each testimony reserves two enlarged direct rockets, telegraphs both paths, and launches from opposite emitters with a 0.22-second stagger toward deterministic lateral leads. Up to two Royal variants rotate continuously from Privy Chirurgeon, Laureate Courser, Ninefold Witness, and Regency Conservator. | Apply the earlier armor lesson, move after the paired target snapshots, and clear whichever two Royal supports currently shape the arena. Echo silhouettes are never projectile or collision authority. |
| **Automatic outcome** | Body-phase rockets and reinforcements stop before the destruction spectacle. The immutable pre-wreck evidence snapshot remains authoritative. | A complete eligible snapshot automatically preserves **DISENTANGLE**; every ineligible snapshot safely commits **PURGE**. The same spectacle completion creates rubble plus three 150-HP repair cells. |

## Fun and fairness assessment

The campaign now exposes damage through moving objects rather than instant invisible area truth. Each boss still teaches a distinct skill: S-04 teaches radial spacing; SAMARITAN teaches a single projectile rhythm amid rescue pressure; MIMESIS changes projectile count and origin through memory grammar; CANTOR tests atomic spread recognition while finite mechanics compete for attention; and CHOIR Prime combines two-shot timing with a restrained Royal roster and evidence-aware automatic resolution.

The visual language is consistent: **yellow is armor, red is body health, white flash confirms accepted damage, gold/orange paths predict projectiles, cyan is memory or Disentangle, and dry lanes are repositioning cues**. Fixed pool capacities remain honest. A saturated partition causes no boss shot and no promised telegraph, ordinary projectile reuse always returns to one-to-one scale, and support caps prevent continuous spawning from becoming geometric comedy.[4][5][7]

## Source references

[1]: ../game/scripts/siege/command_boss_session.gd
[2]: ../game/scripts/siege/arena_lease.gd
[3]: ../game/scripts/siege/boss_rig_2d.gd
[4]: ../game/scripts/siege/boss_projectile_volley.gd
[5]: ../game/scripts/combat/projectile_pool.gd
[6]: ../game/scripts/combat/projectile_2d.gd
[7]: ../game/scripts/encounter/telegraph_presenter_2d.gd
[8]: ../game/scripts/siege/boss_vertical_slice_controller.gd
[9]: ../game/scripts/siege/boss_escalation_controller.gd
[10]: ../game/scripts/siege/boss_royal_finale_controller.gd
[11]: ../game/scripts/actors/procedural_enemy.gd
[12]: ../game/scripts/siege/boss_arena_barrier_2d.gd
[13]: ../game/scripts/siege/boss_defeat_spectacle_2d.gd
