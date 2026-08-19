# Run Upgrade System Baseline

**Captured:** 19 August 2026  
**Source:** `bf072bb`  
**Engine:** Godot `4.7.1.stable.official.a13da4feb`  
**Renderer/export:** GL Compatibility, 1280×720 design canvas, threadless Web

## Full verification

`game/verify.sh --full` passed in **134 seconds**. The GUT gate executed **110 tests** across **19 test scripts** with **1,368 assertions**, the launch and gameplay scenarios passed, and both required render geometries were captured successfully.

| Baseline | Verified value |
|---|---:|
| CitySlice physical lines | 637 |
| Scene node count after warm-up | 451 |
| Enemy actors | 9 (6 soldiers, 2 tanks, 1 helicopter) |
| Hostile projectiles | 24 (16 bullets, 4 shells, 4 rockets) |
| Structural debris | 24 |
| Enemy scrap | 32 |
| Soldier defeat bodies | 8 |
| Wrecks | 4 |
| Impact particle slots | 8 |
| Shared audio voices | 8 |
| Telegraph records | 12 maximum |
| Causal records | 64 maximum |
| Web PCK | 4,016,800 bytes |
| Web PCK budget | 8,388,608 bytes |
| Landscape render | 1280×720 PASS |
| Portrait render | 720×1280 PASS |
| Title render SHA-256 | `187c3c5c2da5d4ede72e0ce43c8547da8f9f2377e00b7e42d74d9ddb27013cec` |

`RuntimeBudget.validation_errors()` was empty. The baseline therefore has **4,371,808 bytes** of PCK headroom before the hard Web budget. Generated Web export binaries and scenario evidence remain excluded from source control.
