# ============================================================================
# RIDE A SEA BEAST - EconomyManager.verse
# Cash is only ever changed here (AddCash / TrySpend). One centralized tick
# pays every player - creatures never run their own income loops.
#
#   Income/sec = sum(placed creature income)
#              x Deep Dive permanent multiplier
#              x (1 + friend boost)
#              x temporary event modifier (weather)
# ============================================================================
using { /Verse.org/Simulation }

(G:sea_beast_game_device).AddCash(Session:player_session, Amount:float):void =
    if (Amount > 0.0, Amount.IsFinite[]):
        set Session.Profile.Cash += Amount
        set Session.Profile.LifetimeCash += Amount

# Atomic spend: succeeds and deducts only when the player can afford it.
(G:sea_beast_game_device).TrySpend(Session:player_session, Amount:float)<transacts><decides>:void =
    Amount >= 0.0
    Session.Profile.Cash >= Amount
    set Session.Profile.Cash = Session.Profile.Cash - Amount

(G:sea_beast_game_device).CanAfford(Session:player_session, Amount:float)<transacts><decides>:void =
    Session.Profile.Cash >= Amount

(G:sea_beast_game_device).ComputeBaseIncome(Session:player_session)<transacts>:float =
    var Total : float = 0.0
    for (C : G.GetPlacedCreatures(Session)):
        set Total += CreatureIncomePerSecond(C)
    Total

(G:sea_beast_game_device).ComputeIncomePerSecond(Session:player_session, IncludeTemporary:logic)<transacts>:float =
    Base := G.ComputeBaseIncome(Session)
    Permanent := Session.Profile.PermanentMoneyMultiplier
    Friend := 1.0 + Session.FriendBoost
    EventModifier := if (IncludeTemporary?) then G.CurrentIncomeModifier() else 1.0
    Base * Permanent * Friend * EventModifier

(G:sea_beast_game_device).RunEconomyLoop()<suspends>:void =
    var TickCount : int = 0
    loop:
        Sleep(EconomyTickSeconds)
        set TickCount += 1
        for (Player -> Session : G.Sessions, Session.Loaded?):
            set Session.FriendBoost = G.ComputeFriendBoost(Session)
            Income := G.ComputeIncomePerSecond(Session, true)
            set Session.LastIncomePerSecond = Income
            G.AddCash(Session, Income * EconomyTickSeconds)
            # Lagoon income signs are refreshed every 5 ticks.
            if (ModInt(TickCount, 5) = 0):
                G.RefreshLagoonSigns(Session)
            Session.UI.RefreshCash()
