# ============================================================================
# RIDE A SEA BEAST - LagoonManager.verse
# Lagoon assignment, ownership validation, signs and Lagoon buttons.
# Other players may look at any Lagoon, but every Lagoon action verifies the
# acting player owns it (IsLagoonOwner) before anything happens.
# ============================================================================
using { /Fortnite.com/Devices }
using { /Fortnite.com/Characters }
using { /Verse.org/Simulation }
using { /UnrealEngine.com/Temporary/SpatialMath }

NoPlayer()<computes>:?player = false

(G:sea_beast_game_device).InitLagoons():void =
    set G.LagoonOwners = for (I := 0..G.Lagoons.Length - 1). NoPlayer()
    for (I -> Lagoon : G.Lagoons):
        Lagoon.BindGame(G, I)
        Lagoon.ResetForNoOwner()

# Assigns the first free Lagoon. Atomic: no suspension between check and set.
(G:sea_beast_game_device).AssignLagoon(Session:player_session)<transacts><decides>:int =
    var Chosen : int = -1
    for (I -> Owner : G.LagoonOwners, Chosen < 0, not Owner?):
        set Chosen = I
    Chosen >= 0
    set G.LagoonOwners[Chosen] = option{Session.Player}
    Chosen

(G:sea_beast_game_device).ReleaseLagoon(Session:player_session):void =
    Index := Session.LagoonIndex
    if (Owner := G.LagoonOwners[Index]?, Owner = Session.Player):
        if (set G.LagoonOwners[Index] = NoPlayer()) {}
        if (Lagoon := G.Lagoons[Index]):
            Lagoon.ResetForNoOwner()
    set Session.LagoonIndex = -1

(G:sea_beast_game_device).GetLagoonForSession(Session:player_session)<transacts><decides>:lagoon_device =
    G.Lagoons[Session.LagoonIndex]

# Succeeds when the session owns the Lagoon with LagoonIndex.
(G:sea_beast_game_device).IsLagoonOwner(Session:player_session, LagoonIndex:int)<transacts><decides>:void =
    LagoonIndex >= 0
    Session.LagoonIndex = LagoonIndex
    Owner := G.LagoonOwners[LagoonIndex]?
    Owner = Session.Player

# Resolves the acting agent and verifies Lagoon ownership. Shows feedback
# to players who press another player's buttons.
(G:sea_beast_game_device).ValidateLagoonAction(LagoonIndex:int, Agent:agent)<transacts><decides>:player_session =
    Session := G.GetAgentSession[Agent]
    Session.Loaded?
    G.IsLagoonOwner[Session, LagoonIndex]
    Session

(G:sea_beast_game_device).RejectForeignLagoon(Agent:agent):void =
    if (Session := G.GetAgentSession[Agent]):
        G.ShowToast(Session, "THIS IS NOT YOUR LAGOON.", ThemeDanger)
        G.PlaySfx(Session, sfx_key.Error)

# ---------------------------------------------------------------- Buttons --
(G:sea_beast_game_device).OnHatchLuckButton(LagoonIndex:int, Agent:agent, BuyMax:logic):void =
    if (Session := G.ValidateLagoonAction[LagoonIndex, Agent]):
        G.TryUpgradeHatchLuck(Session, BuyMax)
    else:
        G.RejectForeignLagoon(Agent)

(G:sea_beast_game_device).OnPlaceBestButton(LagoonIndex:int, Agent:agent):void =
    if (Session := G.ValidateLagoonAction[LagoonIndex, Agent]):
        G.PlaceBest(Session)
    else:
        G.RejectForeignLagoon(Agent)

(G:sea_beast_game_device).OnManageButton(LagoonIndex:int, Agent:agent):void =
    if (Session := G.ValidateLagoonAction[LagoonIndex, Agent]):
        Session.UI.OpenMenu(menu_screen.SeaBeasts)
    else:
        G.RejectForeignLagoon(Agent)

(G:sea_beast_game_device).OnDeepDiveButton(LagoonIndex:int, Agent:agent):void =
    if (Session := G.ValidateLagoonAction[LagoonIndex, Agent]):
        Session.UI.OpenMenu(menu_screen.DeepDive)
    else:
        G.RejectForeignLagoon(Agent)

(G:sea_beast_game_device).OnRideDockButton(LagoonIndex:int, Agent:agent):void =
    if (Session := G.ValidateLagoonAction[LagoonIndex, Agent]):
        G.RequestMount(Session, Session.Profile.ActiveMountID, true)
    else:
        G.RejectForeignLagoon(Agent)

# ---------------------------------------------------------------- Views ----
# Full refresh of the player's Lagoon: signs + swimming creature displays.
(G:sea_beast_game_device).RefreshLagoon(Session:player_session):void =
    G.RefreshLagoonSigns(Session)
    G.RefreshLagoonDisplays(Session)

(G:sea_beast_game_device).RefreshLagoonSigns(Session:player_session):void =
    if (Lagoon := G.GetLagoonForSession[Session]):
        P := Session.Profile
        Lagoon.SetOwnerSign(option{Session.Player}, CosmeticTitle(P.EquippedTitle))
        Income := G.ComputeIncomePerSecond(Session, true)
        Slots := G.GetLagoonSlots(Session)
        Lagoon.SetIncomeText("{FormatIncome(Income)}\nSEA BEASTS {P.PlacedCreatureIDs.Length}/{Slots}")
        G.RefreshHatchLuckSign(Session)
        G.RefreshDeepDiveSign(Session)

(G:sea_beast_game_device).RefreshHatchLuckSign(Session:player_session):void =
    if (Lagoon := G.GetLagoonForSession[Session]):
        P := Session.Profile
        Current := HatchLuckForUpgrades(P.HatchLuckUpgrades)
        Next := HatchLuckForUpgrades(P.HatchLuckUpgrades + 1)
        Cost := HatchLuckUpgradeCost(P.HatchLuckUpgrades)
        Step := HatchLuckCycleStep(P.HatchLuckUpgrades)
        MaxInfo := G.HatchLuckMaxPurchase(Session)
        MaxCount := MaxInfo(0)
        MaxTotal := FormatCash(MaxInfo(1))
        MaxLine := if (MaxCount > 0) then "MAX +{MaxCount}  {MaxTotal}" else "MAX: NOT ENOUGH CASH"
        Lagoon.SetHatchLuckText("HATCH LUCK\n{FormatMultiplier(Current)} > {FormatMultiplier(Next)}\n{Step - 1}/5  {FormatCash(Cost)}\n{MaxLine}")
        Lagoon.SetHatchLuckCostText(FormatCash(Cost))
        Lagoon.SetHatchLuckMaxText(MaxLine)

(G:sea_beast_game_device).RefreshDeepDiveSign(Session:player_session):void =
    if (Lagoon := G.GetLagoonForSession[Session]):
        Lagoon.SetDeepDiveText(G.DeepDiveSignText(Session))

# Placed creatures with the highest income are shown (up to the display cap);
# every placed creature earns regardless of whether it is displayed.
MaxDisplayedLagoonCreatures : int = 8

(G:sea_beast_game_device).RefreshLagoonDisplays(Session:player_session):void =
    if (Lagoon := G.GetLagoonForSession[Session]):
        Placed := G.GetPlacedCreaturesByIncome(Session)
        Requests := for (Index -> C : Placed, Index < MaxDisplayedLagoonCreatures, C.UniqueID <> Session.Mount.CreatureUID or Session.Mount.State = mount_state.Dismounted, PropAsset := G.GetCreatureDisplayAsset[C.TypeID], Def := GetCreatureDef[C.TypeID]):
            lagoon_display_request:
                CreatureUID := C.UniqueID
                TypeID := C.TypeID
                MutationID := C.MutationID
                Asset := PropAsset
                Scale := G.GetCreatureVisualScale(C.TypeID)
                SizeClass := Def.SizeClass
        spawn{ Lagoon.ShowCreatures(Requests) }

# Seconds between two "all incubators are full" warnings.
IncubatorsFullWarningSeconds : float = 6.0

# Carried eggs are secured automatically when the carrier enters their own
# Lagoon (if AutoSecureInLagoon); otherwise they must use an incubator.
(G:sea_beast_game_device).CheckLagoonDelivery(Session:player_session):void =
    if (AutoSecureInLagoon?, Session.Carried.Length > 0, Lagoon := G.GetLagoonForSession[Session], Character := Session.Player.GetFortCharacter[]):
        if (Lagoon.IsInsideArea[Character.GetTransform().Translation]):
            for (Carried : Session.Carried):
                if (Index := G.FirstEmptyIncubator[Session]):
                    G.SecureCarriedEgg(Session, Carried, Index)
                else if (G.GetNow() - Session.LastFullIncubatorWarning >= IncubatorsFullWarningSeconds):
                    set Session.LastFullIncubatorWarning = G.GetNow()
                    G.ShowToast(Session, "ALL INCUBATORS ARE FULL! HATCH AN EGG TO MAKE ROOM.", ThemeWarning)
