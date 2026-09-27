# ============================================================================
# RIDE A SEA BEAST - FeedManager.verse
# Feed Dock (Chef Kelp): buy food, feed creatures, level them up.
# Levels are persistent and give a meaningful but secondary bonus (see
# LevelStatBonusPerLevel) - rarity always matters more than level.
# ============================================================================
using { /Verse.org/Simulation }

(G:sea_beast_game_device).BuyFood(Session:player_session, FoodIndex:int, Quantity:int):void =
    if (Def := GetFoodDef[FoodIndex], Quantity > 0):
        Total := Def.Price * ToFloat(Quantity)
        if (G.TrySpend[Session, Total]):
            if (Owned := Session.Profile.FoodInventory[FoodIndex], set Session.Profile.FoodInventory[FoodIndex] = Owned + Quantity) {}
            G.PlaySfx(Session, sfx_key.Purchase)
            G.ShowToast(Session, "BOUGHT {Quantity}x {Def.Name}!", ThemeCash)
            Session.UI.RefreshOpenMenu()
            G.RefreshHud(Session)
            G.SaveSession(Session)
        else:
            G.ShowToast(Session, "NOT ENOUGH CASH! NEED {FormatCash(Total)}.", ThemeDanger)
            G.PlaySfx(Session, sfx_key.Error)

(G:sea_beast_game_device).GetFoodCount(Session:player_session, FoodIndex:int)<transacts>:int =
    if (Count := Session.Profile.FoodInventory[FoodIndex]) then Count else 0

# Spends one food item on a creature and applies XP / level ups.
(G:sea_beast_game_device).FeedCreature(Session:player_session, UID:int, FoodIndex:int):void =
    if (C := G.FindCreature[Session, UID], Def := GetFoodDef[FoodIndex]):
        Owned := G.GetFoodCount(Session, FoodIndex)
        if (Owned <= 0):
            G.ShowToast(Session, "NO {Def.Name} LEFT. VISIT CHEF KELP AT THE FEED DOCK!", ThemeWarning)
            return
        if (C.Level >= MaxCreatureLevel):
            G.ShowToast(Session, "{CreatureName(C.TypeID)} IS ALREADY MAX LEVEL!", ThemeMuted)
            return
        if (set Session.Profile.FoodInventory[FoodIndex] = Owned - 1) {}
        LevelsGained := G.AddCreatureXP(C, Def.XP)
        G.PlaySfx(Session, sfx_key.Feeding)
        if (Center := G.GetPickupCenter[Session]):
            G.PlayVfxAt(vfx_key.FeedSparkle, Center)
        if (LevelsGained > 0):
            G.ShowToast(Session, "{CreatureName(C.TypeID)} REACHED LEVEL {C.Level}!", ThemeGold)
        else:
            G.ShowToast(Session, "+{FormatCompact(ToFloat(Def.XP))} XP", ThemeCyan)
        # Stats changed: refresh everything that shows them.
        if (Session.Mount.CreatureUID = UID, Session.Mount.State = mount_state.Mounted):
            G.RefreshMountStats(Session)
        G.RefreshLagoonSigns(Session)
        Session.UI.RefreshOpenMenu()
        G.SaveSession(Session)

# Adds XP and returns how many levels were gained.
(G:sea_beast_game_device).AddCreatureXP(C:owned_creature, Amount:int)<transacts>:int =
    var Gained : int = 0
    set C.XP += Amount
    loop:
        if (C.Level >= MaxCreatureLevel):
            set C.XP = 0
            break
        Needed := XPToNextLevel(C.Level)
        if (C.XP < Needed):
            break
        set C.XP -= Needed
        set C.Level += 1
        set Gained += 1
    Gained
