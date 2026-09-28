# ============================================================================
# RIDE A SEA BEAST - LagoonDevice.verse
# One per Lagoon (exactly six, around the central island). Place the device
# at the center of the Lagoon's pool at water level; all offsets are relative
# to it and rotate with it, so a Lagoon can be built once and duplicated.
#
# This device is the Lagoon's VIEW: signs, buttons, incubator pads, cameras,
# creature displays and effects. Ownership rules and all validation live in
# LagoonManager.verse / IncubatorManager.verse on the game device.
# The Lagoon also performs its own SpawnProp calls (creature displays,
# incubator eggs, hatch reveals) from its own task to spread spawn usage.
# ============================================================================
using { /Fortnite.com/Devices }
using { /Fortnite.com/Devices/CreativeAnimation }
using { /Fortnite.com/Devices/CreativeAnimation/InterpolationTypes }
using { /Verse.org/Simulation }
using { /Verse.org/Random }
using { /UnrealEngine.com/Temporary/SpatialMath }

incubator_setup := class<concrete>:
    @editable
    Button : button_device = button_device{}
    @editable
    TimerSign : billboard_device = billboard_device{}
    @editable
    ReadyEffect : []vfx_spawner_device = array{}
    # Egg prop position relative to the button (world axes, cm).
    @editable
    EggOffset : vector3 = vector3{X := 0.0, Y := 0.0, Z := 90.0}

mutation_aura_pool := class<concrete>:
    @editable
    MutationID : int = 1
    @editable
    Effects : []vfx_spawner_device = array{}

# One creature to display swimming in the Lagoon pool.
lagoon_display_request := struct:
    CreatureUID : int = 0
    TypeID : int = 0
    MutationID : int = 0
    Asset : creative_prop_asset = DefaultCreativePropAsset
    Scale : float = 1.0
    SizeClass : int = 0

prop_spawn_job := class:
    Asset : creative_prop_asset
    SpawnTransform : transform
    var Result : ?creative_prop = false
    var Done : logic = false
    Finished : event() = event(){}

incubator_button_handler := class:
    Lagoon : lagoon_device
    Index : int
    OnPressed(Agent:agent):void = Lagoon.OnIncubatorPressed(Index, Agent)

EmptyPropSlot()<computes>:?creative_prop = false

lagoon_device := class(creative_device):
    @editable
    NameSign : billboard_device = billboard_device{}
    @editable
    IncomeSign : billboard_device = billboard_device{}
    @editable
    HatchLuckSign : billboard_device = billboard_device{}
    @editable
    DeepDiveSign : billboard_device = billboard_device{}
    @editable
    HatchLuckButton : button_device = button_device{}
    @editable
    HatchLuckMaxButton : button_device = button_device{}
    @editable
    PlaceBestButton : button_device = button_device{}
    @editable
    ManageButton : button_device = button_device{}
    @editable
    DeepDiveButton : button_device = button_device{}
    @editable
    RideButton : button_device = button_device{}
    @editable
    Incubators : []incubator_setup = array{}
    @editable
    HatchCamera : []gameplay_camera_fixed_point_device = array{}
    @editable
    DeepDiveCamera : []gameplay_camera_fixed_point_device = array{}
    @editable
    DeepDiveWave : []vfx_spawner_device = array{}
    @editable
    MutationAuras : []mutation_aura_pool = array{}
    # Where the owner spawns / is returned to (relative to this device).
    @editable
    SpawnOffset : vector3 = vector3{X := -1800.0, Y := 0.0, Z := 150.0}
    # Where the owner's Sea Beast is summoned at the dock (relative).
    @editable
    MountOffset : vector3 = vector3{X := -1200.0, Y := 0.0, Z := 0.0}
    # Where the new player's tutorial Pearl Egg appears (relative).
    @editable
    TutorialEggOffset : vector3 = vector3{X := 2600.0, Y := 900.0, Z := 60.0}
    # Placed creatures swim on a ring of this radius (cm) around the center.
    @editable
    CreatureRingRadius : float = 1300.0
    @editable
    CreatureDepth : float = -30.0
    # Radius of the Lagoon area (delivery zone / private interactions).
    @editable
    AreaRadius : float = 2600.0

    var Game : ?sea_beast_game_device = false
    var LagoonIndex : int = -1
    var PropJobs : []prop_spawn_job = array{}
    JobSignal : event() = event(){}
    var DisplayProps : []creative_prop = array{}
    var ActiveAuraKeys : []int = array{}
    var IncubatorProps : []?creative_prop = array{}
    # Per incubator: bumped on every show/hide so a slow spawn that finishes
    # after the slot changed is discarded instead of leaking a prop.
    var IncubatorGenerations : []int = array{}
    var DisplayGeneration : int = 0

    OnBegin<override>()<suspends>:void =
        set IncubatorProps = for (I := 0..Incubators.Length - 1). EmptyPropSlot()
        set IncubatorGenerations = for (I := 0..Incubators.Length - 1). 0
        for (I -> Setup : Incubators):
            Handler := incubator_button_handler{Lagoon := Self, Index := I}
            Setup.Button.InteractedWithEvent.Subscribe(Handler.OnPressed)
            for (Effect : Setup.ReadyEffect):
                Effect.Disable()
        for (Pool : MutationAuras, Effect : Pool.Effects):
            Effect.Disable()
        HatchLuckButton.InteractedWithEvent.Subscribe(OnHatchLuckPressed)
        HatchLuckMaxButton.InteractedWithEvent.Subscribe(OnHatchLuckMaxPressed)
        PlaceBestButton.InteractedWithEvent.Subscribe(OnPlaceBestPressed)
        ManageButton.InteractedWithEvent.Subscribe(OnManagePressed)
        DeepDiveButton.InteractedWithEvent.Subscribe(OnDeepDivePressed)
        RideButton.InteractedWithEvent.Subscribe(OnRidePressed)
        PlaceBestButton.SetInteractionText(PlaceBestPrompt)
        ManageButton.SetInteractionText(ManageBeastsPrompt)
        DeepDiveButton.SetInteractionText(DeepDivePrompt)
        RideButton.SetInteractionText(RideDockPrompt)
        HatchLuckMaxButton.SetInteractionText(UpgradeMaxPrompt)
        # This Lagoon's own task performs its SpawnProp calls.
        loop:
            if (PropJobs.Length = 0):
                JobSignal.Await()
            Jobs := PropJobs
            set PropJobs = array{}
            for (Job : Jobs):
                Result := SpawnProp(Job.Asset, Job.SpawnTransform)
                set Job.Result = Result(0)
                set Job.Done = true
                Job.Finished.Signal()

    BindGame(G:sea_beast_game_device, Index:int):void =
        set Game = option{G}
        set LagoonIndex = Index

    # ---------------------------------------------------------- Forwarding ---
    OnIncubatorPressed(Index:int, Agent:agent):void =
        if (G := Game?):
            G.OnIncubatorInteracted(LagoonIndex, Index, Agent)

    OnHatchLuckPressed(Agent:agent):void =
        if (G := Game?):
            G.OnHatchLuckButton(LagoonIndex, Agent, false)

    OnHatchLuckMaxPressed(Agent:agent):void =
        if (G := Game?):
            G.OnHatchLuckButton(LagoonIndex, Agent, true)

    OnPlaceBestPressed(Agent:agent):void =
        if (G := Game?):
            G.OnPlaceBestButton(LagoonIndex, Agent)

    OnManagePressed(Agent:agent):void =
        if (G := Game?):
            G.OnManageButton(LagoonIndex, Agent)

    OnDeepDivePressed(Agent:agent):void =
        if (G := Game?):
            G.OnDeepDiveButton(LagoonIndex, Agent)

    OnRidePressed(Agent:agent):void =
        if (G := Game?):
            G.OnRideDockButton(LagoonIndex, Agent)

    # ---------------------------------------------------------- Geometry -----
    GetCenter()<transacts>:vector3 = GetTransform().Translation

    LocalToWorld(Offset:vector3)<transacts>:vector3 =
        T := GetTransform()
        T.Translation + T.Rotation.RotateVector(Offset)

    GetYawDegrees()<transacts>:float =
        Angles := GetTransform().Rotation.GetYawPitchRollDegrees()
        if (Yaw := Angles[0]) then Yaw else 0.0

    GetSpawnPosition()<transacts>:vector3 = LocalToWorld(SpawnOffset)
    GetMountPosition()<transacts>:vector3 = LocalToWorld(MountOffset)
    GetTutorialEggPosition()<transacts>:vector3 = LocalToWorld(TutorialEggOffset)

    IsInsideArea(Position:vector3)<transacts><decides>:void =
        DistanceXY(Position, GetCenter()) <= AreaRadius

    # ---------------------------------------------------------- Signs --------
    SetOwnerSign(Owner:?agent, Title:string):void =
        if (O := Owner?):
            if (Title <> ""):
                NameSign.SetText(LagoonTitleWithCosmeticMessage(O, Title))
            else:
                NameSign.SetText(LagoonTitleMessage(O))
        else:
            NameSign.SetText(AvailableLagoonMessage)
            IncomeSign.SetText(EmptyMessage)
            HatchLuckSign.SetText(EmptyMessage)
            DeepDiveSign.SetText(EmptyMessage)

    SetIncomeText(Text:string):void = IncomeSign.SetText(ToMessage(Text))
    SetHatchLuckText(Text:string):void = HatchLuckSign.SetText(ToMessage(Text))
    SetDeepDiveText(Text:string):void = DeepDiveSign.SetText(ToMessage(Text))
    SetHatchLuckCostText(Cost:string):void = HatchLuckButton.SetInteractionText(UpgradePrompt(Cost))
    SetHatchLuckMaxText(Text:string):void = HatchLuckMaxButton.SetInteractionText(ToMessage("BUY {Text}"))

    SetIncubatorPrompt(Index:int, Prompt:message):void =
        if (Setup := Incubators[Index]):
            Setup.Button.SetInteractionText(Prompt)

    SetIncubatorTimer(Index:int, Text:string):void =
        if (Setup := Incubators[Index]):
            Setup.TimerSign.SetText(ToMessage(Text))

    # ---------------------------------------------------------- Spawning -----
    SpawnPropAsync(Asset:creative_prop_asset, SpawnAt:transform)<suspends>:?creative_prop =
        Job := prop_spawn_job{Asset := Asset, SpawnTransform := SpawnAt}
        set PropJobs += array{Job}
        JobSignal.Signal()
        if (not Job.Done?):
            Job.Finished.Await()
        Job.Result

    # ---------------------------------------------------------- Displays -----
    # Replaces the swimming creature displays. Uses a generation counter so a
    # newer request cancels an older one that is still spawning.
    ShowCreatures(Requests:[]lagoon_display_request)<suspends>:void =
        set DisplayGeneration += 1
        MyGeneration := DisplayGeneration
        ClearCreatureDisplays()
        Count := Max(1, Requests.Length)
        var I : int = 0
        loop:
            if (I >= Requests.Length or MyGeneration <> DisplayGeneration):
                break
            if (Req := Requests[I]):
                Angle := 2.0 * PiFloat * ToFloat(I) / ToFloat(Count)
                SwimRadius := 150.0 + 70.0 * ToFloat(Req.SizeClass)
                Ring := vector3{X := CreatureRingRadius * Cos(Angle), Y := CreatureRingRadius * Sin(Angle), Z := CreatureDepth}
                Anchor := LocalToWorld(Ring)
                StartPos := Anchor + vector3{X := SwimRadius, Y := 0.0, Z := 0.0}
                StartRot := MakeRotationFromYawPitchRollDegrees(90.0, 0.0, 0.0)
                SpawnAt := transform{Translation := StartPos, Rotation := StartRot, Scale := vector3{X := Req.Scale, Y := Req.Scale, Z := Req.Scale}}
                MaybeProp := SpawnPropAsync(Req.Asset, SpawnAt)
                if (Prop := MaybeProp?):
                    if (MyGeneration = DisplayGeneration):
                        set DisplayProps += array{Prop}
                        StartSwimLoop(Prop, SwimRadius, Req.SizeClass)
                        AttachAura(Req.MutationID, Anchor)
                    else:
                        Prop.Dispose()
            set I += 1

    ClearCreatureDisplays():void =
        for (Prop : DisplayProps, Prop.IsValid[]):
            Prop.Dispose()
        set DisplayProps = array{}
        for (Key : ActiveAuraKeys, Effect := GetAuraEffect[Key]):
            Effect.Disable()
        set ActiveAuraKeys = array{}

    # Native looping swim path (octagon around the anchor). No Verse loop.
    StartSwimLoop(Prop:creative_prop, SwimRadius:float, SizeClass:int):void =
        if (Controller := Prop.GetAnimationController[]):
            SegmentTime := 0.55 + 0.12 * ToFloat(SizeClass) + GetRandomFloat(0.0, 0.15)
            Keys := for (K := 0..7):
                A0 := ToFloat(K) * PiFloat / 4.0
                A1 := ToFloat(K + 1) * PiFloat / 4.0
                Bob := if (ModInt(K, 2) = 0) then 12.0 else -12.0
                keyframe_delta:
                    DeltaLocation := vector3{X := SwimRadius * (Cos(A1) - Cos(A0)), Y := SwimRadius * (Sin(A1) - Sin(A0)), Z := Bob}
                    DeltaRotation := MakeRotationFromYawPitchRollDegrees(45.0, 0.0, 0.0)
                    DeltaScale := vector3{X := 1.0, Y := 1.0, Z := 1.0}
                    Time := SegmentTime
                    Interpolation := Linear
            Controller.SetAnimation(Keys, ?Mode := animation_mode.Loop)
            Controller.Play()

    # Aura effects are identified by key PoolIndex * 1000 + EffectIndex because
    # devices are not comparable in Verse.
    AttachAura(MutationID:int, Anchor:vector3):void =
        if (MutationID > 0):
            var Placed : logic = false
            for (PoolIndex -> Pool : MutationAuras, Pool.MutationID = MutationID, EffectIndex -> Effect : Pool.Effects, not Placed?):
                Key := PoolIndex * 1000 + EffectIndex
                if (not ActiveAuraKeys.Find[Key]):
                    if (Effect.TeleportTo[Anchor, IdentityRotation()]) {}
                    Effect.Enable()
                    set ActiveAuraKeys += array{Key}
                    set Placed = true

    GetAuraEffect(Key:int)<transacts><decides>:vfx_spawner_device =
        Pool := MutationAuras[QuotInt(Key, 1000)]
        Pool.Effects[ModInt(Key, 1000)]

    # ---------------------------------------------------------- Incubators ---
    IncubatorEggTransform(Index:int)<transacts>:transform =
        if (Setup := Incubators[Index]):
            Base := Setup.Button.GetTransform().Translation
            transform{Translation := Base + Setup.EggOffset, Rotation := IdentityRotation(), Scale := vector3{X := 1.0, Y := 1.0, Z := 1.0}}
        else:
            transform{Translation := GetCenter(), Rotation := IdentityRotation(), Scale := vector3{X := 1.0, Y := 1.0, Z := 1.0}}

    GetIncubatorGeneration(Index:int)<transacts>:int =
        if (Current := IncubatorGenerations[Index]) then Current else 0

    BumpIncubatorGeneration(Index:int)<transacts>:void =
        if (set IncubatorGenerations[Index] = GetIncubatorGeneration(Index) + 1) {}

    ShowIncubatorEgg(Index:int, Asset:creative_prop_asset, Ready:logic)<suspends>:void =
        HideIncubatorEgg(Index)
        MyGeneration := GetIncubatorGeneration(Index)
        if (Index >= 0, Index < Incubators.Length):
            MaybeProp := SpawnPropAsync(Asset, IncubatorEggTransform(Index))
            if (Prop := MaybeProp?):
                if (GetIncubatorGeneration(Index) = MyGeneration, set IncubatorProps[Index] = option{Prop}):
                    StartIncubatorWobble(Prop, 3.0)
                    if (Ready?):
                        SetIncubatorReady(Index, true)
                else:
                    # The slot was hidden or refilled while this was spawning.
                    Prop.Dispose()

    HideIncubatorEgg(Index:int):void =
        BumpIncubatorGeneration(Index)
        if (Existing := IncubatorProps[Index]?):
            if (Existing.IsValid[]):
                Existing.Dispose()
        if (set IncubatorProps[Index] = EmptyPropSlot()) {}
        SetIncubatorReady(Index, false)

    SetIncubatorReady(Index:int, Ready:logic):void =
        if (Setup := Incubators[Index]):
            for (Effect : Setup.ReadyEffect):
                if (Ready?):
                    Effect.Enable()
                else:
                    Effect.Disable()
        if (Ready?, Existing := IncubatorProps[Index]?):
            StartIncubatorWobble(Existing, 12.0)

    # Wobble amplitude in degrees; larger when the egg is ready to hatch.
    StartIncubatorWobble(Prop:creative_prop, Degrees:float):void =
        if (Controller := Prop.GetAnimationController[]):
            Left := keyframe_delta:
                DeltaLocation := vector3{X := 0.0, Y := 0.0, Z := 0.0}
                DeltaRotation := MakeRotationFromYawPitchRollDegrees(0.0, 0.0, Degrees)
                DeltaScale := vector3{X := 1.0, Y := 1.0, Z := 1.0}
                Time := 0.6
                Interpolation := EaseInOut
            Right := keyframe_delta:
                DeltaLocation := vector3{X := 0.0, Y := 0.0, Z := 0.0}
                DeltaRotation := MakeRotationFromYawPitchRollDegrees(0.0, 0.0, -Degrees)
                DeltaScale := vector3{X := 1.0, Y := 1.0, Z := 1.0}
                Time := 0.6
                Interpolation := EaseInOut
            Controller.SetAnimation(array{Left, Right}, ?Mode := animation_mode.PingPong)
            Controller.Play()

    # Hatch step 2: the egg shakes harder and harder.
    ShakeIncubatorEgg(Index:int, Intensity:float)<suspends>:void =
        if (Prop := IncubatorProps[Index]?, Prop.IsValid[]):
            if (Controller := Prop.GetAnimationController[]):
                Controller.Stop()
            Base := IncubatorEggTransform(Index)
            var Step : int = 0
            loop:
                if (Step >= 12):
                    break
                Amplitude := (6.0 + ToFloat(Step) * 1.5) * Intensity
                Roll := if (ModInt(Step, 2) = 0) then Amplitude else -Amplitude
                ShakeRot := MakeRotationFromYawPitchRollDegrees(0.0, 0.0, Roll)
                Prop.MoveTo(Base.Translation, ShakeRot, 0.07)
                set Step += 1
            Prop.MoveTo(Base.Translation, IdentityRotation(), 0.05)

    # Hatch step 5: the egg bursts (the prop disappears, VFX plays elsewhere).
    BurstIncubatorEgg(Index:int):void =
        HideIncubatorEgg(Index)

    # Hatch step 7: the creature appears above the incubator, grows and spins.
    PlayHatchReveal(Index:int, Asset:creative_prop_asset, Scale:float)<suspends>:void =
        Base := IncubatorEggTransform(Index).Translation
        StartScale := vector3{X := Scale * 0.15, Y := Scale * 0.15, Z := Scale * 0.15}
        FullScale := vector3{X := Scale, Y := Scale, Z := Scale}
        FacingYaw := GetYawDegrees() + 180.0
        SpawnAt := transform{Translation := Base, Rotation := MakeRotationFromYawPitchRollDegrees(FacingYaw, 0.0, 0.0), Scale := StartScale}
        MaybeProp := SpawnPropAsync(Asset, SpawnAt)
        if (Prop := MaybeProp?):
            Lifted := Base + vector3{X := 0.0, Y := 0.0, Z := 140.0}
            # One full turn in 120-degree steps (rotations interpolate along
            # the shortest path, so a single +360 step would not spin).
            Prop.MoveTo(transform{Translation := Lifted, Rotation := MakeRotationFromYawPitchRollDegrees(FacingYaw + 120.0, 0.0, 0.0), Scale := FullScale}, 0.5)
            Prop.MoveTo(transform{Translation := Lifted, Rotation := MakeRotationFromYawPitchRollDegrees(FacingYaw + 240.0, 0.0, 0.0), Scale := FullScale}, 0.8)
            Prop.MoveTo(transform{Translation := Lifted, Rotation := MakeRotationFromYawPitchRollDegrees(FacingYaw + 360.0, 0.0, 0.0), Scale := FullScale}, 0.8)
            Sleep(1.4)
            if (Prop.IsValid[]):
                Prop.Dispose()

    # ---------------------------------------------------------- Cameras ------
    FocusHatchCamera(Agent:agent):void =
        for (Camera : HatchCamera):
            Camera.AddTo(Agent)

    ReleaseHatchCamera(Agent:agent):void =
        for (Camera : HatchCamera):
            Camera.RemoveFrom(Agent)

    FocusDeepDiveCamera(Agent:agent):void =
        if (DeepDiveCamera.Length > 0):
            for (Camera : DeepDiveCamera):
                Camera.AddTo(Agent)
        else:
            FocusHatchCamera(Agent)

    ReleaseDeepDiveCamera(Agent:agent):void =
        for (Camera : DeepDiveCamera):
            Camera.RemoveFrom(Agent)
        ReleaseHatchCamera(Agent)

    PlayDeepDiveWave():void =
        for (Effect : DeepDiveWave):
            Effect.Enable()
            Effect.Restart()

    # Called when the owner leaves: clear every per-owner visual.
    ResetForNoOwner():void =
        set DisplayGeneration += 1
        ClearCreatureDisplays()
        for (I := 0..Incubators.Length - 1):
            HideIncubatorEgg(I)
            SetIncubatorTimer(I, "")
            SetIncubatorPrompt(I, EmptyIncubatorPrompt)
        HatchLuckButton.SetInteractionText(HatchLuckIdlePrompt)
        HatchLuckMaxButton.SetInteractionText(UpgradeMaxPrompt)
        SetOwnerSign(false, "")
