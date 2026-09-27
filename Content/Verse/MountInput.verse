# ============================================================================
# RIDE A SEA BEAST - MountInput.verse
# Player input through the Verse Player Input API (/Verse.org/Input) using
# only NON-experimental Fortnite input actions, so the island can publish:
#
#   Jump            -> BREACH (or DISMOUNT when stopped)
#   Crouch (hold)   -> DIVE
#   Sprint          -> toggle FAST SWIM
#   WeaponPrimary   -> SWIM (hold) / start-stop (tap, Toggle mode)
#   WeaponSecondary -> BRAKE / reverse (hold)
#   Reload (hold)   -> open the main menu
#   Camera          -> steering direction (GetViewRotation)
#
# These work on keyboard/mouse, controller and touch. Analog movement
# (WASD / left stick / virtual joystick) is provided by optional
# mount_input_provider_device subclasses - see ExperimentalMoveInput.verse.
# ============================================================================
using { /Fortnite.com/Devices }
using { /Fortnite.com/Input/Character }
using { /Verse.org/Input }
using { /Verse.org/Simulation }

# Base class for optional analog movement providers. Place a subclass device
# in the level and add it to the game device's InputProviders list.
mount_input_provider_device := class(creative_device):
    # Called once per joining player. Subclasses subscribe to their inputs and
    # report analog movement with Game.SetAnalogMove / Game.ClearAnalogMove.
    RegisterPlayer(Game:sea_beast_game_device, Player:player):void = {}

# Routes input events (payload carries the player) into the game device.
input_router := class:
    Game : sea_beast_game_device

    OnJump(Data:tuple(player, logic)):void = Game.OnJumpPressed(Data(0))
    OnCrouchBegin(Data:tuple(player, logic)):void = Game.OnCrouchChanged(Data(0), true)
    OnCrouchEnd(Data:tuple(player, float)):void = Game.OnCrouchChanged(Data(0), false)
    OnSprint(Data:tuple(player, logic)):void = Game.OnSprintPressed(Data(0))
    OnFireBegin(Data:tuple(player, logic)):void = Game.OnFireChanged(Data(0), true)
    OnFireEnd(Data:tuple(player, float)):void = Game.OnFireChanged(Data(0), false)
    OnAimBegin(Data:tuple(player, logic)):void = Game.OnAimChanged(Data(0), true)
    OnAimEnd(Data:tuple(player, float)):void = Game.OnAimChanged(Data(0), false)
    OnReloadEnd(Data:tuple(player, float)):void = Game.OnReloadReleased(Data(0), Data(1))

(G:sea_beast_game_device).RegisterPlayerInput(Session:player_session):void =
    if (Session.InputRegistered?):
        return
    if (PlayerInput := GetPlayerInput[Session.Player]):
        PlayerInput.AddInputMapping(TraversalMapping)
        PlayerInput.AddInputMapping(RangedWeaponMapping)
        Router := input_router{Game := G}
        PlayerInput.GetInputEvents(Jump).TriggerActivationEvent.Subscribe(Router.OnJump)
        PlayerInput.GetInputEvents(Crouch).BeginDetectEvent.Subscribe(Router.OnCrouchBegin)
        PlayerInput.GetInputEvents(Crouch).EndDetectEvent.Subscribe(Router.OnCrouchEnd)
        PlayerInput.GetInputEvents(Sprint).TriggerActivationEvent.Subscribe(Router.OnSprint)
        PlayerInput.GetInputEvents(WeaponPrimary).BeginDetectEvent.Subscribe(Router.OnFireBegin)
        PlayerInput.GetInputEvents(WeaponPrimary).EndDetectEvent.Subscribe(Router.OnFireEnd)
        PlayerInput.GetInputEvents(WeaponSecondary).BeginDetectEvent.Subscribe(Router.OnAimBegin)
        PlayerInput.GetInputEvents(WeaponSecondary).EndDetectEvent.Subscribe(Router.OnAimEnd)
        PlayerInput.GetInputEvents(Reload).EndDetectEvent.Subscribe(Router.OnReloadEnd)
        # Touch is a platform capability that does not change during a session.
        set Session.IsTouch = PlayerInput.AvailableInputDevices.Touch
        set Session.InputRegistered = true
    else:
        LogSeaWarning("GetPlayerInput failed; mounted controls will use the menu only.")
    for (Provider : G.InputProviders):
        Provider.RegisterPlayer(G, Session.Player)

# ---------------------------------------------------------------- Handlers -
(G:sea_beast_game_device).OnJumpPressed(Player:player):void =
    if (Session := G.GetPlayerSession[Player], Session.Mount.State = mount_state.Mounted):
        if (AbsF(Session.Mount.Speed) <= MountDismountMaxSpeed and Session.Mount.Mode = swim_mode.Surface):
            G.Dismount(Session, true)
        else:
            G.TryBreach(Session)

(G:sea_beast_game_device).OnCrouchChanged(Player:player, Down:logic):void =
    if (Session := G.GetPlayerSession[Player]):
        set Session.CrouchHeld = Down

(G:sea_beast_game_device).OnSprintPressed(Player:player):void =
    if (Session := G.GetPlayerSession[Player], Session.Mount.State = mount_state.Mounted):
        set Session.BoostOn = if (Session.BoostOn?) then false else true
        if (Session.BoostOn?):
            G.PlaySfx(Session, sfx_key.FastSwim)
        G.RefreshHud(Session)

(G:sea_beast_game_device).OnFireChanged(Player:player, Down:logic):void =
    if (Session := G.GetPlayerSession[Player]):
        set Session.FireHeld = Down
        if (Down?, Session.Mount.State = mount_state.Mounted, Session.Profile.ThrottleToggle?):
            set Session.CruiseOn = if (Session.CruiseOn?) then false else true

(G:sea_beast_game_device).OnAimChanged(Player:player, Down:logic):void =
    if (Session := G.GetPlayerSession[Player]):
        set Session.AimHeld = Down
        if (Down?, Session.Profile.ThrottleToggle?):
            set Session.CruiseOn = false

(G:sea_beast_game_device).OnReloadReleased(Player:player, HeldSeconds:float):void =
    if (Session := G.GetPlayerSession[Player], Session.Loaded?, HeldSeconds >= MenuHoldSeconds):
        if (not Session.DeepDiveRunning?, Session.HatchingIncubator < 0):
            Session.UI.ToggleMainMenu()

# Releases every held mount control (used when a menu captures input, so a
# ridden beast coasts to a stop instead of swimming on by itself).
(G:sea_beast_game_device).ClearMountInput(Session:player_session):void =
    set Session.FireHeld = false
    set Session.AimHeld = false
    set Session.CrouchHeld = false
    set Session.CruiseOn = false
    set Session.BoostOn = false
    set Session.AnalogForward = 0.0
    set Session.AnalogRight = 0.0

# ---------------------------------------------------------------- Analog ---
# Forward/Right in -1..1, relative to the camera. Called by input providers.
(G:sea_beast_game_device).SetAnalogMove(Player:player, Forward:float, Right:float):void =
    if (Session := G.GetPlayerSession[Player]):
        set Session.AnalogActive = true
        set Session.AnalogForward = ClampF(Forward, -1.0, 1.0)
        set Session.AnalogRight = ClampF(Right, -1.0, 1.0)
        set Session.AnalogLastTime = G.GetNow()

(G:sea_beast_game_device).ClearAnalogMove(Player:player):void =
    if (Session := G.GetPlayerSession[Player]):
        set Session.AnalogForward = 0.0
        set Session.AnalogRight = 0.0
        set Session.AnalogLastTime = G.GetNow()

(G:sea_beast_game_device).HasAnalogProvider()<transacts><decides>:void =
    G.InputProviders.Length > 0
