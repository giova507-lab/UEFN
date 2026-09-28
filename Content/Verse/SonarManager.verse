# ============================================================================
# RIDE A SEA BEAST - SonarManager.verse
# Sonar Shack stock (independent restock timer), purchases and tracking.
# A Sonar NEVER creates or teleports anything: it only points at an egg that
# already exists. Each Sonar tracks one rarity (Pocket = Rare ... Leviathan =
# Ethereal). If another player claims the target: "SIGNAL LOST! SEARCHING..."
# and the Sonar retargets another eligible egg automatically.
# Activation consumes one charge; no charge is used if nothing is detected.
# ============================================================================
using { /Fortnite.com/Characters }
using { /Verse.org/Simulation }
using { /Verse.org/Random }
using { /UnrealEngine.com/Temporary/SpatialMath }

# Safety cap on sonars bought automatically per tier and restock.
SonarAutoBuyMaxPerRestock : int = 20

RollSonarStock()<transacts>:[]int =
    for (Def : SonarDefs):
        if (GetRandomFloat(0.0, 1.0) <= Def.StockChance) then GetRandomInt(Def.StockMin, Def.StockMax) else 0

(G:sea_beast_game_device).InitSonarStock():void =
    set G.GlobalSonarStock = RollSonarStock()
    set G.SonarRestockEnd = G.GetNow() + SonarRestockSeconds

# On join: keep the player's saved personal stock if it was rolled less than
# one restock period ago, so leaving and rejoining cannot re-roll the shop.
(G:sea_beast_game_device).InitSessionSonarStock(Session:player_session):void =
    if (SharedSonarStock?):
        return
    P := Session.Profile
    Age := GetSecondsSinceEpoch() - P.SonarStockEpoch
    if (P.SonarStock.Length <> SonarTierCount or P.SonarStockEpoch <= 0.0 or Age < 0.0 or Age >= SonarRestockSeconds):
        G.RollSessionSonarStock(Session)

(G:sea_beast_game_device).RollSessionSonarStock(Session:player_session):void =
    set Session.Profile.SonarStock = RollSonarStock()
    set Session.Profile.SonarStockEpoch = GetSecondsSinceEpoch()

(G:sea_beast_game_device).GetSonarRestockRemaining()<transacts>:float =
    MaxF(0.0, G.SonarRestockEnd - G.GetNow())

(G:sea_beast_game_device).RunSonarRestockLoop()<suspends>:void =
    loop:
        Sleep(MaxF(1.0, G.SonarRestockEnd - G.GetNow()))
        set G.GlobalSonarStock = RollSonarStock()
        set G.SonarRestockEnd = G.GetNow() + SonarRestockSeconds
        for (Player -> Session : G.Sessions, Session.Loaded?):
            if (not SharedSonarStock?):
                G.RollSessionSonarStock(Session)
            G.RunSonarAutoBuy(Session)
            Session.UI.RefreshOpenMenu()
            G.SaveSession(Session)
        LogSea("Sonar Shack restocked.")

(G:sea_beast_game_device).GetSonarStock(Session:player_session, Tier:int)<transacts>:int =
    Source := if (SharedSonarStock?) then G.GlobalSonarStock else Session.Profile.SonarStock
    if (Count := Source[Tier]) then Count else 0

(G:sea_beast_game_device).BuySonar(Session:player_session, Tier:int):void =
    if (Def := GetSonarDef[Tier]):
        if (G.GetSonarStock(Session, Tier) <= 0):
            G.ShowToast(Session, "{Def.Name} IS OUT OF STOCK!", ThemeDanger)
            G.PlaySfx(Session, sfx_key.Error)
            return
        if (G.TrySpend[Session, Def.Price]):
            G.TakeSonarFromStock(Session, Tier)
            G.PlaySfx(Session, sfx_key.Purchase)
            G.ShowToast(Session, "BOUGHT {Def.Name}!", ThemeCash)
            Session.UI.RefreshOpenMenu()
            G.RefreshHud(Session)
            G.SaveSession(Session)
        else:
            G.ShowToast(Session, "NOT ENOUGH CASH! {Def.Name} COSTS {FormatCash(Def.Price)}.", ThemeDanger)
            G.PlaySfx(Session, sfx_key.Error)

# Moves one sonar of Tier from the shop stock into the player's inventory.
# Callers have already checked the stock and charged the price.
(G:sea_beast_game_device).TakeSonarFromStock(Session:player_session, Tier:int):void =
    if (SharedSonarStock?):
        if (Old := G.GlobalSonarStock[Tier], set G.GlobalSonarStock[Tier] = Old - 1) {}
    else:
        if (Old := Session.Profile.SonarStock[Tier], set Session.Profile.SonarStock[Tier] = Old - 1) {}
    if (Owned := Session.Profile.SonarInventory[Tier], set Session.Profile.SonarInventory[Tier] = Owned + 1) {}

# ---------------------------------------------------------------- Auto-Buy -
(G:sea_beast_game_device).IsSonarAutoBuyOn(Session:player_session, Tier:int)<transacts><decides>:void =
    Session.Profile.SonarAutoBuy[Tier]?

(G:sea_beast_game_device).ToggleSonarAutoBuy(Session:player_session, Tier:int):void =
    if (SharedSonarStock?):
        # With one shared stock, auto-buy would let the first player in the
        # list take everything at every restock, so it is per-player only.
        G.ShowToast(Session, "AUTO-BUY IS NOT AVAILABLE WITH SHARED SHOP STOCK.", ThemeMuted)
    else if (Def := GetSonarDef[Tier]):
        NewValue := if (G.IsSonarAutoBuyOn[Session, Tier]) then false else true
        if (set Session.Profile.SonarAutoBuy[Tier] = NewValue) {}
        StateText := if (NewValue?) then "ON" else "OFF"
        G.ShowToast(Session, "AUTO-BUY {Def.Name}: {StateText}", ThemeCyan)
        if (NewValue?):
            # Also buy what is in stock right now.
            G.RunSonarAutoBuy(Session)
        Session.UI.RefreshOpenMenu()
        G.SaveSession(Session)

# Buys the available stock of every tier with AUTO-BUY on, while the player
# can afford it. Runs on every restock and when a tier is switched on.
(G:sea_beast_game_device).RunSonarAutoBuy(Session:player_session):void =
    if (SharedSonarStock?):
        return
    var BoughtTotal : int = 0
    for (Tier -> Enabled : Session.Profile.SonarAutoBuy, Enabled?, Def := GetSonarDef[Tier]):
        var Bought : int = 0
        loop:
            if (G.GetSonarStock(Session, Tier) <= 0 or Bought >= SonarAutoBuyMaxPerRestock):
                break
            if (G.TrySpend[Session, Def.Price]):
                G.TakeSonarFromStock(Session, Tier)
                set Bought += 1
            else:
                break
        if (Bought > 0):
            set BoughtTotal += Bought
            G.ShowToast(Session, "AUTO-BUY: +{Bought} {Def.Name}", ThemeCash)
    if (BoughtTotal > 0):
        G.PlaySfx(Session, sfx_key.Purchase)
        G.RefreshHud(Session)
        G.SaveSession(Session)

# Nearest active, unreserved egg whose rarity this Sonar tier tracks.
(G:sea_beast_game_device).FindSonarTarget(Session:player_session, Tier:int)<transacts><decides>:world_egg =
    Def := GetSonarDef[Tier]
    Center := G.GetPickupCenter[Session]
    var Best : ?world_egg = false
    var BestDistance : float = 100000000000.0
    for (Egg : G.WorldEggs, Egg.Active?, not Egg.ReservedFor?, EggRarity(Egg.EggTypeID) = Def.TracksRarity):
        D := DistanceSquared(Center, Egg.Position)
        if (D < BestDistance):
            set BestDistance = D
            set Best = option{Egg}
    Best?

(G:sea_beast_game_device).ActivateSonar(Session:player_session, Tier:int):void =
    if (Def := GetSonarDef[Tier]):
        Owned := if (Count := Session.Profile.SonarInventory[Tier]) then Count else 0
        if (Owned <= 0):
            G.ShowToast(Session, "YOU HAVE NO {Def.Name}. VISIT FINN AT THE SONAR SHACK!", ThemeWarning)
            return
        if (Session.ActiveSonarTier = Tier):
            G.ShowToast(Session, "YOUR {Def.Name} IS ALREADY TRACKING.", ThemeMuted)
            return
        if (Target := G.FindSonarTarget[Session, Tier]):
            # Switching to another tier replaces the running sonar (its charge
            # was spent when it started).
            if (Session.ActiveSonarTier >= 0):
                G.StopSonar(Session, false)
            if (set Session.Profile.SonarInventory[Tier] = Owned - 1) {}
            set Session.ActiveSonarTier = Tier
            set Session.SonarTargetUID = Target.UID
            set Session.SonarStartTime = G.GetNow()
            set Session.NextPingTime = G.GetNow()
            set Session.SonarSearching = false
            G.PlaySfx(Session, sfx_key.SonarPing)
            if (Center := G.GetPickupCenter[Session]):
                G.PlayVfxAt(vfx_key.SonarPulse, Center)
            G.ShowToast(Session, "{Def.Name} ACTIVATED! FOLLOW THE SIGNAL.", ThemeCyan)
            G.TrackFirst(Session, analytics_key.FirstSonar)
            Session.UI.CloseMenu()
            G.RefreshHud(Session)
            G.SaveSession(Session)
        else:
            G.ShowToast(Session, "NO {RarityName(Def.TracksRarity)} SEA EGGS DETECTED. TRY AGAIN AFTER THE TIDE CHANGES.", ThemeMuted)

(G:sea_beast_game_device).StopSonar(Session:player_session, ShowMessage:logic):void =
    if (Session.ActiveSonarTier >= 0):
        set Session.ActiveSonarTier = -1
        set Session.SonarTargetUID = 0
        set Session.SonarSearching = false
        Session.UI.HideSonar()
        if (ShowMessage?):
            G.ShowToast(Session, "SONAR POWERED DOWN.", ThemeMuted)

# Called by EggManager whenever any egg is claimed.
(G:sea_beast_game_device).OnWorldEggClaimed(Egg:world_egg, Claimer:player_session):void =
    for (Player -> Session : G.Sessions, Session.ActiveSonarTier >= 0, Session.SonarTargetUID = Egg.UID):
        if (Player = Claimer.Player):
            G.StopSonar(Session, false)
            G.ShowToast(Session, "SONAR TARGET ACQUIRED!", ThemeCash)
        else:
            G.HandleSonarSignalLost(Session)

(G:sea_beast_game_device).HandleSonarSignalLost(Session:player_session):void =
    set Session.SonarTargetUID = 0
    if (not Session.SonarSearching?):
        set Session.SonarSearching = true
        G.ShowToast(Session, "SIGNAL LOST!\nSEARCHING...", ThemeDanger)
        G.PlaySfx(Session, sfx_key.SonarLost)
    G.TryRetargetSonar(Session)

(G:sea_beast_game_device).TryRetargetSonar(Session:player_session):void =
    if (Target := G.FindSonarTarget[Session, Session.ActiveSonarTier]):
        set Session.SonarTargetUID = Target.UID
        set Session.SonarSearching = false
        G.ShowToast(Session, "NEW SIGNAL FOUND!", ThemeCyan)
        G.PlaySfx(Session, sfx_key.SonarPing)

(G:sea_beast_game_device).RunSonarLoop()<suspends>:void =
    loop:
        Sleep(SonarTickSeconds)
        Now := G.GetNow()
        for (Player -> Session : G.Sessions, Session.Loaded?, Session.ActiveSonarTier >= 0):
            G.UpdateSonar(Session, Now)

(G:sea_beast_game_device).UpdateSonar(Session:player_session, Now:float):void =
    if (Now - Session.SonarStartTime > SonarMaxTrackSeconds):
        G.StopSonar(Session, false)
        G.ShowToast(Session, "SONAR BATTERY DEPLETED.", ThemeMuted)
        return
    if (Session.SonarSearching?):
        G.TryRetargetSonar(Session)
        Session.UI.ShowSonarSearching(G.GetSonarName(Session.ActiveSonarTier))
        return
    if (Egg := G.FindWorldEgg[Session.SonarTargetUID], Egg.Active?):
        if (Center := G.GetPickupCenter[Session], Character := Session.Player.GetFortCharacter[]):
            DX := Egg.Position.X - Center.X
            DY := Egg.Position.Y - Center.Y
            Dist := Sqrt(DX * DX + DY * DY)
            TargetYaw := RadiansToDegrees(ArcTan(DY, DX))
            Angles := Character.GetViewRotation().GetYawPitchRollDegrees()
            CameraYaw := if (Yaw := Angles[0]) then Yaw else 0.0
            Relative := WrapDegrees(TargetYaw - CameraYaw)
            Session.UI.ShowSonar(EggName(Egg.EggTypeID), FormatDistance(Dist), Relative, RarityColor(EggRarity(Egg.EggTypeID)))
            if (Now >= Session.NextPingTime):
                G.PlaySfx(Session, sfx_key.SonarPing)
                Closeness := ClampF(Dist / SonarPingFarDistance, 0.0, 1.0)
                set Session.NextPingTime = Now + SonarPingMinInterval + (SonarPingMaxInterval - SonarPingMinInterval) * Closeness
    else:
        G.HandleSonarSignalLost(Session)

(G:sea_beast_game_device).GetSonarName(Tier:int)<transacts>:string =
    if (Def := GetSonarDef[Tier]) then Def.Name else "SONAR"
