# ============================================================================
# RIDE A SEA BEAST - UIMenus.verse
# Main menu window and its tabs: SEA BEASTS, OCEAN INDEX, DEEP DIVE,
# SETTINGS and the developer-only DEV tab. Widgets are built once per player
# and then updated in place (no widget churn while browsing).
# Verse UI has no scroll boxes, so long lists are paginated.
# ============================================================================
using { /Fortnite.com/UI }
using { /Verse.org/Colors }
using { /Verse.org/Simulation }
using { /UnrealEngine.com/Temporary/UI }
using { /UnrealEngine.com/Temporary/SpatialMath }

MenuWindowWidth : float = 1500.0
MenuWindowHeight : float = 860.0

# ---------------------------------------------------------------- Cards ----
creature_card := class:
    var Root : button = button{Slot := button_slot{Widget := color_block{}}}
    var Border : color_block = color_block{}
    var Background : color_block = color_block{}
    var NameLabel : text_block = text_block{}
    var InfoLabel : text_block = text_block{}
    var BadgeLabel : text_block = text_block{}

    Fill(Name:string, Info:string, Badge:string, AccentColor:color, Selected:logic):void =
        Root.SetVisibility(widget_visibility.Visible)
        SetLabel(NameLabel, Name)
        NameLabel.SetTextColor(AccentColor)
        SetLabel(InfoLabel, Info)
        SetLabel(BadgeLabel, Badge)
        Border.SetColor(if (Selected?) then ThemeWhite else AccentColor)
        Background.SetColor(if (Selected?) then ThemeNavyLight else ThemeNavy)

    Clear():void = Root.SetVisibility(widget_visibility.Hidden)

MakeCreatureCard(UI:player_ui_controller, Index:int):creature_card =
    Card := creature_card{}
    set Card.Border = MakeBlock(ThemeCyan, 1.0, 262.0, 128.0)
    set Card.Background = MakeBlock(ThemeNavy, 0.96, 256.0, 122.0)
    set Card.NameLabel = MakeLabel("", 18.0, ThemeWhite)
    set Card.InfoLabel = MakeLabel("", 14.0, ThemePearl)
    set Card.BadgeLabel = MakeLabel("", 13.0, ThemeGold)
    Content := overlay:
        Slots := array:
            OverlayFill(Card.Border)
            OverlayPadded(Card.Background, 3.0)
            OverlayPadded(MakeVStackLeft(array{Card.NameLabel, Card.InfoLabel, Card.BadgeLabel}, 1.0), 10.0)
    set Card.Root = MakeWidgetButton(UI, Content, ui_action.SelectCard, Index)
    Card

index_card := class:
    var Root : overlay = overlay{}
    var Border : color_block = color_block{}
    var Background : color_block = color_block{}
    var NameLabel : text_block = text_block{}
    var InfoLabel : text_block = text_block{}

    Fill(Name:string, Info:string, AccentColor:color, Discovered:logic):void =
        Root.SetVisibility(widget_visibility.Visible)
        SetLabel(NameLabel, Name)
        SetLabel(InfoLabel, Info)
        NameLabel.SetTextColor(if (Discovered?) then AccentColor else ThemeMuted)
        Border.SetColor(if (Discovered?) then AccentColor else ThemeNavyDark)
        Background.SetColor(if (Discovered?) then ThemeNavy else ThemeNavyDark)

    Clear():void = Root.SetVisibility(widget_visibility.Hidden)

MakeIndexCard():index_card =
    Card := index_card{}
    set Card.Border = MakeBlock(ThemeCyan, 1.0, 262.0, 118.0)
    set Card.Background = MakeBlock(ThemeNavy, 0.96, 256.0, 112.0)
    set Card.NameLabel = MakeLabel("", 17.0, ThemeWhite)
    set Card.InfoLabel = MakeLabel("", 13.0, ThemePearl)
    set Card.Root = overlay:
        Slots := array:
            OverlayFill(Card.Border)
            OverlayPadded(Card.Background, 3.0)
            OverlayPadded(MakeVStackLeft(array{Card.NameLabel, Card.InfoLabel}, 1.0), 10.0)
    Card

# ---------------------------------------------------------------- Window ---
(UI:player_ui_controller).BuildMenus():void =
    set UI.DevTabButton = MakeActionButton(UI, "DEV", ui_action.OpenTab, 8, 2)
    TabButtons : []widget = array:
        MakeActionButton(UI, "SEA BEASTS", ui_action.OpenTab, 0, 1)
        MakeActionButton(UI, "OCEAN INDEX", ui_action.OpenTab, 1, 1)
        MakeActionButton(UI, "DEEP DIVE", ui_action.OpenTab, 2, 1)
        MakeActionButton(UI, "SETTINGS", ui_action.OpenTab, 3, 1)
        UI.DevTabButton
    set UI.TabRow = MakeHStack(TabButtons, 4.0)
    set UI.StationTitleLabel = MakeLabel("", 30.0, ThemeGold)
    set UI.GreetingLabel = MakeLabel("", 18.0, ThemePearl)
    set UI.ScreenRoots = array:
        UI.BuildSeaBeastsScreen()
        UI.BuildIndexScreen()
        UI.BuildDeepDiveScreen()
        UI.BuildSettingsScreen()
        UI.BuildTrackerScreen()
        UI.BuildSonarScreen()
        UI.BuildFeedScreen()
        UI.BuildTraderScreen()
        UI.BuildDebugScreen()
    Content := overlay:
        Slots := for (Root : UI.ScreenRoots). OverlayFill(Root)
    CloseButton := MakeActionButton(UI, "CLOSE", ui_action.CloseMenu, 0, 2)
    Header := MakeHStack(array{UI.TabRow, UI.StationTitleLabel, CloseButton}, 6.0)
    Window := MakeBorderedPanel(MakeVStackLeft(array{Header, UI.GreetingLabel, Content}, 6.0), ThemeCyan, ThemeNavy, 18.0)
    set UI.MenuCanvas = canvas:
        Slots := array:
            FullScreenSlot(MakeBlock(ThemeNavyDark, 0.35, 1.0, 1.0))
            CenteredWindowSlot(Window, MenuWindowWidth, MenuWindowHeight)
    set UI.MenuBuilt = true

# ---------------------------------------------------------------- Sea Beasts
(UI:player_ui_controller).BuildSeaBeastsScreen():widget =
    FilterButtons1 : []widget = for (I := 0..4). MakeActionButton(UI, FilterName(FilterFromIndex(I)), ui_action.SetFilter, I, 2)
    FilterButtons2 : []widget = for (I := 5..9). MakeActionButton(UI, FilterName(FilterFromIndex(I)), ui_action.SetFilter, I, 2)
    FilterRow1 := MakeHStack(FilterButtons1, 2.0)
    FilterRow2 := MakeHStack(FilterButtons2, 2.0)
    SortButtons : []widget = array:
        MakeActionButton(UI, "BEST SPEED", ui_action.SetSort, 0, 2)
        MakeActionButton(UI, "BEST INCOME", ui_action.SetSort, 1, 2)
        MakeActionButton(UI, "BEST BREACH", ui_action.SetSort, 2, 2)
        MakeActionButton(UI, "RARITY", ui_action.SetSort, 3, 2)
        MakeActionButton(UI, "NEWEST", ui_action.SetSort, 4, 2)
        MakeActionButton(UI, "PLACE BEST", ui_action.PlaceBest, 0, 0)
    SortRow := MakeHStack(SortButtons, 2.0)
    set UI.Cards = for (I := 0..CreatureCardsPerPage - 1). MakeCreatureCard(UI, I)
    CardRoots1 : []widget = for (I := 0..3, Card := UI.Cards[I]). Card.Root
    CardRoots2 : []widget = for (I := 4..7, Card := UI.Cards[I]). Card.Root
    Row1 := MakeHStack(CardRoots1, 4.0)
    Row2 := MakeHStack(CardRoots2, 4.0)
    set UI.PageLabel = MakeLabel("PAGE 1/1", 16.0, ThemePearl)
    PageRow := MakeHStack(array{MakeActionButton(UI, "PREV", ui_action.PrevPage, 0, 2), UI.PageLabel, MakeActionButton(UI, "NEXT", ui_action.NextPage, 0, 2)}, 4.0)
    set UI.SummaryLabel = MakeLabel("", 15.0, ThemeTurquoise)
    set UI.FilterLabel = MakeLabel("", 14.0, ThemeMuted)
    Left := MakeVStackLeft(array{FilterRow1, FilterRow2, SortRow, UI.FilterLabel, Row1, Row2, PageRow, UI.SummaryLabel}, 3.0)
    # Detail panel.
    set UI.DetailName = MakeLabel("", 26.0, ThemeWhite)
    set UI.DetailRarity = MakeLabel("", 18.0, ThemeGold)
    set UI.DetailStats = MakeLabel("", 16.0, ThemePearl)
    set UI.DetailExtra = MakeLabel("", 14.0, ThemeTurquoise)
    set UI.PlaceButton = MakeActionButton(UI, "PLACE IN LAGOON", ui_action.TogglePlace, 0, 1)
    set UI.FeedButton = MakeActionButton(UI, "FEED", ui_action.Feed, 0, 1)
    set UI.FavoriteButton = MakeActionButton(UI, "FAVORITE: OFF", ui_action.ToggleFavorite, 0, 2)
    set UI.LockButton = MakeActionButton(UI, "LOCK: OFF", ui_action.ToggleLock, 0, 2)
    set UI.FoodLabel = MakeLabel("", 14.0, ThemePearl)
    FoodRow := MakeHStack(array{MakeActionButton(UI, "<", ui_action.PrevFood, 0, 2), UI.FoodLabel, MakeActionButton(UI, ">", ui_action.NextFood, 0, 2), UI.FeedButton}, 2.0)
    ActionWidgets : []widget = array:
        MakeActionButton(UI, "RIDE", ui_action.Ride, 0, 0)
        UI.PlaceButton
        FoodRow
        MakeHStack(array{UI.FavoriteButton, UI.LockButton}, 2.0)
        MakeActionButton(UI, "SELL", ui_action.Sell, 0, 2)
        MakeActionButton(UI, "DISMOUNT", ui_action.Dismount, 0, 2)
    Actions := MakeVStack(ActionWidgets, 3.0)
    Detail := MakePanel(MakeVStackLeft(array{UI.DetailName, UI.DetailRarity, UI.DetailStats, UI.DetailExtra, Actions}, 4.0), ThemeNavyDark, 0.8, 14.0)
    MakeHStack(array{Left, Detail}, 6.0)

(UI:player_ui_controller).RefreshSeaBeasts():void =
    if (Session := UI.GetMySession[]):
        P := Session.Profile
        List := UI.Game.GetFilteredCreatures(Session, UI.Filter, UI.Sort)
        PerPage := CreatureCardsPerPage
        PageCount := Max(1, QuotInt(List.Length + PerPage - 1, PerPage))
        set UI.Page = Clamp(UI.Page, 0, PageCount - 1)
        Start := UI.Page * PerPage
        set UI.VisibleUIDs = for (I := 0..PerPage - 1, C := List[Start + I]). C.UniqueID
        if (not UI.Game.FindCreature[Session, UI.SelectedUID]):
            if (First := List[0]):
                set UI.SelectedUID = First.UniqueID
            else if (Any := P.Creatures[0]):
                set UI.SelectedUID = Any.UniqueID
        for (I -> Card : UI.Cards):
            if (C := List[Start + I]):
                Card.Fill(UI.CardName(C), UI.CardInfo(C), UI.CardBadges(Session, C), RarityColor(CreatureRarity(C.TypeID)), logic{C.UniqueID = UI.SelectedUID})
            else:
                Card.Clear()
        SetLabel(UI.PageLabel, "PAGE {UI.Page + 1}/{PageCount}")
        SetLabel(UI.FilterLabel, "FILTER: {FilterName(UI.Filter)}   SORT: {SortName(UI.Sort)}   ({List.Length} SHOWN)")
        SetLabel(UI.SummaryLabel, "LAGOON {P.PlacedCreatureIDs.Length}/{UI.Game.GetLagoonSlots(Session)}   SEA BEASTS {P.Creatures.Length}/{MaxCreatureInventory}   INCOME {FormatIncome(UI.Game.ComputeIncomePerSecond(Session, true))}")
        UI.RefreshDetail(Session)

(UI:player_ui_controller).CardName(C:owned_creature)<transacts>:string =
    "{CreatureName(C.TypeID)}  LV {C.Level}"

(UI:player_ui_controller).CardInfo(C:owned_creature)<transacts>:string =
    "{RarityName(CreatureRarity(C.TypeID))}\nSPD {FormatCompact(CreatureDisplaySpeed(C))}   INC {FormatCash(CreatureIncomePerSecond(C))}/s"

(UI:player_ui_controller).CardBadges(Session:player_session, C:owned_creature)<transacts>:string =
    Placed := if (UI.Game.IsPlaced[Session, C.UniqueID]) then "PLACED " else ""
    Riding := if (Session.Mount.State <> mount_state.Dismounted and Session.Mount.CreatureUID = C.UniqueID) then "RIDING " else ""
    Fav := if (C.Favorite?) then "FAV " else ""
    Locked := if (C.Locked?) then "LOCKED " else ""
    Mutation := if (C.MutationID > 0) then MutationName(C.MutationID) else ""
    "{Placed}{Riding}{Fav}{Locked}{Mutation}"

(UI:player_ui_controller).RefreshDetail(Session:player_session):void =
    if (C := UI.Game.FindCreature[Session, UI.SelectedUID], Def := GetCreatureDef[C.TypeID]):
        R := Def.Rarity
        SetLabel(UI.DetailName, "{Def.Name}  LV {C.Level}")
        SetLabel(UI.DetailRarity, "{RarityName(R)}   {FormatOdds(Def.Odds)}")
        UI.DetailRarity.SetTextColor(RarityColor(R))
        DisplaySpeed := CreatureDisplaySpeed(C)
        MetersPerSecond := DisplaySpeedToMetersPerSecond(DisplaySpeed)
        XPText := if (C.Level >= MaxCreatureLevel) then "MAX LEVEL" else "XP {FormatCompact(ToFloat(C.XP))} / {FormatCompact(ToFloat(XPToNextLevel(C.Level)))}"
        SetLabel(UI.DetailStats, "SPEED {FormatCompact(DisplaySpeed)}  ({FormatDecimal(MetersPerSecond, 1)} m/s, {SpeedBandName(MetersPerSecond)})\nBREACH {FormatCompact(CreatureDisplayBreach(C))}  ({FormatDecimal(BreachToLaunchHeightCm(CreatureDisplayBreach(C)) / 100.0, 1)} m jump)\nINCOME {FormatCash(CreatureIncomePerSecond(C))}/s\n{XPText}")
        MutationText := if (C.MutationID > 0) then "MUTATION: {MutationName(C.MutationID)} (x{FormatCompact(MutationSpeedMult(C.MutationID))} SPEED)" else "MUTATION: NONE"
        SetLabel(UI.DetailExtra, "{MutationText}\nTRAIT: {TraitName(C.TraitID)}\n{Def.Flavor}")
        PlaceText := if (UI.Game.IsPlaced[Session, C.UniqueID]) then "REMOVE FROM LAGOON" else "PLACE IN LAGOON"
        UI.PlaceButton.SetText(ToMessage(PlaceText))
        UI.FavoriteButton.SetText(ToMessage("FAVORITE: {OnOffText(C.Favorite)}"))
        UI.LockButton.SetText(ToMessage("LOCK: {OnOffText(C.Locked)}"))
        if (Food := GetFoodDef[UI.SelectedFood]):
            SetLabel(UI.FoodLabel, "{Food.Name} x{UI.Game.GetFoodCount(Session, UI.SelectedFood)}  (+{FormatCompact(ToFloat(Food.XP))} XP)")
    else:
        SetLabel(UI.DetailName, "NO SEA BEAST SELECTED")
        SetLabel(UI.DetailRarity, "")
        SetLabel(UI.DetailStats, "")
        SetLabel(UI.DetailExtra, "")

# ---------------------------------------------------------------- Index ----
(UI:player_ui_controller).BuildIndexScreen():widget =
    IndexTabs : []widget = array:
        MakeActionButton(UI, "SEA BEASTS", ui_action.SetIndexTab, 0, 1)
        MakeActionButton(UI, "SEA EGGS", ui_action.SetIndexTab, 1, 1)
        MakeActionButton(UI, "MUTATIONS", ui_action.SetIndexTab, 2, 1)
    IndexTabRow := MakeHStack(IndexTabs, 3.0)
    set UI.IndexHeader = MakeLabel("", 20.0, ThemeGold)
    set UI.IndexCards = for (I := 0..IndexCardsPerPage - 1). MakeIndexCard()
    IndexRoots1 : []widget = for (I := 0..4, Card := UI.IndexCards[I]). Card.Root
    IndexRoots2 : []widget = for (I := 5..9, Card := UI.IndexCards[I]). Card.Root
    Row1 := MakeHStack(IndexRoots1, 4.0)
    Row2 := MakeHStack(IndexRoots2, 4.0)
    set UI.IndexPageLabel = MakeLabel("", 16.0, ThemePearl)
    PageRow := MakeHStack(array{MakeActionButton(UI, "PREV", ui_action.IndexPrev, 0, 2), UI.IndexPageLabel, MakeActionButton(UI, "NEXT", ui_action.IndexNext, 0, 2)}, 4.0)
    set UI.MilestoneButtons = for (I := 0..IndexMilestones.Length - 1). MakeActionButton(UI, "", ui_action.ClaimMilestone, I, 2)
    MilestoneWidgets : []widget = for (Button : UI.MilestoneButtons). Button
    MilestoneRow := MakeHStack(MilestoneWidgets, 3.0)
    MakeVStackLeft(array{IndexTabRow, UI.IndexHeader, Row1, Row2, PageRow, MakeLabel("COLLECTION REWARDS", 18.0, ThemeGold), MilestoneRow}, 4.0)

(UI:player_ui_controller).RefreshIndex():void =
    if (Session := UI.GetMySession[]):
        P := Session.Profile
        PerPage := IndexCardsPerPage
        Total := if (UI.IndexTab = index_tab.SeaBeasts) then CreatureCount else if (UI.IndexTab = index_tab.SeaEggs) then EggCount else MutationCount - 1
        PageCount := Max(1, QuotInt(Total + PerPage - 1, PerPage))
        set UI.IndexPage = Clamp(UI.IndexPage, 0, PageCount - 1)
        Start := UI.IndexPage * PerPage
        for (I -> Card : UI.IndexCards):
            ItemIndex := Start + I
            if (ItemIndex < Total):
                UI.FillIndexCard(P, Card, ItemIndex)
            else:
                Card.Clear()
        Discovered := DiscoveryCount(P)
        SetLabel(UI.IndexHeader, "SEA BEASTS DISCOVERED: {Discovered}/{CreatureCount}")
        SetLabel(UI.IndexPageLabel, "PAGE {UI.IndexPage + 1}/{PageCount}")
        for (I -> Button : UI.MilestoneButtons, Milestone := IndexMilestones[I]):
            State := if (IsMilestoneClaimed[P, I]) then "CLAIMED" else if (IsMilestoneClaimable[P, I]) then "CLAIM!" else "{Discovered}/{Milestone.Discoveries}"
            Button.SetText(ToMessage("{Milestone.Discoveries}: {Milestone.Label}  [{State}]"))

(UI:player_ui_controller).FillIndexCard(P:player_profile, Card:index_card, ItemIndex:int):void =
    if (UI.IndexTab = index_tab.SeaBeasts):
        if (Def := CreatureDefs[ItemIndex]):
            if (Best := P.CreatureDiscovery[ItemIndex], Best >= 0):
                BestText := if (Best > 0) then MutationName(Best) else "NONE"
                Card.Fill(Def.Name, "{RarityName(Def.Rarity)}   {FormatOdds(Def.Odds)}\nBEST MUTATION: {BestText}", RarityColor(Def.Rarity), true)
            else:
                Card.Fill("???", "{RarityName(Def.Rarity)}   {FormatOdds(Def.Odds)}\nUNDISCOVERED", RarityColor(Def.Rarity), false)
    else if (UI.IndexTab = index_tab.SeaEggs):
        if (Def := EggDefs[ItemIndex]):
            if (IsEggDiscovered[P, Def.ID]):
                Card.Fill(Def.Name, "{RarityName(Def.Rarity)}\n{FormatLuck(Def.Luck)}", RarityColor(Def.Rarity), true)
            else:
                Card.Fill("???", "{RarityName(Def.Rarity)}\nUNDISCOVERED", RarityColor(Def.Rarity), false)
    else:
        MutationID := ItemIndex + 1
        if (Def := GetMutationDef[MutationID]):
            if (IsMutationDiscovered[P, MutationID]):
                Card.Fill(Def.Name, "x{FormatCompact(Def.SpeedMult)} SPEED\nDISCOVERED", MutationColor(MutationID), true)
            else:
                Card.Fill("???", "x{FormatCompact(Def.SpeedMult)} SPEED\n???", MutationColor(MutationID), false)

# ---------------------------------------------------------------- Deep Dive
(UI:player_ui_controller).BuildDeepDiveScreen():widget =
    set UI.DeepDiveInfo = MakeLabel("", 20.0, ThemePearl)
    set UI.DeepDiveButton = MakeActionButton(UI, "DEEP DIVE", ui_action.DoDeepDive, 0, 0)
    Explain := MakeLabel("DEEP DIVE RESETS: CASH AND HATCH LUCK.\nYOU KEEP: EVERY SEA BEAST, MUTATIONS, THE OCEAN INDEX, COSMETICS\nAND ALL PERMANENT BONUSES.\nEVERY DEEP DIVE GRANTS +1X MONEY MULTIPLIER AND +1 LAGOON SLOT.", 16.0, ThemeTurquoise)
    MakeVStackLeft(array{MakeLabel("DEEP DIVE", 34.0, ThemeCyan), UI.DeepDiveInfo, Explain, UI.DeepDiveButton}, 8.0)

(UI:player_ui_controller).RefreshDeepDive():void =
    if (Session := UI.GetMySession[]):
        P := Session.Profile
        Current := "DEEP DIVES COMPLETED: {P.DeepDiveCount}/{MaxDeepDives}\nMONEY MULTIPLIER: {FormatCompact(P.PermanentMoneyMultiplier)}X\nLAGOON CAPACITY: {UI.Game.GetLagoonSlots(Session)} SLOTS"
        if (Next := GetNextDeepDive[P.DeepDiveCount]):
            CashState := if (P.Cash >= Next.CashRequired) then "READY" else "{FormatCash(P.Cash)} / {FormatCash(Next.CashRequired)}"
            BeastState := if (UI.Game.OwnsCreatureType[Session, Next.RequiredCreatureID]) then "OWNED" else "NOT OWNED"
            Ready := logic{UI.Game.IsDeepDiveReady[Session]}
            StatusText := if (Ready?) then "READY!" else "NOT READY"
            ButtonText := if (Ready?) then "DEEP DIVE!" else "NOT READY"
            SetLabel(UI.DeepDiveInfo, "{Current}\n\nNEXT: DEEP DIVE {Next.Level}\nCASH: {CashState}\nREQUIRED SEA BEAST: {CreatureName(Next.RequiredCreatureID)} ({BeastState})\nREWARD: +{FormatCompact(Next.MoneyMultiplierGain)}X MONEY, +{Next.SlotGain} LAGOON SLOT\n\nSTATUS: {StatusText}")
            UI.DeepDiveButton.SetText(ToMessage(ButtonText))
        else:
            SetLabel(UI.DeepDiveInfo, "{Current}\n\nYOU HAVE REACHED THE DEEPEST DEPTHS.")
            UI.DeepDiveButton.SetText(ToMessage("MAX DEPTH"))

# ---------------------------------------------------------------- Settings -
SettingCount : int = 7

(UI:player_ui_controller).BuildSettingsScreen():widget =
    set UI.SettingButtons = for (I := 0..SettingCount - 1). MakeActionButton(UI, "", ui_action.ToggleSetting, I, 1)
    Buttons : []widget = for (Button : UI.SettingButtons). Button
    Title : widget = MakeLabel("SETTINGS", 34.0, ThemeCyan)
    Note : widget = MakeLabel("OTHER PLAYER EFFECTS: announcements about other players' finds, hatches and dives.\nLOW EFFECTS MODE: turns off weather screen effects, your wake spray, egg glow and hatch energy build-up.", 13.0, ThemeMuted)
    MakeVStackLeft(array{Title} + Buttons + array{Note}, 5.0)

(UI:player_ui_controller).RefreshSettings():void =
    if (Session := UI.GetMySession[]):
        P := Session.Profile
        SwimControl := if (P.ThrottleToggle?) then "TAP TO START/STOP" else "HOLD TO SWIM"
        Labels := array:
            "MUSIC: {OnOffText(P.MusicOn)}"
            "SFX: {OnOffText(P.SfxOn)}"
            "CAMERA SHAKE: {OnOffText(P.CameraShakeOn)}"
            "HATCH CINEMATIC: {OnOffText(P.HatchCinematicOn)}"
            "OTHER PLAYER EFFECTS: {OnOffText(P.OtherPlayerEffectsOn)}"
            "LOW EFFECTS MODE: {OnOffText(P.LowEffectsMode)}"
            "SWIM CONTROL: {SwimControl}"
        for (I -> Button : UI.SettingButtons, Text := Labels[I]):
            Button.SetText(ToMessage(Text))

# ---------------------------------------------------------------- Dev ------
(UI:player_ui_controller).BuildDebugScreen():widget =
    set UI.DebugInfo = MakeLabel("", 20.0, ThemeWarning)
    CommandRow := MakeHStack(array{MakeActionButton(UI, "< COMMAND", ui_action.DebugPrevCommand, 0, 2), MakeActionButton(UI, "COMMAND >", ui_action.DebugNextCommand, 0, 2)}, 3.0)
    ArgButtons : []widget = array:
        MakeActionButton(UI, "-10", ui_action.DebugArgMinus10, 0, 2)
        MakeActionButton(UI, "-1", ui_action.DebugArgMinus, 0, 2)
        MakeActionButton(UI, "+1", ui_action.DebugArgPlus, 0, 2)
        MakeActionButton(UI, "+10", ui_action.DebugArgPlus10, 0, 2)
    ArgRow := MakeHStack(ArgButtons, 3.0)
    MakeVStackLeft(array{MakeLabel("DEVELOPER TOOLS (EDIT / PRIVATE SESSIONS ONLY)", 26.0, ThemeDanger), UI.DebugInfo, CommandRow, ArgRow, MakeActionButton(UI, "EXECUTE", ui_action.DebugExecute, 0, 0)}, 6.0)

(UI:player_ui_controller).RefreshDebug():void =
    Command := DebugCommandFromIndex(UI.DebugCommandIndex)
    Meaning := case (Command):
        debug_command.GiveCash => "ARG = POWER OF TEN (3 = $1K, 9 = $1B)"
        debug_command.SetHatchLuck => "ARG = UPGRADE COUNT ({FormatMultiplier(HatchLuckForUpgrades(Max(0, UI.DebugArg)))})"
        debug_command.SpawnEgg => "ARG = EGG ID ({EggName(Clamp(UI.DebugArg, 1, EggCount))})"
        debug_command.ForceTideReset => "NO ARG"
        debug_command.GiveCreature => "ARG = CREATURE ID ({CreatureName(Clamp(UI.DebugArg, 1, CreatureCount))})"
        debug_command.SetMutation => "ARG = MUTATION ID ({MutationName(Clamp(UI.DebugArg, 0, MutationCount - 1))}) ON ACTIVE MOUNT"
        debug_command.TriggerWeather => "ARG = WEATHER ({WeatherName(WeatherFromIndex(UI.DebugArg))})"
        debug_command.SetDayPhase => "ARG = 0 DAY, 1 SUNSET, 2 NIGHT"
        debug_command.CompleteIncubation => "NO ARG"
        debug_command.SetDeepDive => "ARG = DEEP DIVE LEVEL (0-{MaxDeepDives})"
        debug_command.TeleportBiome => "ARG = BIOME ({BiomeName(BiomeFromIndex(UI.DebugArg))})"
        debug_command.ClearSave => "WIPES YOUR SAVE (DEV ONLY)"
    SetLabel(UI.DebugInfo, "COMMAND: {DebugCommandName(Command)}\nARG: {UI.DebugArg}\n{Meaning}")
