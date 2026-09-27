# ============================================================================
# RIDE A SEA BEAST - EggSpawnPoint.verse
# Place many of these around each biome and name them in the Outliner, e.g.
#   Reef_Common_01, Kelp_Rare_03, Frozen_Legendary_02, Abyss_Ethereal_01.
# Every Tide Reset, EggManager picks random eligible points per egg type, so
# an egg never has a single predictable location.
#
# Egg visuals, in order of preference:
#   1. PlacedEggProps: pre-placed hidden props for specific egg IDs at this
#      point (no runtime spawning, no spawn-limit cost). Best for common eggs.
#   2. Otherwise the egg type's prop asset from the game device's Egg Visuals
#      list is spawned BY THIS DEVICE'S OWN TASK, which spreads SpawnProp
#      usage across devices (Fortnite limits spawned props per script device
#      and per island).
# Optional PickupButton gives on-foot players a "TAKE SEA EGG" interaction.
# Riders claim eggs by proximity (see EggManager.verse).
# ============================================================================
using { /Fortnite.com/Devices }
using { /Fortnite.com/Devices/CreativeAnimation }
using { /Fortnite.com/Devices/CreativeAnimation/InterpolationTypes }
using { /Verse.org/Simulation }
using { /Verse.org/Random }
using { /UnrealEngine.com/Temporary/SpatialMath }

placed_egg_prop := class<concrete>:
    @editable
    EggID : int = 1
    @editable
    Prop : creative_prop = creative_prop{}

egg_spawn_point_device := class(creative_device):
    @editable
    Biome : biome = biome.ShallowReef
    # Rarity tiers this point accepts (ignored when AllowedEggIDs is set).
    @editable
    AcceptedTiers : []beast_rarity = array{beast_rarity.Common}
    # Optional explicit whitelist of egg IDs (see EggConfig.verse).
    @editable
    AllowedEggIDs : []int = array{}
    @editable
    PlacedEggProps : []placed_egg_prop = array{}
    @editable
    PickupButton : []button_device = array{}
    # Height of the egg above this device (cm).
    @editable
    HeightOffset : float = 60.0
    # Relative chance of being chosen among eligible points.
    @editable
    SelectionWeight : float = 1.0
    # Set on points next to a Lagoon that are used for tutorial eggs only.
    @editable
    TutorialOnly : logic = false

    var Game : ?sea_beast_game_device = false
    var ActiveEggUID : int = 0
    var ActiveEggID : int = 0
    var SpawnedProp : ?creative_prop = false
    var ShownPlacedProp : ?creative_prop = false
    var PendingAsset : ?creative_prop_asset = false
    var PendingUID : int = 0
    SpawnSignal : event() = event(){}

    OnBegin<override>()<suspends>:void =
        for (Entry : PlacedEggProps):
            Entry.Prop.Hide()
        for (Button : PickupButton):
            Button.SetInteractionText(TakeEggPrompt)
            Button.Disable()
            Button.InteractedWithEvent.Subscribe(OnPickupPressed)
        GetWorldRegistry().RegisterSpawnPoint(Self)
        # This device's own task performs its SpawnProp calls.
        loop:
            SpawnSignal.Await()
            ProcessPendingSpawn()

    BindGame(G:sea_beast_game_device):void =
        set Game = option{G}

    OnPickupPressed(Agent:agent):void =
        if (G := Game?):
            G.OnEggPointInteracted(Self, Agent)

    IsOccupied()<transacts><decides>:void = ActiveEggUID > 0

    GetEggPosition()<transacts>:vector3 =
        T := GetTransform()
        vector3{X := T.Translation.X, Y := T.Translation.Y, Z := T.Translation.Z + HeightOffset}

    # Succeeds when this point may host the egg definition.
    AcceptsEgg(Def:egg_def)<transacts><decides>:void =
        (AllowedEggIDs.Length > 0 and AllowedEggIDs.Find[Def.ID] >= 0) or (AllowedEggIDs.Length = 0 and EggAllowsBiome[Def, Biome] and AcceptedTiers.Find[Def.Rarity] >= 0)

    FindPlacedProp(EggID:int)<transacts><decides>:creative_prop =
        var Found : ?creative_prop = false
        for (Entry : PlacedEggProps, Entry.EggID = EggID, not Found?):
            set Found = option{Entry.Prop}
        Found?

    # Shows egg UID of type EggID here. Asset is used only when no placed prop
    # exists for this egg type.
    ShowEgg(UID:int, EggID:int, Asset:?creative_prop_asset):void =
        ClearVisuals()
        set ActiveEggUID = UID
        set ActiveEggID = EggID
        if (Placed := FindPlacedProp[EggID]):
            Placed.Show()
            set ShownPlacedProp = option{Placed}
            StartBob(Placed)
        else if (A := Asset?):
            set PendingAsset = option{A}
            set PendingUID = UID
            SpawnSignal.Signal()
        for (Button : PickupButton):
            Button.Enable()

    # Removes the egg UID if it is still the one shown here.
    HideEgg(UID:int):void =
        if (ActiveEggUID = UID):
            ClearVisuals()
            set ActiveEggUID = 0
            set ActiveEggID = 0
            for (Button : PickupButton):
                Button.Disable()

    ClearVisuals():void =
        if (Placed := ShownPlacedProp?):
            if (Controller := Placed.GetAnimationController[]):
                Controller.Stop()
            Placed.Hide()
        set ShownPlacedProp = false
        if (Spawned := SpawnedProp?):
            if (Spawned.IsValid[]):
                Spawned.Dispose()
        set SpawnedProp = false
        set PendingAsset = false
        set PendingUID = 0

    ProcessPendingSpawn():void =
        if (A := PendingAsset?, PendingUID > 0, PendingUID = ActiveEggUID):
            Position := GetEggPosition()
            Rotation := MakeRotationFromYawPitchRollDegrees(GetRandomYaw(), 0.0, 0.0)
            Result := SpawnProp(A, Position, Rotation)
            if (Spawned := Result(0)?):
                set SpawnedProp = option{Spawned}
                StartBob(Spawned)
            else:
                # Usually the spawned-prop limit: the egg stays claimable but
                # invisible. Use PlacedEggProps for common eggs (PERFORMANCE.md).
                LogSeaWarning("Egg spawn point could not spawn the egg prop for egg {ActiveEggID} (spawned-prop limit?).")
            set PendingAsset = false

    GetRandomYaw()<transacts>:float = GetRandomFloat(0.0, 360.0)

    # Gentle native bob + sway; runs on the prop without a Verse loop.
    StartBob(Prop:creative_prop):void =
        if (Controller := Prop.GetAnimationController[]):
            Up := keyframe_delta:
                DeltaLocation := vector3{X := 0.0, Y := 0.0, Z := 25.0}
                DeltaRotation := MakeRotationFromYawPitchRollDegrees(18.0, 0.0, 0.0)
                DeltaScale := vector3{X := 1.0, Y := 1.0, Z := 1.0}
                Time := 1.1
                Interpolation := EaseInOut
            Down := keyframe_delta:
                DeltaLocation := vector3{X := 0.0, Y := 0.0, Z := -25.0}
                DeltaRotation := MakeRotationFromYawPitchRollDegrees(-18.0, 0.0, 0.0)
                DeltaScale := vector3{X := 1.0, Y := 1.0, Z := 1.0}
                Time := 1.1
                Interpolation := EaseInOut
            Controller.SetAnimation(array{Up, Down}, ?Mode := animation_mode.Loop)
            Controller.Play()
