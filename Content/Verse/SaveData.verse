# ============================================================================
# RIDE A SEA BEAST - SaveData.verse
# Verse persistence schema + the mutable runtime profile it maps to.
#
# PERSISTENCE RULES (read before publishing - these are permanent):
#   * Persisted types are `class<final><persistable>` so fields can be ADDED
#     later with default values. Never rename, remove or change the type of a
#     field after the island is published.
#   * Only compact integer IDs are stored (creature type, mutation, trait,
#     egg type). Meshes, widgets, devices and actors are never persisted -
#     visuals are rebuilt from IDs after loading.
#   * DataVersion starts at 1. Bump CurrentDataVersion and extend
#     MigrateProfile when the meaning of existing data changes.
#   * All gameplay mutates the runtime `player_profile`; SaveManager.verse
#     converts it to a fresh `sea_beast_save` and writes it to the weak_map.
# ============================================================================
using { /Verse.org/Simulation }

CurrentDataVersion : int = 1

# ------------------------------------------------------------ Persisted ----

creature_save := class<final><persistable>:
    UniqueID : int = 0
    TypeID : int = 0
    Level : int = 1
    XP : int = 0
    MutationID : int = 0
    TraitID : int = 0
    Favorite : logic = false
    Locked : logic = false
    HatchedAt : float = 0.0

incubator_save := class<final><persistable>:
    EggTypeID : int = 0
    Progress : float = 0.0
    Required : float = 0.0
    LastUpdateEpoch : float = 0.0

sea_beast_save := class<final><persistable>:
    DataVersion : int = 0
    Cash : float = 0.0
    LifetimeCash : float = 0.0
    HatchLuckUpgrades : int = 0
    DeepDiveCount : int = 0
    PermanentMoneyMultiplier : float = 1.0
    BonusLagoonSlots : int = 0
    Creatures : []creature_save = array{}
    PlacedCreatureIDs : []int = array{}
    ActiveMountID : int = 0
    UniqueCreatureCounter : int = 0
    Incubators : []incubator_save = array{}
    FoodInventory : []int = array{}
    SonarInventory : []int = array{}
    SonarAutoBuy : []logic = array{}
    # Personal shop stock and when it was rolled (seconds since epoch), so
    # leaving and rejoining cannot re-roll the Sonar Shack.
    SonarStock : []int = array{}
    SonarStockEpoch : float = 0.0
    CreatureDiscovery : []int = array{}
    EggDiscovery : []logic = array{}
    MutationDiscovery : []logic = array{}
    ClaimedMilestones : []int = array{}
    MusicOn : logic = true
    SfxOn : logic = true
    CameraShakeOn : logic = true
    HatchCinematicOn : logic = true
    OtherPlayerEffectsOn : logic = true
    LowEffectsMode : logic = false
    ThrottleToggle : logic = false
    SettingsInitialized : logic = false
    TutorialStep : int = 0
    TutorialComplete : logic = false
    SeenIntro : logic = false
    SeenHatchCinematic : logic = false
    LastSeenEpoch : float = 0.0
    IncomeSnapshot : float = 0.0
    PendingOfflineReward : float = 0.0
    Cosmetics : []int = array{}
    EquippedTitle : int = 0
    FiredFirsts : []int = array{}
    TotalHatches : int = 0
    EggsDelivered : int = 0
    EggsLost : int = 0
    CreaturesSold : int = 0

# One persistent weak_map. Keyed by player, so Fortnite saves it per player.
var SeaBeastSaveMap : weak_map(player, sea_beast_save) = map{}

# ------------------------------------------------------------ Runtime ------

owned_creature := class:
    UniqueID : int
    TypeID : int
    var Level : int = 1
    var XP : int = 0
    var MutationID : int = 0
    TraitID : int = 0
    var Favorite : logic = false
    var Locked : logic = false
    HatchedAt : float = 0.0

incubator_state := class:
    var EggTypeID : int = 0
    var Progress : float = 0.0
    var Required : float = 0.0

    IsEmpty()<transacts><decides>:void = EggTypeID = 0
    IsReady()<transacts><decides>:void =
        EggTypeID > 0
        Progress >= Required

player_profile := class:
    var DataVersion : int = 1
    var Cash : float = 0.0
    var LifetimeCash : float = 0.0
    var HatchLuckUpgrades : int = 0
    var DeepDiveCount : int = 0
    var PermanentMoneyMultiplier : float = 1.0
    var BonusLagoonSlots : int = 0
    var Creatures : []owned_creature = array{}
    var PlacedCreatureIDs : []int = array{}
    var ActiveMountID : int = 0
    var UniqueCreatureCounter : int = 0
    var Incubators : []incubator_state = array{}
    var FoodInventory : []int = array{}
    var SonarInventory : []int = array{}
    # Per sonar tier: buy the shop's stock automatically on every restock.
    var SonarAutoBuy : []logic = array{}
    var SonarStock : []int = array{}
    var SonarStockEpoch : float = 0.0
    var CreatureDiscovery : []int = array{}
    var EggDiscovery : []logic = array{}
    var MutationDiscovery : []logic = array{}
    var ClaimedMilestones : []int = array{}
    var MusicOn : logic = true
    var SfxOn : logic = true
    var CameraShakeOn : logic = true
    var HatchCinematicOn : logic = true
    var OtherPlayerEffectsOn : logic = true
    var LowEffectsMode : logic = false
    var ThrottleToggle : logic = false
    var SettingsInitialized : logic = false
    var TutorialStep : int = 0
    var TutorialComplete : logic = false
    var SeenIntro : logic = false
    var SeenHatchCinematic : logic = false
    var LastSeenEpoch : float = 0.0
    var IncomeSnapshot : float = 0.0
    var PendingOfflineReward : float = 0.0
    var Cosmetics : []int = array{}
    var EquippedTitle : int = 0
    var FiredFirsts : []int = array{}
    var TotalHatches : int = 0
    var EggsDelivered : int = 0
    var EggsLost : int = 0
    var CreaturesSold : int = 0
    # True when this profile was created fresh this session (new player).
    var IsNewPlayer : logic = false

# ------------------------------------------------------------ Helpers ------

ResizeIntArray(Source:[]int, Length:int, Fill:int)<transacts>:[]int =
    for (I := 0..Length - 1):
        if (V := Source[I]) then V else Fill

ResizeLogicArray(Source:[]logic, Length:int, Fill:logic)<transacts>:[]logic =
    for (I := 0..Length - 1):
        if (V := Source[I]) then V else Fill

MakeOwnedCreature(S:creature_save)<transacts>:owned_creature =
    owned_creature:
        UniqueID := S.UniqueID
        TypeID := S.TypeID
        Level := S.Level
        XP := S.XP
        MutationID := S.MutationID
        TraitID := S.TraitID
        Favorite := S.Favorite
        Locked := S.Locked
        HatchedAt := S.HatchedAt

MakeCreatureSave(C:owned_creature)<transacts>:creature_save =
    creature_save:
        UniqueID := C.UniqueID
        TypeID := C.TypeID
        Level := C.Level
        XP := C.XP
        MutationID := C.MutationID
        TraitID := C.TraitID
        Favorite := C.Favorite
        Locked := C.Locked
        HatchedAt := C.HatchedAt

# Builds a runtime profile from persisted data, normalizing array sizes so
# newly added creatures/eggs/tiers always have a slot.
ProfileFromSave(S:sea_beast_save)<transacts>:player_profile =
    P := player_profile{}
    set P.DataVersion = S.DataVersion
    set P.Cash = S.Cash
    set P.LifetimeCash = S.LifetimeCash
    set P.HatchLuckUpgrades = Max(0, S.HatchLuckUpgrades)
    set P.DeepDiveCount = Clamp(S.DeepDiveCount, 0, MaxDeepDives)
    set P.PermanentMoneyMultiplier = S.PermanentMoneyMultiplier
    set P.BonusLagoonSlots = Max(0, S.BonusLagoonSlots)
    set P.Creatures = for (CS : S.Creatures, IsValidCreatureID[CS.TypeID]):
        MakeOwnedCreature(CS)
    set P.PlacedCreatureIDs = S.PlacedCreatureIDs
    set P.ActiveMountID = S.ActiveMountID
    set P.UniqueCreatureCounter = S.UniqueCreatureCounter
    set P.Incubators = for (I := 0..IncubatorsPerLagoon - 1):
        if (IS := S.Incubators[I], IsValidEggID[IS.EggTypeID]):
            incubator_state{EggTypeID := IS.EggTypeID, Progress := IS.Progress, Required := IS.Required}
        else:
            incubator_state{}
    set P.FoodInventory = ResizeIntArray(S.FoodInventory, FoodCount, 0)
    set P.SonarInventory = ResizeIntArray(S.SonarInventory, SonarTierCount, 0)
    set P.SonarAutoBuy = ResizeLogicArray(S.SonarAutoBuy, SonarTierCount, false)
    set P.SonarStock = S.SonarStock
    set P.SonarStockEpoch = S.SonarStockEpoch
    set P.CreatureDiscovery = ResizeIntArray(S.CreatureDiscovery, CreatureCount, -1)
    set P.EggDiscovery = ResizeLogicArray(S.EggDiscovery, EggCount, false)
    set P.MutationDiscovery = ResizeLogicArray(S.MutationDiscovery, MutationCount, false)
    set P.ClaimedMilestones = S.ClaimedMilestones
    set P.MusicOn = S.MusicOn
    set P.SfxOn = S.SfxOn
    set P.CameraShakeOn = S.CameraShakeOn
    set P.HatchCinematicOn = S.HatchCinematicOn
    set P.OtherPlayerEffectsOn = S.OtherPlayerEffectsOn
    set P.LowEffectsMode = S.LowEffectsMode
    set P.ThrottleToggle = S.ThrottleToggle
    set P.SettingsInitialized = S.SettingsInitialized
    set P.TutorialStep = S.TutorialStep
    set P.TutorialComplete = S.TutorialComplete
    set P.SeenIntro = S.SeenIntro
    set P.SeenHatchCinematic = S.SeenHatchCinematic
    set P.LastSeenEpoch = S.LastSeenEpoch
    set P.IncomeSnapshot = S.IncomeSnapshot
    set P.PendingOfflineReward = S.PendingOfflineReward
    set P.Cosmetics = S.Cosmetics
    set P.EquippedTitle = S.EquippedTitle
    set P.FiredFirsts = S.FiredFirsts
    set P.TotalHatches = S.TotalHatches
    set P.EggsDelivered = S.EggsDelivered
    set P.EggsLost = S.EggsLost
    set P.CreaturesSold = S.CreaturesSold
    P

# Captures the runtime profile into a fresh persistable object.
SaveFromProfile(P:player_profile, IncubatorEpoch:float)<transacts>:sea_beast_save =
    sea_beast_save:
        DataVersion := CurrentDataVersion
        Cash := P.Cash
        LifetimeCash := P.LifetimeCash
        HatchLuckUpgrades := P.HatchLuckUpgrades
        DeepDiveCount := P.DeepDiveCount
        PermanentMoneyMultiplier := P.PermanentMoneyMultiplier
        BonusLagoonSlots := P.BonusLagoonSlots
        Creatures := for (C : P.Creatures). MakeCreatureSave(C)
        PlacedCreatureIDs := P.PlacedCreatureIDs
        ActiveMountID := P.ActiveMountID
        UniqueCreatureCounter := P.UniqueCreatureCounter
        Incubators := for (Inc : P.Incubators):
            incubator_save{EggTypeID := Inc.EggTypeID, Progress := Inc.Progress, Required := Inc.Required, LastUpdateEpoch := IncubatorEpoch}
        FoodInventory := P.FoodInventory
        SonarInventory := P.SonarInventory
        SonarAutoBuy := P.SonarAutoBuy
        SonarStock := P.SonarStock
        SonarStockEpoch := P.SonarStockEpoch
        CreatureDiscovery := P.CreatureDiscovery
        EggDiscovery := P.EggDiscovery
        MutationDiscovery := P.MutationDiscovery
        ClaimedMilestones := P.ClaimedMilestones
        MusicOn := P.MusicOn
        SfxOn := P.SfxOn
        CameraShakeOn := P.CameraShakeOn
        HatchCinematicOn := P.HatchCinematicOn
        OtherPlayerEffectsOn := P.OtherPlayerEffectsOn
        LowEffectsMode := P.LowEffectsMode
        ThrottleToggle := P.ThrottleToggle
        SettingsInitialized := P.SettingsInitialized
        TutorialStep := P.TutorialStep
        TutorialComplete := P.TutorialComplete
        SeenIntro := P.SeenIntro
        SeenHatchCinematic := P.SeenHatchCinematic
        LastSeenEpoch := P.LastSeenEpoch
        IncomeSnapshot := P.IncomeSnapshot
        PendingOfflineReward := P.PendingOfflineReward
        Cosmetics := P.Cosmetics
        EquippedTitle := P.EquippedTitle
        FiredFirsts := P.FiredFirsts
        TotalHatches := P.TotalHatches
        EggsDelivered := P.EggsDelivered
        EggsLost := P.EggsLost
        CreaturesSold := P.CreaturesSold

# Schema migration hook. v1 is the first published schema, so today this only
# repairs derived values. Future versions add `if (P.DataVersion < N)` blocks.
MigrateProfile(P:player_profile)<transacts>:void =
    if (P.DataVersion < 1):
        # Pre-release / empty data: nothing to convert.
        set P.DataVersion = 1
    # Derived values are always recomputed from the source of truth.
    set P.PermanentMoneyMultiplier = PermanentMultiplierForDives(P.DeepDiveCount)
    # Hardening: new creatures must never reuse an existing unique ID, and a
    # creature is placed at most once.
    var HighestUID : int = 0
    for (C : P.Creatures, C.UniqueID > HighestUID):
        set HighestUID = C.UniqueID
    set P.UniqueCreatureCounter = Max(P.UniqueCreatureCounter, HighestUID)
    var UniquePlaced : []int = array{}
    for (UID : P.PlacedCreatureIDs, not UniquePlaced.Find[UID]):
        set UniquePlaced += array{UID}
    set P.PlacedCreatureIDs = UniquePlaced
    set P.DataVersion = CurrentDataVersion

# Creates the profile for a brand new player (starter Sea Slug is granted by
# CreatureManager so it gets a proper unique ID and Index discovery).
MakeNewProfile()<transacts>:player_profile =
    P := player_profile{}
    set P.DataVersion = CurrentDataVersion
    set P.Cash = StartingCash
    set P.PermanentMoneyMultiplier = 1.0
    set P.Incubators = for (I := 0..IncubatorsPerLagoon - 1). incubator_state{}
    set P.FoodInventory = ResizeIntArray(array{}, FoodCount, 0)
    set P.SonarInventory = ResizeIntArray(array{}, SonarTierCount, 0)
    set P.SonarAutoBuy = ResizeLogicArray(array{}, SonarTierCount, false)
    set P.CreatureDiscovery = ResizeIntArray(array{}, CreatureCount, -1)
    set P.EggDiscovery = ResizeLogicArray(array{}, EggCount, false)
    set P.MutationDiscovery = ResizeLogicArray(array{}, MutationCount, false)
    set P.IsNewPlayer = true
    P

# Persistence access ----------------------------------------------------------

ReadSavedProfile(Player:player)<transacts><decides>:sea_beast_save =
    SeaBeastSaveMap[Player]

WriteSavedProfile(Player:player, Profile:player_profile, Epoch:float)<transacts><decides>:void =
    NewSave := SaveFromProfile(Profile, Epoch)
    set SeaBeastSaveMap[Player] = NewSave

# Development only (DebugManager gates this behind non-Live sessions).
ClearSavedProfile(Player:player)<transacts><decides>:void =
    set SeaBeastSaveMap[Player] = sea_beast_save{}
