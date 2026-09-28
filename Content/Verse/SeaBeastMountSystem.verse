# ============================================================================
# RIDE A SEA BEAST - SeaBeastMountSystem.verse
# Custom Sea Beast riding for UEFN (no humanoid mounting exists in Fortnite).
#
#   PLAYER INPUT (MountInput.verse)
#     -> Verse mount controller (this file, server authoritative, 10 Hz)
#     -> kinematic simulation (heading, speed, surface/dive/breach arcs)
#     -> navigation (SeaNavigation.verse: shores, reef walls, pools)
#     -> rig transforms via overlapping MoveTo segments (smooth on clients)
#     -> creature visual (Animated Mesh pool: swim / idle / fast variants,
#        or a spawned display prop as fallback)
#     -> rider attachment (chair_device seat that moves with the creature,
#        or an invisible saddle platform + stasis)
#
# Physical speed comes from MovementBalance.verse (log curve), so a
# 1,000,000,000 display-speed Celestial Serpent still moves at ~57 m/s.
# The creature banks into turns, pitches on breaches and dives, bobs at the
# surface and drives a wake effect while swimming fast.
# ============================================================================
using { /Fortnite.com/Devices }
using { /Fortnite.com/Characters }
using { /Verse.org/Simulation }
using { /UnrealEngine.com/Temporary/SpatialMath }

# Visual variants inside a creature's pool slot.
VisualVariantSwim : int = 0
VisualVariantIdle : int = 1
VisualVariantFast : int = 2

# Rider seat handler: reacts when a player leaves a chair on their own.
seat_exit_handler := class:
    Game : sea_beast_game_device
    RigIndex : int
    OnExited(Agent:agent):void = Game.OnSeatExited(RigIndex, Agent)

# ---------------------------------------------------------------- Setup ----
(G:sea_beast_game_device).InitMountRigs():void =
    set G.RigUsers = for (I := 0..G.MountRigs.Length - 1). NoPlayer()
    set G.VisualSlotsInUse = for (Def : CreatureDefs):
        SlotCount := if (Entry := G.GetCreatureVisual[Def.ID]) then Entry.MountSwim.Length else 0
        for (I := 0..SlotCount - 1). false
    for (I -> Rig : G.MountRigs):
        Handler := seat_exit_handler{Game := G, RigIndex := I}
        Rig.Seat.ExitedEvent.Subscribe(Handler.OnExited)
        G.ParkRig(Rig)
    for (Entry : G.CreatureVisuals):
        for (Device : Entry.MountSwim):
            G.ParkObject(Device)
            Device.Pause()
        for (Device : Entry.MountIdle):
            G.ParkObject(Device)
            Device.Pause()
        for (Device : Entry.MountFast):
            G.ParkObject(Device)
            Device.Pause()

(G:sea_beast_game_device).ParkObject(Object:creative_object):void =
    if (Object.TeleportTo[G.ParkingLocation, IdentityRotation()]):
        return
    # (A teleport inside `not` would be rolled back, so check success first.)
    if (not G.ParkingWarned?):
        set G.ParkingWarned = true
        LogSeaWarning("Could not move an object to ParkingLocation - move it inside the island bounds on the game device.")

(G:sea_beast_game_device).ParkRig(Rig:mount_rig_setup):void =
    # A parked chair is disabled so nobody can sit in it; AttachRider enables
    # it again for the next ride.
    Rig.Seat.Disable()
    G.ParkObject(Rig.Seat)
    for (Saddle : Rig.Saddle):
        G.ParkObject(Saddle)
    for (Wake : Rig.Wake):
        Wake.Disable()
        G.ParkObject(Wake)

(G:sea_beast_game_device).GetRig(Session:player_session)<transacts><decides>:mount_rig_setup =
    G.MountRigs[Session.Mount.RigIndex]

# ---------------------------------------------------------------- Stats ----
(G:sea_beast_game_device).CacheMountStats(Session:player_session, C:owned_creature):void =
    M := Session.Mount
    if (Def := GetCreatureDef[C.TypeID]):
        set M.CreatureUID = C.UniqueID
        set M.TypeID = C.TypeID
        set M.SizeClass = Def.SizeClass
        set M.MaxSpeed = DisplaySpeedToCmPerSecond(CreatureDisplaySpeed(C))
        set M.TurnRate = SizeClassTurnRate(Def.SizeClass)
        set M.BreachVelocity = BreachLaunchVelocity(CreatureDisplayBreach(C))
        set M.Radius = SizeClassCollisionRadius(Def.SizeClass)
        set M.VisualScale = G.GetCreatureVisualScale(C.TypeID)
        set M.SaddleHeight = SizeClassSaddleHeight(Def.SizeClass) * (M.VisualScale / MaxF(SizeClassVisualScale(Def.SizeClass), 0.01))
        set M.SaddleForward = 0.0
        if (Entry := G.GetCreatureVisual[C.TypeID]):
            if (Entry.SaddleHeight >= 0.0):
                set M.SaddleHeight = Entry.SaddleHeight
            set M.SaddleForward = Entry.SaddleForward

# Re-reads stats after feeding or a mutation while riding.
(G:sea_beast_game_device).RefreshMountStats(Session:player_session):void =
    if (C := G.FindCreature[Session, Session.Mount.CreatureUID]):
        G.CacheMountStats(Session, C)
        G.RefreshHud(Session)

# ---------------------------------------------------------------- Mounting -
# Summons the creature and seats the rider. AtDock forces the Lagoon dock.
(G:sea_beast_game_device).RequestMount(Session:player_session, UID:int, AtDock:logic):void =
    if (not Session.Loaded? or Session.DeepDiveRunning? or Session.IntroRunning? or Session.HatchingIncubator >= 0):
        return
    if (not G.FindCreature[Session, UID]):
        G.ShowToast(Session, "CHOOSE A SEA BEAST TO RIDE IN THE SEA BEASTS MENU.", ThemeWarning)
        return
    if (Session.Mount.State = mount_state.Mounting):
        return
    var UseDock : logic = AtDock
    var HaveSpot : logic = false
    var StartPos : vector3 = vector3{}
    var StartYaw : float = 0.0
    if (Session.Mount.State = mount_state.Mounted):
        if (Session.Mount.CreatureUID = UID):
            return
        # Switching beasts at sea: the new one appears where the old one was.
        set StartPos = vector3{X := Session.Mount.PosX, Y := Session.Mount.PosY, Z := Session.Mount.PosZ}
        set StartYaw = Session.Mount.Yaw
        set HaveSpot = true
        set UseDock = false
        G.Dismount(Session, false)
    if (not UseDock? and not HaveSpot?):
        if (Spot := G.FindWaterSpotNearPlayer[Session]):
            set StartPos = Spot(0)
            set StartYaw = Spot(1)
        else if (G.IsNearOwnLagoon[Session], Session.Carried.Length = 0):
            set UseDock = true
        else:
            # Never a free trip home: away from water the beast only comes
            # to the player's own Lagoon dock.
            G.ShowToast(Session, "GET INTO OPEN WATER TO CALL YOUR SEA BEAST, OR USE THE RIDE DOCK AT YOUR LAGOON.", ThemeWarning)
            return
    G.SetActiveMount(Session, UID)
    if (UseDock?):
        if (Lagoon := G.GetLagoonForSession[Session]):
            set StartPos = Lagoon.GetMountPosition()
            set StartYaw = Lagoon.GetYawDegrees()
        else:
            return
    spawn{ G.DoMount(Session, UID, StartPos, StartYaw) }

(G:sea_beast_game_device).IsNearOwnLagoon(Session:player_session)<transacts><decides>:void =
    Lagoon := G.GetLagoonForSession[Session]
    Character := Session.Player.GetFortCharacter[]
    Lagoon.IsInsideArea[Character.GetTransform().Translation]

# Succeeds with (position at the surface, yaw) when the player stands in or
# right next to open water.
(G:sea_beast_game_device).FindWaterSpotNearPlayer(Session:player_session)<transacts><decides>:tuple(vector3, float) =
    Character := Session.Player.GetFortCharacter[]
    Position := Character.GetTransform().Translation
    Surface := G.Navigator.SurfaceZAt(Position.X, Position.Y, Position.Z)
    AbsF(Position.Z - Surface) <= 300.0
    not G.Navigator.IsBlocked[Position.X, Position.Y, Surface, 150.0]
    Angles := Character.GetViewRotation().GetYawPitchRollDegrees()
    Yaw := if (V := Angles[0]) then V else 0.0
    (vector3{X := Position.X, Y := Position.Y, Z := Surface}, Yaw)

(G:sea_beast_game_device).DoMount(Session:player_session, UID:int, StartPos:vector3, StartYaw:float)<suspends>:void =
    M := Session.Mount
    if (C := G.FindCreature[Session, UID], Rig := G.MountRigs[Session.LagoonIndex], Character := Session.Player.GetFortCharacter[]):
        set M.State = mount_state.Mounting
        set M.Generation += 1
        Generation := M.Generation
        set M.RigIndex = Session.LagoonIndex
        if (set G.RigUsers[Session.LagoonIndex] = option{Session.Player}) {}
        G.CacheMountStats(Session, C)
        set M.PosX = StartPos.X
        set M.PosY = StartPos.Y
        set M.PosZ = G.Navigator.SurfaceZAt(StartPos.X, StartPos.Y, StartPos.Z)
        set M.Yaw = StartYaw
        set M.YawRate = 0.0
        set M.Speed = 0.0
        set M.VerticalSpeed = 0.0
        set M.Mode = swim_mode.Surface
        set M.Bank = 0.0
        set M.Pitch = 0.0
        set Session.CruiseOn = false
        set Session.BoostOn = false
        G.AcquireMountVisual(Session)
        G.TeleportRig(Session)
        Attached := G.AttachRider(Session, Rig, Character, Generation)
        if (M.Generation <> Generation):
            # Dismounted while seating (respawn, menu, leaving): Dismount has
            # already cleaned up and AttachRider undid its own seating.
            return
        if (not Attached?):
            G.ShowToast(Session, "YOUR SEA BEAST COULD NOT PICK YOU UP. TRY AGAIN.", ThemeDanger)
            G.CleanupRig(Session)
            set M.State = mount_state.Dismounted
            return
        set M.State = mount_state.Mounted
        G.PlaySfx(Session, sfx_key.Mount)
        G.PlayVfxAt(vfx_key.Splash, StartPos)
        G.ShowToast(Session, "RIDING {CreatureName(C.TypeID)}  ({FormatDecimal(M.MaxSpeed / 100.0, 1)} m/s)", RarityColor(CreatureRarity(C.TypeID)))
        G.RefreshLagoonDisplays(Session)
        G.RefreshHud(Session)
        G.RunMountLoop(Session, Generation)

# Seats the rider. Chair mode first; falls back to the saddle platform.
# Generation is the mount generation of this ride: if it changes while
# waiting for the seat (the ride was cancelled), the seating is undone.
(G:sea_beast_game_device).AttachRider(Session:player_session, Rig:mount_rig_setup, Character:fort_character, Generation:int)<suspends>:logic =
    if (G.RiderAttachMode = rider_attach_mode.Chair):
        Rig.Seat.Enable()
        Rig.Seat.EnableExit()
        var Attempt : int = 0
        loop:
            if (Attempt >= 3 or Session.Mount.Generation <> Generation):
                break
            Rig.Seat.Seat(Session.Player)
            Sleep(0.15)
            if (Rig.Seat.IsSeated[Session.Player]):
                break
            set Attempt += 1
        if (Session.Mount.Generation <> Generation):
            # Undo only when no newer ride is seating the player in this chair.
            if (Session.Mount.State = mount_state.Dismounted, Rig.Seat.IsSeated[Session.Player]):
                Rig.Seat.EnableExit()
                Rig.Seat.Eject(Session.Player)
                G.MoveRiderToExit(Session)
            return false
        if (Rig.Seat.IsSeated[Session.Player]):
            Rig.Seat.DisableExit()
            return true
        LogSeaWarning("Chair seating failed - falling back to the saddle platform for this ride.")
    if (Session.Mount.Generation <> Generation):
        return false
    if (Saddle := Rig.Saddle[0]):
        SaddlePos := G.GetSaddlePosition(Session)
        if (Saddle.TeleportTo[SaddlePos, MakeRotationFromYawPitchRollDegrees(Session.Mount.Yaw, 0.0, 0.0)]) {}
        RiderPos := SaddlePos + vector3{X := 0.0, Y := 0.0, Z := 110.0}
        if (Character.TeleportTo[RiderPos, MakeRotationFromYawPitchRollDegrees(Session.Mount.Yaw, 0.0, 0.0)]) {}
        Character.PutInStasis(stasis_args{AllowTurning := true, AllowFalling := true, AllowEmotes := false})
        return true
    false

(G:sea_beast_game_device).IsSeatedInChair(Session:player_session)<transacts><decides>:void =
    Rig := G.GetRig[Session]
    Rig.Seat.IsSeated[Session.Player]

(G:sea_beast_game_device).Dismount(Session:player_session, PlayEffects:logic):void =
    M := Session.Mount
    if (M.State = mount_state.Dismounted):
        return
    set M.Generation += 1
    set M.State = mount_state.Dismounted
    if (Rig := G.GetRig[Session]):
        if (Rig.Seat.IsSeated[Session.Player]):
            Rig.Seat.EnableExit()
            Rig.Seat.Eject(Session.Player)
    G.MoveRiderToExit(Session)
    G.CleanupRig(Session)
    set Session.CruiseOn = false
    set Session.BoostOn = false
    if (PlayEffects?):
        G.PlaySfx(Session, sfx_key.Dismount)
        G.PlayVfxAt(vfx_key.Splash, vector3{X := M.PosX, Y := M.PosY, Z := M.PosZ})
    G.RefreshLagoonDisplays(Session)
    G.RefreshHud(Session)

(G:sea_beast_game_device).ForceDismount(Session:player_session):void =
    G.Dismount(Session, false)

# Frees the rider and puts them just above where the beast was.
(G:sea_beast_game_device).MoveRiderToExit(Session:player_session):void =
    M := Session.Mount
    ExitPos := vector3{X := M.PosX, Y := M.PosY, Z := M.PosZ + M.SaddleHeight + 120.0}
    if (Character := Session.Player.GetFortCharacter[]):
        Character.ReleaseFromStasis()
        if (Character.TeleportTo[ExitPos, MakeRotationFromYawPitchRollDegrees(M.Yaw, 0.0, 0.0)]) {}

(G:sea_beast_game_device).CleanupRig(Session:player_session):void =
    M := Session.Mount
    RigIndex := M.RigIndex
    TypeID := M.TypeID
    Slot := M.VisualSlot
    G.ReleaseMountVisual(Session)
    if (Rig := G.GetRig[Session]):
        G.ParkRig(Rig)
    if (set G.RigUsers[M.RigIndex] = NoPlayer()) {}
    set M.RigIndex = -1
    set M.WakeOn = false
    # MoveTo segments started during the last tick may still be running and
    # could carry parked objects back; park again once they are over.
    spawn{ G.ReparkAfterMoves(RigIndex, TypeID, Slot) }

# Parks the rig and the creature visuals of a finished ride a second time,
# after in-flight MoveTo segments ended - but only what nobody uses now.
(G:sea_beast_game_device).ReparkAfterMoves(RigIndex:int, TypeID:int, Slot:int)<suspends>:void =
    Sleep(MountTickSeconds + MountMoveLeadSeconds + 0.1)
    if (Rig := G.MountRigs[RigIndex], not G.RigUsers[RigIndex]?):
        G.ParkRig(Rig)
    if (Slot >= 0, Entry := G.GetCreatureVisual[TypeID]):
        for (Variant := 0..2, Device := G.GetVariantDevice[Entry, Slot, Variant], not G.IsVisualActive[TypeID, Slot, Variant]):
            G.ParkObject(Device)

# Succeeds when a current ride shows the animated device (TypeID, Slot, Variant).
(G:sea_beast_game_device).IsVisualActive(TypeID:int, Slot:int, Variant:int)<transacts><decides>:void =
    var Found : logic = false
    for (Player -> Other : G.Sessions, Other.Mount.State <> mount_state.Dismounted, Other.Mount.TypeID = TypeID, Other.Mount.VisualSlot = Slot, Other.Mount.VisualVariant = Variant):
        set Found = true
    Found?

# The player left the chair by themselves (or was removed by the game).
(G:sea_beast_game_device).OnSeatExited(RigIndex:int, Agent:agent):void =
    if (Session := G.GetAgentSession[Agent], Session.Mount.State = mount_state.Mounted, Session.Mount.RigIndex = RigIndex):
        G.Dismount(Session, true)

# ---------------------------------------------------------------- Visuals --
(G:sea_beast_game_device).AcquireMountVisual(Session:player_session):void =
    M := Session.Mount
    set M.VisualSlot = -1
    set M.VisualVariant = VisualVariantSwim
    if (Entry := G.GetCreatureVisual[M.TypeID], Slots := G.VisualSlotsInUse[M.TypeID - 1]):
        var Chosen : int = -1
        for (I -> InUse : Slots, Chosen < 0, not InUse?, I < Entry.MountSwim.Length):
            set Chosen = I
        if (Chosen >= 0, set G.VisualSlotsInUse[M.TypeID - 1][Chosen] = true):
            set M.VisualSlot = Chosen
            if (Device := Entry.MountSwim[Chosen]):
                Device.Play()
            return
    # Fallback: spawn the static display prop through the owner's Lagoon.
    if (Asset := G.GetCreatureDisplayAsset[M.TypeID], Lagoon := G.GetLagoonForSession[Session]):
        spawn{ G.SpawnMountFallbackProp(Session, M.Generation, Asset, Lagoon) }
    else:
        LogSeaWarning("Creature {M.TypeID} has no riding visual or display prop assigned.")

(G:sea_beast_game_device).SpawnMountFallbackProp(Session:player_session, Generation:int, Asset:creative_prop_asset, Lagoon:lagoon_device)<suspends>:void =
    M := Session.Mount
    SpawnAt := transform{Translation := vector3{X := M.PosX, Y := M.PosY, Z := M.PosZ}, Rotation := MakeRotationFromYawPitchRollDegrees(M.Yaw, 0.0, 0.0), Scale := vector3{X := M.VisualScale, Y := M.VisualScale, Z := M.VisualScale}}
    MaybeProp := Lagoon.SpawnPropAsync(Asset, SpawnAt)
    if (Prop := MaybeProp?):
        if (M.Generation = Generation, M.State <> mount_state.Dismounted):
            set M.FallbackProp = option{Prop}
        else:
            Prop.Dispose()

(G:sea_beast_game_device).ReleaseMountVisual(Session:player_session):void =
    M := Session.Mount
    if (M.VisualSlot >= 0, Entry := G.GetCreatureVisual[M.TypeID]):
        for (Variant := 0..2, Device := G.GetVariantDevice[Entry, M.VisualSlot, Variant]):
            Device.Pause()
            G.ParkObject(Device)
        if (set G.VisualSlotsInUse[M.TypeID - 1][M.VisualSlot] = false) {}
    set M.VisualSlot = -1
    if (Prop := M.FallbackProp?):
        if (Prop.IsValid[]):
            Prop.Dispose()
    set M.FallbackProp = false

(G:sea_beast_game_device).GetVariantDevice(Entry:creature_visual_entry, Slot:int, Variant:int)<transacts><decides>:animated_mesh_device =
    Devices := if (Variant = VisualVariantIdle) then Entry.MountIdle else if (Variant = VisualVariantFast) then Entry.MountFast else Entry.MountSwim
    Devices[Slot]

(G:sea_beast_game_device).GetActiveVisualDevice(Session:player_session)<transacts><decides>:animated_mesh_device =
    M := Session.Mount
    M.VisualSlot >= 0
    Entry := G.GetCreatureVisual[M.TypeID]
    G.GetVariantDevice[Entry, M.VisualSlot, M.VisualVariant]

# Swaps between idle / swim / fast animated devices of the same pool slot.
(G:sea_beast_game_device).UpdateVisualVariant(Session:player_session):void =
    M := Session.Mount
    if (M.VisualSlot >= 0, Entry := G.GetCreatureVisual[M.TypeID]):
        SpeedFraction := AbsF(M.Speed) / MaxF(M.MaxSpeed, 1.0)
        Desired := if (M.Mode <> swim_mode.Airborne and SpeedFraction < 0.12) then VisualVariantIdle else if (Session.BoostOn? and SpeedFraction > 0.85) then VisualVariantFast else VisualVariantSwim
        if (Desired <> M.VisualVariant, NewDevice := G.GetVariantDevice[Entry, M.VisualSlot, Desired]):
            Transform := G.GetVisualTransform(Session)
            OldVariant := M.VisualVariant
            if (OldDevice := G.GetActiveVisualDevice[Session]):
                OldDevice.Pause()
                G.ParkObject(OldDevice)
            if (NewDevice.TeleportTo[Transform]) {}
            NewDevice.Play()
            set M.VisualVariant = Desired
            # The old variant may still be finishing a MoveTo toward the beast.
            spawn{ G.ReparkVariantLater(M.TypeID, M.VisualSlot, OldVariant) }

(G:sea_beast_game_device).ReparkVariantLater(TypeID:int, Slot:int, Variant:int)<suspends>:void =
    Sleep(MountTickSeconds + MountMoveLeadSeconds + 0.1)
    if (Entry := G.GetCreatureVisual[TypeID], Device := G.GetVariantDevice[Entry, Slot, Variant], not G.IsVisualActive[TypeID, Slot, Variant]):
        G.ParkObject(Device)

# ---------------------------------------------------------------- Loop -----
(G:sea_beast_game_device).RunMountLoop(Session:player_session, Generation:int)<suspends>:void =
    var LastTime : float = G.GetNow()
    var NextCheck : float = 0.0
    loop:
        M := Session.Mount
        if (M.Generation <> Generation or M.State <> mount_state.Mounted):
            break
        if (not G.Sessions[Session.Player]):
            G.CleanupRig(Session)
            break
        if (not G.IsPlayerAlive[Session]):
            G.Dismount(Session, false)
            break
        Now := G.GetNow()
        Dt := ClampF(Now - LastTime, 0.02, 0.3)
        set LastTime = Now
        G.StepLocomotion(Session, Dt, Now)
        G.UpdateVisualVariant(Session)
        G.ApplyRig(Session)
        # A rider standing on the saddle platform is checked every tick so
        # fast beasts do not leave them behind.
        if (G.RiderAttachMode = rider_attach_mode.PlatformStasis):
            G.SnapRiderIfNeeded(Session)
        if (Now >= NextCheck):
            set NextCheck = Now + 0.5
            G.MountSafetyChecks(Session)
        Sleep(MountTickSeconds)

# Heading, speed, surface / dive / breach physics for one tick.
(G:sea_beast_game_device).StepLocomotion(Session:player_session, Dt:float, Now:float):void =
    M := Session.Mount
    # ---- Desired heading and throttle ----
    CameraYaw := G.GetRiderCameraYaw(Session, M.Yaw)
    var DesiredYaw : float = CameraYaw
    var Throttle : float = 0.0
    AnalogFresh := logic{Session.AnalogActive? and Now - Session.AnalogLastTime < 0.5}
    if (AnalogFresh?):
        Magnitude := Sqrt(Session.AnalogForward * Session.AnalogForward + Session.AnalogRight * Session.AnalogRight)
        if (Magnitude > 0.15):
            set DesiredYaw = CameraYaw + RadiansToDegrees(ArcTan(Session.AnalogRight, Session.AnalogForward))
            set Throttle = MinF(Magnitude, 1.0)
    else:
        if (Session.Profile.ThrottleToggle?):
            set Throttle = if (Session.CruiseOn?) then 1.0 else 0.0
        else:
            set Throttle = if (Session.FireHeld?) then 1.0 else 0.0
    if (Session.AimHeld?):
        set Throttle = -MountReverseFraction
    Airborne := logic{M.Mode = swim_mode.Airborne}
    # ---- Turning (only while moving or throttling) ----
    if (not Airborne? and (Throttle <> 0.0 or AbsF(M.Speed) > 60.0)):
        Delta := WrapDegrees(DesiredYaw - M.Yaw)
        SlowFactor := if (AbsF(M.Speed) < 0.2 * M.MaxSpeed) then 0.7 else 1.0
        MaxTurn := M.TurnRate * SlowFactor * Dt
        Turn := ClampF(Delta, -MaxTurn, MaxTurn)
        set M.YawRate = Turn / Dt
        set M.Yaw = WrapDegrees(M.Yaw + Turn)
    else:
        set M.YawRate = M.YawRate * 0.8
    # ---- Speed ----
    Cruise := if (Session.BoostOn?) then 1.0 else MountCruiseFraction
    TargetSpeed := if (Throttle > 0.0) then Throttle * M.MaxSpeed * Cruise else if (Throttle < 0.0) then Throttle * M.MaxSpeed else 0.0
    if (not Airborne?):
        Rate := if (Session.AimHeld? and M.Speed > 0.0) then M.MaxSpeed / MountBrakeTime else if (TargetSpeed = 0.0) then M.MaxSpeed / MountCoastTime else M.MaxSpeed / MountAccelerationTime
        set M.Speed = MoveToward(M.Speed, TargetSpeed, Rate * Dt)
    # ---- Horizontal movement with shore sliding ----
    # Sub-stepped (each step at most the beast's radius) so fast beasts
    # cannot skip through thin reef walls between two ticks.
    YawRad := DegreesToRadians(M.Yaw)
    TravelDistance := AbsF(M.Speed) * Dt
    StepLength := MaxF(M.Radius, 100.0)
    StepCount := Clamp(FloorToInt(TravelDistance / StepLength, 0) + 1, 1, 8)
    StepX := Cos(YawRad) * M.Speed * Dt / ToFloat(StepCount)
    StepY := Sin(YawRad) * M.Speed * Dt / ToFloat(StepCount)
    var HitShore : logic = false
    var StepIndex : int = 0
    loop:
        if (StepIndex >= StepCount or HitShore?):
            break
        Resolved := G.Navigator.ResolveHorizontal(M.PosX, M.PosY, M.PosX + StepX, M.PosY + StepY, M.PosZ, M.Radius)
        set M.PosX = Resolved(0)
        set M.PosY = Resolved(1)
        if (Resolved(2)?):
            set HitShore = true
        set StepIndex += 1
    if (HitShore?):
        set M.Speed = M.Speed * 0.35
    # ---- Vertical ----
    Surface := G.Navigator.SurfaceZAt(M.PosX, M.PosY, M.PosZ)
    set M.LastSurfaceZ = Surface
    if (M.Mode = swim_mode.Surface):
        if (Session.CrouchHeld?):
            set M.Mode = swim_mode.Diving
            # A raised pool's surface stops counting once the beast is deep
            # in it, so the dive keeps the surface it started from.
            set M.DiveSurfaceZ = Surface
        else if (M.PosZ > Surface + 40.0):
            # Swam off the edge of a raised pool: fall back down.
            set M.Mode = swim_mode.Airborne
            set M.VerticalSpeed = 0.0
        else:
            set M.PosZ = Surface
    if (M.Mode = swim_mode.Diving):
        DiveSurface := M.DiveSurfaceZ
        MaxDepth := DiveDepthForBreach(G.GetMountBreach(Session), G.Navigator.MaxDiveDepthAt(M.PosX, M.PosY))
        TargetZ := if (Session.CrouchHeld?) then DiveSurface - MaxDepth else DiveSurface
        NewZ := MoveToward(M.PosZ, TargetZ, MountDiveSpeedCmPerSec * Dt)
        if (not G.Navigator.IsBlocked[M.PosX, M.PosY, NewZ, M.Radius]):
            set M.VerticalSpeed = (NewZ - M.PosZ) / Dt
            set M.PosZ = NewZ
        if (not Session.CrouchHeld?, M.PosZ >= DiveSurface - 5.0):
            set M.PosZ = DiveSurface
            set M.Mode = swim_mode.Surface
            set M.VerticalSpeed = 0.0
    if (M.Mode = swim_mode.Airborne):
        set M.VerticalSpeed = MaxF(M.VerticalSpeed - MountGravityCmPerSec2 * Dt, -MountMaxFallSpeed)
        NewZ := M.PosZ + M.VerticalSpeed * Dt
        LandingSurface := G.Navigator.SurfaceZAt(M.PosX, M.PosY, M.PosZ)
        if (M.VerticalSpeed < 0.0 and NewZ <= LandingSurface):
            set M.PosZ = LandingSurface
            set M.Mode = swim_mode.Surface
            set M.VerticalSpeed = 0.0
            G.PlayVfxAt(vfx_key.Splash, vector3{X := M.PosX, Y := M.PosY, Z := LandingSurface})
            G.PlaySfx(Session, sfx_key.Splash)
            if (M.SizeClass >= 4):
                G.PlayCameraShake(Session, false)
        else if (Zone := G.Navigator.FindBlockingZone[M.PosX, M.PosY, NewZ, M.Radius]):
            if (M.VerticalSpeed > 0.0):
                # Hit something overhead (an arch): start falling.
                set M.VerticalSpeed = 0.0
            else:
                # Falling onto land: slide off its edge and keep falling
                # into the water instead of hovering above it.
                Pushed := Zone.PushOut(M.PosX, M.PosY, M.Radius)
                set M.PosX = Pushed(0)
                set M.PosY = Pushed(1)
                set M.PosZ = NewZ
            set M.Speed = M.Speed * 0.5
        else:
            set M.PosZ = NewZ
    # ---- Attitude (visual only) ----
    TargetBank := ClampF(M.YawRate * 0.12, -MountMaxBankDegrees, MountMaxBankDegrees)
    set M.Bank = M.Bank + (TargetBank - M.Bank) * MinF(1.0, Dt * 6.0)
    TargetPitch := if (M.Mode = swim_mode.Airborne) then ClampF(RadiansToDegrees(ArcTan(M.VerticalSpeed, MaxF(AbsF(M.Speed), 200.0))), -MountMaxPitchDegrees, MountMaxPitchDegrees) else if (M.Mode = swim_mode.Diving) then ClampF(M.VerticalSpeed * 0.05, -25.0, 20.0) else 0.0
    set M.Pitch = M.Pitch + (TargetPitch - M.Pitch) * MinF(1.0, Dt * 5.0)

MoveToward(Current:float, Target:float, MaxStep:float)<computes>:float =
    if (Current < Target):
        MinF(Current + MaxStep, Target)
    else:
        MaxF(Current - MaxStep, Target)

(G:sea_beast_game_device).GetMountBreach(Session:player_session)<transacts>:float =
    if (C := G.FindCreature[Session, Session.Mount.CreatureUID]) then CreatureDisplayBreach(C) else 80.0

(G:sea_beast_game_device).GetRiderCameraYaw(Session:player_session, Fallback:float)<transacts>:float =
    if (Character := Session.Player.GetFortCharacter[]):
        Angles := Character.GetViewRotation().GetYawPitchRollDegrees()
        if (Yaw := Angles[0]) then Yaw else Fallback
    else:
        Fallback

(G:sea_beast_game_device).TryBreach(Session:player_session):void =
    M := Session.Mount
    if (M.Mode = swim_mode.Surface, M.Speed >= MountBreachMinSpeedFraction * M.MaxSpeed):
        set M.Mode = swim_mode.Airborne
        set M.VerticalSpeed = M.BreachVelocity
        G.PlayVfxAt(vfx_key.Splash, vector3{X := M.PosX, Y := M.PosY, Z := M.PosZ})
        G.PlaySfx(Session, sfx_key.Splash)
    else if (M.Mode = swim_mode.Surface):
        G.ShowToast(Session, "SWIM FASTER TO BREACH!", ThemeMuted)

# ---------------------------------------------------------------- Rig ------
(G:sea_beast_game_device).GetVisualTransform(Session:player_session)<transacts>:transform =
    M := Session.Mount
    Bob := if (M.Mode = swim_mode.Surface) then MountSurfaceBobCm * Sin(G.GetNow() * MountSurfaceBobHz * 2.0 * PiFloat) else 0.0
    transform:
        Translation := vector3{X := M.PosX, Y := M.PosY, Z := M.PosZ + Bob}
        Rotation := MakeRotationFromYawPitchRollDegrees(M.Yaw, M.Pitch, M.Bank)
        Scale := vector3{X := M.VisualScale, Y := M.VisualScale, Z := M.VisualScale}

(G:sea_beast_game_device).GetSaddlePosition(Session:player_session)<transacts>:vector3 =
    M := Session.Mount
    Visual := G.GetVisualTransform(Session)
    Visual.Translation + Visual.Rotation.RotateVector(vector3{X := M.SaddleForward, Y := 0.0, Z := M.SaddleHeight})

(G:sea_beast_game_device).GetSeatRotation(Session:player_session)<transacts>:rotation =
    M := Session.Mount
    MakeRotationFromYawPitchRollDegrees(M.Yaw, M.Pitch * 0.5, M.Bank * 0.3)

# Instant placement used when mounting. Creature visuals use the transform
# overloads so the creature's visual scale (size class x DisplayScale) is
# applied, matching the saddle height.
(G:sea_beast_game_device).TeleportRig(Session:player_session):void =
    Visual := G.GetVisualTransform(Session)
    if (Device := G.GetActiveVisualDevice[Session]):
        if (Device.TeleportTo[Visual]) {}
    if (Prop := Session.Mount.FallbackProp?):
        if (Prop.TeleportTo[Visual]) {}
    if (Rig := G.GetRig[Session]):
        if (Rig.Seat.TeleportTo[G.GetSaddlePosition(Session), G.GetSeatRotation(Session)]) {}

# Overlapping MoveTo segments: each lasts a little longer than the tick, and
# the next command interrupts it, so clients see continuous motion.
(G:sea_beast_game_device).ApplyRig(Session:player_session):void =
    M := Session.Mount
    MoveTime := MountTickSeconds + MountMoveLeadSeconds
    Visual := G.GetVisualTransform(Session)
    SaddlePos := G.GetSaddlePosition(Session)
    SeatRot := G.GetSeatRotation(Session)
    if (Device := G.GetActiveVisualDevice[Session]):
        spawn{ G.MoveObjectTransform(Device, Visual, MoveTime) }
    if (Prop := M.FallbackProp?, Prop.IsValid[]):
        spawn{ G.MoveObjectTransform(Prop, Visual, MoveTime) }
    if (Rig := G.GetRig[Session]):
        if (G.RiderAttachMode = rider_attach_mode.Chair):
            spawn{ G.MoveObject(Rig.Seat, SaddlePos, SeatRot, MoveTime) }
        for (Saddle : Rig.Saddle):
            spawn{ G.MoveProp(Saddle, SaddlePos, MakeRotationFromYawPitchRollDegrees(M.Yaw, 0.0, 0.0), MoveTime) }
        G.UpdateWake(Session, Rig, MoveTime)

(G:sea_beast_game_device).MoveObject(Object:creative_object, Position:vector3, Rotation:rotation, Time:float)<suspends>:void =
    Object.MoveTo(Position, Rotation, Time)

(G:sea_beast_game_device).MoveProp(Prop:creative_prop, Position:vector3, Rotation:rotation, Time:float)<suspends>:void =
    Prop.MoveTo(Position, Rotation, Time)

(G:sea_beast_game_device).MoveObjectTransform(Object:creative_object, Target:transform, Time:float)<suspends>:void =
    Object.MoveTo(Target, Time)

(G:sea_beast_game_device).UpdateWake(Session:player_session, Rig:mount_rig_setup, MoveTime:float):void =
    M := Session.Mount
    WantWake := logic{M.Mode = swim_mode.Surface and AbsF(M.Speed) > 0.2 * M.MaxSpeed and not Session.Profile.LowEffectsMode?}
    WakePos := vector3{X := M.PosX, Y := M.PosY, Z := M.LastSurfaceZ}
    WakeRot := MakeRotationFromYawPitchRollDegrees(M.Yaw, 0.0, 0.0)
    for (Wake : Rig.Wake):
        if (WantWake?):
            if (not M.WakeOn?):
                if (Wake.TeleportTo[WakePos, WakeRot]) {}
                Wake.Enable()
            else:
                spawn{ G.MoveObject(Wake, WakePos, WakeRot, MoveTime) }
        else if (M.WakeOn?):
            Wake.Disable()
    set M.WakeOn = WantWake

# Twice per second: rider re-snap if a chair lost its rider, biome tracking.
(G:sea_beast_game_device).MountSafetyChecks(Session:player_session):void =
    M := Session.Mount
    if (G.RiderAttachMode = rider_attach_mode.Chair and not G.IsSeatedInChair[Session]):
        G.SnapRiderIfNeeded(Session)
    G.UpdateBiome(Session, vector3{X := M.PosX, Y := M.PosY, Z := M.PosZ})

# Puts the rider back on the saddle when they drifted too far from it.
(G:sea_beast_game_device).SnapRiderIfNeeded(Session:player_session):void =
    M := Session.Mount
    if (Character := Session.Player.GetFortCharacter[]):
        SaddlePos := G.GetSaddlePosition(Session)
        RiderPos := Character.GetTransform().Translation
        if (Distance(RiderPos, SaddlePos + vector3{X := 0.0, Y := 0.0, Z := 100.0}) > MountRiderSnapDistance):
            if (Character.TeleportTo[SaddlePos + vector3{X := 0.0, Y := 0.0, Z := 110.0}, MakeRotationFromYawPitchRollDegrees(M.Yaw, 0.0, 0.0)]) {}
