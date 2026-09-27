# ============================================================================
# RIDE A SEA BEAST - Types.verse
# Shared enums used by every system.
# Persisted data never stores these enums directly; it stores integer IDs so
# the save format stays stable if enums are reordered (see SaveData.verse).
# ============================================================================
using { /Verse.org/Simulation }

# Creature / egg rarity, ordered from most common to rarest.
beast_rarity := enum{Common, Rare, Epic, Legendary, Mythic, Divine, Ethereal}

# The eight ocean regions. Zone 0 is the central hub.
biome := enum{CentralLagoon, ShallowReef, KelpForest, TropicalAtoll, FrozenSea, VolcanicArchipelago, TheAbyss, CelestialSea}

# Global ocean events driven by WeatherManager.verse.
weather_kind := enum{Clear, Thunderstorm, Maelstrom, BloodTide, AbyssStorm, PrimordialStorm}

# World cycle phases driven by DayNightManager.verse.
day_phase := enum{Day, Sunset, Night}

# Interactable hub stations (NPC shops, kiosks) - see MenuStationDevice.verse.
station_kind := enum{CurrentTracker, SonarShack, FeedDock, HarborTrader, OceanIndex, Settings, SeaBeasts, DeepDive}

# Navigation zones authored in the level - see SeaZoneDevice.verse.
#   Land      : blocks Sea Beasts between BottomZ and TopZ (islands, reef walls, arches).
#   WaterPool : raised water surface (pools above waterfalls, floating caves).
#   Biome     : names the region for music, analytics and the HUD.
#   DeepWater : allows deeper dives (trenches, the Abyss).
zone_kind := enum{Land, WaterPool, Biome, DeepWater}
zone_shape := enum{Cylinder, Box}

# How the rider is attached to the Sea Beast rig (SeaBeastMountSystem.verse).
#   Chair          : rider is seated in a chair_device that moves with the creature.
#   PlatformStasis : rider stands on an invisible saddle prop and is put in stasis.
rider_attach_mode := enum{Chair, PlatformStasis}

# How mounted throttle works when no analog movement provider is active.
throttle_mode := enum{Hold, Toggle}

# Keys for sound effects routed through AudioManager.verse.
sfx_key := enum {
    UIClick
    UIHover
    Cash
    Purchase
    EggPickup
    EggCrack
    EggPlace
    Hatch
    RareHatch
    EtherealHatch
    Mount
    Dismount
    Splash
    FastSwim
    SonarPing
    SonarLost
    TideReset
    DivineEggSpawn
    EtherealEggSpawn
    Weather
    Mutation
    DeepDive
    Feeding
    Selling
    IndexReward
    Error
    Claim
}

# Keys for pooled world VFX routed through VFXManager.verse.
vfx_key := enum {
    Splash
    SonarPulse
    EggCrackBurst
    HatchEnergy
    HatchCommon
    HatchRare
    HatchEpic
    HatchLegendary
    HatchMythic
    HatchDivine
    HatchEthereal
    RareSpawnBeacon
    MutationFlash
    DeepDiveWave
    FeedSparkle
    SellCoins
    IndexReward
    EggSecured
}

# Progression analytics events (AnalyticsManager.verse). No personal data is sent:
# an analytics_device only records that an event happened for a player.
analytics_key := enum {
    TutorialStarted
    TutorialComplete
    FirstEggFound
    FirstEggDelivered
    FirstHatch
    FirstRare
    FirstEpic
    FirstLegendary
    FirstMythic
    FirstDivine
    FirstEthereal
    FirstSonar
    FirstLuckUpgrade
    FirstMutation
    FirstDeepDive
    EggLost
    EggSecured
    CreatureSold
    BiomeReached
}

# Filters and sorts offered by the SEA BEASTS menu.
creature_filter := enum{All, Common, Rare, Epic, Legendary, Mythic, Divine, Ethereal, Mutated, Locked}
creature_sort := enum{BestSpeed, BestIncome, BestBreach, Rarity, Newest}

# Sorting for the Current Tracker board.
tracker_sort := enum{HighestLuck, LowestLuck, Rarity}

# Which menu screen is open for a player (UIManager.verse).
menu_screen := enum{None, SeaBeasts, OceanIndex, DeepDive, Settings, Tracker, SonarShop, FeedDock, Trader, Debug}

# Ocean Index categories.
index_tab := enum{SeaBeasts, SeaEggs, Mutations}

# Per-player mount state (SeaBeastMountSystem.verse).
mount_state := enum{Dismounted, Mounting, Mounted}

# Vertical locomotion state of a mounted Sea Beast.
swim_mode := enum{Surface, Diving, Airborne}

# Tutorial progress. Stored in the save as an int (see TutorialManager.verse).
tutorial_step := enum{Welcome, ThisIsYourLagoon, MountSeaSlug, FindEgg, BringItHome, PlaceInIncubator, HatchIt, FasterBeasts, Done}

# Pending confirmation dialog actions (UIPopups.verse).
confirm_action := enum{None, SellRequired, SellDuplicates, DeepDive, ResetSave}

# Developer console commands (DebugManager.verse). Never available in Live.
debug_command := enum {
    GiveCash
    SetHatchLuck
    SpawnEgg
    ForceTideReset
    GiveCreature
    SetMutation
    TriggerWeather
    SetDayPhase
    CompleteIncubation
    SetDeepDive
    TeleportBiome
    ClearSave
}
