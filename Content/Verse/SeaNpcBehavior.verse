# ============================================================================
# RIDE A SEA BEAST - SeaNpcBehavior.verse
# Behavior for the hub shopkeepers (Marina, Finn, Chef Kelp, Captain Pearl).
# Assign `sea_npc_behavior` in each NPC Character Definition (Custom type).
# The NPC idles at its spot and turns to face the nearest player in range.
# No combat AI and no navigation - intentionally cheap.
# ============================================================================
using { /Fortnite.com/AI }
using { /Fortnite.com/Characters }
using { /Fortnite.com/Playspaces }
using { /Verse.org/Simulation }
using { /UnrealEngine.com/Temporary/SpatialMath }

sea_npc_behavior := class(npc_behavior):
    # Players closer than this (cm) get looked at.
    @editable
    FocusRadius : float = 1200.0
    @editable
    RefreshSeconds : float = 1.5

    OnBegin<override>()<suspends>:void =
        if (Agent := GetAgent[], Character := Agent.GetFortCharacter[], Focus := Character.GetFocusInterface[]):
            loop:
                if (Target := FindNearestPlayer[Character]):
                    race:
                        Focus.MaintainFocus(Target)
                        Sleep(RefreshSeconds)
                else:
                    Sleep(RefreshSeconds)

    FindNearestPlayer(Self_Character:fort_character)<transacts><decides>:agent =
        Entity := GetEntity[]
        Playspace := Entity.GetPlayspaceForEntity[]
        MyPosition := Self_Character.GetTransform().Translation
        var Best : ?agent = false
        var BestDistance : float = FocusRadius
        for (Player : Playspace.GetPlayers(), Character := Player.GetFortCharacter[], Character.IsActive[]):
            D := Distance(MyPosition, Character.GetTransform().Translation)
            if (D < BestDistance):
                set BestDistance = D
                set Best = option{Player}
        Best?
