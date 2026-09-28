# ============================================================================
# RIDE A SEA BEAST - HatchLuckManager.verse
# Hatch Luck upgrades at each Lagoon. Five-upgrade cycle (+1 +1 +1 +1 +5).
# Prices come ONLY from HatchLuckUpgradeCost (ProgressionConfig.verse), which
# the signs and menus also use, so displayed and charged prices always match.
# ============================================================================
using { /Verse.org/Simulation }

# Safety cap for a single "buy max" press.
HatchLuckMaxPurchasesPerPress : int = 1000

# (upgrades a BUY MAX press would buy right now, their total price), using the
# same price formula and per-press cap as TryUpgradeHatchLuck.
(G:sea_beast_game_device).HatchLuckMaxPurchase(Session:player_session)<transacts>:tuple(int, float) =
    P := Session.Profile
    var Count : int = 0
    var Total : float = 0.0
    loop:
        if (Count >= HatchLuckMaxPurchasesPerPress):
            break
        Next := HatchLuckUpgradeCost(P.HatchLuckUpgrades + Count)
        if (Total + Next > P.Cash):
            break
        set Total += Next
        set Count += 1
    (Count, Total)

(G:sea_beast_game_device).TryUpgradeHatchLuck(Session:player_session, BuyMax:logic):void =
    P := Session.Profile
    var Bought : int = 0
    loop:
        Cost := HatchLuckUpgradeCost(P.HatchLuckUpgrades)
        if (G.TrySpend[Session, Cost]):
            set P.HatchLuckUpgrades += 1
            set Bought += 1
        else:
            break
        if (not BuyMax? or Bought >= HatchLuckMaxPurchasesPerPress):
            break
    if (Bought > 0):
        G.PlaySfx(Session, sfx_key.Purchase)
        Plural := if (Bought > 1) then "S" else ""
        LuckText := FormatMultiplier(HatchLuckForUpgrades(P.HatchLuckUpgrades))
        G.ShowToast(Session, "HATCH LUCK {LuckText}  (+{Bought} UPGRADE{Plural})", ThemeGold)
        G.TrackFirst(Session, analytics_key.FirstLuckUpgrade)
        G.RefreshHatchLuckSign(Session)
        G.RefreshHud(Session)
        Session.UI.RefreshOpenMenu()
        G.SaveSession(Session)
    else:
        G.ShowToast(Session, "NOT ENOUGH CASH! NEXT UPGRADE COSTS {FormatCash(HatchLuckUpgradeCost(P.HatchLuckUpgrades))}.", ThemeDanger)
        G.PlaySfx(Session, sfx_key.Error)
