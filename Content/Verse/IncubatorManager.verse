# ============================================================================
# RIDE A SEA BEAST - IncubatorManager.verse
# Incubators: placing eggs, growth (10x during the Night Tide), signs and
# prompts. Incubator state is persisted in the player's profile, so eggs keep
# incubating across sessions (OfflineIncubationMultiplier while away).
# ============================================================================
using { /Fortnite.com/Devices }
using { /Verse.org/Simulation }

IncubationTickSeconds : float = 1.0

(G:sea_beast_game_device).FirstEmptyIncubator(Session:player_session)<transacts><decides>:int =
    var Found : int = -1
    for (I -> Incubator : Session.Profile.Incubators, Found < 0, Incubator.EggTypeID = 0):
        set Found = I
    Found >= 0
    Found

(G:sea_beast_game_device).OnIncubatorInteracted(LagoonIndex:int, Index:int, Agent:agent):void =
    if (Session := G.ValidateLagoonAction[LagoonIndex, Agent]):
        if (Incubator := Session.Profile.Incubators[Index]):
            if (Incubator.EggTypeID = 0):
                if (Carried := Session.Carried[0]):
                    G.SecureCarriedEgg(Session, Carried, Index)
                else:
                    G.ShowToast(Session, "BRING A SEA EGG HOME TO PLACE IT HERE.", ThemeMuted)
            else if (Incubator.IsReady[]):
                G.StartHatch(Session, Index)
            else:
                Remaining := G.RealSecondsRemaining(Incubator)
                Hint := if (G.IsNight[]) then "  NIGHT TIDE: 10X GROWTH" else ""
                G.ShowToast(Session, "INCUBATING... {FormatClock(Remaining)}{Hint}", ThemeTurquoise)
    else:
        G.RejectForeignLagoon(Agent)

(G:sea_beast_game_device).PlaceEggInIncubator(Session:player_session, Index:int, EggTypeID:int, IsTutorial:logic):void =
    if (Incubator := Session.Profile.Incubators[Index]):
        set Incubator.EggTypeID = EggTypeID
        set Incubator.Progress = 0.0
        set Incubator.Required = if (IsTutorial?) then TutorialIncubationSeconds else IncubationSecondsForEgg(EggTypeID)
        G.ShowIncubatorEggVisual(Session, Index)
        G.UpdateIncubatorSign(Session, Index)

(G:sea_beast_game_device).RealSecondsRemaining(Incubator:incubator_state)<transacts>:float =
    (Incubator.Required - Incubator.Progress) / MaxF(G.IncubationMultiplier(), 0.01)

(G:sea_beast_game_device).ShowIncubatorEggVisual(Session:player_session, Index:int):void =
    if (Lagoon := G.GetLagoonForSession[Session], Incubator := Session.Profile.Incubators[Index]):
        if (Incubator.EggTypeID > 0, Asset := G.GetEggPropAsset[Incubator.EggTypeID]):
            spawn{ G.ShowIncubatorEggAsync(Lagoon, Index, Asset, logic{Incubator.IsReady[]}) }
        else:
            Lagoon.HideIncubatorEgg(Index)

(G:sea_beast_game_device).ShowIncubatorEggAsync(Lagoon:lagoon_device, Index:int, Asset:creative_prop_asset, Ready:logic)<suspends>:void =
    Lagoon.ShowIncubatorEgg(Index, Asset)
    if (Ready?):
        Lagoon.SetIncubatorReady(Index, true)

# Re-creates incubator eggs and signs (join, Deep Dive, dev reset).
(G:sea_beast_game_device).RestoreIncubatorVisuals(Session:player_session):void =
    for (I -> Incubator : Session.Profile.Incubators):
        G.ShowIncubatorEggVisual(Session, I)
        G.UpdateIncubatorSign(Session, I)

(G:sea_beast_game_device).UpdateIncubatorSign(Session:player_session, Index:int):void =
    if (Lagoon := G.GetLagoonForSession[Session], Incubator := Session.Profile.Incubators[Index]):
        if (Incubator.EggTypeID = 0):
            Lagoon.SetIncubatorTimer(Index, "EMPTY")
            Lagoon.SetIncubatorPrompt(Index, PlaceEggPrompt)
        else if (Incubator.IsReady[]):
            Lagoon.SetIncubatorTimer(Index, "{EggName(Incubator.EggTypeID)}\nREADY TO HATCH!")
            Lagoon.SetIncubatorPrompt(Index, HatchPrompt)
        else:
            Remaining := FormatClock(G.RealSecondsRemaining(Incubator))
            NightText := if (G.IsNight[]) then "\nNIGHT TIDE 10X" else ""
            Lagoon.SetIncubatorTimer(Index, "{EggName(Incubator.EggTypeID)}\n{Remaining}{NightText}")
            Lagoon.SetIncubatorPrompt(Index, IncubatingPrompt(Remaining))

(G:sea_beast_game_device).RunIncubationLoop()<suspends>:void =
    var LastTime : float = G.GetNow()
    loop:
        Sleep(IncubationTickSeconds)
        Now := G.GetNow()
        Delta := ClampF(Now - LastTime, 0.0, 5.0)
        set LastTime = Now
        Growth := Delta * G.IncubationMultiplier()
        for (Player -> Session : G.Sessions, Session.Loaded?):
            for (I -> Incubator : Session.Profile.Incubators, Incubator.EggTypeID > 0):
                if (Incubator.Progress < Incubator.Required):
                    set Incubator.Progress = MinF(Incubator.Required, Incubator.Progress + Growth)
                    if (Incubator.Progress >= Incubator.Required):
                        G.OnIncubatorReady(Session, I)
                G.UpdateIncubatorSign(Session, I)

(G:sea_beast_game_device).OnIncubatorReady(Session:player_session, Index:int):void =
    if (Lagoon := G.GetLagoonForSession[Session]):
        Lagoon.SetIncubatorReady(Index, true)
    if (Incubator := Session.Profile.Incubators[Index]):
        G.ShowToast(Session, "{EggName(Incubator.EggTypeID)} IS READY TO HATCH!", ThemeGold)
    G.PlaySfx(Session, sfx_key.Claim)
    G.OnTutorialEggReady(Session)
