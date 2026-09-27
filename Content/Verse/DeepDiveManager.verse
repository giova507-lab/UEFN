# ============================================================================
# RIDE A SEA BEAST - DeepDiveManager.verse
# DEEP DIVE (long-term reset).
#   RESET: Cash, Hatch Luck.
#   KEEP : every Sea Beast, mutations, Ocean Index, Deep Dive count,
#          permanent multiplier, Lagoon slots, cosmetics.
#   Each dive: +1X permanent Money Multiplier and +1 Lagoon slot.
# The required creature is only checked for ownership - never consumed.
# ============================================================================
using { /Fortnite.com/Devices }
using { /Verse.org/Simulation }

# Succeeds when the player meets every requirement for their next dive.
(G:sea_beast_game_device).IsDeepDiveReady(Session:player_session)<transacts><decides>:void =
    Next := GetNextDeepDive[Session.Profile.DeepDiveCount]
    Session.Profile.Cash >= Next.CashRequired
    G.OwnsCreatureType[Session, Next.RequiredCreatureID]

(G:sea_beast_game_device).DeepDiveSignText(Session:player_session)<transacts>:string =
    P := Session.Profile
    if (Next := GetNextDeepDive[P.DeepDiveCount]):
        CashOk := if (P.Cash >= Next.CashRequired) then "OK" else "NEEDED"
        BeastOk := if (G.OwnsCreatureType[Session, Next.RequiredCreatureID]) then "OK" else "NEEDED"
        Status := if (G.IsDeepDiveReady[Session]) then "READY!" else "NOT READY"
        "DEEP DIVE {Next.Level}\n{FormatCash(Next.CashRequired)} ({CashOk})\n{CreatureName(Next.RequiredCreatureID)} ({BeastOk})\n{Status}"
    else:
        "MAX DEEP DIVE REACHED\nMONEY x{FormatCompact(P.PermanentMoneyMultiplier)}"

(G:sea_beast_game_device).RequestDeepDive(Session:player_session):void =
    if (Session.DeepDiveRunning?):
        return
    if (not GetNextDeepDive[Session.Profile.DeepDiveCount]):
        G.ShowToast(Session, "YOU HAVE REACHED THE DEEPEST DEPTHS!", ThemeGold)
        return
    if (G.IsDeepDiveReady[Session]):
        Session.UI.ShowConfirm("DEEP DIVE NOW?\nYOUR CASH AND HATCH LUCK RESET.\nYOU KEEP EVERY SEA BEAST, MUTATION AND DISCOVERY.", confirm_action.DeepDive)
    else:
        G.ShowToast(Session, "NOT READY FOR THE DEEP DIVE YET.", ThemeDanger)
        G.PlaySfx(Session, sfx_key.Error)

(G:sea_beast_game_device).ExecuteDeepDive(Session:player_session):void =
    if (Session.DeepDiveRunning?):
        return
    P := Session.Profile
    if (Next := GetNextDeepDive[P.DeepDiveCount], G.IsDeepDiveReady[Session]):
        OldMultiplier := P.PermanentMoneyMultiplier
        OldSlots := G.GetLagoonSlots(Session)
        set P.DeepDiveCount += 1
        set P.PermanentMoneyMultiplier = PermanentMultiplierForDives(P.DeepDiveCount)
        set P.Cash = StartingCash
        set P.HatchLuckUpgrades = 0
        NewSlots := G.GetLagoonSlots(Session)
        G.TrackFirst(Session, analytics_key.FirstDeepDive)
        G.SaveSession(Session)
        spawn{ G.RunDeepDiveSequence(Session, OldMultiplier, P.PermanentMoneyMultiplier, OldSlots, NewSlots) }
    else:
        G.ShowToast(Session, "NOT READY FOR THE DEEP DIVE YET.", ThemeDanger)

(G:sea_beast_game_device).RunDeepDiveSequence(Session:player_session, OldMultiplier:float, NewMultiplier:float, OldSlots:int, NewSlots:int)<suspends>:void =
    set Session.DeepDiveRunning = true
    G.ForceDismount(Session)
    Session.UI.CloseMenu()
    if (Lagoon := G.GetLagoonForSession[Session]):
        # Camera focuses on the Lagoon, the ocean pulls back, a wave rises.
        Lagoon.FocusDeepDiveCamera(Session.Player)
        G.PlaySfx(Session, sfx_key.DeepDive)
        Lagoon.PlayDeepDiveWave()
        G.PlayVfxAt(vfx_key.DeepDiveWave, Lagoon.GetCenter())
        G.PlayCameraShake(Session, true)
        Session.UI.ShowDeepDiveTransition()
        Sleep(1.4)
        # The screen transitions underwater; a leviathan silhouette passes.
        for (Post : G.UnderwaterPostProcess):
            Post.BlendIn(Session.Player)
        for (Sequence : G.DeepDiveCinematic):
            Sequence.Play(Session.Player)
        Sleep(3.2)
        Session.UI.ShowDeepDiveComplete(OldMultiplier, NewMultiplier, OldSlots, NewSlots)
        Sleep(4.5)
        for (Sequence : G.DeepDiveCinematic):
            Sequence.Stop(Session.Player)
        for (Post : G.UnderwaterPostProcess):
            Post.BlendOut(Session.Player)
        Lagoon.ReleaseDeepDiveCamera(Session.Player)
        Session.UI.HideDeepDiveOverlay()
    set Session.DeepDiveRunning = false
    G.RefreshLagoon(Session)
    G.RefreshHud(Session)
    Session.UI.RefreshOpenMenu()
    G.AnnounceGlobalText(Session.Player, "COMPLETED DEEP DIVE {Session.Profile.DeepDiveCount}!")
    G.SaveSession(Session)
