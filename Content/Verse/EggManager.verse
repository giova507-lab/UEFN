# ============================================================================
# RIDE A SEA BEAST - EggManager.verse
# World Sea Eggs: Tide Resets, spawn point selection, claiming, carrying,
# cracking and delivery. Verse is authoritative over every egg:
#   * TryClaimEgg never suspends between "is it free?" and "it is mine", so
#     two players pressing at the same time can never both get the egg.
#   * Eggs are removed from the world list the moment they are claimed.
# ============================================================================
using { /Fortnite.com/Devices }
using { /Fortnite.com/Characters }
using { /Verse.org/Simulation }
using { /Verse.org/Random }
using { /UnrealEngine.com/Temporary/SpatialMath }

EggWatchTickSeconds : float = 0.2

# ---------------------------------------------------------------- Tides ----
(G:sea_beast_game_device).RunTideLoop()<suspends>:void =
    G.PerformTideReset(false)
    loop:
        set G.TideEndTime = G.GetNow() + EggResetSeconds
        race:
            Sleep(EggResetSeconds)
            G.ForceTideEvent.Await()
        G.PerformTideReset(true)

(G:sea_beast_game_device).GetTideRemaining()<transacts>:float =
    MaxF(0.0, G.TideEndTime - G.GetNow())

(G:sea_beast_game_device).PerformTideReset(Announce:logic):void =
    # 1. Remove expired unclaimed eggs. Tutorial eggs are personal and stay,
    #    unless the player they were reserved for is gone.
    for (Egg : G.WorldEggs, Egg.Active?, not Egg.ReservedFor?):
        set Egg.Active = false
        G.RemoveEggVisual(Egg)
    for (Egg : G.WorldEggs, Egg.Active?, Reserved := Egg.ReservedFor?, not G.Sessions[Reserved]):
        set Egg.Active = false
        G.RemoveEggVisual(Egg)
    set G.WorldEggs = for (Egg : G.WorldEggs, Egg.Active?). Egg
    # 2 + 3. Select new spawn points and spawn, rarest eggs first so they get
    # first pick of shared points.
    var SpawnedRare : []int = array{}
    var EggIndex : int = EggDefs.Length - 1
    loop:
        if (EggIndex < 0):
            break
        if (Def := EggDefs[EggIndex]):
            Spawned := G.SpawnEggsOfType(Def)
            if (Spawned > 0, Def.AnnounceGlobally?):
                set SpawnedRare += array{Def.ID}
        set EggIndex -= 1
    # 4. Current Tracker.
    for (Player -> Session : G.Sessions):
        Session.UI.RefreshTrackerIfOpen()
    # 5. Announcements.
    if (Announce?):
        G.AnnounceGlobal("THE TIDE HAS CHANGED!\nNEW SEA EGGS HAVE APPEARED!", ThemeCyan)
        G.PlaySfxGlobal(sfx_key.TideReset)
    for (EggID : SpawnedRare):
        R := EggRarity(EggID)
        if (R = beast_rarity.Ethereal):
            G.AnnounceGlobal("AN {EggName(EggID)} HAS SURFACED!", RarityColorEthereal)
            G.PlaySfxGlobal(sfx_key.EtherealEggSpawn)
        else:
            G.AnnounceGlobal("A {EggName(EggID)} HAS APPEARED!", RarityColorDivine)
            G.PlaySfxGlobal(sfx_key.DivineEggSpawn)
    LogSea("Tide reset: {G.WorldEggs.Length} eggs active.")

# Picks SpawnCount random eligible points (weighted, no repeats) and spawns.
# Avoids reusing the point this egg type used last tide when possible.
(G:sea_beast_game_device).SpawnEggsOfType(Def:egg_def):int =
    LastIndex := if (L := G.LastEggPointByType[Def.ID - 1]) then L else -1
    AllCandidates := for (I -> Point : G.SpawnPoints, not Point.TutorialOnly?, not Point.IsOccupied[], Point.AcceptsEgg[Def]). I
    Candidates := if (AllCandidates.Length > 1) then AllCandidates.RemoveAllElements(LastIndex) else AllCandidates
    var Remaining : []int = Candidates
    var SpawnedCount : int = 0
    var FirstPick : int = -1
    loop:
        if (SpawnedCount >= Def.SpawnCount or Remaining.Length = 0):
            break
        Pick := G.PickWeightedPoint(Remaining)
        if (FirstPick < 0):
            set FirstPick = Pick
        G.SpawnWorldEgg(Def.ID, Pick)
        set Remaining = Remaining.RemoveAllElements(Pick)
        set SpawnedCount += 1
    if (FirstPick >= 0):
        if (set G.LastEggPointByType[Def.ID - 1] = FirstPick) {}
    if (SpawnedCount < Def.SpawnCount):
        LogSeaWarning("{Def.Name}: wanted {Def.SpawnCount}, only {SpawnedCount} eligible spawn points free.")
    SpawnedCount

(G:sea_beast_game_device).PickWeightedPoint(Indices:[]int)<transacts>:int =
    var Total : float = 0.0
    for (I : Indices, Point := G.SpawnPoints[I]):
        set Total += MaxF(Point.SelectionWeight, 0.01)
    Roll := GetRandomFloat(0.0, Total)
    var Accumulated : float = 0.0
    var Chosen : int = if (First := Indices[0]) then First else 0
    var Done : logic = false
    for (I : Indices, not Done?, Point := G.SpawnPoints[I]):
        set Accumulated += MaxF(Point.SelectionWeight, 0.01)
        if (Roll <= Accumulated):
            set Chosen = I
            set Done = true
    Chosen

(G:sea_beast_game_device).SpawnWorldEgg(EggID:int, SpawnIndex:int):void =
    if (Point := G.SpawnPoints[SpawnIndex]):
        UID := G.NextEggUID
        set G.NextEggUID += 1
        Egg := world_egg:
            UID := UID
            EggTypeID := EggID
            SpawnIndex := SpawnIndex
            Position := Point.GetEggPosition()
            SpawnTime := G.GetNow()
        set G.WorldEggs += array{Egg}
        Asset : ?creative_prop_asset = if (A := G.GetEggPropAsset[EggID]) then option{A} else false
        Point.ShowEgg(UID, EggID, Asset)
        # A short surfacing burst for Legendary and Mythic eggs. Divine and
        # Ethereal eggs get none: their location must stay secret.
        # RareSpawnBeacon must be a one-shot (non-looping) effect.
        Tier := RarityIndex(EggRarity(EggID))
        if (Tier >= RarityIndex(beast_rarity.Legendary), Tier <= RarityIndex(beast_rarity.Mythic)):
            G.PlayVfxAt(vfx_key.RareSpawnBeacon, Egg.Position)

(G:sea_beast_game_device).RemoveEggVisual(Egg:world_egg):void =
    if (Egg.SpawnIndex >= 0):
        if (Point := G.SpawnPoints[Egg.SpawnIndex]):
            Point.HideEgg(Egg.UID)
    else if (Prop := Egg.TutorialProp?):
        if (Prop.IsValid[]):
            Prop.Dispose()
        set Egg.TutorialProp = false

(G:sea_beast_game_device).FindWorldEgg(UID:int)<transacts><decides>:world_egg =
    var Found : ?world_egg = false
    for (Egg : G.WorldEggs, not Found?, Egg.UID = UID):
        set Found = option{Egg}
    Found?

# Active (unclaimed, non-tutorial) eggs per egg ID - for the Current Tracker.
(G:sea_beast_game_device).GetActiveEggCounts()<transacts>:[]int =
    for (Def : EggDefs):
        var Count : int = 0
        for (Egg : G.WorldEggs, Egg.Active?, not Egg.ReservedFor?, Egg.EggTypeID = Def.ID):
            set Count += 1
        Count

# ---------------------------------------------------------------- Claims ---
# Button interaction ("TAKE SEA EGG") from an egg spawn point.
(G:sea_beast_game_device).OnEggPointInteracted(Point:egg_spawn_point_device, Agent:agent):void =
    if (Session := G.GetAgentSession[Agent]):
        if (Egg := G.FindWorldEgg[Point.ActiveEggUID]):
            G.TryClaimEgg(Session, Egg, true)
        else:
            G.ShowToast(Session, "EGG CLAIMED!", ThemeDanger)

# Validates and claims. Never suspends (atomic with respect to other players).
(G:sea_beast_game_device).TryClaimEgg(Session:player_session, Egg:world_egg, Interactive:logic):void =
    if (not Egg.Active?):
        if (Interactive?):
            G.ShowToast(Session, "EGG CLAIMED!", ThemeDanger)
        return
    if (Reserved := Egg.ReservedFor?, Reserved <> Session.Player):
        if (Interactive?):
            G.ShowToast(Session, "THIS EGG IS RESERVED FOR A NEW EXPLORER.", ThemeMuted)
        return
    if (not Session.Loaded? or Session.DeepDiveRunning? or Session.IntroRunning?):
        return
    if (Session.Carried.Length >= MaxEggBasket):
        if (Interactive?):
            G.ShowToast(Session, "YOUR EGG BASKET IS FULL! BRING YOUR EGG HOME FIRST.", ThemeWarning)
        return
    if (not G.IsPlayerAlive[Session]):
        return
    # ---- Claim (atomic) ----
    Now := G.GetNow()
    set Egg.Active = false
    set Egg.ClaimedBy = option{Session.Player}
    G.RemoveEggVisual(Egg)
    set G.WorldEggs = for (Other : G.WorldEggs, Other.UID <> Egg.UID). Other
    IsTutorial := logic{Egg.ReservedFor?}
    CarryTime := if (IsTutorial?) then CarrySecondsForEgg(Egg.EggTypeID) * 2.0 else CarrySecondsForEgg(Egg.EggTypeID)
    Carried := carried_egg{UID := Egg.UID, EggTypeID := Egg.EggTypeID, ClaimTime := Now, ExpireTime := Now + CarryTime, IsTutorial := IsTutorial}
    set Session.Carried += array{Carried}
    # ---- Feedback ----
    G.ShowCarryEffect(Session, EggRarity(Egg.EggTypeID))
    G.RegisterEggDiscovery(Session, Egg.EggTypeID)
    G.PlaySfx(Session, sfx_key.EggPickup)
    G.ShowToast(Session, "{EggName(Egg.EggTypeID)}  {FormatLuck(EggLuck(Egg.EggTypeID))}\nBRING IT HOME BEFORE IT CRACKS!", RarityColor(EggRarity(Egg.EggTypeID)))
    G.TrackFirst(Session, analytics_key.FirstEggFound)
    G.OnTutorialEggClaimed(Session, Egg.UID)
    G.OnWorldEggClaimed(Egg, Session)
    G.NotifyNearbyClaim(Egg, Session)
    if (RarityIndex(EggRarity(Egg.EggTypeID)) >= RarityIndex(beast_rarity.Mythic)):
        G.AnnounceGlobalAgent(Session.Player, EggName(Egg.EggTypeID), true)
    G.RefreshHud(Session)
    for (Player -> Other : G.Sessions):
        Other.UI.RefreshTrackerIfOpen()

# Players near an egg that someone else just took get clear feedback.
(G:sea_beast_game_device).NotifyNearbyClaim(Egg:world_egg, Claimer:player_session):void =
    for (Player -> Session : G.Sessions, Player <> Claimer.Player, Position := G.GetPickupCenter[Session]):
        if (DistanceSquared(Position, Egg.Position) <= 4.0 * EggPickupRadiusMounted * EggPickupRadiusMounted):
            G.ShowToast(Session, "EGG CLAIMED!", ThemeDanger)

(G:sea_beast_game_device).IsPlayerAlive(Session:player_session)<transacts><decides>:void =
    Character := Session.Player.GetFortCharacter[]
    Character.IsActive[]

# Where the player's egg reach is centered: the creature when riding.
(G:sea_beast_game_device).GetPickupCenter(Session:player_session)<transacts><decides>:vector3 =
    G.FindPickupCenter(Session)?

(G:sea_beast_game_device).FindPickupCenter(Session:player_session)<transacts>:?vector3 =
    if (Session.Mount.State = mount_state.Mounted):
        option{vector3{X := Session.Mount.PosX, Y := Session.Mount.PosY, Z := Session.Mount.PosZ}}
    else if (Character := Session.Player.GetFortCharacter[]):
        option{Character.GetTransform().Translation}
    else:
        false

(G:sea_beast_game_device).GetPickupRadius(Session:player_session)<transacts>:float =
    if (Session.Mount.State = mount_state.Mounted):
        MountedPickupRadius(Session.Mount.SizeClass)
    else if (ProximityPickupWhenOnFoot?):
        EggPickupRadiusOnFoot
    else:
        0.0

# ---------------------------------------------------------------- Watch ----
# Carry timers, Lagoon delivery and proximity claims for every player.
(G:sea_beast_game_device).RunEggWatchLoop()<suspends>:void =
    loop:
        Sleep(EggWatchTickSeconds)
        Now := G.GetNow()
        for (Player -> Session : G.Sessions, Session.Loaded?):
            G.UpdateCarriedEggs(Session, Now)
            G.CheckLagoonDelivery(Session)
            G.CheckProximityClaims(Session)

(G:sea_beast_game_device).CheckProximityClaims(Session:player_session):void =
    if (Session.Carried.Length < MaxEggBasket, Center := G.GetPickupCenter[Session]):
        Radius := G.GetPickupRadius(Session)
        if (Radius > 0.0):
            RadiusSquared := Radius * Radius
            var Claimed : logic = false
            for (Egg : G.WorldEggs, not Claimed?, Egg.Active?, DistanceSquared(Center, Egg.Position) <= RadiusSquared):
                if (not Egg.ReservedFor? or G.IsReservedFor[Egg, Session]):
                    G.TryClaimEgg(Session, Egg, false)
                    set Claimed = true

(G:sea_beast_game_device).IsReservedFor(Egg:world_egg, Session:player_session)<transacts><decides>:void =
    Reserved := Egg.ReservedFor?
    Reserved = Session.Player

(G:sea_beast_game_device).UpdateCarriedEggs(Session:player_session, Now:float):void =
    for (Carried : Session.Carried, Now >= Carried.ExpireTime):
        G.CrackCarriedEgg(Session, Carried)

(G:sea_beast_game_device).CrackCarriedEgg(Session:player_session, Carried:carried_egg):void =
    set Session.Carried = for (Other : Session.Carried, Other.UID <> Carried.UID). Other
    if (Session.Carried.Length = 0):
        G.ReleaseCarryEffect(Session)
    set Session.Profile.EggsLost += 1
    G.PlaySfx(Session, sfx_key.EggCrack)
    if (Center := G.GetPickupCenter[Session]):
        G.PlayVfxAt(vfx_key.EggCrackBurst, Center)
    Session.UI.ShowBigMessage("YOUR SEA EGG CRACKED!", ThemeDanger)
    G.Track(Session, analytics_key.EggLost)
    if (Carried.IsTutorial?):
        # Never soft-lock onboarding: give the new player another try.
        G.SpawnTutorialEgg(Session)
    G.RefreshHud(Session)
    G.SaveSession(Session)

(G:sea_beast_game_device).SecureCarriedEgg(Session:player_session, Carried:carried_egg, IncubatorIndex:int):void =
    set Session.Carried = for (Other : Session.Carried, Other.UID <> Carried.UID). Other
    if (Session.Carried.Length = 0):
        G.ReleaseCarryEffect(Session)
    G.PlaceEggInIncubator(Session, IncubatorIndex, Carried.EggTypeID, Carried.IsTutorial)
    set Session.Profile.EggsDelivered += 1
    G.PlaySfx(Session, sfx_key.EggPlace)
    if (Lagoon := G.GetLagoonForSession[Session]):
        G.PlayVfxAt(vfx_key.EggSecured, Lagoon.IncubatorEggTransform(IncubatorIndex).Translation)
    Session.UI.ShowBigMessage("EGG SECURED!", ThemeCash)
    G.TrackFirst(Session, analytics_key.FirstEggDelivered)
    G.Track(Session, analytics_key.EggSecured)
    G.OnTutorialEggSecured(Session)
    G.RefreshHud(Session)
    G.SaveSession(Session)

# ---------------------------------------------------------------- Tutorial -
(G:sea_beast_game_device).SpawnTutorialEgg(Session:player_session):void =
    G.ReleaseTutorialEgg(Session)
    if (Lagoon := G.GetLagoonForSession[Session]):
        UID := G.NextEggUID
        set G.NextEggUID += 1
        Egg := world_egg:
            UID := UID
            EggTypeID := TutorialEggID
            SpawnIndex := -1
            Position := Lagoon.GetTutorialEggPosition()
            SpawnTime := G.GetNow()
            ReservedFor := option{Session.Player}
            TutorialLagoon := Session.LagoonIndex
        set G.WorldEggs += array{Egg}
        set Session.TutorialEggUID = UID
        spawn{ G.SpawnTutorialEggProp(Egg, Lagoon) }

(G:sea_beast_game_device).SpawnTutorialEggProp(Egg:world_egg, Lagoon:lagoon_device)<suspends>:void =
    if (Asset := G.GetEggPropAsset[Egg.EggTypeID]):
        SpawnAt := transform{Translation := Egg.Position, Rotation := IdentityRotation(), Scale := vector3{X := 1.0, Y := 1.0, Z := 1.0}}
        MaybeProp := Lagoon.SpawnPropAsync(Asset, SpawnAt)
        if (Prop := MaybeProp?):
            if (Egg.Active?):
                set Egg.TutorialProp = option{Prop}
            else:
                Prop.Dispose()

(G:sea_beast_game_device).ReleaseTutorialEgg(Session:player_session):void =
    if (Session.TutorialEggUID > 0, Egg := G.FindWorldEgg[Session.TutorialEggUID]):
        set Egg.Active = false
        G.RemoveEggVisual(Egg)
        set G.WorldEggs = for (Other : G.WorldEggs, Other.UID <> Egg.UID). Other
    set Session.TutorialEggUID = 0
