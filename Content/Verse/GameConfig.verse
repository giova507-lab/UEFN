# ============================================================================
# RIDE A SEA BEAST - GameConfig.verse
# Global tuning values. Every gameplay number that is not a per-creature or
# per-egg value lives here or in ProgressionConfig.verse. Gameplay code must
# read these constants instead of hard-coding numbers.
# ============================================================================
using { /Verse.org/Colors }
using { /Verse.org/Simulation }

# ---------------------------------------------------------------- Session ---
MaxPlayers : int = 6
LagoonCount : int = 6

# Autosave cadence for cash / incubation progress / last-seen timestamp.
AutosaveIntervalSeconds : float = 30.0
# Economy tick (one centralized tick for every player's income).
EconomyTickSeconds : float = 1.0
# HUD refresh cadence for timers that are not event driven.
HudRefreshSeconds : float = 0.5
# Wait after OnBegin so self-registering devices (spawn points, zones,
# stations) have finished registering before managers read the registry.
RegistrySettleSeconds : float = 1.0

# ---------------------------------------------------------------- Economy ---
StartingCash : float = 25.0
StartingHatchLuck : float = 1.0
StartingCreatureSlots : int = 5
MaxCreatureSlots : int = 12
# Hard cap on owned creatures so a player's save stays well inside the
# per-player persistence budget. The UI asks players to sell when full.
MaxCreatureInventory : int = 300
# Offline income.
OfflineIncomeCapHours : float = 8.0
OfflineIncomeEfficiency : float = 1.0
OfflineMinimumSeconds : float = 60.0

# ---------------------------------------------------------------- Eggs ------
EggResetSeconds : float = 480.0
DefaultEggCarrySeconds : float = 45.0
MaxEggBasket : int = 1
# Proximity claim radius (cm). Mounted riders use the larger radius, scaled by
# creature size class (see MovementBalance.verse).
EggPickupRadiusOnFoot : float = 300.0
EggPickupRadiusMounted : float = 650.0
# When false, on-foot players must use the spawn point's button (TAKE SEA EGG).
ProximityPickupWhenOnFoot : logic = true
# Carrying players who enter their own Lagoon's delivery radius have the egg
# secured into the first empty incubator automatically.
AutoSecureInLagoon : logic = true
LagoonDeliveryRadius : float = 2600.0
# Carried eggs are lost if the carrier leaves or is eliminated.
EggWarningSeconds : float = 10.0

# ---------------------------------------------------------------- Incubation
IncubatorsPerLagoon : int = 4
NightIncubationMultiplier : float = 10.0
# Offline incubation runs at base speed (night bonus needs the live world).
OfflineIncubationMultiplier : float = 1.0
# The very first tutorial egg incubates quickly so onboarding stays < 5 min.
TutorialIncubationSeconds : float = 20.0
# The first ever hatch is guaranteed to be at least this creature ID
# (teaches "a faster beast"). 2 = Hermit Crab.
FirstHatchMinCreatureID : int = 2

# ---------------------------------------------------------------- Mounts ----
# Locomotion tick. Every rig issues MoveTo commands at this rate.
MountTickSeconds : float = 0.1
# Extra time added to each MoveTo so consecutive segments overlap and the
# client never sees the rig stop between segments.
MountMoveLeadSeconds : float = 0.05
MountAccelerationTime : float = 1.1
MountBrakeTime : float = 0.6
MountCoastTime : float = 1.8
MountReverseFraction : float = 0.35
MountCruiseFraction : float = 0.8
MountSurfaceBobCm : float = 8.0
MountSurfaceBobHz : float = 0.6
MountGravityCmPerSec2 : float = 2000.0
MountDiveSpeedCmPerSec : float = 350.0
MountDefaultDiveDepthCm : float = 600.0
MountMaxBankDegrees : float = 22.0
MountMaxPitchDegrees : float = 35.0
# Minimum fraction of top speed required to breach.
MountBreachMinSpeedFraction : float = 0.15
# Below this speed (cm/s) a Jump press dismounts instead of breaching.
MountDismountMaxSpeed : float = 150.0
# Rider re-snap safety net for PlatformStasis mode (cm).
MountRiderSnapDistance : float = 180.0
# World bounds (cm) measured from the hub center on the XY plane.
WorldBoundsRadius : float = 190000.0

# ---------------------------------------------------------------- Sonar -----
SonarRestockSeconds : float = 300.0
SonarTickSeconds : float = 0.2
SonarMaxTrackSeconds : float = 240.0
SonarPingMinInterval : float = 0.25
SonarPingMaxInterval : float = 2.0
SonarPingFarDistance : float = 120000.0
SharedSonarStock : logic = false

# ---------------------------------------------------------------- Day/Night -
DaySeconds : float = 600.0
SunsetSeconds : float = 120.0
NightSeconds : float = 360.0

# ---------------------------------------------------------------- Weather ---
ClearWeatherMinSeconds : float = 240.0
ClearWeatherMaxSeconds : float = 420.0
WeatherEventMinSeconds : float = 120.0
WeatherEventMaxSeconds : float = 180.0
MutationRollIntervalSeconds : float = 15.0
PrimordialMinIntervalSeconds : float = 3600.0

# ---------------------------------------------------------------- Friends ---
# Friend boost uses the supported party API (see FriendBonusService.verse).
FriendBoostEnabled : logic = true
FriendBoostPerMember : float = 0.10
FriendBoostMax : float = 0.50

# ---------------------------------------------------------------- UI --------
CreatureCardsPerPage : int = 8
TraderRowsPerPage : int = 6
TrackerRowsPerPage : int = 10
IndexCardsPerPage : int = 10
ToastSeconds : float = 3.5
AnnouncementSeconds : float = 5.0
# Hold the Reload input this long (seconds) to open the main menu on foot.
MenuHoldSeconds : float = 0.35

# ---------------------------------------------------------------- Intro -----
IntroCinematicSeconds : float = 10.0

# ================================================================ Colors ====
# Original UI theme: navy, cyan, turquoise, white, pearl, gold.
ThemeNavy : color = MakeColorFromHex("#0A1F3D")
ThemeNavyDark : color = MakeColorFromHex("#06142A")
ThemeNavyLight : color = MakeColorFromHex("#16345F")
ThemeCyan : color = MakeColorFromHex("#27E1FF")
ThemeTurquoise : color = MakeColorFromHex("#1FC8B4")
ThemeWhite : color = MakeColorFromHex("#FFFFFF")
ThemePearl : color = MakeColorFromHex("#F3EEE4")
ThemeGold : color = MakeColorFromHex("#FFC83D")
ThemeCash : color = MakeColorFromHex("#7CFF6B")
ThemeDanger : color = MakeColorFromHex("#FF4D5E")
ThemeWarning : color = MakeColorFromHex("#FF9F2E")
ThemeMuted : color = MakeColorFromHex("#8FA6C4")
ThemeNight : color = MakeColorFromHex("#8C7CFF")
ThemeSunset : color = MakeColorFromHex("#FF8A4C")

RarityColorCommon : color = MakeColorFromHex("#D9DEE6")
RarityColorRare : color = MakeColorFromHex("#3D8BFF")
RarityColorEpic : color = MakeColorFromHex("#A24DFF")
RarityColorLegendary : color = MakeColorFromHex("#FFC21A")
RarityColorMythic : color = MakeColorFromHex("#FF3D8B")
RarityColorDivine : color = MakeColorFromHex("#3DF2FF")
RarityColorEthereal : color = MakeColorFromHex("#FF7BF2")
# Second color used to fake gradients (Divine cyan/gold, Ethereal cosmic).
RarityAccentDivine : color = MakeColorFromHex("#FFD86B")
RarityAccentEthereal : color = MakeColorFromHex("#6B7BFF")

# ================================================================ Helpers ===
RarityCount : int = 7

RarityIndex(R:beast_rarity)<computes>:int =
    case (R):
        beast_rarity.Common => 0
        beast_rarity.Rare => 1
        beast_rarity.Epic => 2
        beast_rarity.Legendary => 3
        beast_rarity.Mythic => 4
        beast_rarity.Divine => 5
        beast_rarity.Ethereal => 6

RarityFromIndex(I:int)<computes>:beast_rarity =
    if (I <= 0):
        beast_rarity.Common
    else if (I = 1):
        beast_rarity.Rare
    else if (I = 2):
        beast_rarity.Epic
    else if (I = 3):
        beast_rarity.Legendary
    else if (I = 4):
        beast_rarity.Mythic
    else if (I = 5):
        beast_rarity.Divine
    else:
        beast_rarity.Ethereal

RarityName(R:beast_rarity)<computes>:string =
    case (R):
        beast_rarity.Common => "COMMON"
        beast_rarity.Rare => "RARE"
        beast_rarity.Epic => "EPIC"
        beast_rarity.Legendary => "LEGENDARY"
        beast_rarity.Mythic => "MYTHIC"
        beast_rarity.Divine => "DIVINE"
        beast_rarity.Ethereal => "ETHEREAL"

RarityColor(R:beast_rarity)<computes>:color =
    case (R):
        beast_rarity.Common => RarityColorCommon
        beast_rarity.Rare => RarityColorRare
        beast_rarity.Epic => RarityColorEpic
        beast_rarity.Legendary => RarityColorLegendary
        beast_rarity.Mythic => RarityColorMythic
        beast_rarity.Divine => RarityColorDivine
        beast_rarity.Ethereal => RarityColorEthereal

RarityAccent(R:beast_rarity)<computes>:color =
    case (R):
        beast_rarity.Divine => RarityAccentDivine
        beast_rarity.Ethereal => RarityAccentEthereal
        _ => RarityColor(R)

BiomeCount : int = 8

BiomeIndex(B:biome)<computes>:int =
    case (B):
        biome.CentralLagoon => 0
        biome.ShallowReef => 1
        biome.KelpForest => 2
        biome.TropicalAtoll => 3
        biome.FrozenSea => 4
        biome.VolcanicArchipelago => 5
        biome.TheAbyss => 6
        biome.CelestialSea => 7

BiomeName(B:biome)<computes>:string =
    case (B):
        biome.CentralLagoon => "CENTRAL LAGOON"
        biome.ShallowReef => "SHALLOW REEF"
        biome.KelpForest => "KELP FOREST"
        biome.TropicalAtoll => "TROPICAL ATOLL"
        biome.FrozenSea => "FROZEN SEA"
        biome.VolcanicArchipelago => "VOLCANIC ARCHIPELAGO"
        biome.TheAbyss => "THE ABYSS"
        biome.CelestialSea => "CELESTIAL SEA"

WeatherName(W:weather_kind)<computes>:string =
    case (W):
        weather_kind.Clear => "CLEAR SKIES"
        weather_kind.Thunderstorm => "THUNDERSTORM"
        weather_kind.Maelstrom => "MAELSTROM"
        weather_kind.BloodTide => "BLOOD TIDE"
        weather_kind.AbyssStorm => "ABYSS STORM"
        weather_kind.PrimordialStorm => "PRIMORDIAL STORM"

WeatherIndex(W:weather_kind)<computes>:int =
    case (W):
        weather_kind.Clear => 0
        weather_kind.Thunderstorm => 1
        weather_kind.Maelstrom => 2
        weather_kind.BloodTide => 3
        weather_kind.AbyssStorm => 4
        weather_kind.PrimordialStorm => 5

WeatherColor(W:weather_kind)<computes>:color =
    case (W):
        weather_kind.Clear => ThemeCyan
        weather_kind.Thunderstorm => RarityColorRare
        weather_kind.Maelstrom => RarityColorEpic
        weather_kind.BloodTide => ThemeDanger
        weather_kind.AbyssStorm => RarityAccentEthereal
        weather_kind.PrimordialStorm => ThemeGold

DayPhaseName(P:day_phase)<computes>:string =
    case (P):
        day_phase.Day => "DAY"
        day_phase.Sunset => "SUNSET"
        day_phase.Night => "NIGHT"

DayPhaseColor(P:day_phase)<computes>:color =
    case (P):
        day_phase.Day => ThemeGold
        day_phase.Sunset => ThemeSunset
        day_phase.Night => ThemeNight

AnalyticsKeyIndex(K:analytics_key)<computes>:int =
    case (K):
        analytics_key.TutorialStarted => 0
        analytics_key.TutorialComplete => 1
        analytics_key.FirstEggFound => 2
        analytics_key.FirstEggDelivered => 3
        analytics_key.FirstHatch => 4
        analytics_key.FirstRare => 5
        analytics_key.FirstEpic => 6
        analytics_key.FirstLegendary => 7
        analytics_key.FirstMythic => 8
        analytics_key.FirstDivine => 9
        analytics_key.FirstEthereal => 10
        analytics_key.FirstSonar => 11
        analytics_key.FirstLuckUpgrade => 12
        analytics_key.FirstMutation => 13
        analytics_key.FirstDeepDive => 14
        analytics_key.EggLost => 15
        analytics_key.EggSecured => 16
        analytics_key.CreatureSold => 17
        analytics_key.BiomeReached => 18

TutorialStepIndex(S:tutorial_step)<computes>:int =
    case (S):
        tutorial_step.Welcome => 0
        tutorial_step.ThisIsYourLagoon => 1
        tutorial_step.MountSeaSlug => 2
        tutorial_step.FindEgg => 3
        tutorial_step.BringItHome => 4
        tutorial_step.PlaceInIncubator => 5
        tutorial_step.HatchIt => 6
        tutorial_step.FasterBeasts => 7
        tutorial_step.Done => 8

TutorialStepFromIndex(I:int)<computes>:tutorial_step =
    if (I <= 0):
        tutorial_step.Welcome
    else if (I = 1):
        tutorial_step.ThisIsYourLagoon
    else if (I = 2):
        tutorial_step.MountSeaSlug
    else if (I = 3):
        tutorial_step.FindEgg
    else if (I = 4):
        tutorial_step.BringItHome
    else if (I = 5):
        tutorial_step.PlaceInIncubator
    else if (I = 6):
        tutorial_step.HatchIt
    else if (I = 7):
        tutorial_step.FasterBeasts
    else:
        tutorial_step.Done

# Small float helpers used across systems.
AbsF(X:float)<computes>:float = if (X < 0.0) then -X else X
ClampF(X:float, Lo:float, Hi:float)<computes>:float = if (X < Lo) then Lo else if (X > Hi) then Hi else X
MaxF(A:float, B:float)<computes>:float = if (A > B) then A else B
MinF(A:float, B:float)<computes>:float = if (A < B) then A else B
ToFloat(I:int)<computes>:float = I * 1.0

# Largest integer <= X, safe for NaN/Inf (returns Fallback).
FloorToInt(X:float, Fallback:int)<reads>:int =
    if (R := Floor[X]) then R else Fallback

RoundToInt(X:float, Fallback:int)<reads>:int =
    if (R := Round[X]) then R else Fallback

# Positive modulo for ints; returns 0 when Y is 0.
ModInt(X:int, Y:int)<computes>:int =
    if (R := Mod[X, Y]) then R else 0

QuotInt(X:int, Y:int)<computes>:int =
    if (R := Quotient[X, Y]) then R else 0

# Wraps an angle in degrees to [-180, 180).
WrapDegrees(Angle:float)<reads>:float =
    if (Turns := Floor[(Angle + 180.0) / 360.0]):
        Angle - 360.0 * ToFloat(Turns)
    else:
        0.0
