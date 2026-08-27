from __future__ import annotations

import json
from pathlib import Path
from typing import Final

ROOT: Final = Path("/home/ubuntu/workspace/proto-scroller")
ROSTER_SOURCE: Final = ROOT / "docs/story-concepts/production-sources/chimera-variants/roster-design.json"
OUTPUT: Final = ROOT / "docs/DISTRICT_CHIMERA_ENEMY_PROPOSAL.md"

BASE_ARCHETYPES: Final = {
    "covenant_warden": "bulwark",
    "mercy_recovery_cart": "jackal",
    "testament_kite": "needle",
    "receivership_ambulance": "aegis",
    "intake_shepherd": "sapper",
    "evacuation_litter": "jackal",
    "rainvault_pressure_ward": "basilisk",
    "balcony_recall_beacon": "needle",
    "memorial_usher": "sapper",
    "glassback_double": "jackal",
    "recall_lantern": "choir_siren",
    "marquee_anesthetist": "basilisk",
    "suture_marshal": "sapper",
    "mercy_raker": "jackal",
    "revetment_ward": "cinder",
    "triage_kite": "kestrel",
    "privy_chirurgeon": "sapper",
    "laureate_courser": "ossuary_crawler",
    "ninefold_witness": "choir_siren",
    "regency_conservator": "basilisk",
}

DISTRICT_CANON: Final = {
    "BUSINESS": ("Administrative ambiguity", "Corporate security still reads as conventional hardware; human origins survive as records, posture, and occupants rather than explicit warforms."),
    "residential": ("First conscious captives", "The player first sees living responders and residents trapped inside corrupted intake and rescue systems."),
    "entertainment": ("Identity conditioning", "Broadcast infrastructure turns copied faces, memories, and performance timing into battlefield support without deceptive hitboxes."),
    "military": ("Export-line fusion", "Clinical and military systems are deliberately fused into repeatable combined-arms products."),
    "ROYAL": ("Mature command ecology", "Royal ceremony, medical preservation, and civic memory become composite command organs and predictive councils."),
}


def normalized_district_id(raw: str) -> str:
    return raw.upper()


def concept_path(number: int, enemy_id: str) -> str:
    return f"concepts/district-enemies/{number:02d}-{enemy_id.replace('_', '-')}.png"


def build() -> str:
    data = json.loads(ROSTER_SOURCE.read_text())
    districts = data["districts"]
    final = data["final"]
    lines: list[str] = []
    lines.extend([
        "# District Chimera Enemy Proposal",
        "",
        "**Project:** Proto Scroller  ",
        "**Feature:** Twenty additional Project CHOIR enemy variants  ",
        "**Engine:** Godot 4.7.2  ",
        "**Status:** Approved production proposal",
        "",
        "## Executive Proposal",
        "",
        "Project CHOIR should expand the ordinary encounter roster through **twenty district-specific derivatives**, four per spatial district. These enemies are not a parallel bestiary and do not introduce a second combat economy. They are engineered overlays on the existing procedural archetypes, reusing the fixed infantry, light, heavy, air, projectile, telegraph, body, and wreck pools while changing silhouette, statistics, tactical emphasis, and narrative meaning.",
        "",
        "The horror remains **tragic, clinical, and legible**. Every design preserves a recognizable rescue, medical, or civic origin. Containment glass, synthetic membrane, and cyan memory light expose what the Directorate preserved and repurposed. No unit relies on comedy-zombie movement, exposed-organ spectacle, fantasy mutation, hidden attacks, input inversion, weapon disable, targetable decoys, persistent hazards, or route-blocking kill gates.",
        "",
        "## Canon Escalation",
        "",
        "| District | Stage | Narrative Function |",
        "|---|---|---|",
    ])
    for district in districts:
        district_id = normalized_district_id(district["district_id"])
        stage, description = DISTRICT_CANON[district["district_id"]]
        lines.append(f"| **{district['district_name']}** (`{district_id}`) | {stage} | {description} |")
    lines.extend([
        "",
        "## Production Architecture Contract",
        "",
        "The current twenty-six procedural archetypes remain the immutable baseline. The feature adds **twenty concrete district variants** and exposes a forty-six-entry all-spawnable view. Every variant declares a canonical `base_archetype_id`, resolves to an existing family reservation key, and consumes an already-prewarmed shell. Authored six-act decks remain unchanged; deterministic runtime substitution applies the existing Project CHOIR hybrid pass first and the district-variant pass second.",
        "",
        "The roster deliberately reuses five combat verbs: bounded repair, short target marking, ground-pass attacks, single-shell artillery, and standard close/pass attacks. Cosmetic tethers, faces, memory routes, occupants, rings, countdown lights, and afterimages remain actor-owned presentation with no collision, health, targetability, navigation, reservation, or independent lifetime.",
        "",
        "## Roster at a Glance",
        "",
        "| # | District | Enemy | Base | Family | Role | Threat |",
        "|---:|---|---|---|---|---|---:|",
    ])
    number = 0
    for district in districts:
        for enemy in district["enemies"]:
            number += 1
            lines.append(
                f"| {number} | {district['district_name']} | **{enemy['display_name']}** | "
                f"`{BASE_ARCHETYPES[enemy['id']]}` | `{enemy['family']}` | {enemy['combat_role']} | {enemy['threat_cost']} |"
            )
    lines.append("")
    number = 0
    for district in districts:
        district_id = normalized_district_id(district["district_id"])
        stage, _ = DISTRICT_CANON[district["district_id"]]
        lines.extend([
            f"## {district['district_name']} — {stage}",
            "",
            district["design_thesis"],
            "",
        ])
        for enemy in district["enemies"]:
            number += 1
            base = BASE_ARCHETYPES[enemy["id"]]
            lines.extend([
                f"### {number:02d}. {enemy['display_name']}",
                "",
                f"![{enemy['display_name']} concept]({concept_path(number, enemy['id'])})",
                "",
                f"> **{enemy['epithet']}**",
                "",
                "| Attribute | Production Value |",
                "|---|---|",
                f"| Concrete ID | `{enemy['id']}` |",
                f"| District | `{district_id}` |",
                f"| Canonical base | `{base}` |",
                f"| Family / health / threat | `{enemy['family']}` / {enemy['health']} / {enemy['threat_cost']} |",
                f"| Runtime behavior | `{enemy['behavior']}` + `{enemy['movement_style']}` + `{enemy['attack_style']}` |",
                f"| Projectile contract | `{enemy['projectile_kind']}` |",
                f"| District weight | {enemy['district_weight']} |",
                "",
                f"**Origin and tragedy.** {enemy['lore_origin']}",
                "",
                f"**Silhouette and visual language.** {enemy['visual_description']}",
                "",
                f"**Combat function.** {enemy['combat_role']}",
                "",
                f"**Telegraph and player answer.** {enemy['telegraph']} {enemy['player_answer']}",
                "",
                f"**Spawn use.** {enemy['spawn_strategy']}",
                "",
                f"**Reuse boundary.** {enemy['reuse_constraints']}",
                "",
            ])
    lines.extend([
        "## Shared Behavior Extensions",
        "",
        "| Extension | Scope | Contract |",
        "|---|---|---|",
    ])
    for extension in final["shared_behavior_extensions"]:
        scope = ", ".join(f"`{value}`" for value in extension["scope"])
        lines.append(
            f"| **{extension['id']}** | {scope} | {extension['implementation']} {extension['runtime_impact']} |"
        )
    lines.extend([
        "",
        "## District Spawn Rules",
        "",
        "| District | Allowed variants | Budget guidance | Exclusions and readability rules |",
        "|---|---|---|---|",
    ])
    for rule in final["district_spawn_rules"]:
        allowed = ", ".join(f"`{value}`" for value in rule["allowed_ids"])
        lines.append(
            f"| `{normalized_district_id(rule['district_id'])}` | {allowed} | {rule['budget_guidance']} | {rule['rules']} |"
        )
    lines.extend([
        "",
        "## Acceptance Criteria",
        "",
    ])
    for criterion in final["acceptance_criteria"]:
        lines.append(f"- {criterion}")
    lines.extend([
        "",
        "## Concept Art and Production Source",
        "",
        "All twenty concepts were generated with **GPT Image 2** from the approved roster descriptions and the existing Project CHOIR visual language. The proposal embeds cleaned, transparent concept masters under `docs/concepts/district-enemies/`. Lossless production sources remain outside `game/` under `docs/story-concepts/production-sources/chimera-variants/`; compact transparent derivatives numbered `27` through `46` are the only new textures imported into the Godot runtime.",
        "",
        "The concepts are authoritative for silhouette, material language, human readability, and memory-light telegraphs. Runtime animation continues to be generated by the pooled actor's existing movement and attack presentation rather than by additional animated child actors.",
        "",
    ])
    return "\n".join(lines)


OUTPUT.write_text(build())
print(OUTPUT)
