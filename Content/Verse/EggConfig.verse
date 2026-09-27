# ============================================================================
# RIDE A SEA BEAST - EggConfig.verse
# The Sea Egg table. Rules:
#   * ID must equal (array index + 1) and must never change after publishing.
#   * Luck multiplies the player's Hatch Luck (HatchManager.verse).
#   * SpawnCount is how many of this egg are placed at every Tide Reset.
#   * Biomes lists the regions whose spawn points may host this egg. A spawn
#     point accepts an egg when its biome is listed here AND the egg's rarity
#     is one of the point's accepted tiers (see EggSpawnPoint.verse).
#   * Divine and Ethereal eggs are announced globally without a location.
# Visual assets (egg props, carry VFX) are assigned in the editor on the game
# device's Egg Visuals list - see EditorLibraries.verse.
# ============================================================================

egg_def := struct:
    ID : int = 0
    Name : string = ""
    Luck : float = 1.0
    Rarity : beast_rarity = beast_rarity.Common
    SpawnCount : int = 1
    Biomes : []biome = array{}
    AnnounceGlobally : logic = false

EggDefs : []egg_def = array:
    egg_def{ID := 1, Name := "PEARL EGG", Luck := 1.0, Rarity := beast_rarity.Common, SpawnCount := 30, Biomes := array{biome.CentralLagoon, biome.ShallowReef}}
    egg_def{ID := 2, Name := "SANDY EGG", Luck := 5.0, Rarity := beast_rarity.Common, SpawnCount := 10, Biomes := array{biome.CentralLagoon, biome.ShallowReef}}
    egg_def{ID := 3, Name := "BARNACLE EGG", Luck := 30.0, Rarity := beast_rarity.Rare, SpawnCount := 6, Biomes := array{biome.ShallowReef}}
    egg_def{ID := 4, Name := "STRIPED REEF EGG", Luck := 50.0, Rarity := beast_rarity.Rare, SpawnCount := 5, Biomes := array{biome.ShallowReef}}
    egg_def{ID := 5, Name := "STONE SHELL EGG", Luck := 100.0, Rarity := beast_rarity.Rare, SpawnCount := 4, Biomes := array{biome.ShallowReef, biome.KelpForest}}
    egg_def{ID := 6, Name := "KELP EGG", Luck := 200.0, Rarity := beast_rarity.Rare, SpawnCount := 3, Biomes := array{biome.KelpForest}}
    egg_def{ID := 7, Name := "CORAL EGG", Luck := 500.0, Rarity := beast_rarity.Epic, SpawnCount := 3, Biomes := array{biome.KelpForest, biome.TropicalAtoll}}
    egg_def{ID := 8, Name := "ANEMONE EGG", Luck := 750.0, Rarity := beast_rarity.Epic, SpawnCount := 1, Biomes := array{biome.KelpForest}}
    egg_def{ID := 9, Name := "JELLY EGG", Luck := 1000.0, Rarity := beast_rarity.Epic, SpawnCount := 2, Biomes := array{biome.TropicalAtoll}}
    egg_def{ID := 10, Name := "FROZEN TIDE EGG", Luck := 3000.0, Rarity := beast_rarity.Epic, SpawnCount := 2, Biomes := array{biome.FrozenSea}}
    egg_def{ID := 11, Name := "GLASSWATER EGG", Luck := 10000.0, Rarity := beast_rarity.Legendary, SpawnCount := 2, Biomes := array{biome.TropicalAtoll}}
    egg_def{ID := 12, Name := "SUNKEN GOLD EGG", Luck := 30000.0, Rarity := beast_rarity.Legendary, SpawnCount := 2, Biomes := array{biome.TropicalAtoll}}
    egg_def{ID := 13, Name := "CRYSTAL REEF EGG", Luck := 150000.0, Rarity := beast_rarity.Mythic, SpawnCount := 2, Biomes := array{biome.FrozenSea}}
    egg_def{ID := 14, Name := "BONE REEF EGG", Luck := 250000.0, Rarity := beast_rarity.Mythic, SpawnCount := 1, Biomes := array{biome.FrozenSea}}
    egg_def{ID := 15, Name := "TRIDENT EGG", Luck := 700000.0, Rarity := beast_rarity.Mythic, SpawnCount := 1, Biomes := array{biome.FrozenSea, biome.VolcanicArchipelago}}
    egg_def{ID := 16, Name := "MAGMA VENT EGG", Luck := 1000000.0, Rarity := beast_rarity.Mythic, SpawnCount := 1, Biomes := array{biome.VolcanicArchipelago}}
    egg_def{ID := 17, Name := "CURSED DEPTHS EGG", Luck := 3000000.0, Rarity := beast_rarity.Mythic, SpawnCount := 1, Biomes := array{biome.VolcanicArchipelago}}
    egg_def{ID := 18, Name := "SOUL TIDE EGG", Luck := 7000000.0, Rarity := beast_rarity.Mythic, SpawnCount := 1, Biomes := array{biome.VolcanicArchipelago, biome.TheAbyss}}
    egg_def{ID := 19, Name := "AURORA OCEAN EGG", Luck := 300000000.0, Rarity := beast_rarity.Divine, SpawnCount := 1, Biomes := array{biome.VolcanicArchipelago}, AnnounceGlobally := true}
    egg_def{ID := 20, Name := "COSMIC TIDE EGG", Luck := 1500000000.0, Rarity := beast_rarity.Divine, SpawnCount := 1, Biomes := array{biome.TheAbyss, biome.CelestialSea}, AnnounceGlobally := true}
    egg_def{ID := 21, Name := "ABYSSAL RIFT EGG", Luck := 100000000000.0, Rarity := beast_rarity.Ethereal, SpawnCount := 1, Biomes := array{biome.TheAbyss}, AnnounceGlobally := true}
    egg_def{ID := 22, Name := "CELESTIAL PEARL EGG", Luck := 1000000000000.0, Rarity := beast_rarity.Ethereal, SpawnCount := 1, Biomes := array{biome.CelestialSea}, AnnounceGlobally := true}

EggCount : int = 22

# Egg used for the new-player tutorial egg next to their Lagoon.
TutorialEggID : int = 1

GetEggDef(ID:int)<computes><decides>:egg_def =
    Def := EggDefs[ID - 1]
    Def.ID = ID
    Def

IsValidEggID(ID:int)<computes><decides>:void =
    ID >= 1
    ID <= EggCount

EggName(ID:int)<computes>:string =
    if (Def := GetEggDef[ID]) then Def.Name else "SEA EGG"

EggRarity(ID:int)<computes>:beast_rarity =
    if (Def := GetEggDef[ID]) then Def.Rarity else beast_rarity.Common

EggLuck(ID:int)<computes>:float =
    if (Def := GetEggDef[ID]) then Def.Luck else 1.0

# Incubation time by rarity in seconds (before the night multiplier).
IncubationSecondsForRarity(R:beast_rarity)<computes>:float =
    case (R):
        beast_rarity.Common => 180.0
        beast_rarity.Rare => 300.0
        beast_rarity.Epic => 600.0
        beast_rarity.Legendary => 1200.0
        beast_rarity.Mythic => 7200.0
        beast_rarity.Divine => 14400.0
        beast_rarity.Ethereal => 21600.0

IncubationSecondsForEgg(EggID:int)<computes>:float =
    IncubationSecondsForRarity(EggRarity(EggID))

# Carry time before a claimed egg cracks. One global value by default; kept
# as a function so specific eggs can be tuned later without touching logic.
CarrySecondsForEgg(EggID:int)<computes>:float = DefaultEggCarrySeconds

EggAllowsBiome(Def:egg_def, B:biome)<computes><decides>:void =
    Def.Biomes.Find[B] >= 0
