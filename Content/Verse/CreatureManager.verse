# ============================================================================
# RIDE A SEA BEAST - CreatureManager.verse
# Owned creature inventory: granting (unique IDs), stat computation, Lagoon
# placement, Place Best, favorites / locks, filtering and sorting.
# ============================================================================
using { /Verse.org/Simulation }
using { /Verse.org/Random }
using { /UnrealEngine.com/Temporary }

# Breach scales gently with level so high-level beginners stay grounded.
LevelBreachBonusPerLevel : float = 0.004

# Sorting helper: SortBy needs a <computes> comparator, so we sort immutable
# (key, index) pairs and then reorder the creatures.
sort_entry := struct:
    Key : float = 0.0
    Index : int = 0

SortEntryDescending(A:sort_entry, B:sort_entry)<computes><decides>:void =
    A.Key > B.Key or (A.Key = B.Key and A.Index < B.Index)

# Stable descending sort of (key, index) entries.
SortEntries(Entries:[]sort_entry)<computes>:[]sort_entry =
    SortBy(Entries, SortEntryDescending)

# ---------------------------------------------------------------- Lookup ---
(G:sea_beast_game_device).FindCreature(Session:player_session, UID:int)<transacts><decides>:owned_creature =
    var Found : ?owned_creature = false
    for (C : Session.Profile.Creatures, not Found?, C.UniqueID = UID):
        set Found = option{C}
    Found?

(G:sea_beast_game_device).OwnsCreatureType(Session:player_session, TypeID:int)<transacts><decides>:void =
    var Found : logic = false
    for (C : Session.Profile.Creatures, not Found?, C.TypeID = TypeID):
        set Found = true
    Found?

(G:sea_beast_game_device).CountCreaturesOfType(Session:player_session, TypeID:int)<transacts>:int =
    var Count : int = 0
    for (C : Session.Profile.Creatures, C.TypeID = TypeID):
        set Count += 1
    Count

# ---------------------------------------------------------------- Stats ----
GetTraitSpeedMult(TraitID:int)<computes>:float = if (T := GetTraitDef[TraitID]) then T.SpeedMult else 1.0
GetTraitBreachMult(TraitID:int)<computes>:float = if (T := GetTraitDef[TraitID]) then T.BreachMult else 1.0
GetTraitIncomeMult(TraitID:int)<computes>:float = if (T := GetTraitDef[TraitID]) then T.IncomeMult else 1.0

# Display Speed including level, trait and mutation.
CreatureDisplaySpeed(C:owned_creature)<transacts>:float =
    if (Def := GetCreatureDef[C.TypeID]):
        Def.BaseSpeed * LevelStatMultiplier(C.Level) * GetTraitSpeedMult(C.TraitID) * MutationSpeedMult(C.MutationID)
    else:
        1.0

CreatureDisplayBreach(C:owned_creature)<transacts>:float =
    if (Def := GetCreatureDef[C.TypeID]):
        LevelMult := 1.0 + LevelBreachBonusPerLevel * ToFloat(Max(0, C.Level - 1))
        Def.BaseBreach * LevelMult * GetTraitBreachMult(C.TraitID)
    else:
        1.0

# Income per second of one creature (before Lagoon-wide multipliers).
CreatureIncomePerSecond(C:owned_creature)<transacts>:float =
    if (Def := GetCreatureDef[C.TypeID]):
        Def.BaseIncome * LevelStatMultiplier(C.Level) * GetTraitIncomeMult(C.TraitID)
    else:
        0.0

# ---------------------------------------------------------------- Grant ----
RollTraitID()<transacts>:int =
    var Total : float = 0.0
    for (T : TraitDefs):
        set Total += T.RollWeight
    Roll := GetRandomFloat(0.0, Total)
    var Accumulated : float = 0.0
    var Chosen : int = 0
    var Done : logic = false
    for (T : TraitDefs, not Done?):
        set Accumulated += T.RollWeight
        if (Roll <= Accumulated):
            set Chosen = T.ID
            set Done = true
    Chosen

# Adds a creature with a new unique ID. Returns the new record.
(G:sea_beast_game_device).GrantCreature(Session:player_session, TypeID:int, TraitID:int, MutationID:int)<transacts>:owned_creature =
    P := Session.Profile
    set P.UniqueCreatureCounter += 1
    NewCreature := owned_creature:
        UniqueID := P.UniqueCreatureCounter
        TypeID := TypeID
        TraitID := TraitID
        MutationID := MutationID
        HatchedAt := GetSecondsSinceEpoch()
    set P.Creatures += array{NewCreature}
    NewCreature

# New players receive the Sea Slug, placed in their Lagoon and ready to ride.
(G:sea_beast_game_device).EnsureStarterCreature(Session:player_session):void =
    P := Session.Profile
    if (P.Creatures.Length = 0):
        Starter := G.GrantCreature(Session, StarterCreatureID, 0, 0)
        G.RegisterCreatureDiscovery(Session, StarterCreatureID, 0)
        set P.PlacedCreatureIDs = array{Starter.UniqueID}
        set P.ActiveMountID = Starter.UniqueID

# ---------------------------------------------------------------- Lagoon ---
(G:sea_beast_game_device).GetLagoonSlots(Session:player_session)<transacts>:int =
    SlotsForDives(Session.Profile.DeepDiveCount, Session.Profile.BonusLagoonSlots)

(G:sea_beast_game_device).IsPlaced(Session:player_session, UID:int)<transacts><decides>:void =
    Session.Profile.PlacedCreatureIDs.Find[UID] >= 0

(G:sea_beast_game_device).GetPlacedCreatures(Session:player_session)<transacts>:[]owned_creature =
    for (UID : Session.Profile.PlacedCreatureIDs, C := G.FindCreature[Session, UID]). C

(G:sea_beast_game_device).GetPlacedCreaturesByIncome(Session:player_session)<transacts>:[]owned_creature =
    SortCreatures(G.GetPlacedCreatures(Session), creature_sort.BestIncome)

(G:sea_beast_game_device).PlaceCreature(Session:player_session, UID:int):void =
    P := Session.Profile
    if (not G.FindCreature[Session, UID]):
        return
    if (G.IsPlaced[Session, UID]):
        G.ShowToast(Session, "ALREADY IN YOUR LAGOON.", ThemeMuted)
        return
    if (P.PlacedCreatureIDs.Length >= G.GetLagoonSlots(Session)):
        G.ShowToast(Session, "YOUR LAGOON IS FULL! REMOVE A SEA BEAST OR USE PLACE BEST.", ThemeWarning)
        G.PlaySfx(Session, sfx_key.Error)
        return
    set P.PlacedCreatureIDs += array{UID}
    G.AfterLagoonChanged(Session)

(G:sea_beast_game_device).RemoveCreatureFromLagoon(Session:player_session, UID:int):void =
    P := Session.Profile
    if (G.IsPlaced[Session, UID]):
        set P.PlacedCreatureIDs = P.PlacedCreatureIDs.RemoveAllElements(UID)
        G.AfterLagoonChanged(Session)

# Places the creatures with the highest INCOME per second (not Speed).
(G:sea_beast_game_device).PlaceBest(Session:player_session):void =
    P := Session.Profile
    Slots := G.GetLagoonSlots(Session)
    Sorted := SortCreatures(P.Creatures, creature_sort.BestIncome)
    set P.PlacedCreatureIDs = for (Index -> C : Sorted, Index < Slots). C.UniqueID
    G.AfterLagoonChanged(Session)
    G.ShowToast(Session, "PLACED YOUR BEST SEA BEASTS: {FormatIncome(G.ComputeIncomePerSecond(Session, true))}", ThemeCash)
    G.PlaySfx(Session, sfx_key.Purchase)

(G:sea_beast_game_device).AfterLagoonChanged(Session:player_session):void =
    G.RefreshLagoon(Session)
    G.RefreshHud(Session)
    Session.UI.RefreshOpenMenu()
    G.SaveSession(Session)

# Auto-places a new creature if a slot is free.
(G:sea_beast_game_device).AutoPlaceIfRoom(Session:player_session, UID:int):void =
    P := Session.Profile
    if (P.PlacedCreatureIDs.Length < G.GetLagoonSlots(Session), not G.IsPlaced[Session, UID]):
        set P.PlacedCreatureIDs += array{UID}

# ---------------------------------------------------------------- Flags ----
(G:sea_beast_game_device).ToggleFavorite(Session:player_session, UID:int):void =
    if (C := G.FindCreature[Session, UID]):
        set C.Favorite = if (C.Favorite?) then false else true
        Session.UI.RefreshOpenMenu()
        G.SaveSession(Session)

(G:sea_beast_game_device).ToggleLock(Session:player_session, UID:int):void =
    if (C := G.FindCreature[Session, UID]):
        set C.Locked = if (C.Locked?) then false else true
        Session.UI.RefreshOpenMenu()
        G.SaveSession(Session)

(G:sea_beast_game_device).SetActiveMount(Session:player_session, UID:int):void =
    if (G.FindCreature[Session, UID]):
        set Session.Profile.ActiveMountID = UID
        G.SaveSession(Session)

# ---------------------------------------------------------------- Lists ----
CreatureSortKey(C:owned_creature, Sort:creature_sort)<transacts>:float =
    case (Sort):
        creature_sort.BestSpeed => CreatureDisplaySpeed(C)
        creature_sort.BestIncome => CreatureIncomePerSecond(C)
        creature_sort.BestBreach => CreatureDisplayBreach(C)
        creature_sort.Rarity => ToFloat(RarityIndex(CreatureRarity(C.TypeID))) * 1000000000000.0 + CreatureIncomePerSecond(C)
        creature_sort.Newest => ToFloat(C.UniqueID)

SortCreatures(Items:[]owned_creature, Sort:creature_sort)<transacts>:[]owned_creature =
    Entries := for (I -> C : Items). sort_entry{Key := CreatureSortKey(C, Sort), Index := I}
    Sorted := SortEntries(Entries)
    for (E : Sorted, C := Items[E.Index]). C

CreatureMatchesFilter(C:owned_creature, Filter:creature_filter)<transacts>:logic =
    R := CreatureRarity(C.TypeID)
    case (Filter):
        creature_filter.All => true
        creature_filter.Common => logic{R = beast_rarity.Common}
        creature_filter.Rare => logic{R = beast_rarity.Rare}
        creature_filter.Epic => logic{R = beast_rarity.Epic}
        creature_filter.Legendary => logic{R = beast_rarity.Legendary}
        creature_filter.Mythic => logic{R = beast_rarity.Mythic}
        creature_filter.Divine => logic{R = beast_rarity.Divine}
        creature_filter.Ethereal => logic{R = beast_rarity.Ethereal}
        creature_filter.Mutated => logic{C.MutationID > 0}
        creature_filter.Locked => C.Locked

(G:sea_beast_game_device).GetFilteredCreatures(Session:player_session, Filter:creature_filter, Sort:creature_sort)<transacts>:[]owned_creature =
    Matching := for (C : Session.Profile.Creatures, CreatureMatchesFilter(C, Filter)?). C
    SortCreatures(Matching, Sort)
