# Aegis Patch Cell — Power-Box Repair Pickup

**Status:** Approved for implementation  
**Engine:** Godot 4.7.2-stable  
**Asset model:** GPT Image 2

## Purpose

Destroying the foreground power transformer should produce a small, immediately readable reward that reinforces environmental aggression without replacing the district weapon-shop economy. The reward restores a modest portion of chassis integrity and is implemented through a fixed prewarmed pool so combat does not allocate nodes after warm-up.

## Concept

The **Aegis Patch Cell** is a rugged nanoweld service cartridge ejected when the transformer ruptures. Its cream segmented armor visually belongs to the giant robot, while exposed copper windings, charcoal end caps, and sparse magenta diagnostics connect it to the existing city power cabinet. A cyan-white cross-shaped energy aperture communicates repair at gameplay scale without text or a generic red first-aid box.

The pickup uses a compact 64-pixel presentation envelope, a restrained cyan glow, and a gentle hover pulse. It appears above the spent transformer, remains available for a bounded lifetime, and collects only when the robot is below maximum chassis integrity. Collection restores **5 percent of maximum chassis health**—40 points at the baseline 800 maximum—and never exceeds the current maximum.

## Runtime Contract

| Concern | Decision |
|---|---|
| Source | Transformer catalyst destruction only |
| Allocation | Two pickup slots prewarmed with the two catalyst slots |
| Repair | 5% of the robot's current maximum health |
| Full-health contact | Pickup remains active rather than being wasted |
| Lifetime | 12 seconds before returning to the pool |
| Collision | Sensor-only overlap with the robot layer |
| Pause/reset | Pickup processing pauses with the scene and all slots reset between runs/cycles |
| Art | GPT Image 2 transparent sprite, 256×256 source, rendered at 64×64 |

## Street Destruction Scope

Foreground cars and streetlamps remain two-stage pooled `DestructibleProp2D` objects with mutation-ledger persistence. Power transformers are pooled `Catalyst2D` objects and accept player damage before discharging. Encounter street hazards—powerline poles, traffic gantries, valves, vents, road plates, metro cars, ammunition convoys, and related machinery—already expose `receive_damage()` and transition into their authored destruction/impact sequence when damaged. Noninteractive parallax skyline pixels remain background scenery rather than physics objects.

## Acceptance Criteria

The transformer must accept player damage, trigger once, spawn one prewarmed Aegis Patch Cell, and preserve its existing delayed blast. A damaged robot must collect the cell and recover exactly 5 percent of maximum chassis integrity without overhealing. A full-health robot must not consume it. Resetting the catalyst runtime must clear every pickup without new node creation. Focused tests, the standard harness, landscape and portrait screenshots, the full Web export, browser smoke, WebDev synchronization, checkpointing, and publication are blocking release gates.
