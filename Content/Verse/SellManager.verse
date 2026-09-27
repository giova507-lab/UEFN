# ============================================================================
# RIDE A SEA BEAST - SellManager.verse
# Harbor Trader (Captain Pearl). Rules enforced here, never by the UI:
#   * cannot sell the mounted creature, a locked creature, an invalid or
#     already-sold creature, or the player's last creature;
#   * selling the last copy of the creature required for the NEXT Deep Dive
#     asks for confirmation first.
# ============================================================================
using { /Verse.org/Simulation }

SellValueFor(C:owned_creature)<transacts>:float =
    if (Def := GetCreatureDef[C.TypeID]):
        LevelFactor := 1.0 + SellLevelBonusPerLevel * ToFloat(Max(0, C.Level - 1))
        MutationFactor := 1.0 + SellMutationBonusPerTier * ToFloat(MutationTier(C.MutationID))
        Def.BaseIncome * SellSecondsForRarity(Def.Rarity) * LevelFactor * MutationFactor
    else:
        0.0

# Empty string when the creature can be sold, otherwise the reason.
(G:sea_beast_game_device).GetSellBlockReason(Session:player_session, UID:int)<transacts>:string =
    if (C := G.FindCreature[Session, UID]):
        if (Session.Mount.State <> mount_state.Dismounted and Session.Mount.CreatureUID = UID):
            "DISMOUNT BEFORE SELLING THIS SEA BEAST."
        else if (C.Locked?):
            "THIS SEA BEAST IS LOCKED."
        else if (Session.Profile.Creatures.Length <= 1):
            "YOU CAN'T SELL YOUR LAST SEA BEAST."
        else:
            ""
    else:
        "THAT SEA BEAST NO LONGER EXISTS."

# Succeeds when UID is the player's only copy of the next Deep Dive creature.
(G:sea_beast_game_device).IsRequiredForNextDeepDive(Session:player_session, UID:int)<transacts><decides>:void =
    C := G.FindCreature[Session, UID]
    Next := GetNextDeepDive[Session.Profile.DeepDiveCount]
    C.TypeID = Next.RequiredCreatureID
    G.CountCreaturesOfType(Session, C.TypeID) <= 1

(G:sea_beast_game_device).RequestSell(Session:player_session, UID:int):void =
    Reason := G.GetSellBlockReason(Session, UID)
    if (Reason <> ""):
        G.ShowToast(Session, Reason, ThemeDanger)
        G.PlaySfx(Session, sfx_key.Error)
        return
    if (G.IsRequiredForNextDeepDive[Session, UID]):
        set Session.PendingSellUID = UID
        Session.UI.ShowConfirm("THIS SEA BEAST IS REQUIRED FOR YOUR NEXT DEEP DIVE.\nSELL ANYWAY?", confirm_action.SellRequired)
        return
    G.ExecuteSell(Session, UID)

(G:sea_beast_game_device).ConfirmPendingSell(Session:player_session):void =
    UID := Session.PendingSellUID
    set Session.PendingSellUID = 0
    if (UID > 0):
        G.ExecuteSell(Session, UID)

(G:sea_beast_game_device).ExecuteSell(Session:player_session, UID:int):void =
    # Re-validate: the creature may have been sold or locked meanwhile.
    Reason := G.GetSellBlockReason(Session, UID)
    if (Reason <> ""):
        G.ShowToast(Session, Reason, ThemeDanger)
        return
    if (C := G.FindCreature[Session, UID]):
        Value := SellValueFor(C)
        G.RemoveOwnedCreature(Session, UID)
        G.AddCash(Session, Value)
        set Session.Profile.CreaturesSold += 1
        G.PlaySfx(Session, sfx_key.Selling)
        if (Center := G.GetPickupCenter[Session]):
            G.PlayVfxAt(vfx_key.SellCoins, Center)
        G.ShowToast(Session, "SOLD {CreatureName(C.TypeID)} FOR {FormatCash(Value)}!", ThemeCash)
        G.Track(Session, analytics_key.CreatureSold)
        G.AfterLagoonChanged(Session)

(G:sea_beast_game_device).RemoveOwnedCreature(Session:player_session, UID:int):void =
    P := Session.Profile
    set P.Creatures = for (Other : P.Creatures, Other.UniqueID <> UID). Other
    set P.PlacedCreatureIDs = P.PlacedCreatureIDs.RemoveAllElements(UID)
    if (P.ActiveMountID = UID):
        Best := SortCreatures(P.Creatures, creature_sort.BestSpeed)
        if (First := Best[0]):
            set P.ActiveMountID = First.UniqueID

# Duplicates = every copy of a species except the best one, skipping
# favorites, locked, placed, mounted and required-for-next-Deep-Dive copies.
(G:sea_beast_game_device).GetSellableDuplicates(Session:player_session)<transacts>:[]owned_creature =
    Sorted := SortCreatures(Session.Profile.Creatures, creature_sort.BestIncome)
    var KeptTypes : []int = array{}
    var Result : []owned_creature = array{}
    for (C : Sorted):
        if (KeptTypes.Find[C.TypeID]):
            if (not C.Favorite?, not C.Locked?, not G.IsPlaced[Session, C.UniqueID], G.GetSellBlockReason(Session, C.UniqueID) = ""):
                set Result += array{C}
        else:
            set KeptTypes += array{C.TypeID}
    Result

(G:sea_beast_game_device).RequestSellAllDuplicates(Session:player_session):void =
    Duplicates := G.GetSellableDuplicates(Session)
    if (Duplicates.Length = 0):
        G.ShowToast(Session, "NO DUPLICATES TO SELL.", ThemeMuted)
        return
    var Total : float = 0.0
    for (C : Duplicates):
        set Total += SellValueFor(C)
    Session.UI.ShowConfirm("SELL {Duplicates.Length} DUPLICATE SEA BEASTS FOR {FormatCash(Total)}?", confirm_action.SellDuplicates)

(G:sea_beast_game_device).ExecuteSellAllDuplicates(Session:player_session):void =
    Duplicates := G.GetSellableDuplicates(Session)
    var Total : float = 0.0
    var Count : int = 0
    for (C : Duplicates, G.GetSellBlockReason(Session, C.UniqueID) = ""):
        set Total += SellValueFor(C)
        G.RemoveOwnedCreature(Session, C.UniqueID)
        set Count += 1
    if (Count > 0):
        G.AddCash(Session, Total)
        set Session.Profile.CreaturesSold += Count
        G.PlaySfx(Session, sfx_key.Selling)
        G.ShowToast(Session, "SOLD {Count} DUPLICATES FOR {FormatCash(Total)}!", ThemeCash)
        G.Track(Session, analytics_key.CreatureSold)
        G.AfterLagoonChanged(Session)
