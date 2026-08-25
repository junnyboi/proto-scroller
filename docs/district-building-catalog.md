# Proto Scroller District Building Catalog

**Author:** Manus AI

**Scope:** Six districts, thirty destructible building archetypes

## Shared Visual Contract

Every building is an isolated orthographic side elevation for a gritty late-industrial photographic-pixel-art city. Assets use transparent backgrounds, a common ground baseline, readable floor and bay divisions, deep windows, sparse warm practical lights, weathered materials, and a distinct rooftop silhouette. Buildings contain no people, vehicles, sky, street, logos, or precise signage. Each silhouette must remain identifiable after cell-by-cell destruction.

The catalog assumes a generalized structural grid of two to five columns and two to four rows. Each cell inherits the existing cracks, façade hollowing, support damage, debris, dangling cable, broken pipe, spark, and water-spray behaviors.

## Residential District

The residential district combines dense brick housing, patched concrete, fire escapes, rooftop water tanks, domestic utilities, and sparse warm window light. Forms should feel crowded, improvised, and lived-in without depicting residents.

| ID | Archetype | Footprint | Production Description | Spawn Weight |
|---|---|---:|---|---:|
| `res_tenement_block` | Tenement Block | 3×4 | Tall soot-stained brick apartments with repetitive deep windows, rusted zig-zag fire escapes, patched masonry, and a wooden rooftop water tower. | 35% |
| `res_brownstone_walkup` | Brownstone Walk-up | 2×3 | Compact decaying stone walk-up with a weathered cornice, bay windows, narrow stoop, rusted drainpipes, and uneven amber apartment lights. | 25% |
| `res_courtyard_apartments` | Courtyard Apartments | 4×3 | Wide concrete apartment complex with a central recessed arch, exposed rebar repairs, faded terracotta panels, rooftop dishes, and clustered utility sheds. | 20% |
| `res_narrow_highrise` | Narrow High-rise | 2×4 | Slender soot-streaked residential tower with vertical utility trunks, rooftop antenna, external junction boxes, and tangled service cables. | 10% |
| `res_housing_block` | Low-income Housing Block | 5×2 | Long repetitive brick housing slab with many identical deep windows, peeling painted panels, ventilation shafts, and a low industrial roofline. | 10% |

**Destruction identity:** red brick dust, domestic plumbing spray, splintered interiors, window glass, and dense hanging utility cable clusters.

## Business District

The business district uses oppressive vertical rhythm, stained granite, oxidized bronze, black glass, heavy office-service equipment, and deliberately sparse late-night lighting.

| ID | Archetype | Footprint | Production Description | Spawn Weight |
|---|---|---:|---|---:|
| `biz_corporate_tower` | Corporate Tower | 3×4 | Monolithic office tower with vertical steel mullions, deep black glass, charcoal granite base, and a roof packed with large cooling equipment. | 25% |
| `biz_bank_headquarters` | Bank Headquarters | 4×3 | Heavy limestone and granite headquarters with thick pillars, oxidized bronze detailing, narrow recessed windows, and stepped communications roofline. | 20% |
| `biz_commercial_exchange` | Commercial Exchange | 5×2 | Wide trading-floor building with large arched dark-glass bays, weathered steel frames, deep interior shadows, rooftop pipes, and heavy ventilation machinery. | 15% |
| `biz_executive_highrise` | Executive High-rise | 2×4 | Narrow vertical office slab with continuous dark glazing, bronze panel bands, granite podium, rooftop spire, and communications arrays. | 25% |
| `biz_syndicate_office` | Syndicate Office | 3×2 | Squat fortified office with thick soot-black columns, narrow windows, transformer clusters, exposed cable conduits, and dense cooling units. | 15% |

**Destruction identity:** black glass showers, granite chunks, bronze panels, severed data cables, and rooftop cooling-water ruptures.

## Party and Nightlife District

The nightlife district repurposes industrial shells with magenta, cyan, violet, and amber practical lighting. Tarnished brass, black brick, generators, exhaust systems, and improvised neon armatures create recognizable silhouettes without legible signs.

| ID | Archetype | Footprint | Production Description | Spawn Weight |
|---|---|---:|---|---:|
| `night_underground_club` | Underground Club | 4×3 | Low concrete entertainment bunker with reinforced doors, narrow magenta-lit openings, black acoustic additions, and oversized tangled rooftop exhaust fans. | 15% |
| `night_dive_bar_tower` | Dive Bar Tower | 2×4 | Narrow crimson-brick tower with stacked arched windows, heavy fire escapes, rooftop water tank, dangling cables, and uneven amber-violet light. | 30% |
| `night_casino_warehouse` | Casino Warehouse | 5×3 | Broad converted warehouse with stained concrete, iron pillars, dim colored glass, extensive cooling towers, and interlocked rooftop scaffolding. | 10% |
| `night_vip_lounge` | VIP Lounge | 3×4 | Tall black-brick club with tarnished brass frames, deep panoramic windows, angular steel roof beams, compact antennas, and restrained amber-magenta glow. | 20% |
| `night_arcade_hall` | Arcade Hall | 3×2 | Compact stained-concrete hall with reinforced steel grid, erratic cyan and magenta window glow, generator banks, heavy piping, and broken neon armatures. | 25% |

**Destruction identity:** colored electrical sparks, stained-glass fragments, heavy generators, cables, ventilation ducts, and occasional sprinkler spray.

## Shopping District

The shopping district combines rusted cast iron, soot-stained brick, tarnished brass, cracked display glass, faded awnings, broad entrances, and mechanical rooftop clutter. Buildings should read as commercial even without text.

| ID | Archetype | Footprint | Production Description | Spawn Weight |
|---|---|---:|---|---:|
| `shop_boutique_arcade` | Boutique Arcade | 3×2 | Two-story cast-iron retail arcade with ornate but rusted framing, deep display windows, teal awnings, upper brickwork, and warm storefront light. | 25% |
| `shop_department_store` | Department Store | 5×4 | Massive tiered concrete store with tarnished brass accents, repetitive display bays, decayed central entrance, rooftop vents, and large mechanical armatures. | 10% |
| `shop_market_hall` | Market Hall | 4×3 | Broad indoor market with arched iron roof, exposed trusses, oxidized copper panels, cracked tinted glass, and deep warmly lit interior bays. | 20% |
| `shop_retail_tower` | Retail Tower | 2×4 | Narrow commercial tower with reinforced steel skeleton, vertical display glazing, floor-by-floor overhangs, rooftop water tank, and utility cables. | 20% |
| `shop_corner_plaza` | Corner Plaza | 3×3 | Asymmetrical stepped shopping complex with terraces, soot-red brick, rusted railings, recessed storefront alcoves, HVAC units, and exposed pipes. | 25% |

**Destruction identity:** display-glass cascades, awning fragments, brass trim, retail electrical trunks, concrete dust, and fire-suppression water spray.

## Government District

The government district fuses monumental neoclassical mass with brutalist defenses. Rigid symmetry, limestone, cast iron, deep slits, thick cornices, communications hardware, and cold institutional silhouettes dominate.

| ID | Archetype | Footprint | Production Description | Spawn Weight |
|---|---|---:|---|---:|
| `gov_ministry_records` | Ministry of Records | 4×3 | Monolithic administrative block with thick vertical ribs, narrow deep windows, pale stained limestone, central communications tower, and massive HVAC units. | 30% |
| `gov_municipal_courthouse` | Municipal Courthouse | 5×4 | Wide dark-stone courthouse with giant fluted columns, heavy cornice, damaged central dome, deep steps integrated into the façade, and fortified parapets. | 15% |
| `gov_tax_bureau` | Bureau of Taxation | 3×4 | Tall interlocking brutalist concrete blocks with sparse horizontal window slits, exposed side pipes, jagged roof spires, and severe geometric massing. | 20% |
| `gov_sector_precinct` | Sector Precinct | 4×2 | Low reinforced security building with barred windows, armored entrances, rooftop radar dishes, spotlight housings, fencing, and compact bunker proportions. | 25% |
| `gov_archive_vault` | Archive Vault | 2×3 | Narrow windowless storage tower with thick limestone slabs, tarnished brass bands, oversized ventilation housings, and a roof-mounted service crane. | 10% |

**Destruction identity:** pale limestone dust, heavy concrete slabs, dense rebar, steam or water conduits, and sparking institutional power trunks.

## Military District

The military district is dense, fortified, and utilitarian: olive concrete, matte blast armor, rusted corrugated steel, dull brass utilities, slit windows, radar silhouettes, and amber hazard lights.

| ID | Archetype | Footprint | Production Description | Spawn Weight |
|---|---|---:|---|---:|
| `mil_command_bunker` | Command Bunker | 5×2 | Wide armored bunker with thick olive concrete, horizontal slit windows, matte blast plates, recessed command doors, and a prominent rooftop radar dish. | 10% |
| `mil_munitions_depot` | Munitions Depot | 4×2 | Dense reinforced depot with corrugated armored roof, recessed blast doors, brass utility pipes, segmented hazard lighting, and protected ventilation stacks. | 25% |
| `mil_comms_tower_base` | Communications Tower Base | 2×4 | Tall narrow plated service tower with inset windows, external caged ladders, cable trunks, antenna arrays, and a jagged communications silhouette. | 20% |
| `mil_barracks_block` | Barracks Block | 3×3 | Brutalist barracks with uniform square windows, weathered concrete, sparse amber lights, roof vents, water tanks, and exposed service conduits. | 30% |
| `mil_vehicle_depot` | Vehicle Depot | 4×3 | Rugged depot with massive garage bays, heavy support columns, olive panels, roof guard housings, exhaust vents, and reinforced corner towers. | 15% |

**Destruction identity:** jagged concrete shrapnel, armored plate fragments, twisted rebar, intense power sparks, ruptured utility pipes, and dense soot effects.
