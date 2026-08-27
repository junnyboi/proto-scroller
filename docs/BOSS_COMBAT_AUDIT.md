# Proto Scroller Boss Combat Audit

**Audit date:** 2026-08-27

**Engine target:** Godot 4.7.2-stable

**Scope:** Settlement Engine S-04, SAMARITAN-15, MIMESIS-04, CANTOR-31 / Pale Engine, and CHOIR Prime

## Executive assessment

The reported first-boss lock was real. The screenshot shows the encounter still at **Armor 100%, Body 100%, Connections 0/3**. Before this repair, boss armor accepted only a moving, fully charged jab-cross, but rejected attacks gave the player no useful explanation. More seriously, standard bosses did not configure their mandatory wreck-finisher receiver because that setup was accidentally nested inside the CHOIR Prime-only branch. Therefore, even a player who discovered the hidden armor input could reach another blocked state after reducing the body to zero.

The audit found additional systemic weaknesses: telegraphed attack areas were visual-only; the screen-introduction state could advance attack timers invisibly; all attack patterns were exposed from the opening second rather than escalating; one boss-support wave had been doubled despite being a stateful boss mechanic; SAMARITAN's broad fallback hurtboxes overlapped protected glass; MIMESIS advertised a hollow-center counter that did not react continuously; the Military Graft Runner did not receive its target mark; evidence payloads could be lost because wreck generation could clean up a controller before its death callback captured results; and a transient completion-save failure could leave a consumed boss behind an owned route gate.[1][2][3][4]

The repaired contract is now readable across the campaign. A generated red-and-white **BOSS FIGHT** splash and synchronized announcer-impact cue introduce each attempt for approximately 1.2 seconds. The combat HUD has been reduced to the localized boss name, a yellow armor bar, and a red health bar. Every accepted boss hit flashes the complete visible rig white. Safe telegraphs transition to **magenta armed zones** that inflict one deduplicated chassis hit per activation, and introductions cannot arm attacks. Settlement Engine S-04 accepts every player damage type against armor; later bosses retain their authored charged-connection rule. One invisible player-only wall creates the arena exactly 1,000 pixels right of the live boss, then drops when the body reaches zero. That body defeat launches 12 overlapping explosions, 10 fireworks, 14 reusable emitters driving 548 particles, one heavy camera kick, and one positional carrier-derived detonation mix. Standard evidence survives the wreck callback order. Completion writes retry in place before the route state is consumed, and Royal persists its ending transaction before release.[1][2][5][10][12]

## Universal defeat sequence

> **Keyboard:** Move with **A/D**, hold **Space** for the charge attack, and dodge with **Shift**. On touch devices, use the floating movement joystick, **SMASH**, and **DASH**.

Every campaign boss follows the same readable armor, body, and wreck structure, with one deliberate opening-boss exception.

| Stage | Required player action | What does not work |
|---|---|---|
| **Armored** | Against **Settlement Engine S-04**, use any melee or equipped weapon: every accepted damage type chips the yellow armor bar by its actual damage. Against bosses 2–5, reach at least 70% movement speed, line up with the glowing gold core, then hold **Space/SMASH for the full 2.0 seconds** and release; repeat for three accepted connections. | Only the four later bosses reject standing smashes, taps, and ranged armor damage. Their corrective feedback remains available through combat presentation, not the compact durability HUD. |
| **Exposed body** | Use normal melee and equipped weapons while reading the telegraphs. Attacks escalate again below roughly one-third body integrity. | Remaining inside a magenta armed footprint. Pale/gold telegraphs are warnings; magenta is live damage. |
| **Boss corpse** | The authentic animated boss freezes on its final attack frame and darkens. Strike the labeled corpse with one **fresh melee**—jab-cross or ground smash—to reduce it to rubble. The fatal attack cannot double as the finisher. | Ranged fire, autonomous weapons, and the lethal attack/root chain. Rubble completion controls rewards and progression only; it never controls route access. |

The dodge has a 0.30-second invulnerability window and a 1.20-second cooldown. Line up before charging; once an attack is committed, locomotion remains locked through recovery and a recovery-phase dodge request is buffered until release. Boss attempts suspend the ordinary rear wall and facade obstruction but create one invisible right boundary 1,000 pixels beyond the boss. The route marker and left side remain open for retreat and repositioning; the right boundary disappears as soon as the live body is defeated. Ordinary boss hazard activations deal 16 base chassis damage once per activation, then deduplicate until a new attack arms.[5][6][10]

## Boss-by-boss field guide

### 1. Settlement Engine S-04 — The Fiduciary Saint

**Identity:** A lane-control tutorial boss with forgiving universal armor damage before later encounters introduce stricter connection mechanics.

| Phase | Abilities and attack pattern | Counterplay |
|---|---|---|
| **Armored** | **Settlement Sweep** covers asymmetric left and right ground zones. **Double-Entry Barrage** attacks both outer approaches and, after recovery, deploys one Bulwark and one Sapper. | Use any melee or equipped weapon. Ground smash, tap jab-cross, bullets, shells, rockets, and impact damage all reduce armor by their actual accepted amount. Attack during the open interval and watch the yellow bar. |
| **Exposed** | **Foreclosure Stamp** attacks the center. **Audit Beam** creates a long horizontal beam above the road. | Stay near an edge during Stamp; change vertical/road position relative to the thin beam; attack during recovery. |
| **Final third** | **Audit Beam** remains and **Foundation Cascade** adds a heavy left-side ground collapse. | Favor the right approach, dodge through a late arm, then punish the recovery. Eliminate the two support enemies if they obstruct the charging lane. |
| **Corpse** | The S-04 atlas freezes and darkens at body death; a gold **MELEE TO SCRAP** receiver appears. | Land one fresh jab-cross or ground smash to create rubble and two 50-HP repair cells. |

**How to take it down:** Damage the armor with any weapon while crossing the open lanes, then continue with any normal damage source against the exposed body. Each accepted hit produces a brief white flash and updates the compact yellow/red bars. Use the full space left of the right arena boundary; it vanishes into the explosion-and-fireworks barrage when the body fails. Strike the darkened boss corpse once with a fresh melee for the completion record and repair drop.[1][3][10][12]

### 2. SAMARITAN-15 — The Last Evacuation

**Identity:** A rescue-pressure fight built around protected side pods and rotating safe lanes.

| Phase | Abilities and attack pattern | Counterplay |
|---|---|---|
| **Armored** | **Triage Sweep** attacks the two outer lanes. **Pressure Sentence** fires a thin horizontal beam and can deploy one Reclaimed Breacher during recovery. | Use the center gap during Triage, then land three moving full-charge core hits. Kill the Breacher rather than letting it occupy the charging route. |
| **Exposed** | Triage remains. **Extraction Clamp** targets one side pod. | Damage the exposed chassis while avoiding the pod glass. Mechanical boss hurtboxes have been narrowed and separated from all protected glass rectangles. |
| **Final third** | **Blackout Harvest** arms two of three road lanes while one dry lane rotates each cycle; Pressure Sentence and Extraction Clamp remain. Blackout can deploy at most one live Graft Runner. | Identify the dry lane before magenta activation, move into it, and destroy the Runner before resuming body damage. |
| **Corpse** | The SAMARITAN atlas freezes and darkens; surviving pods are rescued automatically at body defeat. | Use one fresh melee on the labeled corpse to create rubble and two 50-HP repair cells. Optional pod loss affects the record, not route completion. |

**How to take it down:** Break armor with the universal three-hit charge sequence, fight from the dry lane, and prioritize Breacher/Runner support when it blocks movement. The body is always directly damageable after armor breaks; the captive glass is no longer part of the fallback body target.[1][7]

### 3. MIMESIS-04 — The Afterimage Conductor

**Identity:** A memory-versus-threat recognition fight with a localized weapon-jamming counter.

| Phase | Abilities and attack pattern | Counterplay |
|---|---|---|
| **Armored** | **Dead-Air Sweep** paints a left-biased line. **Memory Blocking** closes both side lanes and later deploys a single Needle-class CHOIR Siren. | Use the open side or center and land three moving full-charge core hits. Cyan history images are presentation-only. |
| **Exposed** | **Armed Afterimage** turns one recorded position magenta and damaging. Dead-Air Sweep and Memory Blocking remain. | Track the magenta afterimage rather than the cyan memory trail. Do not dodge away from harmless cyan echoes. |
| **Final third** | Armed Afterimage alternates with the long **Encore Impact** beam. If the Siren ring is active, one weapon can be paused. | Enter the 118-pixel hollow center to immediately restore the paused weapon; leaving the center reapplies the single-weapon lock while the ring remains active. Direct movement and melee controls are never disabled. |
| **Corpse** | The MIMESIS atlas freezes and darkens. The STAGE continuity payload is captured before controller cleanup. | Use one fresh melee to create rubble and three 50-HP repair cells; the evidence result survives callback ordering. |

**How to take it down:** Learn the color language: **cyan is memory, magenta is damage**. Break armor at speed, use the hollow center when the Siren jams a weapon, and attack the exposed chassis between Armed Afterimage and Encore windows.[2][8]

### 4. CANTOR-31 / Pale Engine — The Export Surgeon

**Identity:** A production-lane fight that introduces marked support pursuit and finite reclamation pressure.

| Phase | Abilities and attack pattern | Counterplay |
|---|---|---|
| **Armored** | **Suture Salvo** arms two of three lanes and leaves one dry lane. | Move to the visible dry lane and release the full-charge core hit from there. Repeat three times. |
| **Exposed** | Suture Salvo remains. **Dispatch Harness** deploys one Graft Runner and applies the target mark required by its attack logic. A freight anchor is recorded only after successful deployment. | Destroy the marked Runner first; no false dispatch telegraph appears if the pool cannot supply it. Resume body damage during recovery. |
| **Final third** | **Pale Reclamation** consumes at most three finite freight anchors into capped ablative records. **Compression Psalm** combines a long beam with a left ground zone. | Deny space around visible anchors, use the right side against Compression Psalm, and keep moving between dry-lane changes. The decorative Seraph projections are not extra enemies. |
| **Corpse** | The CANTOR atlas freezes and darkens. The ARSENAL export payload remains intact through the corpse transition. | Use one fresh melee to create rubble and three 50-HP repair cells, then let the transaction commit before advancing. |

**How to take it down:** Treat dry lanes as the primary navigation puzzle, kill the marked Runner, then pressure the exposed chassis. Reclamation is finite and capped; surviving long enough does not produce infinite armor or enemies.[2][8]

### 5. CHOIR Prime — The Last Sovereign

**Identity:** A final exam that reuses one mechanic from each prior district, then presents an explicit ending choice.

| Phase | Abilities and attack pattern | Counterplay |
|---|---|---|
| **Armored** | **Ledger / Settlement Sweep** covers a left-biased ground zone. **Nursery / Braced Shock** attacks the center. | Use the remembered Business/Nursery spacing and land the universal three moving full-charge core hits. |
| **Exposed** | **Stage / Armed Ring** creates a wide central footprint. **Arsenal / Production Lanes** arms two lanes and rotates the dry lane. | Respect magenta Stage pressure and move to the dry Arsenal lane before attacking the body. |
| **Final third** | Arsenal remains and **Crown / Radial Verdict** adds a long horizontal verdict beam. All large composition echoes remain non-colliding presentation. | Avoid reading the large echo art as hitboxes; only the magenta authored pressure zones can damage the robot. |
| **Outcome corpse** | CHOIR Prime freezes on its final atlas frame and darkens while exposing red **PURGE** and cyan **DISENTANGLE** receivers. Ineligible Disentangle remains visibly warned. | One fresh jab-cross or ground smash on the chosen receiver commits PURGE, eligible DISENTANGLE, or ASCENSION FAILURE, then creates rubble and three 50-HP repair cells. The fatal chain remains rejected. |

**How to take it down:** Apply everything learned in the earlier fights, break armor, destroy the exposed Sovereign core, then choose a clearly labeled receiver. PURGE always remains available. DISENTANGLE remains evidence-dependent, but the selected ending and rubble conversion now commit together on one genuinely fresh melee.[1][9]

## Fun and fairness assessment

The campaign now has a coherent learning curve instead of five differently decorated target dummies. Settlement teaches lane recovery and clearly visible durability while accepting the player's entire arsenal. SAMARITAN introduces the stricter movement-charge armor lesson, then adds protection pressure and rotating sanctuary. MIMESIS tests visual discrimination and spatial counterplay to a weapon jam. CANTOR adds marked pursuit and finite area denial. CHOIR Prime recombines those rules, then ends with a legible consequential choice. The visual grammar remains consistent: **yellow is armor durability, red is body health, white flash means accepted damage, pale/gold is warning, magenta is armed damage, cyan is memory or Disentangle, and labeled circles are finishers**.

The implementation deliberately keeps stateful boss support singular despite global 2× enemy density. This preserves readable boss mechanics while ordinary authored waves remain doubled. Each attack uses a bounded pooled area, supports are capped, phase transitions are health-driven, and no encounter requires the player to destroy optional evidence to open the route.

## Remaining high-value design opportunities

The current repair makes every fight playable, damaging, phase-structured, explainable, and emphatic at defeat. The shared intro splash, announcer cue, compact durability bars, white accepted-hit flash, generated explosion/firework textures, positional detonation mix, and heavy camera kick cover the presentation arc from entrance through destruction. A subsequent content pass could deepen identity without changing the stable contracts: add boss-specific hit-stun and armor-break animations; make the Business treasury slab, Entertainment control cabinet, and Military freight anchors directly attackable world receivers; add unique per-boss telegraph and exposure stingers; and tune hazard damage after collecting real completion-time and chassis-loss telemetry. Those are enhancements, not blockers to defeating the campaign.

## Source references

[1]: ../game/scripts/siege/command_boss_session.gd
[2]: ../game/scripts/siege/boss_attack_area_2d.gd
[3]: ../game/scripts/siege/boss_vertical_slice_controller.gd
[4]: ../game/scripts/siege/boss_campaign_director.gd
[5]: ../game/scripts/siege/boss_wreck_receiver_2d.gd
[6]: ../game/scripts/player/giant_robot_controller.gd
[7]: ../game/scripts/siege/boss_rig_2d.gd
[8]: ../game/scripts/siege/boss_escalation_controller.gd
[9]: ../game/scripts/siege/boss_royal_finale_controller.gd
[10]: ../game/scripts/siege/boss_arena_barrier_2d.gd
[11]: ../game/scripts/ui/boss_fight_herald.gd
[12]: ../game/scripts/siege/boss_defeat_spectacle_2d.gd
