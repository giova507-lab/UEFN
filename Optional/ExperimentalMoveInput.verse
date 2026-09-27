# ============================================================================
# RIDE A SEA BEAST - ExperimentalMoveInput.verse   (OPTIONAL, NOT PUBLISHABLE)
#
# Adds analog WASD / left stick / virtual joystick steering for Sea Beasts
# using /Fortnite.com/Input/Character.Move, which is marked @experimental in
# UEFN 42.x. Projects that use experimental APIs cannot be published, so:
#
#   * This file lives OUTSIDE Content/ and is not compiled by default.
#   * To try it in private edit sessions: copy it into Content/Verse/,
#     place an `experimental_move_input_device` in the level and add it to
#     the game device's InputProviders list.
#   * Before publishing: delete the device and this file again - unless Epic
#     has promoted `Move` out of experimental by then (check the digest).
#
# The stable controls (look to steer + Fire to swim) keep working either way.
# ============================================================================
using { /Fortnite.com/Devices }
using { /Fortnite.com/Input/Character }
using { /Verse.org/Input }
using { /Verse.org/Simulation }

experimental_move_input_device := class(mount_input_provider_device):
    # The Move action reports a vector3 (Forward / Left / Up). If your test
    # shows swapped or inverted axes, adjust these without touching code.
    @editable
    SwapAxes : logic = false
    @editable
    InvertForward : logic = false
    @editable
    InvertRight : logic = false

    RegisterPlayer<override>(Game:sea_beast_game_device, Player:player):void =
        if (PlayerInput := GetPlayerInput[Player]):
            PlayerInput.AddInputMapping(TraversalMapping)
            Handler := move_input_handler{Game := Game, Device := Self}
            PlayerInput.GetInputEvents(Move).TriggerActivationEvent.Subscribe(Handler.OnMove)
            PlayerInput.GetInputEvents(Move).EndDetectEvent.Subscribe(Handler.OnMoveEnd)

move_input_handler := class:
    Game : sea_beast_game_device
    Device : experimental_move_input_device

    OnMove(Data:tuple(player, (/Verse.org/SpatialMath:)vector3)):void =
        Value := Data(1)
        RawForward := if (Device.SwapAxes?) then Value.Left else Value.Forward
        RawRight := if (Device.SwapAxes?) then Value.Forward else -Value.Left
        Forward := if (Device.InvertForward?) then -RawForward else RawForward
        Right := if (Device.InvertRight?) then -RawRight else RawRight
        Game.SetAnalogMove(Data(0), Forward, Right)

    OnMoveEnd(Data:tuple(player, float)):void =
        Game.ClearAnalogMove(Data(0))
