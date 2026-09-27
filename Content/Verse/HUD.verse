# ============================================================================
# RIDE A SEA BEAST - HUD.verse
# Always-on, non-interactive HUD (input mode None, so it never blocks play).
#   TOP LEFT   : Cash, Income/sec, Friend Boost
#   TOP CENTER : Tide Reset countdown, world event, day/night + progress,
#                current biome, Sonar compass
#   RIGHT      : menu shortcuts
#   BOTTOM     : Egg Basket + crack timer, mount state, control hints
#   CENTER     : toasts, announcements, big messages, tutorial panel
# Placement avoids Fortnite's native health / minimap areas.
# ============================================================================
using { /Fortnite.com/UI }
using { /Verse.org/Colors }
using { /Verse.org/Simulation }
using { /UnrealEngine.com/Temporary/UI }
using { /UnrealEngine.com/Temporary/SpatialMath }

HudToastSlots : int = 3
SonarBarWidth : float = 520.0
SonarMarkerSize : float = 22.0

hud_view := class:
    var Root : canvas = canvas{}
    var CashLabel : text_block = text_block{}
    var IncomeLabel : text_block = text_block{}
    var BoostLabel : text_block = text_block{}
    var TideLabel : text_block = text_block{}
    var WeatherLabel : text_block = text_block{}
    var PhaseLabel : text_block = text_block{}
    var PhaseBar : ui_progress_bar = ui_progress_bar{Width := 260.0, Height := 8.0, Back := color_block{}, Fill := color_block{}}
    var BiomeLabel : text_block = text_block{}
    var BasketLabel : text_block = text_block{}
    var EggLabel : text_block = text_block{}
    var CrackLabel : text_block = text_block{}
    var MountLabel : text_block = text_block{}
    var HintLabel : text_block = text_block{}
    var MenuHintLabel : text_block = text_block{}
    # Sonar compass.
    var SonarRoot : stack_box = stack_box{Orientation := orientation.Vertical}
    var SonarNameLabel : text_block = text_block{}
    var SonarDistanceLabel : text_block = text_block{}
    var SonarSpacer : color_block = color_block{}
    var SonarMarker : color_block = color_block{}
    # Messages.
    var ToastLabels : []text_block = array{}
    var ToastExpire : []float = array{}
    var AnnouncementLabel : text_block = text_block{}
    var AnnouncementExpire : float = 0.0
    var BigLabel : text_block = text_block{}
    var BigExpire : float = 0.0
    # Tutorial.
    var TutorialRoot : overlay = overlay{}
    var TutorialStepLabel : text_block = text_block{}
    var TutorialTitleLabel : text_block = text_block{}
    var TutorialHintLabel : text_block = text_block{}

    Build():canvas =
        set CashLabel = MakeLabel("$0", 46.0, ThemeCash)
        set IncomeLabel = MakeLabel("+$0/s", 24.0, ThemeCash)
        set BoostLabel = MakeLabel("FRIEND BOOST (PARTY): +0%", 16.0, ThemePearl)
        set TideLabel = MakeCenteredLabel("TIDE CHANGES IN 08:00", 22.0, ThemeCyan)
        set WeatherLabel = MakeCenteredLabel("CLEAR SKIES", 18.0, ThemePearl)
        set PhaseLabel = MakeCenteredLabel("DAY", 16.0, ThemeGold)
        set PhaseBar = MakeProgressBar(260.0, 8.0, ThemeGold)
        set BiomeLabel = MakeCenteredLabel("CENTRAL LAGOON", 16.0, ThemeTurquoise)
        set BasketLabel = MakeCenteredLabel("EGG BASKET  0 / 1", 22.0, ThemePearl)
        set EggLabel = MakeCenteredLabel("", 20.0, ThemeWhite)
        set CrackLabel = MakeCenteredLabel("", 26.0, ThemeWarning)
        set MountLabel = MakeCenteredLabel("", 18.0, ThemeCyan)
        set HintLabel = MakeCenteredLabel("", 14.0, ThemeMuted)
        set MenuHintLabel = MakeLabel("HOLD RELOAD: MENU\nSEA BEASTS - OCEAN INDEX\nDEEP DIVE - SETTINGS", 15.0, ThemePearl)
        set SonarNameLabel = MakeCenteredLabel("", 18.0, ThemeCyan)
        set SonarDistanceLabel = MakeCenteredLabel("", 16.0, ThemeWhite)
        set SonarSpacer = MakeBlock(ThemeNavy, 0.0, SonarBarWidth * 0.5, SonarMarkerSize)
        set SonarMarker = MakeBlock(ThemeCyan, 1.0, SonarMarkerSize, SonarMarkerSize)
        set ToastLabels = for (I := 0..HudToastSlots - 1). MakeCenteredLabel("", 22.0, ThemeWhite)
        set ToastExpire = for (I := 0..HudToastSlots - 1). 0.0
        set AnnouncementLabel = MakeCenteredLabel("", 34.0, ThemeCyan)
        set BigLabel = MakeCenteredLabel("", 44.0, ThemeWhite)
        set TutorialStepLabel = MakeLabel("", 14.0, ThemeMuted)
        set TutorialTitleLabel = MakeLabel("", 24.0, ThemeGold)
        set TutorialHintLabel = MakeLabel("", 16.0, ThemePearl)

        TopLeft := MakePanel(MakeVStackLeft(array{CashLabel, IncomeLabel, BoostLabel}, 2.0), ThemeNavyDark, 0.55, 12.0)
        PhaseRow := MakeHStackCenter(array{PhaseLabel, PhaseBar.GetWidget()}, 4.0)
        # Sonar: a bar with a marker pushed sideways by a transparent spacer.
        SonarTrack := overlay:
            Slots := array:
                overlay_slot{Widget := MakeBlock(ThemeNavyDark, 0.8, SonarBarWidth, SonarMarkerSize), HorizontalAlignment := horizontal_alignment.Left, VerticalAlignment := vertical_alignment.Center}
                overlay_slot{Widget := MakeBlock(ThemeCyan, 0.5, 2.0, SonarMarkerSize + 8.0), HorizontalAlignment := horizontal_alignment.Center, VerticalAlignment := vertical_alignment.Center}
                overlay_slot{Widget := stack_box{Orientation := orientation.Horizontal, Slots := array{stack_box_slot{Widget := SonarSpacer}, stack_box_slot{Widget := SonarMarker}}}, HorizontalAlignment := horizontal_alignment.Left, VerticalAlignment := vertical_alignment.Center}
        set SonarRoot = MakeVStack(array{SonarNameLabel, SonarTrack, SonarDistanceLabel}, 2.0)
        SonarRoot.SetVisibility(widget_visibility.Collapsed)
        TopCenter := MakeVStack(array{TideLabel, WeatherLabel, PhaseRow, BiomeLabel, SonarRoot}, 2.0)
        BottomCenter := MakePanel(MakeVStack(array{BasketLabel, EggLabel, CrackLabel, MountLabel, HintLabel}, 1.0), ThemeNavyDark, 0.5, 10.0)
        ToastWidgets : []widget = for (Label : ToastLabels). Label
        Toasts := MakeVStack(ToastWidgets, 2.0)
        set TutorialRoot = MakePanel(MakeVStackLeft(array{TutorialStepLabel, TutorialTitleLabel, TutorialHintLabel}, 3.0), ThemeNavy, 0.82, 14.0)
        TutorialRoot.SetVisibility(widget_visibility.Collapsed)
        set Root = canvas:
            Slots := array:
                AnchoredSlot(TopLeft, 0.0, 0.0, 36.0, 120.0, 0.0, 0.0)
                AnchoredSlot(TopCenter, 0.5, 0.0, 0.0, 16.0, 0.5, 0.0)
                AnchoredSlot(MakePanel(MenuHintLabel, ThemeNavyDark, 0.45, 10.0), 1.0, 0.32, -24.0, 0.0, 1.0, 0.0)
                AnchoredSlot(BottomCenter, 0.5, 1.0, 0.0, -170.0, 0.5, 1.0)
                AnchoredSlot(Toasts, 0.5, 0.24, 0.0, 0.0, 0.5, 0.0)
                AnchoredSlot(AnnouncementLabel, 0.5, 0.36, 0.0, 0.0, 0.5, 0.5)
                AnchoredSlot(BigLabel, 0.5, 0.47, 0.0, 0.0, 0.5, 0.5)
                AnchoredSlot(TutorialRoot, 0.0, 0.45, 36.0, 0.0, 0.0, 0.5)
        Root

    # ---------------------------------------------------------- Setters -----
    SetEconomy(Cash:string, Income:string, Boost:string):void =
        SetLabel(CashLabel, Cash)
        SetLabel(IncomeLabel, Income)
        SetLabel(BoostLabel, Boost)

    SetTide(Text:string):void = SetLabel(TideLabel, Text)

    SetWeather(Text:string, TextColor:color):void =
        SetLabel(WeatherLabel, Text)
        WeatherLabel.SetTextColor(TextColor)

    SetPhase(Text:string, Progress:float, PhaseColor:color):void =
        SetLabel(PhaseLabel, Text)
        PhaseLabel.SetTextColor(PhaseColor)
        PhaseBar.SetProgress(Progress)
        PhaseBar.SetFillColor(PhaseColor)

    SetBiome(Text:string):void = SetLabel(BiomeLabel, Text)

    SetBasket(Basket:string, Egg:string, EggColor:color, Crack:string, Urgent:logic):void =
        SetLabel(BasketLabel, Basket)
        SetLabel(EggLabel, Egg)
        EggLabel.SetTextColor(EggColor)
        SetLabel(CrackLabel, Crack)
        CrackLabel.SetTextColor(if (Urgent?) then ThemeDanger else ThemeWarning)

    SetMount(Text:string, Hint:string):void =
        SetLabel(MountLabel, Text)
        SetLabel(HintLabel, Hint)

    # Relative bearing in degrees (-180..180, positive = right of camera).
    ShowSonar(Name:string, DistanceText:string, Relative:float, MarkerColor:color):void =
        SonarRoot.SetVisibility(widget_visibility.Visible)
        Clamped := ClampF(Relative / 90.0, -1.0, 1.0)
        X := (SonarBarWidth - SonarMarkerSize) * (0.5 + 0.5 * Clamped)
        SonarSpacer.SetDesiredSize(vector2{X := X, Y := SonarMarkerSize})
        SonarMarker.SetColor(MarkerColor)
        SetLabel(SonarNameLabel, "SONAR: {Name}")
        Direction := if (Relative < -90.0) then "<< BEHIND YOU (LEFT)" else if (Relative > 90.0) then "BEHIND YOU (RIGHT) >>" else if (Relative < -12.0) then "<< LEFT" else if (Relative > 12.0) then "RIGHT >>" else "AHEAD"
        SetLabel(SonarDistanceLabel, "{DistanceText}   {Direction}")

    ShowSonarSearching(Name:string):void =
        SonarRoot.SetVisibility(widget_visibility.Visible)
        SonarSpacer.SetDesiredSize(vector2{X := (SonarBarWidth - SonarMarkerSize) * 0.5, Y := SonarMarkerSize})
        SonarMarker.SetColor(ThemeMuted)
        SetLabel(SonarNameLabel, "{Name}: SIGNAL LOST")
        SetLabel(SonarDistanceLabel, "SEARCHING...")

    HideSonar():void = SonarRoot.SetVisibility(widget_visibility.Collapsed)

    # ---------------------------------------------------------- Messages ----
    PushToast(Text:string, TextColor:color, Now:float):void =
        # Shift older toasts down, newest on top.
        var Index : int = HudToastSlots - 1
        loop:
            if (Index <= 0):
                break
            if (Below := ToastLabels[Index], Above := ToastLabels[Index - 1], AboveExpire := ToastExpire[Index - 1]):
                Below.SetText(ToMessage(Above.GetText()))
                Below.SetTextColor(Above.GetTextColor())
                if (set ToastExpire[Index] = AboveExpire) {}
            set Index -= 1
        if (Top := ToastLabels[0]):
            SetLabel(Top, Text)
            Top.SetTextColor(TextColor)
            if (set ToastExpire[0] = Now + ToastSeconds) {}

    ShowAnnouncement(Text:message, TextColor:color, Now:float):void =
        AnnouncementLabel.SetText(Text)
        AnnouncementLabel.SetTextColor(TextColor)
        set AnnouncementExpire = Now + AnnouncementSeconds

    ShowBig(Text:string, TextColor:color, Now:float):void =
        SetLabel(BigLabel, Text)
        BigLabel.SetTextColor(TextColor)
        set BigExpire = Now + 3.0

    ExpireMessages(Now:float):void =
        for (I -> Label : ToastLabels, Expire := ToastExpire[I], Expire > 0.0, Now >= Expire):
            SetLabel(Label, "")
            if (set ToastExpire[I] = 0.0) {}
        if (AnnouncementExpire > 0.0, Now >= AnnouncementExpire):
            AnnouncementLabel.SetText(EmptyMessage)
            set AnnouncementExpire = 0.0
        if (BigExpire > 0.0, Now >= BigExpire):
            SetLabel(BigLabel, "")
            set BigExpire = 0.0

    ShowTutorial(Title:string, Hint:string, Step:int, Total:int):void =
        TutorialRoot.SetVisibility(widget_visibility.Visible)
        SetLabel(TutorialStepLabel, "TUTORIAL {Step}/{Total}")
        SetLabel(TutorialTitleLabel, Title)
        SetLabel(TutorialHintLabel, Hint)

    HideTutorial():void = TutorialRoot.SetVisibility(widget_visibility.Collapsed)
