# ============================================================================
# RIDE A SEA BEAST - GameManager.verse
# The composition root. Place exactly ONE sea_beast_game_device in the level
# (at the center of the central island, at sea level) and fill in its lists
# in the Details panel - see docs/UEFN_SETUP_GUIDE.md.
#
# Architecture: all runtime state lives on this device. Each subsystem is a
# set of extension methods on sea_beast_game_device in its own file
# (EggManager.verse, EconomyManager.verse, ...). This keeps one authoritative
# server-side state with no duplicated data, while files stay focused.
# Every player action is validated here, never trusted from UI state.
# ============================================================================
using { /Fortnite.com/Devices }
using { /Fortnite.com/Characters }
using { /Fortnite.com/Playspaces }
using { /Verse.org/Simulation }
using { /UnrealEngine.com/Temporary/SpatialMath }

sea_beast_game_device := class(creative_device):
    # ------------------------------------------------------------ Lagoons ---
    # Exactly six Lagoons, arranged around the hub.
    @editable
    Lagoons : []lagoon_device = array{}
    # One mount rig per Lagoon, same order as Lagoons.
    @editable
    MountRigs : []mount_rig_setup = array{}
    @editable
    RiderAttachMode : rider_attach_mode = rider_attach_mode.Chair
    # Optional analog movement providers (see ExperimentalMoveInput.verse).
    @editable
    InputProviders : []mount_input_provider_device = array{}

    # ------------------------------------------------------------ World -----
    # Height of the open ocean surface (cm).
    @editable
    SeaLevelZ : float = 0.0
    # Where unused riding visuals are parked (must be inside the island).
    @editable
    ParkingLocation : vector3 = vector3{X := 0.0, Y := 0.0, Z := -30000.0}
    # All player spawners; players are moved to their own Lagoon on spawn.
    @editable
    PlayerSpawners : []player_spawner_device = array{}

    # ------------------------------------------------------------ Visuals ---
    @editable
    CreatureVisuals : []creature_visual_entry = array{}
    @editable
    EggVisuals : []egg_visual_entry = array{}
    @editable
    CarriedEggEffects : []carried_egg_effect_entry = array{}

    # ------------------------------------------------------------ Audio/FX --
    @editable
    Sounds : []sfx_entry = array{}
    @editable
    BiomeMusic : []biome_music_entry = array{}
    @editable
    VisualEffects : []vfx_entry = array{}
    @editable
    Analytics : []analytics_entry = array{}

    # ------------------------------------------------------------ Cycles ----
    @editable
    DayPhaseVisuals : []phase_visual_entry = array{}
    @editable
    WeatherVisuals : []weather_visual_entry = array{}

    # ------------------------------------------------------------ Cinematics
    # First-join flyover (8-12 s), played per player with Play(Agent).
    @editable
    IntroCinematic : []cinematic_sequence_device = array{}
    # Deep Dive underwater sequence with the leviathan silhouette.
    @editable
    DeepDiveCinematic : []cinematic_sequence_device = array{}
    # Blended in per player during the Deep Dive transition.
    @editable
    UnderwaterPostProcess : []post_process_device = array{}
    # Optional camera shakes: Cinematic Sequence devices that only contain a
    # camera shake, visible to the instigator. Played per player (big hatches,
    # Deep Dive, heavy breach landings) unless CAMERA SHAKE is turned off.
    @editable
    CameraShakeSmall : []cinematic_sequence_device = array{}
    @editable
    CameraShakeLarge : []cinematic_sequence_device = array{}

    # ------------------------------------------------------------ Developer -
    # Turn on while developing. Developer tools only ever open in Edit /
    # Private sessions, never Live, whatever this is set to.
    @editable
    DeveloperToolsEnabled : logic = false

    # ============================================================ Runtime ===
    var Sessions : [player]player_session = map{}
    var LagoonOwners : []?player = array{}
    var WorldEggs : []world_egg = array{}
    var NextEggUID : int = 1
    var TideEndTime : float = 0.0
    var CurrentWeather : weather_kind = weather_kind.Clear
    var WeatherEndTime : float = 0.0
    var LastPrimordialTime : float = -1000000.0
    var DayCycleStart : float = 0.0
    var CurrentPhase : day_phase = day_phase.Day
    var SonarRestockEnd : float = 0.0
    var GlobalSonarStock : []int = array{}
    # rig index -> player currently using it
    var RigUsers : []?player = array{}
    # creature ID - 1 -> which visual pool slots are in use
    var VisualSlotsInUse : [][]logic = array{}
    var SfxRoundRobin : []int = array{}
    var VfxRoundRobin : []int = array{}
    var Navigator : sea_navigator = sea_navigator{}
    var SpawnPoints : []egg_spawn_point_device = array{}
    var Stations : []menu_station_device = array{}
    var LastEggPointByType : []int = array{}
    var Started : logic = false
    ForceTideEvent : event() = event(){}
    ForceWeatherEvent : event(weather_kind) = event(weather_kind){}

    OnBegin<override>()<suspends>:void =
        LogSea("RIDE A SEA BEAST - starting")
        ValidateConfiguration()
        Self.InitLagoons()
        Self.InitMountRigs()
        Self.InitAudioVisual()
        Self.InitDayNight()
        # Let self-registering devices (spawn points, zones, stations) finish.
        Sleep(RegistrySettleSeconds)
        InitRegistryDevices()
        Self.InitSonarStock()
        Playspace := GetPlayspace()
        Playspace.PlayerAddedEvent().Subscribe(HandlePlayerAdded)
        Playspace.PlayerRemovedEvent().Subscribe(HandlePlayerRemoved)
        for (Spawner : PlayerSpawners):
            Spawner.SpawnedEvent.Subscribe(HandlePlayerSpawned)
        for (Player : Playspace.GetPlayers()):
            Self.OnPlayerAdded(Player)
        set Started = true
        spawn{ Self.RunTideLoop() }
        spawn{ Self.RunEconomyLoop() }
        spawn{ Self.RunIncubationLoop() }
        spawn{ Self.RunEggWatchLoop() }
        spawn{ Self.RunSonarLoop() }
        spawn{ Self.RunSonarRestockLoop() }
        spawn{ Self.RunWeatherLoop() }
        spawn{ Self.RunDayNightLoop() }
        spawn{ Self.RunAutosaveLoop() }
        spawn{ Self.RunHudLoop() }
        spawn{ Self.RunWorldWatchLoop() }
        LogSea("RIDE A SEA BEAST - running")

    OnEnd<override>():void =
        # Best-effort final save while players are still valid.
        for (Player -> Session : Sessions, Player.IsActive[]):
            Self.SaveSession(Session)

    # Event callbacks are class methods that forward to the subsystems'
    # extension methods (PlayerManager.verse).
    HandlePlayerAdded(Player:player):void = Self.OnPlayerAdded(Player)
    HandlePlayerRemoved(Player:player):void = Self.OnPlayerRemoved(Player)
    HandlePlayerSpawned(Agent:agent):void = Self.OnPlayerSpawned(Agent)

    # Reads self-registered level devices and binds them to this game.
    InitRegistryDevices():void =
        Registry := GetWorldRegistry()
        set SpawnPoints = Registry.SpawnPoints
        set Stations = Registry.Stations
        for (Point : SpawnPoints):
            Point.BindGame(Self)
        for (Station : Stations):
            Station.BindGame(Self)
        set Navigator = MakeNavigator(Registry.Zones, SeaLevelZ, GetTransform().Translation)
        set LastEggPointByType = for (I := 0..EggCount - 1). -1
        LogSea("Registry: {SpawnPoints.Length} egg spawn points, {Registry.Zones.Length} zones, {Stations.Length} stations")

    # Logs configuration problems early (missing lagoons, table mismatches).
    ValidateConfiguration():void =
        if (Lagoons.Length <> LagoonCount):
            LogSeaWarning("Expected {LagoonCount} Lagoons on the game device, found {Lagoons.Length}.")
        if (MountRigs.Length < Lagoons.Length):
            LogSeaWarning("Each Lagoon needs a mount rig: {MountRigs.Length} rigs for {Lagoons.Length} Lagoons.")
        for (I -> Lagoon : Lagoons, Lagoon.Incubators.Length < IncubatorsPerLagoon):
            LogSeaWarning("Lagoon {I + 1} has {Lagoon.Incubators.Length} incubators; {IncubatorsPerLagoon} are expected (extra saved eggs wait until a pad exists).")
        for (I -> Def : CreatureDefs, Def.ID <> I + 1):
            LogSeaWarning("CreatureDefs: entry {I} has ID {Def.ID}; IDs must equal index + 1.")
        for (I -> Def : EggDefs, Def.ID <> I + 1):
            LogSeaWarning("EggDefs: entry {I} has ID {Def.ID}; IDs must equal index + 1.")
        for (Entry : CreatureVisuals, not IsValidCreatureID[Entry.CreatureID]):
            LogSeaWarning("CreatureVisuals has invalid CreatureID {Entry.CreatureID}.")

    # ---------------------------------------------------------- Lookups -----
    GetCreatureVisual(CreatureID:int)<transacts><decides>:creature_visual_entry =
        var Found : ?creature_visual_entry = false
        for (Entry : CreatureVisuals, Entry.CreatureID = CreatureID, not Found?):
            set Found = option{Entry}
        Found?

    GetEggVisual(EggID:int)<transacts><decides>:egg_visual_entry =
        var Found : ?egg_visual_entry = false
        for (Entry : EggVisuals, Entry.EggID = EggID, not Found?):
            set Found = option{Entry}
        Found?

    # Display prop asset for a creature, if the designer assigned one.
    GetCreatureDisplayAsset(CreatureID:int)<transacts><decides>:creative_prop_asset =
        Entry := GetCreatureVisual[CreatureID]
        Entry.HasDisplayProp?
        Entry.DisplayProp

    GetEggPropAsset(EggID:int)<transacts><decides>:creative_prop_asset =
        Entry := GetEggVisual[EggID]
        Entry.HasEggProp?
        Entry.EggProp

    # Visual scale for a creature (size class default x designer multiplier).
    GetCreatureVisualScale(CreatureID:int)<transacts>:float =
        SizeScale := if (Def := GetCreatureDef[CreatureID]) then SizeClassVisualScale(Def.SizeClass) else 1.0
        Multiplier := if (Entry := GetCreatureVisual[CreatureID]) then Entry.DisplayScale else 1.0
        SizeScale * Multiplier

    GetNow()<transacts>:float = GetSimulationElapsedTime()
