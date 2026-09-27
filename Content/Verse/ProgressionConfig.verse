# ============================================================================
# RIDE A SEA BEAST - ProgressionConfig.verse
# Shops, upgrades, levels, traits, mutations, weather, Deep Dive and Ocean
# Index milestones. Pricing formulas live here ONLY - both UI and gameplay
# call these functions so displayed and charged prices can never differ.
# ============================================================================

using { /Verse.org/Colors }

# ============================================================== SONAR =====
sonar_def := struct:
    Tier : int = 0
    Name : string = ""
    TracksRarity : beast_rarity = beast_rarity.Rare
    Price : float = 0.0
    StockMin : int = 0
    StockMax : int = 0
    # Chance (0..1) that this tier appears in stock at all on a restock.
    StockChance : float = 1.0

SonarDefs : []sonar_def = array:
    sonar_def{Tier := 0, Name := "POCKET SONAR", TracksRarity := beast_rarity.Rare, Price := 50.0, StockMin := 3, StockMax := 8, StockChance := 1.0}
    sonar_def{Tier := 1, Name := "CORAL SONAR", TracksRarity := beast_rarity.Epic, Price := 3000.0, StockMin := 1, StockMax := 4, StockChance := 1.0}
    sonar_def{Tier := 2, Name := "TRIDENT SONAR", TracksRarity := beast_rarity.Legendary, Price := 20000.0, StockMin := 1, StockMax := 3, StockChance := 0.8}
    sonar_def{Tier := 3, Name := "ABYSS SONAR", TracksRarity := beast_rarity.Mythic, Price := 300000.0, StockMin := 1, StockMax := 2, StockChance := 0.6}
    sonar_def{Tier := 4, Name := "CELESTIAL SONAR", TracksRarity := beast_rarity.Divine, Price := 7000000.0, StockMin := 1, StockMax := 1, StockChance := 0.35}
    sonar_def{Tier := 5, Name := "LEVIATHAN SONAR", TracksRarity := beast_rarity.Ethereal, Price := 30000000.0, StockMin := 1, StockMax := 1, StockChance := 0.15}

SonarTierCount : int = 6

GetSonarDef(Tier:int)<computes><decides>:sonar_def = SonarDefs[Tier]

# ============================================================== FOOD ======
food_def := struct:
    Index : int = 0
    Name : string = ""
    Price : float = 0.0
    XP : int = 0

FoodDefs : []food_def = array:
    food_def{Index := 0, Name := "PLANKTON PELLETS", Price := 10.0, XP := 500}
    food_def{Index := 1, Name := "SHELLFISH MIX", Price := 1500.0, XP := 10000}
    food_def{Index := 2, Name := "TUNA CHUNK", Price := 30000.0, XP := 100000}
    food_def{Index := 3, Name := "MAGIC PEARL", Price := 7000000.0, XP := 300000}
    food_def{Index := 4, Name := "LEVIATHAN FRUIT", Price := 30000000.0, XP := 1000000}

FoodCount : int = 5

GetFoodDef(Index:int)<computes><decides>:food_def = FoodDefs[Index]

# ============================================================== LEVELS ====
MaxCreatureLevel : int = 100
LevelXPBase : float = 500.0
LevelXPGrowth : float = 1.16
# Each level above 1 adds this fraction to Speed, Breach and Income.
# 100 levels = x2.485 - meaningful, but far below a single rarity step.
LevelStatBonusPerLevel : float = 0.015

# XP required to go from Level to Level+1.
XPToNextLevel(Level:int)<reads>:int =
    Needed := LevelXPBase * Pow(LevelXPGrowth, ToFloat(Level - 1))
    Max(1, FloorToInt(Needed, 2147483647))

LevelStatMultiplier(Level:int)<computes>:float =
    1.0 + LevelStatBonusPerLevel * ToFloat(Max(0, Level - 1))

# ============================================================== TRAITS ====
# Rolled once at hatch. TraitID 0 = no trait.
trait_def := struct:
    ID : int = 0
    Name : string = ""
    SpeedMult : float = 1.0
    BreachMult : float = 1.0
    IncomeMult : float = 1.0
    RollWeight : float = 0.0

TraitDefs : []trait_def = array:
    trait_def{ID := 0, Name := "NONE", RollWeight := 60.0}
    trait_def{ID := 1, Name := "SWIFT", SpeedMult := 1.15, RollWeight := 10.0}
    trait_def{ID := 2, Name := "LEAPER", BreachMult := 1.15, RollWeight := 10.0}
    trait_def{ID := 3, Name := "WEALTHY", IncomeMult := 1.15, RollWeight := 10.0}
    trait_def{ID := 4, Name := "TITAN", SpeedMult := 1.05, BreachMult := 1.05, IncomeMult := 1.05, RollWeight := 7.0}
    trait_def{ID := 5, Name := "RADIANT", SpeedMult := 1.1, IncomeMult := 1.1, RollWeight := 3.0}

GetTraitDef(ID:int)<computes><decides>:trait_def = TraitDefs[ID]

TraitName(ID:int)<computes>:string =
    if (Def := GetTraitDef[ID]) then Def.Name else "NONE"

# ============================================================== MUTATIONS =
# MutationID 0 = none. Stronger mutations have a higher Tier; a weaker
# mutation never replaces a stronger one (MutationManager.verse).
mutation_def := struct:
    ID : int = 0
    Name : string = ""
    SpeedMult : float = 1.0
    Tier : int = 0
    # Chance per placed creature per roll while the matching weather is active.
    RollChance : float = 0.0

MutationDefs : []mutation_def = array:
    mutation_def{ID := 0, Name := "NONE", SpeedMult := 1.0, Tier := 0, RollChance := 0.0}
    mutation_def{ID := 1, Name := "ELECTRIFIED", SpeedMult := 2.0, Tier := 1, RollChance := 0.03}
    mutation_def{ID := 2, Name := "STORMCHARGED", SpeedMult := 3.0, Tier := 2, RollChance := 0.022}
    mutation_def{ID := 3, Name := "BLOODTIDE", SpeedMult := 4.0, Tier := 3, RollChance := 0.016}
    mutation_def{ID := 4, Name := "ABYSSAL", SpeedMult := 10.0, Tier := 4, RollChance := 0.01}
    mutation_def{ID := 5, Name := "PRIMORDIAL", SpeedMult := 100.0, Tier := 5, RollChance := 0.004}

MutationCount : int = 6

GetMutationDef(ID:int)<computes><decides>:mutation_def = MutationDefs[ID]

MutationName(ID:int)<computes>:string =
    if (Def := GetMutationDef[ID]) then Def.Name else "NONE"

MutationSpeedMult(ID:int)<computes>:float =
    if (Def := GetMutationDef[ID]) then Def.SpeedMult else 1.0

MutationTier(ID:int)<computes>:int =
    if (Def := GetMutationDef[ID]) then Def.Tier else 0

MutationColor(ID:int)<computes>:color =
    if (ID = 1):
        RarityColorRare
    else if (ID = 2):
        RarityColorEpic
    else if (ID = 3):
        ThemeDanger
    else if (ID = 4):
        RarityAccentEthereal
    else if (ID = 5):
        ThemeGold
    else:
        ThemeMuted

# ============================================================== WEATHER ===
weather_def := struct:
    Kind : weather_kind = weather_kind.Clear
    # Relative chance of being picked when a clear period ends.
    Weight : float = 0.0
    # Mutation granted during this weather (0 = none).
    MutationID : int = 0
    # Temporary income modifier while active (1.0 = none).
    IncomeModifier : float = 1.0
    Announcement : string = ""

WeatherDefs : []weather_def = array:
    weather_def{Kind := weather_kind.Clear, Weight := 0.0, MutationID := 0, Announcement := "THE SKIES CLEAR OVER THE OCEAN."}
    weather_def{Kind := weather_kind.Thunderstorm, Weight := 42.0, MutationID := 1, Announcement := "A THUNDERSTORM ROLLS IN! PLACED SEA BEASTS MAY BECOME ELECTRIFIED!"}
    weather_def{Kind := weather_kind.Maelstrom, Weight := 30.0, MutationID := 2, Announcement := "A MAELSTROM IS FORMING! SEA BEASTS MAY BECOME STORMCHARGED!"}
    weather_def{Kind := weather_kind.BloodTide, Weight := 20.0, MutationID := 3, IncomeModifier := 1.1, Announcement := "THE BLOOD TIDE RISES! THE OCEAN GLOWS RED..."}
    weather_def{Kind := weather_kind.AbyssStorm, Weight := 7.0, MutationID := 4, IncomeModifier := 1.2, Announcement := "AN ABYSS STORM ERUPTS FROM THE DEEP!"}
    weather_def{Kind := weather_kind.PrimordialStorm, Weight := 1.0, MutationID := 5, IncomeModifier := 1.5, Announcement := "A PRIMORDIAL STORM HAS AWAKENED! THE OCEAN REMEMBERS ITS BIRTH!"}

GetWeatherDef(W:weather_kind)<computes><decides>:weather_def = WeatherDefs[WeatherIndex(W)]

# ============================================================== HATCH LUCK
# Five-upgrade cycle: +1, +1, +1, +1, +5 (= +9 per cycle).
HatchLuckCycle : []float = array{1.0, 1.0, 1.0, 1.0, 5.0}
HatchLuckBaseCost : float = 25.0
HatchLuckCostGrowth : float = 1.035

# Luck gained by the upgrade with index UpgradeIndex (0-based).
HatchLuckGainForUpgrade(UpgradeIndex:int)<computes>:float =
    CycleLength := HatchLuckCycle.Length
    if (Gain := HatchLuckCycle[ModInt(UpgradeIndex, CycleLength)]) then Gain else 1.0

# Total Hatch Luck after UpgradeCount purchased upgrades.
HatchLuckForUpgrades(UpgradeCount:int)<transacts>:float =
    Count := Max(0, UpgradeCount)
    FullCycles := QuotInt(Count, HatchLuckCycle.Length)
    Remainder := ModInt(Count, HatchLuckCycle.Length)
    var CycleTotal : float = 0.0
    for (Gain : HatchLuckCycle):
        set CycleTotal += Gain
    var Partial : float = 0.0
    for (I := 0..Remainder - 1, Gain := HatchLuckCycle[I]):
        set Partial += Gain
    StartingHatchLuck + CycleTotal * ToFloat(FullCycles) + Partial

# Price of the next upgrade when UpgradeCount upgrades are already owned.
HatchLuckUpgradeCost(UpgradeCount:int)<reads>:float =
    HatchLuckBaseCost * Pow(HatchLuckCostGrowth, ToFloat(Max(0, UpgradeCount)))

# Position inside the current five-upgrade cycle (1..5) for the UI.
HatchLuckCycleStep(UpgradeCount:int)<computes>:int =
    ModInt(Max(0, UpgradeCount), HatchLuckCycle.Length) + 1

# ============================================================== DEEP DIVE =
deep_dive_def := struct:
    Level : int = 0
    CashRequired : float = 0.0
    RequiredCreatureID : int = 0
    MoneyMultiplierGain : float = 1.0
    SlotGain : int = 1

DeepDiveDefs : []deep_dive_def = array:
    deep_dive_def{Level := 1, CashRequired := 1000000.0, RequiredCreatureID := 17}
    deep_dive_def{Level := 2, CashRequired := 50000000.0, RequiredCreatureID := 22}
    deep_dive_def{Level := 3, CashRequired := 2500000000.0, RequiredCreatureID := 25}
    deep_dive_def{Level := 4, CashRequired := 125000000000.0, RequiredCreatureID := 27}
    deep_dive_def{Level := 5, CashRequired := 6200000000000.0, RequiredCreatureID := 29}
    deep_dive_def{Level := 6, CashRequired := 325000000000000.0, RequiredCreatureID := 29}
    deep_dive_def{Level := 7, CashRequired := 50000000000000000.0, RequiredCreatureID := 30}

MaxDeepDives : int = 7

# Definition of the NEXT Deep Dive for a player who has completed Count dives.
GetNextDeepDive(CompletedCount:int)<computes><decides>:deep_dive_def = DeepDiveDefs[CompletedCount]

PermanentMultiplierForDives(CompletedCount:int)<transacts>:float =
    var Total : float = 1.0
    for (I := 0..CompletedCount - 1, Def := DeepDiveDefs[I]):
        set Total += Def.MoneyMultiplierGain
    Total

SlotsForDives(CompletedCount:int, BonusSlots:int)<transacts>:int =
    var Slots : int = StartingCreatureSlots + BonusSlots
    for (I := 0..CompletedCount - 1, Def := DeepDiveDefs[I]):
        set Slots += Def.SlotGain
    Min(Slots, MaxCreatureSlots + BonusSlots)

# ============================================================== INDEX =====
# Reward kinds: 0 cash, 1 bonus lagoon slot, 2 title/cosmetic.
index_milestone_def := struct:
    Discoveries : int = 0
    RewardKind : int = 0
    CashReward : float = 0.0
    CosmeticID : int = 0
    Label : string = ""

IndexMilestones : []index_milestone_def = array:
    index_milestone_def{Discoveries := 8, RewardKind := 0, CashReward := 15000.0, Label := "$15K"}
    index_milestone_def{Discoveries := 12, RewardKind := 0, CashReward := 400000.0, Label := "$400K"}
    index_milestone_def{Discoveries := 16, RewardKind := 0, CashReward := 25000000.0, Label := "$25M"}
    index_milestone_def{Discoveries := 20, RewardKind := 0, CashReward := 2000000000.0, Label := "$2B"}
    index_milestone_def{Discoveries := 25, RewardKind := 1, Label := "+1 LAGOON SLOT"}
    index_milestone_def{Discoveries := 30, RewardKind := 2, CosmeticID := 1, Label := "TITLE: MASTER OF THE DEEP"}

cosmetic_def := struct:
    ID : int = 0
    Title : string = ""

CosmeticDefs : []cosmetic_def = array:
    cosmetic_def{ID := 0, Title := ""}
    cosmetic_def{ID := 1, Title := "MASTER OF THE DEEP"}

CosmeticTitle(ID:int)<computes>:string =
    if (Def := CosmeticDefs[ID]) then Def.Title else ""

# ============================================================== SELLING ===
# Sell value = base income x seconds-of-income for the rarity x level factor.
SellSecondsForRarity(R:beast_rarity)<computes>:float =
    case (R):
        beast_rarity.Common => 40.0
        beast_rarity.Rare => 60.0
        beast_rarity.Epic => 90.0
        beast_rarity.Legendary => 120.0
        beast_rarity.Mythic => 180.0
        beast_rarity.Divine => 240.0
        beast_rarity.Ethereal => 300.0

SellLevelBonusPerLevel : float = 0.05
SellMutationBonusPerTier : float = 0.5
