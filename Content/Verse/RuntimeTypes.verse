# ============================================================================
# RIDE A SEA BEAST - RuntimeTypes.verse
# Per-session runtime state. Nothing in this file is persisted; persistent
# data lives in SaveData.verse (player_profile / sea_beast_save).
# ============================================================================
using { /Fortnite.com/Devices }
using { /Verse.org/Simulation }
using { /UnrealEngine.com/Temporary/SpatialMath }
using { /UnrealEngine.com/Temporary/Diagnostics }

sea_beast_log := class(log_channel){}

# Project-wide logging usable from <transacts> code.
LogSea(Message:string)<transacts>:void =
    Logger := log{Channel := sea_beast_log}
    Logger.Print(Message)

LogSeaWarning(Message:string)<transacts>:void =
    Logger := log{Channel := sea_beast_log}
    Logger.Print(Message, ?Level := log_level.Warning)

# An egg currently placed in the world, shared by every player on the server.
world_egg := class:
    UID : int
    EggTypeID : int
    # Index into WorldRegistry.SpawnPoints, or -1 for a Lagoon tutorial egg.
    SpawnIndex : int
    Position : vector3
    SpawnTime : float
    # Tutorial eggs can only be claimed by the new player they were made for.
    ReservedFor : ?player = false
    TutorialLagoon : int = -1
    var Active : logic = true
    var ClaimedBy : ?player = false
    var TutorialProp : ?creative_prop = false

# An egg being carried home. It cracks at ExpireTime unless secured.
carried_egg := class:
    UID : int
    EggTypeID : int
    ClaimTime : float
    ExpireTime : float
    IsTutorial : logic = false

# Mount / locomotion state for one player.
mount_runtime := class:
    var State : mount_state = mount_state.Dismounted
    var CreatureUID : int = 0
    var TypeID : int = 0
    var RigIndex : int = -1
    # Pool slot inside the creature's visual lists (-1 = using fallback prop).
    var VisualSlot : int = -1
    # 0 swim, 1 idle, 2 fast.
    var VisualVariant : int = 0
    var FallbackProp : ?creative_prop = false
    var PlatformProp : ?creative_prop = false
    # Simulated root position (cm) and heading (degrees).
    var PosX : float = 0.0
    var PosY : float = 0.0
    var PosZ : float = 0.0
    var Yaw : float = 0.0
    var YawRate : float = 0.0
    # Signed forward speed (cm/s) and vertical speed (cm/s).
    var Speed : float = 0.0
    var VerticalSpeed : float = 0.0
    var Mode : swim_mode = swim_mode.Surface
    var Bank : float = 0.0
    var Pitch : float = 0.0
    # Cached stats for the ridden creature.
    var MaxSpeed : float = 650.0
    var TurnRate : float = 200.0
    var BreachVelocity : float = 800.0
    var Radius : float = 100.0
    var SaddleHeight : float = 80.0
    var SaddleForward : float = 0.0
    var VisualScale : float = 1.0
    var SizeClass : int = 0
    var WakeOn : logic = false
    var LastSurfaceZ : float = 0.0
    var LastBiomeCheck : float = 0.0
    # Increments on every mount/dismount so stale loops exit.
    var Generation : int = 0

# Everything the server tracks for a connected player.
player_session := class:
    Player : player
    UI : player_ui_controller
    var Profile : player_profile = player_profile{}
    var LagoonIndex : int = -1
    var Loaded : logic = false
    var JoinTime : float = 0.0
    var LastSaveTime : float = 0.0
    var Carried : []carried_egg = array{}
    Mount : mount_runtime = mount_runtime{}
    # ---- Input state (updated by MountInput.verse) ----
    var FireHeld : logic = false
    var AimHeld : logic = false
    var CrouchHeld : logic = false
    var BoostOn : logic = false
    var CruiseOn : logic = false
    var ReloadDownTime : float = -1.0
    var AnalogActive : logic = false
    var AnalogForward : float = 0.0
    var AnalogRight : float = 0.0
    var AnalogLastTime : float = -100.0
    var InputRegistered : logic = false
    var IsTouch : logic = false
    # ---- Sonar ----
    var SonarStock : []int = array{}
    var ActiveSonarTier : int = -1
    var SonarTargetUID : int = 0
    var SonarStartTime : float = 0.0
    var NextPingTime : float = 0.0
    var SonarSearching : logic = false
    # ---- Tutorial ----
    var TutorialEggUID : int = 0
    var TutorialTaskRunning : logic = false
    # ---- Busy flags ----
    var HatchingIncubator : int = -1
    var DeepDiveRunning : logic = false
    var IntroRunning : logic = false
    # ---- World ----
    var CurrentBiome : biome = biome.CentralLagoon
    var VisitedBiomes : []logic = array{}
    var MusicBiomeIndex : int = -1
    var LastIncomePerSecond : float = 0.0
    var FriendBoost : float = 0.0
    # ---- Pending confirmation (sell required creature, etc.) ----
    var PendingSellUID : int = 0
    # ---- Carried egg VFX currently shown (rarity index, -1 none) ----
    var CarryEffectRarity : int = -1

# Result of a hatch roll.
hatch_result := struct:
    CreatureTypeID : int = 1
    TraitID : int = 0
    IsNewDiscovery : logic = false
    CreatureUID : int = 0
