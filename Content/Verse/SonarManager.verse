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

RollSonarStock()<transacts>:[]int =
    for (Def : SonarDefs):
        if (GetRandomFloat(0.0, 1.0) <= Def.StockChance) then GetRandomInt(Def.StockMin, Def.StockMax) else 0

(G:sea_beast_game_device).InitSonarStock():void =
    set G.GlobalSonarStock = RollSonarStock()
    set G.SonarRestockEnd = G.GetNow() + SonarRestockSeconds

(G:sea_beast_game_device).InitSessionSonarStock(Session:player_session):void =
    set Session.SonarStock = if (SharedSonarStock?) then G.GlobalSonarStock else RollSonarStock()

(G:sea_beast_game_device).GetSonarRestockRemaining()<transacts>:float =
    MaxF(0.0, G.SonarRestockEnd - G.GetNow())

(G:sea_beast_game_device).RunSonarRestockLoop()<suspends>:void =
    loop:
        Sleep(MaxF(1.0, G.SonarRestockEnd - G.GetNow()))
        set G.GlobalSonarStock = RollSonarStock()
        set G.SonarRestockEnd = G.GetNow() + SonarRestockSeconds
        for (Player -> Session : G.Sessions, Session.Loaded?):
            G.InitSessionSonarStock(Session)
            Session.UI.RefreshOpenMenu()
        LogSea("Sonar Shack restocked.")

(G:sea_beast_game_device).GetSonarStock(Session:player_session, Tier:int)<transacts>:int =
    Source := if (SharedSonarStock?) then G.GlobalSonarStock else Session.SonarStock
    if (Count := Source[Tier]) then Count else 0

(G:sea_beast_game_device).BuySonar(Session:player_session, Tier:int):void =
    if (Def := GetSonarDef[Tier]):
        if (G.GetSonarStock(Session, Tier) <= 0):
            G.ShowToast(Session, "{Def.Name} IS OUT OF STOCK!", ThemeDanger)
            G.PlaySfx(Session, sfx_key.Error)
            return
        if (G.TrySpend[Session, Def.Price]):
            if (SharedSonarStock?):
                if (Old := G.GlobalSonarStock[Tier], set G.GlobalSonarStock[Tier] = Old - 1) {}
            else:
                if (Old := Session.SonarStock[Tier], set Session.SonarStock[Tier] = Old - 1) {}
            if (Owned := Session.Profile.SonarInventory[Tier], set Session.Profile.SonarInventory[Tier] = Owned + 1) {}
            G.PlaySfx(Session, sfx_key.Purchase)
            G.ShowToast(Session, "BOUGHT {Def.Name}!", ThemeCash)
            Session.UI.RefreshOpenMenu()
            G.RefreshHud(Session)
            G.SaveSession(Session)
        else:
            G.ShowToast(Session, "NOT ENOUGH CASH! {Def.Name} COSTS {FormatCash(Def.Price)}.", ThemeDanger)
            G.PlaySfx(Session, sfx_key.Error)

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
        if (Target := G.FindSonarTarget[Session, Tier]):
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
