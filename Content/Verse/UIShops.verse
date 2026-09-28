# ============================================================================
# RIDE A SEA BEAST - UIShops.verse
# Hub station screens: CURRENT TRACKER (Marina), SONAR SHACK (Finn),
# FEED DOCK (Chef Kelp) and HARBOR TRADER (Captain Pearl).
# The Current Tracker lists what is in the ocean but NEVER where it is.
# ============================================================================
using { /Fortnite.com/UI }
using { /Verse.org/Colors }
using { /Verse.org/Simulation }
using { /UnrealEngine.com/Temporary/UI }
using { /UnrealEngine.com/Temporary/SpatialMath }

# ---------------------------------------------------------------- Tracker --
(UI:player_ui_controller).BuildTrackerScreen():widget =
    SortButtons : []widget = array:
        MakeActionButton(UI, "HIGHEST LUCK", ui_action.SetTrackerSort, 0, 2)
        MakeActionButton(UI, "LOWEST LUCK", ui_action.SetTrackerSort, 1, 2)
        MakeActionButton(UI, "RARITY", ui_action.SetTrackerSort, 2, 2)
    set UI.TrackerRows = for (I := 0..TrackerRowsPerPage - 1). MakeLabel("", 19.0, ThemeWhite)
    set UI.TrackerInfo = MakeLabel("", 22.0, ThemeCyan)
    RowWidgets : []widget = for (Row : UI.TrackerRows). Row
    PageButtons : []widget = array:
        MakeActionButton(UI, "PREV", ui_action.TrackerPrev, 0, 2)
        MakeActionButton(UI, "NEXT", ui_action.TrackerNext, 0, 2)
    Title : widget = MakeLabel("SEA EGGS CURRENTLY IN THE OCEAN", 28.0, ThemeGold)
    Note : widget = MakeLabel("LOCATIONS ARE NEVER REVEALED - USE YOUR KNOWLEDGE, EXPLORATION AND SONAR.", 14.0, ThemeMuted)
    Header : []widget = array{Title, UI.TrackerInfo, MakeHStack(SortButtons, 3.0)}
    Footer : []widget = array{MakeHStack(PageButtons, 3.0), Note}
    MakeVStackLeft(Header + RowWidgets + Footer, 3.0)

(UI:player_ui_controller).RefreshTracker():void =
    Counts := UI.Game.GetActiveEggCounts()
    Present := for (I -> Count : Counts, Count > 0). I
    Keys := for (Position -> EggIndex : Present, Def := EggDefs[EggIndex]):
        Key := case (UI.TrackerSort):
            tracker_sort.HighestLuck => Def.Luck
            tracker_sort.LowestLuck => -Def.Luck
            tracker_sort.Rarity => ToFloat(RarityIndex(Def.Rarity)) * 1000000000000000.0 + Def.Luck
        sort_entry{Key := Key, Index := EggIndex}
    Sorted := SortEntries(Keys)
    PerPage := TrackerRowsPerPage
    PageCount := Max(1, QuotInt(Sorted.Length + PerPage - 1, PerPage))
    set UI.TrackerPage = Clamp(UI.TrackerPage, 0, PageCount - 1)
    Start := UI.TrackerPage * PerPage
    for (I -> Row : UI.TrackerRows):
        if (Entry := Sorted[Start + I], Def := EggDefs[Entry.Index], Count := Counts[Entry.Index]):
            SetLabel(Row, "{Def.Name}     {FormatLuck(Def.Luck)}     {RarityName(Def.Rarity)}     x{Count} ACTIVE")
            Row.SetTextColor(RarityColor(Def.Rarity))
        else if (I = 0, Sorted.Length = 0):
            SetLabel(Row, "NO SEA EGGS IN THE OCEAN RIGHT NOW - WAIT FOR THE TIDE!")
            Row.SetTextColor(ThemeMuted)
        else:
            SetLabel(Row, "")
    SetLabel(UI.TrackerInfo, "TIDE RESET: {FormatClock(UI.Game.GetTideRemaining())}")

# ---------------------------------------------------------------- Sonar ----
(UI:player_ui_controller).BuildSonarScreen():widget =
    set UI.SonarRows = for (I := 0..SonarTierCount - 1). MakeLabel("", 18.0, ThemeWhite)
    set UI.SonarInfo = MakeLabel("", 20.0, ThemeCyan)
    Rows : []widget = for (I -> Label : UI.SonarRows):
        RowItems : []widget = array{Label, MakeActionButton(UI, "BUY", ui_action.BuySonar, I, 1), MakeActionButton(UI, "USE", ui_action.UseSonar, I, 2), MakeActionButton(UI, "AUTO-BUY", ui_action.ToggleSonarAutoBuy, I, 2)}
        MakeHStack(RowItems, 4.0)
    Title : widget = MakeLabel("SONAR SHACK", 28.0, ThemeGold)
    Note : widget = MakeLabel("A SONAR TRACKS ONE RARITY AND POINTS TO AN EGG THAT ALREADY EXISTS. ONE CHARGE PER USE.\nAUTO-BUY buys that sonar's stock whenever the shop restocks, if you can afford it.", 14.0, ThemeMuted)
    MakeVStackLeft(array{Title, UI.SonarInfo} + Rows + array{Note}, 4.0)

(UI:player_ui_controller).RefreshSonarShop():void =
    if (Session := UI.GetMySession[]):
        for (Tier -> Label : UI.SonarRows, Def := GetSonarDef[Tier]):
            Stock := UI.Game.GetSonarStock(Session, Tier)
            Owned := if (N := Session.Profile.SonarInventory[Tier]) then N else 0
            StockText := if (Stock > 0) then "x{Stock} STOCK" else "OUT OF STOCK"
            AutoText := if (UI.Game.IsSonarAutoBuyOn[Session, Tier]) then "AUTO-BUY ON" else "AUTO-BUY OFF"
            SetLabel(Label, "{Def.Name}   TRACKS {RarityName(Def.TracksRarity)}   {FormatCash(Def.Price)}   {StockText}   OWNED x{Owned}   {AutoText}")
            Label.SetTextColor(RarityColor(Def.TracksRarity))
        SetLabel(UI.SonarInfo, "NEW STOCK IN {FormatClock(UI.Game.GetSonarRestockRemaining())}")

# ---------------------------------------------------------------- Feed -----
(UI:player_ui_controller).BuildFeedScreen():widget =
    set UI.FoodRows = for (I := 0..FoodCount - 1). MakeLabel("", 18.0, ThemeWhite)
    set UI.FeedInfo = MakeLabel("FEED YOUR SEA BEASTS FROM THE SEA BEASTS MENU (HOLD RELOAD).", 15.0, ThemeTurquoise)
    Rows : []widget = for (I -> Label : UI.FoodRows):
        RowItems : []widget = array{Label, MakeActionButton(UI, "BUY x1", ui_action.BuyFood, I, 1), MakeActionButton(UI, "BUY x10", ui_action.BuyFood10, I, 2)}
        MakeHStack(RowItems, 4.0)
    Title : widget = MakeLabel("FEED DOCK", 28.0, ThemeGold)
    MakeVStackLeft(array{Title} + Rows + array{UI.FeedInfo}, 4.0)

(UI:player_ui_controller).RefreshFeedDock():void =
    if (Session := UI.GetMySession[]):
        for (Index -> Label : UI.FoodRows, Def := GetFoodDef[Index]):
            Owned := UI.Game.GetFoodCount(Session, Index)
            SetLabel(Label, "{Def.Name}   {FormatCash(Def.Price)}   +{FormatCompact(ToFloat(Def.XP))} XP   OWNED x{Owned}")

# ---------------------------------------------------------------- Trader ---
(UI:player_ui_controller).BuildTraderScreen():widget =
    set UI.TraderRows = for (I := 0..TraderRowsPerPage - 1). MakeLabel("", 17.0, ThemeWhite)
    set UI.TraderButtons = for (I := 0..TraderRowsPerPage - 1). MakeActionButton(UI, "SELL", ui_action.TraderSell, I, 1)
    set UI.TraderInfo = MakeLabel("", 18.0, ThemeCash)
    Rows : []widget = for (I -> Label : UI.TraderRows, Button := UI.TraderButtons[I]):
        RowItems : []widget = array{Button, Label}
        MakeHStack(RowItems, 4.0)
    PageButtons : []widget = array:
        MakeActionButton(UI, "PREV", ui_action.TraderPrev, 0, 2)
        MakeActionButton(UI, "NEXT", ui_action.TraderNext, 0, 2)
        MakeActionButton(UI, "SELL ALL DUPLICATES", ui_action.SellDuplicates, 0, 0)
    Title : widget = MakeLabel("HARBOR TRADER", 28.0, ThemeGold)
    Note : widget = MakeLabel("LOCKED, MOUNTED AND LAST SEA BEASTS CANNOT BE SOLD. LOCK FAVORITES IN THE SEA BEASTS MENU.", 14.0, ThemeMuted)
    MakeVStackLeft(array{Title, UI.TraderInfo} + Rows + array{MakeHStack(PageButtons, 4.0), Note}, 3.0)

(UI:player_ui_controller).RefreshTrader():void =
    if (Session := UI.GetMySession[]):
        # Cheapest first so junk is easy to clear.
        Ascending := for (C : SortCreatures(Session.Profile.Creatures, creature_sort.BestIncome)). C
        Count := Ascending.Length
        Reversed := for (I := 0..Count - 1, C := Ascending[Count - 1 - I]). C
        PerPage := TraderRowsPerPage
        PageCount := Max(1, QuotInt(Reversed.Length + PerPage - 1, PerPage))
        set UI.TraderPage = Clamp(UI.TraderPage, 0, PageCount - 1)
        Start := UI.TraderPage * PerPage
        set UI.TraderUIDs = for (I := 0..PerPage - 1, C := Reversed[Start + I]). C.UniqueID
        for (I -> Label : UI.TraderRows, Button := UI.TraderButtons[I]):
            if (C := Reversed[Start + I]):
                Reason := UI.Game.GetSellBlockReason(Session, C.UniqueID)
                Mutation := if (C.MutationID > 0) then "  {MutationName(C.MutationID)}" else ""
                Copies := UI.Game.CountCreaturesOfType(Session, C.TypeID)
                SetLabel(Label, "{CreatureName(C.TypeID)} LV {C.Level}  {RarityName(CreatureRarity(C.TypeID))}{Mutation}   VALUE {FormatCash(SellValueFor(C))}   (x{Copies} OWNED)")
                Label.SetTextColor(RarityColor(CreatureRarity(C.TypeID)))
                ButtonText := if (Reason = "") then "SELL" else "LOCKED"
                Button.SetText(ToMessage(ButtonText))
                Button.SetVisibility(widget_visibility.Visible)
            else:
                SetLabel(Label, "")
                Button.SetVisibility(widget_visibility.Hidden)
        Duplicates := UI.Game.GetSellableDuplicates(Session)
        var Total : float = 0.0
        for (C : Duplicates):
            set Total += SellValueFor(C)
        SetLabel(UI.TraderInfo, "PAGE {UI.TraderPage + 1}/{PageCount}   SELLABLE DUPLICATES: {Duplicates.Length} ({FormatCash(Total)})")
