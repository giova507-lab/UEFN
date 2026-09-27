# ============================================================================
# RIDE A SEA BEAST - CreatureConfig.verse
# The Sea Beast table. Edit names, odds and stats here; gameplay code only
# reads this table. Rules:
#   * ID must equal (array index + 1) and must never change after publishing
#     (saves store the ID). Append new creatures at the end.
#   * Odds is the "1 in N" denominator used by HatchManager.verse.
#   * BaseSpeed is a DISPLAY value. MovementBalance.verse converts it to a
#     stable physical speed with a logarithmic curve.
#   * SizeClass (0 tiny .. 5 massive) drives turning, pickup reach and the
#     default visual scale. Gameplay collision stays separate from visuals.
# Visual assets (props, animated meshes) are assigned in the editor on the
# game device's Creature Visuals list - see EditorLibraries.verse.
# ============================================================================

creature_def := struct:
    ID : int = 0
    Name : string = ""
    Rarity : beast_rarity = beast_rarity.Common
    Odds : float = 2.0
    BaseSpeed : float = 1.0
    BaseBreach : float = 1.0
    BaseIncome : float = 1.0
    SizeClass : int = 0
    Flavor : string = ""

CreatureDefs : []creature_def = array:
    creature_def{ID := 1, Name := "SEA SLUG", Rarity := beast_rarity.Common, Odds := 2.0, BaseSpeed := 15.0, BaseBreach := 78.0, BaseIncome := 3.0, SizeClass := 0, Flavor := "Slow, squishy and always smiling."}
    creature_def{ID := 2, Name := "HERMIT CRAB", Rarity := beast_rarity.Common, Odds := 5.0, BaseSpeed := 50.0, BaseBreach := 80.0, BaseIncome := 5.0, SizeClass := 0, Flavor := "Carries its house and its pride."}
    creature_def{ID := 3, Name := "STARFISH", Rarity := beast_rarity.Common, Odds := 20.0, BaseSpeed := 90.0, BaseBreach := 77.0, BaseIncome := 7.0, SizeClass := 0, Flavor := "Spins like a wheel across the shallows."}
    creature_def{ID := 4, Name := "CLOWNFISH", Rarity := beast_rarity.Common, Odds := 30.0, BaseSpeed := 165.0, BaseBreach := 81.0, BaseIncome := 9.0, SizeClass := 0, Flavor := "Tells terrible jokes. Swims great."}
    creature_def{ID := 5, Name := "PUFFERFISH", Rarity := beast_rarity.Common, Odds := 50.0, BaseSpeed := 300.0, BaseBreach := 95.0, BaseIncome := 5.0, SizeClass := 0, Flavor := "Inflates to bounce over waves."}
    creature_def{ID := 6, Name := "SEAHORSE", Rarity := beast_rarity.Common, Odds := 100.0, BaseSpeed := 407.0, BaseBreach := 89.0, BaseIncome := 20.0, SizeClass := 0, Flavor := "The reef's proudest gallop."}
    creature_def{ID := 7, Name := "BLUE TANG", Rarity := beast_rarity.Common, Odds := 150.0, BaseSpeed := 553.0, BaseBreach := 92.0, BaseIncome := 25.0, SizeClass := 0, Flavor := "Never forgets a current."}
    creature_def{ID := 8, Name := "LIONFISH", Rarity := beast_rarity.Common, Odds := 200.0, BaseSpeed := 750.0, BaseBreach := 90.0, BaseIncome := 30.0, SizeClass := 0, Flavor := "A crown of fins, a heart of gold."}
    creature_def{ID := 9, Name := "STINGRAY", Rarity := beast_rarity.Rare, Odds := 300.0, BaseSpeed := 1020.0, BaseBreach := 75.0, BaseIncome := 35.0, SizeClass := 1, Flavor := "Glides flat and fast over sandbars."}
    creature_def{ID := 10, Name := "OCTOPUS", Rarity := beast_rarity.Rare, Odds := 1000.0, BaseSpeed := 1380.0, BaseBreach := 87.0, BaseIncome := 50.0, SizeClass := 1, Flavor := "Eight arms, eight times the fun."}
    creature_def{ID := 11, Name := "BARRACUDA", Rarity := beast_rarity.Rare, Odds := 3000.0, BaseSpeed := 3050.0, BaseBreach := 125.0, BaseIncome := 120.0, SizeClass := 1, Flavor := "A silver streak with a toothy grin."}
    creature_def{ID := 12, Name := "SWORDFISH", Rarity := beast_rarity.Epic, Odds := 9000.0, BaseSpeed := 3250.0, BaseBreach := 111.0, BaseIncome := 150.0, SizeClass := 2, Flavor := "Cuts through waves like a blade."}
    creature_def{ID := 13, Name := "MANTIS SHRIMP", Rarity := beast_rarity.Epic, Odds := 25000.0, BaseSpeed := 3690.0, BaseBreach := 129.0, BaseIncome := 160.0, SizeClass := 1, Flavor := "Sees colors you have never imagined."}
    creature_def{ID := 14, Name := "MORAY EEL", Rarity := beast_rarity.Epic, Odds := 75000.0, BaseSpeed := 3940.0, BaseBreach := 98.0, BaseIncome := 170.0, SizeClass := 2, Flavor := "Lurks in reef cracks, then strikes forward."}
    creature_def{ID := 15, Name := "HAMMERHEAD SHARK", Rarity := beast_rarity.Legendary, Odds := 150000.0, BaseSpeed := 4480.0, BaseBreach := 99.0, BaseIncome := 200.0, SizeClass := 2, Flavor := "Built-in wide-angle vision."}
    creature_def{ID := 16, Name := "GIANT SQUID", Rarity := beast_rarity.Legendary, Odds := 180000.0, BaseSpeed := 4780.0, BaseBreach := 93.0, BaseIncome := 240.0, SizeClass := 2, Flavor := "Jet propulsion from the deep."}
    creature_def{ID := 17, Name := "ORCA", Rarity := beast_rarity.Legendary, Odds := 500000.0, BaseSpeed := 5340.0, BaseBreach := 108.0, BaseIncome := 350.0, SizeClass := 3, Flavor := "The clever captain of the open sea."}
    creature_def{ID := 18, Name := "GREAT WHITE SHARK", Rarity := beast_rarity.Legendary, Odds := 700000.0, BaseSpeed := 5710.0, BaseBreach := 102.0, BaseIncome := 375.0, SizeClass := 3, Flavor := "Legendary bite, gentle rider."}
    creature_def{ID := 19, Name := "TIGER SHARK", Rarity := beast_rarity.Legendary, Odds := 1000000.0, BaseSpeed := 6100.0, BaseBreach := 114.0, BaseIncome := 400.0, SizeClass := 3, Flavor := "Striped, fearless, and very fast."}
    creature_def{ID := 20, Name := "GIANT MANTA", Rarity := beast_rarity.Mythic, Odds := 1200000.0, BaseSpeed := 6520.0, BaseBreach := 120.0, BaseIncome := 510.0, SizeClass := 3, Flavor := "Flies through water on enormous wings."}
    creature_def{ID := 21, Name := "WHALE SHARK", Rarity := beast_rarity.Mythic, Odds := 1500000.0, BaseSpeed := 6960.0, BaseBreach := 86.0, BaseIncome := 750.0, SizeClass := 3, Flavor := "The gentle giant with a spotted coat."}
    creature_def{ID := 22, Name := "NARWHAL", Rarity := beast_rarity.Mythic, Odds := 21000000.0, BaseSpeed := 19500.0, BaseBreach := 105.0, BaseIncome := 1200.0, SizeClass := 3, Flavor := "The unicorn of the frozen sea."}
    creature_def{ID := 23, Name := "SPERM WHALE", Rarity := beast_rarity.Mythic, Odds := 300000000.0, BaseSpeed := 27400.0, BaseBreach := 83.0, BaseIncome := 2200.0, SizeClass := 4, Flavor := "Dives deeper than any beast alive."}
    creature_def{ID := 24, Name := "MOSASAURUS", Rarity := beast_rarity.Mythic, Odds := 7000000000.0, BaseSpeed := 38400.0, BaseBreach := 117.0, BaseIncome := 3500.0, SizeClass := 4, Flavor := "An ancient hunter returned from the fossils."}
    creature_def{ID := 25, Name := "SEA DRAGON", Rarity := beast_rarity.Divine, Odds := 1000000000000.0, BaseSpeed := 137000.0, BaseBreach := 135.0, BaseIncome := 30000.0, SizeClass := 4, Flavor := "Coils of coral and storm."}
    creature_def{ID := 26, Name := "MEGALODON", Rarity := beast_rarity.Ethereal, Odds := 10000000000000.0, BaseSpeed := 266000.0, BaseBreach := 100.0, BaseIncome := 50000.0, SizeClass := 4, Flavor := "The king of prehistoric oceans."}
    creature_def{ID := 27, Name := "KRAKEN", Rarity := beast_rarity.Ethereal, Odds := 30000000000000.0, BaseSpeed := 1000000.0, BaseBreach := 146.0, BaseIncome := 100000.0, SizeClass := 5, Flavor := "Sailors' legends were understatements."}
    creature_def{ID := 28, Name := "ABYSSAL HYDRA", Rarity := beast_rarity.Ethereal, Odds := 70000000000000000.0, BaseSpeed := 100000000.0, BaseBreach := 143.0, BaseIncome := 30000000.0, SizeClass := 5, Flavor := "Many heads, one terrifying speed."}
    creature_def{ID := 29, Name := "CELESTIAL SERPENT", Rarity := beast_rarity.Ethereal, Odds := 1000000000000000000.0, BaseSpeed := 1000000000.0, BaseBreach := 170.0, BaseIncome := 90000000.0, SizeClass := 5, Flavor := "Rides the starlight between waves. The fastest beast alive."}
    creature_def{ID := 30, Name := "ANCIENT LEVIATHAN", Rarity := beast_rarity.Ethereal, Odds := 5000000000000000000.0, BaseSpeed := 300000000.0, BaseBreach := 150.0, BaseIncome := 300000000.0, SizeClass := 5, Flavor := "Older than the ocean. Richer than kingdoms."}

CreatureCount : int = 30

# Creature ID of the starter granted to every new player.
StarterCreatureID : int = 1

# Returns the creature definition for an ID (IDs start at 1).
GetCreatureDef(ID:int)<computes><decides>:creature_def =
    Def := CreatureDefs[ID - 1]
    Def.ID = ID
    Def

IsValidCreatureID(ID:int)<computes><decides>:void =
    ID >= 1
    ID <= CreatureCount

CreatureName(ID:int)<computes>:string =
    if (Def := GetCreatureDef[ID]) then Def.Name else "UNKNOWN"

CreatureRarity(ID:int)<computes>:beast_rarity =
    if (Def := GetCreatureDef[ID]) then Def.Rarity else beast_rarity.Common

# Size class -> default visual scale multiplier (visual only).
SizeClassVisualScale(SizeClass:int)<computes>:float =
    if (SizeClass <= 0):
        1.0
    else if (SizeClass = 1):
        1.35
    else if (SizeClass = 2):
        1.8
    else if (SizeClass = 3):
        2.6
    else if (SizeClass = 4):
        3.6
    else:
        5.0

# Size class -> gameplay collision radius in cm (kept modest on purpose so
# huge creatures still fit through reef gaps and lagoon docks).
SizeClassCollisionRadius(SizeClass:int)<computes>:float =
    if (SizeClass <= 0):
        90.0
    else if (SizeClass = 1):
        120.0
    else if (SizeClass = 2):
        150.0
    else if (SizeClass = 3):
        190.0
    else if (SizeClass = 4):
        230.0
    else:
        270.0

# Size class -> maximum turn rate in degrees per second.
SizeClassTurnRate(SizeClass:int)<computes>:float =
    if (SizeClass <= 0):
        240.0
    else if (SizeClass = 1):
        200.0
    else if (SizeClass = 2):
        165.0
    else if (SizeClass = 3):
        130.0
    else if (SizeClass = 4):
        105.0
    else:
        85.0

# Default rider seat height above the creature root (cm) per size class.
SizeClassSaddleHeight(SizeClass:int)<computes>:float =
    if (SizeClass <= 0):
        70.0
    else if (SizeClass = 1):
        95.0
    else if (SizeClass = 2):
        125.0
    else if (SizeClass = 3):
        175.0
    else if (SizeClass = 4):
        240.0
    else:
        320.0
