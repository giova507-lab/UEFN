# ============================================================================
# RIDE A SEA BEAST - UIManager.verse
# One player_ui_controller per player. It owns that player's HUD, menus and
# popups, reads state from the game device and turns button clicks into game
# calls. Buttons never change game state directly - every action goes
# through the game device, which validates it on the server.
# ============================================================================
using { /Fortnite.com/UI }
using { /Verse.org/Colors }
using { /Verse.org/Simulation }
using { /UnrealEngine.com/Temporary/UI }
using { /UnrealEngine.com/Temporary/SpatialMath }

player_ui_controller := class:
    Game : sea_beast_game_device
    Player : player
    SkipRequested : event() = event(){}

    var Hud : hud_view = hud_view{}
    var HudAdded : logic = false

    # ---- Menu window ----
    var MenuBuilt : logic = false
    var MenuAdded : logic = false
    var OpenScreen : menu_screen = menu_screen.None
    var MenuCanvas : canvas = canvas{}
    var TabRow : stack_box = stack_box{Orientation := orientation.Horizontal}
    var StationTitleLabel : text_block = text_block{}
    var GreetingLabel : text_block = text_block{}
    var DevTabButton : text_button_base = button_quiet{}
    var ScreenRoots : []widget = array{}

    # ---- Sea Beasts tab ----
    var Filter : creature_filter = creature_filter.All
    var Sort : creature_sort = creature_sort.BestIncome
    var Page : int = 0
    var SelectedUID : int = 0
    var SelectedFood : int = 0
    var VisibleUIDs : []int = array{}
    var Cards : []creature_card = array{}
    var PageLabel : text_block = text_block{}
    var SummaryLabel : text_block = text_block{}
    var FilterLabel : text_block = text_block{}
    var DetailName : text_block = text_block{}
    var DetailRarity : text_block = text_block{}
    var DetailStats : text_block = text_block{}
    var DetailExtra : text_block = text_block{}
    var PlaceButton : text_button_base = button_regular{}
    var FeedButton : text_button_base = button_regular{}
    var FavoriteButton : text_button_base = button_quiet{}
    var LockButton : text_button_base = button_quiet{}
    var FoodLabel : text_block = text_block{}

    # ---- Ocean Index tab ----
    var IndexTab : index_tab = index_tab.SeaBeasts
    var IndexPage : int = 0
    var IndexCards : []index_card = array{}
    var IndexHeader : text_block = text_block{}
    var IndexPageLabel : text_block = text_block{}
    var MilestoneButtons : []text_button_base = array{}

    # ---- Deep Dive tab ----
    var DeepDiveInfo : text_block = text_block{}
    var DeepDiveButton : text_button_base = button_loud{}

    # ---- Settings tab ----
    var SettingButtons : []text_button_base = array{}

    # ---- Dev tab ----
    var DebugCommandIndex : int = 0
    var DebugArg : int = 1
    var DebugInfo : text_block = text_block{}

    # ---- Stations ----
    var TrackerSort : tracker_sort = tracker_sort.HighestLuck
    var TrackerPage : int = 0
    var TrackerRows : []text_block = array{}
    var TrackerInfo : text_block = text_block{}
    var SonarRows : []text_block = array{}
    var SonarInfo : text_block = text_block{}
    var FoodRows : []text_block = array{}
    var FeedInfo : text_block = text_block{}
    var TraderPage : int = 0
    var TraderUIDs : []int = array{}
    var TraderRows : []text_block = array{}
    var TraderButtons : []text_button_base = array{}
    var TraderInfo : text_block = text_block{}

    # ---- Popups ----
    var PopupCanvas : canvas = canvas{}
    var PopupAdded : logic = false
    var PopupTitle : text_block = text_block{}
    var PopupBody : text_block = text_block{}
    var PopupPrimary : text_button_base = button_loud{}
    var PopupSecondary : text_button_base = button_quiet{}
    var PopupCancel : text_button_base = button_quiet{}
    var PopupBuilt : logic = false
    var PendingConfirm : confirm_action = confirm_action.None
    var PopupIsOffline : logic = false

    var OverlayCanvas : canvas = canvas{}
    var OverlayBuilt : logic = false
    var OverlayAdded : logic = false
    var OverlayInteractive : logic = false
    var OverlayBackdrop : color_block = color_block{}
    var OverlayTitle : text_block = text_block{}
    var OverlayLine1 : text_block = text_block{}
    var OverlayLine2 : text_block = text_block{}
    var OverlayLine3 : text_block = text_block{}
    var OverlaySkip : text_button_base = button_quiet{}

    var LastHoverSound : float = 0.0

    GetMySession()<transacts><decides>:player_session = Game.GetPlayerSession[Player]

    # ============================================================ HUD =======
    BuildHud():void =
        if (PlayerUI := GetPlayerUI[Player], not HudAdded?):
            Root := Hud.Build()
            PlayerUI.AddWidget(Root, player_ui_slot{InputMode := ui_input_mode.None, ZOrder := 1})
            set HudAdded = true
            RefreshHud()

    RefreshCash():void =
        if (Session := GetMySession[]):
            P := Session.Profile
            Income := Session.LastIncomePerSecond
            Hud.SetEconomy(FormatCash(P.Cash), FormatIncome(Income), "FRIEND BOOST (PARTY): {FormatPercent(Session.FriendBoost)}")

    RefreshHud():void =
        if (Session := GetMySession[]):
            RefreshCash()
            RefreshTimers(Game.GetNow())
            Hud.SetBiome(BiomeName(Session.CurrentBiome))
            RefreshBasket(Game.GetNow())
            RefreshMountLine()

    RefreshTimers(Now:float):void =
        Hud.SetTide("TIDE CHANGES IN {FormatClock(Game.GetTideRemaining())}")
        if (Game.CurrentWeather = weather_kind.Clear):
            Hud.SetWeather(WeatherName(Game.CurrentWeather), ThemePearl)
        else:
            Hud.SetWeather("{WeatherName(Game.CurrentWeather)}  {FormatClock(Game.GetWeatherRemaining())}", WeatherColor(Game.CurrentWeather))
        Info := Game.GetDayPhaseInfo()
        Phase := Info(0)
        PhaseText := if (Phase = day_phase.Night) then "NIGHT TIDE  10X EGG GROWTH" else DayPhaseName(Phase)
        Hud.SetPhase("{PhaseText}  {FormatClock(Info(2))}", Info(1), DayPhaseColor(Phase))

    RefreshBasket(Now:float):void =
        if (Session := GetMySession[]):
            Basket := "EGG BASKET  {Session.Carried.Length} / {MaxEggBasket}"
            if (Carried := Session.Carried[0]):
                Remaining := Carried.ExpireTime - Now
                EggLine := "{EggName(Carried.EggTypeID)}   {FormatLuck(EggLuck(Carried.EggTypeID))}"
                Hud.SetBasket(Basket, EggLine, RarityColor(EggRarity(Carried.EggTypeID)), "CRACKS IN {FormatClock(Remaining)}", logic{Remaining <= EggWarningSeconds})
            else:
                Hud.SetBasket(Basket, "", ThemeWhite, "", false)

    RefreshMountLine():void =
        if (Session := GetMySession[]):
            M := Session.Mount
            if (M.State = mount_state.Mounted):
                Speed := FormatDecimal(AbsF(M.Speed) / 100.0, 1)
                Boost := if (Session.BoostOn?) then "   FAST SWIM" else ""
                Cruise := if (Session.Profile.ThrottleToggle? and Session.CruiseOn?) then "   CRUISING" else ""
                HasAnalog := logic{Game.HasAnalogProvider[]}
                Mode := if (Session.Profile.ThrottleToggle?) then throttle_mode.Toggle else throttle_mode.Hold
                Hud.SetMount("RIDING {CreatureName(M.TypeID)}   {Speed} m/s{Boost}{Cruise}", MountControlsHint(HasAnalog, Mode))
            else if (M.State = mount_state.Mounting):
                Hud.SetMount("YOUR SEA BEAST IS COMING...", "")
            else:
                Hud.SetMount("ON FOOT", "RIDE: LAGOON DOCK OR HOLD RELOAD > SEA BEASTS > RIDE")

    # Called every HudRefreshSeconds by the game.
    Tick(Now:float):void =
        RefreshTimers(Now)
        RefreshBasket(Now)
        RefreshMountLine()
        Hud.ExpireMessages(Now)
        if (OpenScreen = menu_screen.Tracker or OpenScreen = menu_screen.SonarShop):
            RefreshStationTimers()

    ShowToast(Text:string, TextColor:color):void =
        Hud.PushToast(Text, TextColor, Game.GetNow())

    ShowAnnouncement(Text:message, TextColor:color):void =
        Hud.ShowAnnouncement(Text, TextColor, Game.GetNow())

    ShowBigMessage(Text:string, TextColor:color):void =
        Hud.ShowBig(Text, TextColor, Game.GetNow())

    ShowTutorial(Title:string, Hint:string, Step:int, Total:int):void =
        Hud.ShowTutorial(Title, Hint, Step, Total)

    HideTutorial():void = Hud.HideTutorial()

    ShowSonar(Name:string, Distance:string, Relative:float, MarkerColor:color):void =
        Hud.ShowSonar(Name, Distance, Relative, MarkerColor)

    ShowSonarSearching(Name:string):void = Hud.ShowSonarSearching(Name)
    HideSonar():void = Hud.HideSonar()

    OnButtonHover():void =
        Now := Game.GetNow()
        if (Now - LastHoverSound > 0.12, Session := GetMySession[]):
            set LastHoverSound = Now
            Game.PlaySfx(Session, sfx_key.UIHover)

    # ============================================================ Menus =====
    ToggleMainMenu():void =
        if (OpenScreen <> menu_screen.None):
            CloseMenu()
        else:
            OpenMenu(menu_screen.SeaBeasts)

    OpenMenu(Screen:menu_screen):void =
        if (Screen = menu_screen.None):
            CloseMenu()
            return
        if (Screen = menu_screen.Debug and not Game.IsDeveloperSession[]):
            return
        if (not MenuBuilt?):
            BuildMenus()
        set OpenScreen = Screen
        IsStation := logic{Screen = menu_screen.Tracker or Screen = menu_screen.SonarShop or Screen = menu_screen.FeedDock or Screen = menu_screen.Trader}
        ShowWidget(TabRow, if (IsStation?) then false else true)
        ShowWidget(StationTitleLabel, IsStation)
        ShowWidget(GreetingLabel, IsStation)
        ShowWidget(DevTabButton, logic{Game.IsDeveloperSession[]})
        for (I -> Root : ScreenRoots):
            ShowWidget(Root, logic{ScreenIndex(Screen) = I})
        RefreshOpenMenu()
        if (PlayerUI := GetPlayerUI[Player], not MenuAdded?):
            PlayerUI.AddWidget(MenuCanvas, player_ui_slot{InputMode := ui_input_mode.All, ZOrder := 5})
            set MenuAdded = true
        if (Session := GetMySession[]):
            Game.PlaySfx(Session, sfx_key.UIClick)

    CloseMenu():void =
        if (MenuAdded?, PlayerUI := GetPlayerUI[Player]):
            PlayerUI.RemoveWidget(MenuCanvas)
        set MenuAdded = false
        set OpenScreen = menu_screen.None

    # Station menus (NPC shops) show a header with the NPC name and a line.
    OpenStation(Screen:menu_screen, NPCName:string, Greeting:string, Title:string):void =
        OpenMenu(Screen)
        SetLabel(StationTitleLabel, "{NPCName}  -  {Title}")
        SetLabel(GreetingLabel, "\"{Greeting}\"")

    RefreshOpenMenu():void =
        if (not MenuAdded?):
            return
        if (OpenScreen = menu_screen.SeaBeasts):
            RefreshSeaBeasts()
        else if (OpenScreen = menu_screen.OceanIndex):
            RefreshIndex()
        else if (OpenScreen = menu_screen.DeepDive):
            RefreshDeepDive()
        else if (OpenScreen = menu_screen.Settings):
            RefreshSettings()
        else if (OpenScreen = menu_screen.Tracker):
            RefreshTracker()
        else if (OpenScreen = menu_screen.SonarShop):
            RefreshSonarShop()
        else if (OpenScreen = menu_screen.FeedDock):
            RefreshFeedDock()
        else if (OpenScreen = menu_screen.Trader):
            RefreshTrader()
        else if (OpenScreen = menu_screen.Debug):
            RefreshDebug()

    RefreshTrackerIfOpen():void =
        if (OpenScreen = menu_screen.Tracker):
            RefreshTracker()

    RefreshStationTimers():void =
        if (OpenScreen = menu_screen.Tracker):
            SetLabel(TrackerInfo, "TIDE RESET: {FormatClock(Game.GetTideRemaining())}")
        else if (OpenScreen = menu_screen.SonarShop):
            SetLabel(SonarInfo, "NEW STOCK IN {FormatClock(Game.GetSonarRestockRemaining())}")

    # ============================================================ Actions ===
    HandleAction(Action:ui_action, Arg:int):void =
        if (Session := GetMySession[]):
            if (Action <> ui_action.SelectCard):
                Game.PlaySfx(Session, sfx_key.UIClick)
            case (Action):
                ui_action.CloseMenu => CloseMenu()
                ui_action.OpenTab => OpenMenu(ScreenFromIndex(Arg))
                ui_action.SetFilter =>
                    set Filter = FilterFromIndex(Arg)
                    set Page = 0
                    RefreshSeaBeasts()
                ui_action.SetSort =>
                    set Sort = SortFromIndex(Arg)
                    set Page = 0
                    RefreshSeaBeasts()
                ui_action.PrevPage =>
                    set Page = Max(0, Page - 1)
                    RefreshSeaBeasts()
                ui_action.NextPage =>
                    set Page += 1
                    RefreshSeaBeasts()
                ui_action.SelectCard =>
                    if (UID := VisibleUIDs[Arg]):
                        set SelectedUID = UID
                        Game.PlaySfx(Session, sfx_key.UIClick)
                        RefreshSeaBeasts()
                ui_action.Ride =>
                    if (SelectedUID > 0):
                        CloseMenu()
                        Game.RequestMount(Session, SelectedUID, false)
                ui_action.TogglePlace =>
                    if (Game.IsPlaced[Session, SelectedUID]):
                        Game.RemoveCreatureFromLagoon(Session, SelectedUID)
                    else:
                        Game.PlaceCreature(Session, SelectedUID)
                ui_action.Feed => Game.FeedCreature(Session, SelectedUID, SelectedFood)
                ui_action.PrevFood =>
                    set SelectedFood = ModInt(SelectedFood - 1 + FoodCount, FoodCount)
                    RefreshSeaBeasts()
                ui_action.NextFood =>
                    set SelectedFood = ModInt(SelectedFood + 1, FoodCount)
                    RefreshSeaBeasts()
                ui_action.ToggleFavorite => Game.ToggleFavorite(Session, SelectedUID)
                ui_action.ToggleLock => Game.ToggleLock(Session, SelectedUID)
                ui_action.Sell => Game.RequestSell(Session, SelectedUID)
                ui_action.PlaceBest => Game.PlaceBest(Session)
                ui_action.SetIndexTab =>
                    set IndexTab = IndexTabFromIndex(Arg)
                    set IndexPage = 0
                    RefreshIndex()
                ui_action.IndexPrev =>
                    set IndexPage = Max(0, IndexPage - 1)
                    RefreshIndex()
                ui_action.IndexNext =>
                    set IndexPage += 1
                    RefreshIndex()
                ui_action.ClaimMilestone => Game.ClaimMilestone(Session, Arg)
                ui_action.DoDeepDive => Game.RequestDeepDive(Session)
                ui_action.ToggleSetting => ToggleSetting(Session, Arg)
                ui_action.SetTrackerSort =>
                    set TrackerSort = TrackerSortFromIndex(Arg)
                    set TrackerPage = 0
                    RefreshTracker()
                ui_action.TrackerPrev =>
                    set TrackerPage = Max(0, TrackerPage - 1)
                    RefreshTracker()
                ui_action.TrackerNext =>
                    set TrackerPage += 1
                    RefreshTracker()
                ui_action.BuySonar => Game.BuySonar(Session, Arg)
                ui_action.UseSonar => Game.ActivateSonar(Session, Arg)
                ui_action.BuyFood => Game.BuyFood(Session, Arg, 1)
                ui_action.BuyFood10 => Game.BuyFood(Session, Arg, 10)
                ui_action.TraderSell =>
                    if (UID := TraderUIDs[Arg]):
                        Game.RequestSell(Session, UID)
                ui_action.TraderPrev =>
                    set TraderPage = Max(0, TraderPage - 1)
                    RefreshTrader()
                ui_action.TraderNext =>
                    set TraderPage += 1
                    RefreshTrader()
                ui_action.SellDuplicates => Game.RequestSellAllDuplicates(Session)
                ui_action.ConfirmYes => OnConfirm(Session, true)
                ui_action.ConfirmNo => OnConfirm(Session, false)
                ui_action.ClaimOffline =>
                    ClosePopup()
                    Game.ClaimOfflineReward(Session)
                ui_action.Skip => SkipRequested.Signal()
                ui_action.DebugPrevCommand =>
                    set DebugCommandIndex = ModInt(DebugCommandIndex - 1 + DebugCommandCount, DebugCommandCount)
                    RefreshDebug()
                ui_action.DebugNextCommand =>
                    set DebugCommandIndex = ModInt(DebugCommandIndex + 1, DebugCommandCount)
                    RefreshDebug()
                ui_action.DebugArgMinus =>
                    set DebugArg -= 1
                    RefreshDebug()
                ui_action.DebugArgPlus =>
                    set DebugArg += 1
                    RefreshDebug()
                ui_action.DebugArgMinus10 =>
                    set DebugArg -= 10
                    RefreshDebug()
                ui_action.DebugArgPlus10 =>
                    set DebugArg += 10
                    RefreshDebug()
                ui_action.DebugExecute => Game.ExecuteDebugCommand(Session, DebugCommandFromIndex(DebugCommandIndex), DebugArg)
                ui_action.Dismount =>
                    CloseMenu()
                    Game.Dismount(Session, true)

    ToggleSetting(Session:player_session, Index:int):void =
        P := Session.Profile
        if (Index = 0):
            set P.MusicOn = if (P.MusicOn?) then false else true
            Game.UpdateMusic(Session)
        else if (Index = 1):
            set P.SfxOn = if (P.SfxOn?) then false else true
        else if (Index = 2):
            set P.CameraShakeOn = if (P.CameraShakeOn?) then false else true
        else if (Index = 3):
            set P.HatchCinematicOn = if (P.HatchCinematicOn?) then false else true
        else if (Index = 4):
            set P.OtherPlayerEffectsOn = if (P.OtherPlayerEffectsOn?) then false else true
        else if (Index = 5):
            set P.LowEffectsMode = if (P.LowEffectsMode?) then false else true
            if (P.LowEffectsMode?):
                Game.RemoveEnvironmentForPlayer(Session)
                Game.ReleaseCarryEffect(Session)
            else:
                Game.ApplyEnvironmentForPlayer(Session)
        else if (Index = 6):
            set P.ThrottleToggle = if (P.ThrottleToggle?) then false else true
            set Session.CruiseOn = false
        RefreshSettings()
        Game.SaveSession(Session)

    OnConfirm(Session:player_session, Accepted:logic):void =
        Action := PendingConfirm
        set PendingConfirm = confirm_action.None
        ClosePopup()
        if (Accepted?):
            if (Action = confirm_action.SellRequired):
                Game.ConfirmPendingSell(Session)
            else if (Action = confirm_action.SellDuplicates):
                Game.ExecuteSellAllDuplicates(Session)
            else if (Action = confirm_action.DeepDive):
                Game.ExecuteDeepDive(Session)
            else if (Action = confirm_action.ResetSave):
                Game.DevResetSave(Session)
        else:
            set Session.PendingSellUID = 0

# ---------------------------------------------------------------- Mappings -
ScreenIndex(Screen:menu_screen)<computes>:int =
    case (Screen):
        menu_screen.SeaBeasts => 0
        menu_screen.OceanIndex => 1
        menu_screen.DeepDive => 2
        menu_screen.Settings => 3
        menu_screen.Tracker => 4
        menu_screen.SonarShop => 5
        menu_screen.FeedDock => 6
        menu_screen.Trader => 7
        menu_screen.Debug => 8
        menu_screen.None => -1

ScreenFromIndex(I:int)<computes>:menu_screen =
    if (I = 0):
        menu_screen.SeaBeasts
    else if (I = 1):
        menu_screen.OceanIndex
    else if (I = 2):
        menu_screen.DeepDive
    else if (I = 3):
        menu_screen.Settings
    else if (I = 4):
        menu_screen.Tracker
    else if (I = 5):
        menu_screen.SonarShop
    else if (I = 6):
        menu_screen.FeedDock
    else if (I = 7):
        menu_screen.Trader
    else if (I = 8):
        menu_screen.Debug
    else:
        menu_screen.None

FilterFromIndex(I:int)<computes>:creature_filter =
    if (I = 1):
        creature_filter.Common
    else if (I = 2):
        creature_filter.Rare
    else if (I = 3):
        creature_filter.Epic
    else if (I = 4):
        creature_filter.Legendary
    else if (I = 5):
        creature_filter.Mythic
    else if (I = 6):
        creature_filter.Divine
    else if (I = 7):
        creature_filter.Ethereal
    else if (I = 8):
        creature_filter.Mutated
    else if (I = 9):
        creature_filter.Locked
    else:
        creature_filter.All

FilterName(F:creature_filter)<computes>:string =
    case (F):
        creature_filter.All => "ALL"
        creature_filter.Common => "COMMON"
        creature_filter.Rare => "RARE"
        creature_filter.Epic => "EPIC"
        creature_filter.Legendary => "LEGENDARY"
        creature_filter.Mythic => "MYTHIC"
        creature_filter.Divine => "DIVINE"
        creature_filter.Ethereal => "ETHEREAL"
        creature_filter.Mutated => "MUTATED"
        creature_filter.Locked => "LOCKED"

SortFromIndex(I:int)<computes>:creature_sort =
    if (I = 0):
        creature_sort.BestSpeed
    else if (I = 2):
        creature_sort.BestBreach
    else if (I = 3):
        creature_sort.Rarity
    else if (I = 4):
        creature_sort.Newest
    else:
        creature_sort.BestIncome

SortName(S:creature_sort)<computes>:string =
    case (S):
        creature_sort.BestSpeed => "BEST SPEED"
        creature_sort.BestIncome => "BEST INCOME"
        creature_sort.BestBreach => "BEST BREACH"
        creature_sort.Rarity => "RARITY"
        creature_sort.Newest => "NEWEST"

IndexTabFromIndex(I:int)<computes>:index_tab =
    if (I = 1):
        index_tab.SeaEggs
    else if (I = 2):
        index_tab.Mutations
    else:
        index_tab.SeaBeasts

TrackerSortFromIndex(I:int)<computes>:tracker_sort =
    if (I = 1):
        tracker_sort.LowestLuck
    else if (I = 2):
        tracker_sort.Rarity
    else:
        tracker_sort.HighestLuck

DebugCommandCount : int = 12

DebugCommandFromIndex(I:int)<computes>:debug_command =
    if (I = 1):
        debug_command.SetHatchLuck
    else if (I = 2):
        debug_command.SpawnEgg
    else if (I = 3):
        debug_command.ForceTideReset
    else if (I = 4):
        debug_command.GiveCreature
    else if (I = 5):
        debug_command.SetMutation
    else if (I = 6):
        debug_command.TriggerWeather
    else if (I = 7):
        debug_command.SetDayPhase
    else if (I = 8):
        debug_command.CompleteIncubation
    else if (I = 9):
        debug_command.SetDeepDive
    else if (I = 10):
        debug_command.TeleportBiome
    else if (I = 11):
        debug_command.ClearSave
    else:
        debug_command.GiveCash

# Opens a hub station for a player (called by menu_station_device).
(G:sea_beast_game_device).OpenStation(Player:player, Station:menu_station_device):void =
    if (Session := G.GetPlayerSession[Player], Session.Loaded?):
        Screen := case (Station.Station):
            station_kind.CurrentTracker => menu_screen.Tracker
            station_kind.SonarShack => menu_screen.SonarShop
            station_kind.FeedDock => menu_screen.FeedDock
            station_kind.HarborTrader => menu_screen.Trader
            station_kind.OceanIndex => menu_screen.OceanIndex
            station_kind.Settings => menu_screen.Settings
            station_kind.SeaBeasts => menu_screen.SeaBeasts
            station_kind.DeepDive => menu_screen.DeepDive
        Session.UI.OpenStation(Screen, Station.NPCName, Station.PickGreeting(), Station.StationTitle())
