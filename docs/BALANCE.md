# Balance

All values below come from the Verse config files. **Change the config, not the gameplay code.** The UI and the gameplay code call the same functions, so a displayed value always matches the real one.

| What | File |
|---|---|
| Creatures | `CreatureConfig.verse` (`CreatureDefs`) |
| Eggs, incubation, carry time | `EggConfig.verse` |
| Sonars, food, levels, traits, mutations, weather, Hatch Luck, Deep Dive, Index, selling | `ProgressionConfig.verse` |
| Display → physical speed, breach height, dive depth | `MovementBalance.verse` |
| Timers, limits, economy constants | `GameConfig.verse` |

> **Never change or reuse an ID after publishing.** Saves store creature and egg IDs. Only append new entries.

## Sea Beasts

Physical speed is the fast-swim speed (Sprint). Normal cruising uses 80% of it. Launch height is the top of a breach.

| # | Creature | Rarity | Odds (1 in) | Display speed | Physical speed | Breach | Launch height | Income/s | Size |
|---|---|---|---|---|---|---|---|---|---|
| 1 | Sea Slug | Common | 2 | 15 | 6.5 m/s | 78 | 2.5 m | 3 | 0 |
| 2 | Hermit Crab | Common | 5 | 50 | 7.4 m/s | 80 | 2.7 m | 5 | 0 |
| 3 | Starfish | Common | 20 | 90 | 7.8 m/s | 77 | 2.3 m | 7 | 0 |
| 4 | Clownfish | Common | 30 | 165 | 8.7 m/s | 81 | 2.8 m | 9 | 0 |
| 5 | Pufferfish | Common | 50 | 300 | 9.5 m/s | 95 | 4.5 m | 5 | 0 |
| 6 | Seahorse | Common | 100 | 407 | 10.2 m/s | 89 | 3.8 m | 20 | 0 |
| 7 | Blue Tang | Common | 150 | 553 | 10.8 m/s | 92 | 4.1 m | 25 | 0 |
| 8 | Lionfish | Common | 200 | 750 | 11.5 m/s | 90 | 3.9 m | 30 | 0 |
| 9 | Stingray | Rare | 300 | 1.02K | 13.0 m/s | 75 | 2.1 m | 35 | 1 |
| 10 | Octopus | Rare | 1K | 1.38K | 14.4 m/s | 87 | 3.5 m | 50 | 1 |
| 11 | Barracuda | Rare | 3K | 3.05K | 18.0 m/s | 125 | 8.1 m | 120 | 1 |
| 12 | Swordfish | Epic | 9K | 3.25K | 18.5 m/s | 111 | 6.4 m | 150 | 2 |
| 13 | Mantis Shrimp | Epic | 25K | 3.69K | 19.5 m/s | 129 | 8.6 m | 160 | 1 |
| 14 | Moray Eel | Epic | 75K | 3.94K | 20.0 m/s | 98 | 4.9 m | 170 | 2 |
| 15 | Hammerhead Shark | Legendary | 150K | 4.48K | 21.0 m/s | 99 | 5.0 m | 200 | 2 |
| 16 | Giant Squid | Legendary | 180K | 4.78K | 21.7 m/s | 93 | 4.3 m | 240 | 2 |
| 17 | Orca | Legendary | 500K | 5.34K | 23.0 m/s | 108 | 6.1 m | 350 | 3 |
| 18 | Great White Shark | Legendary | 700K | 5.71K | 23.8 m/s | 102 | 5.3 m | 375 | 3 |
| 19 | Tiger Shark | Legendary | 1M | 6.1K | 24.5 m/s | 114 | 6.8 m | 400 | 3 |
| 20 | Giant Manta | Mythic | 1.2M | 6.52K | 25.8 m/s | 120 | 7.5 m | 510 | 3 |
| 21 | Whale Shark | Mythic | 1.5M | 6.96K | 27.0 m/s | 86 | 3.4 m | 750 | 3 |
| 22 | Narwhal | Mythic | 21M | 19.5K | 31.0 m/s | 105 | 5.7 m | 1.2K | 3 |
| 23 | Sperm Whale | Mythic | 300M | 27.4K | 33.5 m/s | 83 | 3.1 m | 2.2K | 4 |
| 24 | Mosasaurus | Mythic | 7B | 38.4K | 36.0 m/s | 117 | 7.1 m | 3.5K | 4 |
| 25 | Sea Dragon | Divine | 1T | 137K | 42.0 m/s | 135 | 9.3 m | 30K | 4 |
| 26 | Megalodon | Ethereal | 10T | 266K | 43.7 m/s | 100 | 5.1 m | 50K | 4 |
| 27 | Kraken | Ethereal | 30T | 1M | 47.0 m/s | 146 | 10.6 m | 100K | 5 |
| 28 | Abyssal Hydra | Ethereal | 70Qa | 100M | 53.0 m/s | 143 | 10.3 m | 30M | 5 |
| 29 | Celestial Serpent | Ethereal | 1Qi | 1B | 57.0 m/s | 170 | 13.5 m | 90M | 5 |
| 30 | Ancient Leviathan | Ethereal | 5Qi | 300M | 54.9 m/s | 150 | 11.1 m | 300M | 5 |

The Starter is the Sea Slug (`StarterCreatureID`). The first hatch is at least a Hermit Crab (`FirstHatchMinCreatureID = 2`).

### Stat formulas (`CreatureManager.verse`)

```
Display speed  = BaseSpeed  × LevelStatMultiplier(Level) × Trait.SpeedMult × Mutation.SpeedMult
Display breach = BaseBreach × (1 + 0.004 × (Level − 1)) × Trait.BreachMult
Income / s     = BaseIncome × LevelStatMultiplier(Level) × Trait.IncomeMult
LevelStatMultiplier(Level) = 1 + 0.015 × (Level − 1)        (level 100 → ×2.485)
```

Mutations change **speed only**. Because the physical speed curve is logarithmic, even a ×100 Primordial mutation adds a controllable amount of physical speed.

### Speed curve (`SpeedCurveAnchors`)

Physical speed is interpolated in **log10 space** between these anchors:

| Display | 15 | 90 | 300 | 750 | 1,020 | 3,050 | 4,480 | 6,100 | 6,960 | 19,500 | 38,400 | 137K | 1M | 100M | 1B | 100B |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| m/s | 6.5 | 7.8 | 9.5 | 11.5 | 13 | 18 | 21 | 24.5 | 27 | 31 | 36 | 42 | 47 | 53 | 57 | 60 |

Target bands: beginner 6-8 m/s, early 10-15, mid 18-25, late 30-40, endgame 45-60. To make everything faster or slower, scale the second column. Keep it increasing.

## Sea Eggs

| # | Egg | Luck | Rarity | Per tide | Biomes | Global announce |
|---|---|---|---|---|---|---|
| 1 | Pearl Egg | 1 | Common | 30 | Central Lagoon, Shallow Reef | |
| 2 | Sandy Egg | 5 | Common | 10 | Central Lagoon, Shallow Reef | |
| 3 | Barnacle Egg | 30 | Rare | 6 | Shallow Reef | |
| 4 | Striped Reef Egg | 50 | Rare | 5 | Shallow Reef | |
| 5 | Stone Shell Egg | 100 | Rare | 4 | Shallow Reef, Kelp Forest | |
| 6 | Kelp Egg | 200 | Rare | 3 | Kelp Forest | |
| 7 | Coral Egg | 500 | Epic | 3 | Kelp Forest, Tropical Atoll | |
| 8 | Anemone Egg | 750 | Epic | 1 | Kelp Forest | |
| 9 | Jelly Egg | 1K | Epic | 2 | Tropical Atoll | |
| 10 | Frozen Tide Egg | 3K | Epic | 2 | Frozen Sea | |
| 11 | Glasswater Egg | 10K | Legendary | 2 | Tropical Atoll | |
| 12 | Sunken Gold Egg | 30K | Legendary | 2 | Tropical Atoll | |
| 13 | Crystal Reef Egg | 150K | Mythic | 2 | Frozen Sea | |
| 14 | Bone Reef Egg | 250K | Mythic | 1 | Frozen Sea | |
| 15 | Trident Egg | 700K | Mythic | 1 | Frozen Sea, Volcanic Archipelago | |
| 16 | Magma Vent Egg | 1M | Mythic | 1 | Volcanic Archipelago | |
| 17 | Cursed Depths Egg | 3M | Mythic | 1 | Volcanic Archipelago | |
| 18 | Soul Tide Egg | 7M | Mythic | 1 | Volcanic Archipelago, The Abyss | |
| 19 | Aurora Ocean Egg | 300M | Divine | 1 | Volcanic Archipelago | yes |
| 20 | Cosmic Tide Egg | 1.5B | Divine | 1 | The Abyss, Celestial Sea | yes |
| 21 | Abyssal Rift Egg | 100B | Ethereal | 1 | The Abyss | yes |
| 22 | Celestial Pearl Egg | 1T | Ethereal | 1 | Celestial Sea | yes |

81 eggs per tide. Tide reset: every **480 s** (`EggResetSeconds`). Carry time: **45 s** (`DefaultEggCarrySeconds`; the tutorial egg gets double). Basket: **1** egg (`MaxEggBasket`).

### Incubation (`IncubationSecondsForRarity`)

| Egg rarity | Common | Rare | Epic | Legendary | Mythic | Divine | Ethereal |
|---|---|---|---|---|---|---|---|
| Time | 3 min | 5 min | 10 min | 20 min | 2 h | 4 h | 6 h |
| At night (÷10) | 18 s | 30 s | 1 min | 2 min | 12 min | 24 min | 36 min |

Night lasts 6 minutes of every 18-minute cycle (`DaySeconds` 600, `SunsetSeconds` 120, `NightSeconds` 360). Incubation keeps running offline at `OfflineIncubationMultiplier` (1x). The tutorial egg takes 20 s.

## Hatch roll

```
EffectiveLuck = EggLuck × HatchLuck
from the rarest creature down to the most common:
    chance = EffectiveLuck / Odds        (≥ 1 → guaranteed)
    first success wins → exactly one creature
nothing succeeded → Sea Slug (or the first-hatch minimum)
```

Resulting rarity distribution (all creatures in each tier combined):

| Effective luck | Common | Rare | Epic | Legendary | Mythic | Divine | Ethereal | Most likely |
|---|---|---|---|---|---|---|---|---|
| 1 (Pearl, 1x) | 99.5% | 0.47% | 0.02% | 1 in 60,058 | 1 in 644,706 | 1 in 10^12 | 1 in 7.5×10^12 | Sea Slug (70%) |
| 10 | 95% | 5% | 0.16% | 0.02% | 1 in 64,471 | 1 in 10^11 | 1 in 7.5×10^11 | Hermit Crab (20%) |
| 100 | 57% | 41% | 2% | 0.17% | 0.02% | 1 in 10^10 | 1 in 7.5×10^10 | Lionfish (28%) |
| 1K | - | 83% | 16% | 2% | 0.16% | 1 in 10^9 | 1 in 7.5×10^9 | Octopus (55%) |
| 10K | - | - | 83% | 15% | 2% | 1 in 10^8 | 1 in 7.5×10^8 | Swordfish (43%) |
| 100K | - | - | 8% | 77% | 15% | 1 in 10^7 | 1 in 7.5×10^7 | Giant Squid (29%) |
| 1M | - | - | - | 5% | 95% | 1 in 10^6 | 1 in 7.5×10^6 | Whale Shark (63%) |
| 10M | - | - | - | - | 100% | 1 in 100,000 | 1 in 749,913 | Whale Shark (51%) |
| 1B | - | - | - | - | 99.9% | 0.10% | 0.01% | Sperm Whale (86%) |
| 100B | - | - | - | - | 89% | 10% | 1% | Mosasaurus (89%) |
| 10T | - | - | - | - | - | - | 100% | Megalodon (67%) |
| 1Qa | - | - | - | - | - | - | 100% | Kraken (98%) |

## Hatch Luck

Upgrades follow a five-step cycle: **+1, +1, +1, +1, +5** (+9 per cycle). The board shows the step (`4/5`).

```
HatchLuck(n)     = 1 + 9 × floor(n / 5) + partial cycle
UpgradeCost(n)   = 25 × 1.035^n        (n = upgrades already bought)
```

| Upgrades bought | Hatch Luck | Next upgrade costs |
|---|---|---|
| 0 | 1x | $25 |
| 10 | 19x | $35 |
| 50 | 91x | $140 |
| 100 | 181x | $780 |
| 200 | 361x | $24.3K |
| 300 | 541x | $759K |
| 400 | 721x | $23.7M |
| 500 | 901x | $738M |
| 600 | 1,081x | $23B |

`HatchLuckBaseCost` and `HatchLuckCostGrowth` are the only two cost knobs. BUY MAX buys upgrades one at a time with the same formula until the player can't afford the next one (at most 1,000 per press). The board's `MAX` line and the BUY MAX prompt show how many that is and the total price. They use the same function as the purchase and refresh every second and after every purchase, sale or claim.

## Economy

```
Income/s = Σ placed creature income
         × permanent Deep Dive multiplier (1 + dives)
         × (1 + Friend Boost)            (party members on this server, +10% each, max +50%)
         × weather modifier              (Blood Tide 1.1, Abyss Storm 1.2, Primordial 1.5)
```

* Starting cash: $25. Lagoon slots: 5 at the start (`StartingCreatureSlots`), +1 per Deep Dive, +1 from the Index milestone. The cap is `MaxCreatureSlots` (12) plus bonus slots.
* Offline: `IncomeSnapshot × seconds away`, capped at **8 h**, efficiency 100% (`OfflineIncomeEfficiency`), minimum 60 s away. It is paid only after the player presses CLAIM.
* Inventory cap: 300 creatures (`MaxCreatureInventory`).

## Sonar Shack (Finn)

| Tier | Sonar | Tracks | Price | Stock per restock | Chance to be in stock |
|---|---|---|---|---|---|
| 0 | Pocket Sonar | Rare | $50 | 3 - 8 | 100% |
| 1 | Coral Sonar | Epic | $3,000 | 1 - 4 | 100% |
| 2 | Trident Sonar | Legendary | $20,000 | 1 - 3 | 80% |
| 3 | Abyss Sonar | Mythic | $300K | 1 - 2 | 60% |
| 4 | Celestial Sonar | Divine | $7M | 1 | 35% |
| 5 | Leviathan Sonar | Ethereal | $30M | 1 | 15% |

Restock every 300 s. Stock is per player by default (`SharedSonarStock = false`); set it to true for one shared server stock. **AUTO-BUY** (a per-tier toggle saved with the player) buys that tier's stock at every restock, and right away when switched on, as long as the player can afford it (at most `SonarAutoBuyMaxPerRestock` = 20 per tier per restock). A sonar only points at eggs that exist and never creates any. Using one spends a charge only if it finds a target. If the target is claimed, it shows SIGNAL LOST and retargets.

## Feed Dock (Chef Kelp)

| Food | Price | XP |
|---|---|---|
| Plankton Pellets | $10 | 500 |
| Shellfish Mix | $1,500 | 10,000 |
| Tuna Chunk | $30,000 | 100,000 |
| Magic Pearl | $7M | 300,000 |
| Leviathan Fruit | $30M | 1,000,000 |

Levels: max 100. XP to the next level = `500 × 1.16^(level−1)`: level 10 needs about 1.9K and level 50 about 720K, and reaching level 100 takes about 8.7B XP in total. Each level adds +1.5% speed and income and +0.4% breach.

## Traits (rolled at hatch)

| Trait | Effect | Weight |
|---|---|---|
| None | - | 60 |
| Swift | +15% speed | 10 |
| Leaper | +15% breach | 10 |
| Wealthy | +15% income | 10 |
| Titan | +5% all | 7 |
| Radiant | +10% speed and income | 3 |

## Weather and mutations

| Event | Weight | Mutation (speed) | Income modifier | Mutation roll chance (per placed creature, every 15 s) |
|---|---|---|---|---|
| Thunderstorm | 42 | Electrified ×2 | - | 3% |
| Maelstrom | 30 | Stormcharged ×3 | - | 2.2% |
| Blood Tide | 20 | Bloodtide ×4 | ×1.1 | 1.6% |
| Abyss Storm | 7 | Abyssal ×10 | ×1.2 | 1% |
| Primordial Storm | 1 | Primordial ×100 | ×1.5 | 0.4% |

* Clear weather lasts 240-420 s, and events last 120-180 s. A Primordial Storm can happen at most once per hour (`PrimordialMinIntervalSeconds`).
* Only **placed** creatures can mutate. A stronger mutation replaces a weaker one, never the other way around. Mutations are permanent and survive Deep Dives.

## Deep Dive

| Dive | Cash required | Must own (not consumed) | Reward |
|---|---|---|---|
| 1 | $1M | Orca | +1X money multiplier, +1 Lagoon slot |
| 2 | $50M | Narwhal | +1X, +1 slot |
| 3 | $2.5B | Sea Dragon | +1X, +1 slot |
| 4 | $125B | Kraken | +1X, +1 slot |
| 5 | $6.2T | Celestial Serpent | +1X, +1 slot |
| 6 | $325T | Celestial Serpent | +1X, +1 slot |
| 7 | $50Qa | Ancient Leviathan | +1X, +1 slot |

A Deep Dive resets Cash and Hatch Luck. It keeps every creature, mutations, the Ocean Index, the permanent multiplier, slots and cosmetics.

## Ocean Index milestones

| Discovered species | Reward |
|---|---|
| 8 | $15K |
| 12 | $400K |
| 16 | $25M |
| 20 | $2B |
| 25 | +1 Lagoon slot |
| 30 | Title: MASTER OF THE DEEP |

Rewards are claimed manually with CLAIM.

## Selling (Captain Pearl)

```
Sell value = BaseIncome × SellSeconds(rarity) × (1 + 0.05 × (Level − 1)) × (1 + 0.5 × MutationTier)
SellSeconds: Common 40, Rare 60, Epic 90, Legendary 120, Mythic 180, Divine 240, Ethereal 300
```

## Tuning tips

* **Progress too fast?** Raise `HatchLuckCostGrowth` slightly (1.035 → 1.04) before touching creature odds.
* **Early game too slow?** Raise the income of creatures 2-8 or lower `HatchLuckBaseCost`.
* **Eggs too contested?** Raise `SpawnCount` for the tiers players fight over, and add spawn points.
* **Rides feel too slow or too fast?** Scale `SpeedCurveAnchors` meters/second, and keep `WORLD_DESIGN.md` distances in sync.
