# Proto Scroller Runtime Tuning Laboratory — Concept Design

**Author:** Manus AI
**Status:** Accepted implementation concept
**Source baseline:** `8cd2c6484eae25e78de7b79508912135f33a00c9`

## Design intent

Proto Scroller’s tuning surface is a **designer laboratory inside the real game**, not a generic inspector. It gives engineers and designers fast, bounded access to the values that shape movement, melee, hostile pressure, destruction, rewards, presentation, and mobile feel while preserving the game’s fixed-pool architecture, deterministic identities, authored collision geometry, campaign persistence, and leaderboard comparability.

The system borrows the strongest lesson from the supplied Qinzhou Backstreet project—metadata-driven control generation—but removes its duplicated schema, persistence precedence defect, fixed-resolution layout, ambiguous application timing, and competitive-integrity gap. One typed catalog drives validation, rendering, persistence, apply-mode badges, hashes, localization, and tests.

> **Design rule:** A parameter is not exposed merely because it can be represented by a slider. It is exposed only when its ownership, safe range, application boundary, integrity class, and regression scenario are known.

## Visual language

The panel follows Proto Scroller’s existing cyan tactical interface. A near-black translucent command surface sits above a dimmed frozen game. Cyan denotes baseline and navigation, amber denotes pending values, red denotes validation failures or unranked state, and green denotes saved identity-compatible state. Styling is restrained: one border weight, one corner radius, short labels, no decorative dashboard chrome, and no generated artwork.

The header shows **TUNING LAB**, the current category, run state (`BASELINE`, `TUNED`, or `SANDBOX`), and the short preset hash. A compact category selector and search field filter a fixed set of prebuilt rows. Each row presents a label, effective numeric value, unit, application badge, integrity badge, slider, and one-value reset action. The detail line explains the parameter in one sentence and distinguishes **requested** from **active** values.

Landscape uses a centered 1160×640 command surface. Portrait uses a 680×1136 single-column surface with the same hierarchy, minimum 48-pixel touch targets, a taller scroll body, and a fixed footer. Godot Containers and anchors perform reflow; canonical 1280×720 and 720×1280 gameplay viewports are not changed.

## Interaction model

The keyboard opens the laboratory with **F10**. A gamepad opens it with **Back/Share + Y/Triangle** as a chord, not a remappable gameplay action. **Space remains melee-only. A/Cross remains focused-control confirmation. Escape or B/Circle closes.** Directional controls navigate, bumpers or the category selector change domains, and left/right changes focused numeric values.

Opening is refused while another interactive modal owns a pause lease. Otherwise the laboratory acquires exactly one `RunPauseCoordinator` lease, captures the previous pause and mobile-input state, pauses the SceneTree, and consumes the opening event. Its CanvasLayer and persistence timer use `PROCESS_MODE_ALWAYS`; gameplay, physics, weather, attacks, timers, hazards, directives, and world streaming stop. Closing flushes pending persistence, restores the captured state, releases only its lease, and consumes the closing event.

## Application semantics

| Badge | Meaning |
|---|---|
| **LIVE** | Future reads and existing presentation setters use the new value immediately. Promised projectile, tween, cooldown, or damage data is not rewritten. |
| **NEXT ATTACK** | The next melee, hostile shot, boss move, chain, or equivalent begin operation snapshots the value. |
| **NEXT SPAWN** | The next pooled actor, hazard, pickup, boss attempt, or presentation snapshots the value. |
| **NEXT DISTRICT** | The next canonical spatial district transition snapshots the value. |
| **NEXT RUN** | Main freezes the value before constructing a new `CitySlice`. Restart is the explicit apply mechanism. |

There is no misleading global Apply button. A successful edit immediately updates requested state and reports `Applied live`, `Queued for next attack`, or the relevant boundary. Disk persistence is independent and reports `Saving`, `Saved`, or `Not saved`.

## Sandbox model

The Session category adds closed, production-path actions: restart with pending values and a deterministic seed, spawn a selected existing enemy through `EncounterRuntime.acquire`, activate a selected existing hazard through `HazardRuntime.activate`, clear transient combat through release/cancel APIs, grant bounded test XP, and repair chassis through the normal health API. Commands cannot create arbitrary nodes, modify catalog identities, bypass capacities, or write campaign progress.

Any sandbox action irreversibly marks that run `SANDBOX`. It remains visible in the local after-action dossier but does not update ranked career records or contact the global leaderboard.

## Competitive integrity

Every descriptor is classified as `COSMETIC`, `GAMEPLAY`, or `SCORE_AFFECTING`. A non-default gameplay or score value taints the run when it is actually applied at its boundary. The state is sticky because restoring the slider cannot reverse simulation already performed. Cosmetic-only adjustments remain eligible.

`CityRunLifecycle`, `PlayerCombatProfileStore`, and `LeaderboardBridge` each enforce the rule independently. This is intentional defense in depth: the tuning laboratory must never become an unusually well-designed method of submitting fraudulent scores. A pity; the ergonomics would be excellent.

## Persistence model

Startup loads and validates the immutable `res://config/runtime_tweaks/catalog.json` baseline first, then overlays valid deltas from `user://runtime_tweaks/v1/current.json`. Unknown IDs, invalid types, non-finite values, invalid enums, and failed relation groups are rejected. The user file stores only differences from the current baseline, so a reset removes the key and future baseline revisions flow through.

Accepted edits update memory synchronously and restart a 0.40-second always-processing debounce. Save writes a temporary file, rotates one backup, and renames atomically. Panel close and Main exit force a flush. A malformed primary file is quarantined and the backup or baseline is used; a corrupt user file can never override the `res://` baseline partially.

## Scope of the first complete release

The first shipped release enables **50 active descriptors** across Player, Opposition, Siege, Bosses, World, Progression, and Interface. It includes representative controls for every application boundary and integrity class, plus the sandbox actions above. Another 50 audited candidates remain documented but disabled until their scoped selectors, fixed-array editors, and saturation matrices are implemented. Disabled descriptors are not rendered.

The release does not expose pool capacities, reservation counts, collision layers/shapes, catalog cardinality, actor IDs, random draw counts, event protocol fields, leaderboard protocol fields, save schema keys, boss armor geometry, facade topology, or canonical viewport sizes.

## References

[1]: https://github.com/junnyboi/proto-scroller "Proto Scroller source repository"
[2]: https://docs.godotengine.org/en/stable/tutorials/ui/gui_containers.html "Godot Engine documentation: GUI containers"
[3]: https://docs.godotengine.org/en/stable/classes/class_fileaccess.html "Godot Engine documentation: FileAccess"
[4]: https://docs.godotengine.org/en/stable/tutorials/io/data_paths.html "Godot Engine documentation: File paths in Godot projects"
[5]: https://docs.godotengine.org/en/stable/classes/class_range.html "Godot Engine documentation: Range"
[6]: https://docs.godotengine.org/en/stable/classes/class_json.html "Godot Engine documentation: JSON"
