# ============================================================================
# RIDE A SEA BEAST - IndexManager.verse
# Ocean Index: creature / egg / mutation discoveries and collection
# milestones. Milestones require a manual CLAIM and are persistent forever.
# ============================================================================
using { /Verse.org/Simulation }

# Records a creature discovery. Returns true when the species is new.
# Also upgrades the "best mutation discovered" for that species.
(G:sea_beast_game_device).RegisterCreatureDiscovery(Session:player_session, TypeID:int, MutationID:int):logic =
    P := Session.Profile
    Index := TypeID - 1
    var IsNew : logic = false
    if (Current := P.CreatureDiscovery[Index]):
        if (Current < 0):
            if (set P.CreatureDiscovery[Index] = MutationID) {}
            set IsNew = true
        else if (MutationTier(MutationID) > MutationTier(Current)):
            if (set P.CreatureDiscovery[Index] = MutationID) {}
    if (MutationID > 0):
        G.RegisterMutationDiscovery(Session, MutationID)
    if (IsNew?):
        G.CheckMilestonesReady(Session)
    IsNew

(G:sea_beast_game_device).RegisterEggDiscovery(Session:player_session, EggID:int):void =
    if (set Session.Profile.EggDiscovery[EggID - 1] = true) {}

(G:sea_beast_game_device).RegisterMutationDiscovery(Session:player_session, MutationID:int):void =
    if (set Session.Profile.MutationDiscovery[MutationID] = true) {}

DiscoveryCount(P:player_profile)<transacts>:int =
    var Count : int = 0
    for (Value : P.CreatureDiscovery, Value >= 0):
        set Count += 1
    Count

IsCreatureDiscovered(P:player_profile, TypeID:int)<transacts><decides>:void =
    Value := P.CreatureDiscovery[TypeID - 1]
    Value >= 0

IsEggDiscovered(P:player_profile, EggID:int)<transacts><decides>:void =
    P.EggDiscovery[EggID - 1]?

IsMutationDiscovered(P:player_profile, MutationID:int)<transacts><decides>:void =
    P.MutationDiscovery[MutationID]?

IsMilestoneClaimed(P:player_profile, MilestoneIndex:int)<transacts><decides>:void =
    P.ClaimedMilestones.Find[MilestoneIndex] >= 0

IsMilestoneClaimable(P:player_profile, MilestoneIndex:int)<transacts><decides>:void =
    Milestone := IndexMilestones[MilestoneIndex]
    not IsMilestoneClaimed[P, MilestoneIndex]
    DiscoveryCount(P) >= Milestone.Discoveries

(G:sea_beast_game_device).CheckMilestonesReady(Session:player_session):void =
    var Ready : logic = false
    for (I := 0..IndexMilestones.Length - 1, IsMilestoneClaimable[Session.Profile, I]):
        set Ready = true
    if (Ready?):
        G.ShowToast(Session, "OCEAN INDEX REWARD READY! CLAIM IT IN THE OCEAN INDEX.", ThemeGold)

(G:sea_beast_game_device).ClaimMilestone(Session:player_session, MilestoneIndex:int):void =
    P := Session.Profile
    if (Milestone := IndexMilestones[MilestoneIndex], IsMilestoneClaimable[P, MilestoneIndex]):
        set P.ClaimedMilestones += array{MilestoneIndex}
        if (Milestone.RewardKind = 0):
            G.AddCash(Session, Milestone.CashReward)
        else if (Milestone.RewardKind = 1):
            set P.BonusLagoonSlots += 1
            G.RefreshLagoon(Session)
        else if (Milestone.RewardKind = 2):
            if (not P.Cosmetics.Find[Milestone.CosmeticID]):
                set P.Cosmetics += array{Milestone.CosmeticID}
            set P.EquippedTitle = Milestone.CosmeticID
            G.RefreshLagoonSigns(Session)
        G.PlaySfx(Session, sfx_key.IndexReward)
        if (Center := G.GetPickupCenter[Session]):
            G.PlayVfxAt(vfx_key.IndexReward, Center)
        Session.UI.ShowBigMessage("INDEX REWARD: {Milestone.Label}", ThemeGold)
        Session.UI.RefreshOpenMenu()
        G.RefreshHud(Session)
        G.SaveSession(Session)
    else:
        G.ShowToast(Session, "DISCOVER MORE SEA BEASTS TO CLAIM THIS REWARD.", ThemeMuted)
