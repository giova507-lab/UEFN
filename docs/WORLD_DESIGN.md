# World Design

The world is a round ocean, about **3.8 km across**. At its center is the hub island with the six Lagoons, surrounded by seven biome rings. Distances are balanced around two numbers from the code:

* **Egg carry timer: 45 s** (`DefaultEggCarrySeconds`). A claimed egg must reach the owner's Lagoon before it cracks.
* **Physical swim speed** from `MovementBalance.verse` (log curve). Fast Swim (Sprint) uses 100% of the creature's speed; normal cruising uses 80% (`MountCruiseFraction`).

So a biome is "reachable" by a creature when `distance back to the Lagoon / fast-swim speed < 45 s`.

## Layout (distances from the hub center, i.e. the game device)

| Ring | Biome | From → to | Return trip to a Lagoon* | Fast-swim speed needed | First creatures that make it |
|---|---|---|---|---|---|
| 0 | Central Lagoon (hub) | 0 - 200 m | < 150 m | any | Sea Slug (6.5 m/s) |
| 1 | Shallow Reef | 200 - 450 m | 100 - 350 m | 2 - 8 m/s | Sea Slug → Clownfish |
| 2 | Kelp Forest | 450 - 700 m | 350 - 600 m | 8 - 13 m/s | Seahorse, Lionfish, Stingray |
| 3 | Tropical Atoll | 700 - 950 m | 600 - 850 m | 13 - 19 m/s | Octopus, Barracuda, Swordfish |
| 4 | Frozen Sea | 950 - 1200 m | 850 - 1100 m | 19 - 25 m/s | Moray Eel → Tiger Shark |
| 5 | Volcanic Archipelago | 1200 - 1450 m | 1100 - 1350 m | 25 - 30 m/s | Giant Manta, Whale Shark, Narwhal |
| 6 | The Abyss | 1450 - 1650 m | 1350 - 1550 m | 30 - 35 m/s | Narwhal, Sperm Whale, Mosasaurus |
| 7 | Celestial Sea | 1650 - 1900 m | 1550 - 1800 m | 35 - 40 m/s | Mosasaurus, Sea Dragon and up |

\* Lagoons sit about 100 m from the hub center. An egg on the far side of the hub from your own Lagoon adds up to about 200 m, which is intentional: nearer players have an edge.

The ring radii are `BiomeRingRadii` in `SeaNavigation.verse` (20000, 45000, 70000, 95000, 120000, 145000, 165000 cm). The outer limit is `WorldBoundsRadius` (190000 cm) in `GameConfig.verse`.

> **Smaller island?** If your island template or memory budget can't fit a 3.8 km ocean, scale `BiomeRingRadii` and `WorldBoundsRadius` down by the same factor, and scale either the physical speeds (`SpeedCurveAnchors`) or `DefaultEggCarrySeconds` by that factor too. That keeps every biome reachable by the same creature tier. Biome zones (`sea_zone_device`, Kind = Biome) override the rings anywhere you place them, so biomes don't have to be perfect circles. Keep the travel distances above, though.

## Biomes

| Biome | Look | Landmarks | Gameplay features |
|---|---|---|---|
| **Central Lagoon** | Turquoise shallows, white sand, palm hub | Hub island, six Lagoons, the NPC boardwalk (Marina, Finn, Chef Kelp, Captain Pearl), lighthouse | Safe start, tutorial eggs, Pearl/Sandy eggs near docks |
| **Shallow Reef** | Bright coral, clear water | Coral arches, a sunken rowboat, sandbars | First breach pools (2-4 m rims), easy arches |
| **Kelp Forest** | Tall swaying kelp, green light shafts | Kelp maze, sunken lighthouse | Narrow channels (Land zones between kelp walls), hidden pockets |
| **Tropical Atoll** | Palm atolls, rainbow reefs, waterfalls | Waterfall pools, shipwreck | Raised pools 5-8 m above the sea, reachable only by breaching |
| **Frozen Sea** | Ice floes, aurora sky | Glacier arches, ice caves | Ice arches to dive under, floe mazes |
| **Volcanic Archipelago** | Black rock, lava glow, steam | Erupting cone, magma vents | High rock rims (6-8 m), vent pools |
| **The Abyss** | Near-black water, bioluminescence | Trench, giant skeleton, abyssal rift | DeepWater zones for deeper dives, dark approach |
| **Celestial Sea** | Starry water, pastel nebula sky, floating crystals | Floating islands, star gate | Highest pools (10-13 m), Celestial Pearl Egg spots |

All environment art must be original or come from properly licensed Fab / Fortnite assets (see [CONTENT_BROWSER.md](CONTENT_BROWSER.md)).

## Breach heights and pools

The launch height comes from Breach (`BreachToLaunchHeightCm`): `1.5 m + (Breach − 70) × 0.12 m`, clamped to 1.5 - 16 m.

| Creature (Breach) | Launch height |
|---|---|
| Sea Slug (78) | 2.5 m |
| Pufferfish (95) | 4.5 m |
| Barracuda (125) | 8.1 m |
| Mantis Shrimp (129) | 8.6 m |
| Sea Dragon (135) | 9.3 m |
| Kraken (146) | 10.6 m |
| Ancient Leviathan (150) | 11.1 m |
| Celestial Serpent (170) | 13.5 m |

To build a raised pool:

1. A `WaterPool` zone whose device Z is the pool surface.
2. A `Land` zone ring or box for the rim, with `TopOffset` = the rim height above sea level. A beast can only cross the rim when its breach arc is above the rim.
3. Put the rare-egg spawn point inside the pool.

Horizontal reach while airborne ≈ speed × airtime, with airtime = 2 × √(2 × height / g) and g = 20 m/s² (`MountGravityCmPerSec2`). A Sea Slug jump covers about 6 m. A Celestial Serpent at full speed flies over 100 m. Leave approach room in front of every pool rim.

## Dives and arches

Hold Crouch to dive. Dive depth = `6 m × clamp(Breach / 100, 0.75, 1.6)`. It is capped at **6 m** outside DeepWater zones and allowed up to 9.6 m inside them.

An arch is a Land zone whose `BottomOffset` is above the dive depth (for example, the bottom 3 m below the surface and the top 6 m above it). Beasts pass under it while diving and are blocked at the surface. Put eggs behind arches to reward the dive.

## Egg spawn points

Each tide places **81 eggs**. Give every egg type about 1.5x its per-tide count in eligible points so locations vary between tides. Recommended spawn points:

| Biome | Common | Rare | Epic | Legendary | Mythic | Divine | Ethereal |
|---|---|---|---|---|---|---|---|
| Central Lagoon | 15 | - | - | - | - | - | - |
| Shallow Reef | 45 | 22 | - | - | - | - | - |
| Kelp Forest | - | 10 | 6 | - | - | - | - |
| Tropical Atoll | - | - | 6 | 6 | - | - | - |
| Frozen Sea | - | - | 4 | - | 6 | - | - |
| Volcanic Archipelago | - | - | - | - | 5 | 3 | - |
| The Abyss | - | - | - | - | 2 | 2 | 3 |
| Celestial Sea | - | - | - | - | - | 2 | 3 |

That is about 140 spawn points. Common points near docks should use `PlacedEggProps` (a hidden Pearl and Sandy egg per point), so the 40 common eggs don't use the runtime spawn budget ([PERFORMANCE.md](PERFORMANCE.md)).

Placement rules:

* Higher rarity goes further out, higher up (breach pools) and deeper in (behind arches, trenches, mazes).
* Never put a Divine or Ethereal point in plain open water. Those eggs should take skill as well as speed.
* Don't cluster the same tier. Spread points around the whole ring so every Lagoon has a fair distance on average.
* Keep points at least 15 m from Land zone edges so the egg is claimable from the water (mounted claim radius is 6.5 m, growing with creature size).

## Lagoon placement

* Six Lagoons evenly around the hub, 60° apart, about 100 m from the center, each facing outward (device +X toward the open sea).
* Each Lagoon's `AreaRadius` (26 m) must not overlap another Lagoon. Egg delivery triggers inside this radius.
* Keep the tutorial egg spot (`TutorialEggOffset`, 26 m out) in open water, visible from the dock.

## Player spawns

One Player Spawner per Lagoon, or a few at the hub. Verse teleports every spawned player to their own Lagoon (`SpawnOffset`), so the spawner position only matters for the first frames.
