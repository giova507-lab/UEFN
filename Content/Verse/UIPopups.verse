# ============================================================================
# RIDE A SEA BEAST - UIPopups.verse
# Popups and full-screen overlays:
#   * WHILE YOU WERE AWAY... offline rewards (CLAIM)
#   * confirmation dialog (sell required creature, sell duplicates, Deep Dive)
#   * hatch sequence overlay (silhouette -> reveal, rarity, stats, NEW
#     DISCOVERY, SKIP after the first viewing)
#   * Deep Dive transition + DEEP DIVE COMPLETE summary
#   * first-join intro overlay with SKIP
# Widget opacity is a refinement type, so fades step through literal values.
# ============================================================================
using { /Fortnite.com/UI }
using { /Verse.org/Colors }
using { /Verse.org/Simulation }
using { /UnrealEngine.com/Temporary/UI }
using { /UnrealEngine.com/Temporary/SpatialMath }

FadeStepCount : int = 6

# Literal opacity steps for fades (0 = transparent .. 6 = opaque).
OpacityStep(Step:int)<computes>:opacity_value =
    if (Step <= 0):
        0.0
    else if (Step = 1):
        0.18
    else if (Step = 2):
        0.35
    else if (Step = 3):
        0.52
    else if (Step = 4):
        0.7
    else if (Step = 5):
        0.86
    else:
        0.97

(UI:player_ui_controller).BuildPopup():void =
    set UI.PopupTitle = MakeCenteredLabel("", 30.0, ThemeGold)
    set UI.PopupBody = MakeCenteredLabel("", 22.0, ThemePearl)
    set UI.PopupPrimary = MakeActionButton(UI, "CLAIM", ui_action.ClaimOffline, 0, 0)
    set UI.PopupSecondary = MakeActionButton(UI, "CONFIRM", ui_action.ConfirmYes, 0, 0)
    Cancel := MakeActionButton(UI, "CANCEL", ui_action.ConfirmNo, 0, 2)
    Buttons : []widget = array{UI.PopupPrimary, UI.PopupSecondary, Cancel}
    set UI.PopupCancel = Cancel
    Content := MakeVStack(array{UI.PopupTitle, UI.PopupBody, MakeHStackCenter(Buttons, 8.0)}, 10.0)
    Window := MakeBorderedPanel(Content, ThemeGold, ThemeNavy, 26.0)
    set UI.PopupCanvas = canvas:
        Slots := array:
            FullScreenSlot(MakeBlock(ThemeNavyDark, 0.5, 1.0, 1.0))
            CenteredWindowSlot(Window, 900.0, 420.0)

(UI:player_ui_controller).PresentPopup():void =
    if (PlayerUI := GetPlayerUI[UI.Player]):
        if (UI.PopupAdded?):
            PlayerUI.RemoveWidget(UI.PopupCanvas)
        PlayerUI.AddWidget(UI.PopupCanvas, player_ui_slot{InputMode := ui_input_mode.All, ZOrder := 8})
        PlayerUI.SetFocus(UI.PopupPrimary)
        set UI.PopupAdded = true

(UI:player_ui_controller).ClosePopup():void =
    if (UI.PopupAdded?, PlayerUI := GetPlayerUI[UI.Player]):
        PlayerUI.RemoveWidget(UI.PopupCanvas)
    set UI.PopupAdded = false

(UI:player_ui_controller).ShowOfflineRewards(Amount:float):void =
    if (not UI.PopupBuilt?):
        UI.BuildPopup()
        set UI.PopupBuilt = true
    SetLabel(UI.PopupTitle, "WHILE YOU WERE AWAY...")
    SetLabel(UI.PopupBody, "YOUR SEA BEASTS FOUND:\n{FormatCash(Amount)}")
    ShowWidget(UI.PopupPrimary, true)
    ShowWidget(UI.PopupSecondary, false)
    ShowWidget(UI.PopupCancel, false)
    set UI.PendingConfirm = confirm_action.None
    UI.PresentPopup()

(UI:player_ui_controller).ShowConfirm(Text:string, Action:confirm_action):void =
    if (not UI.PopupBuilt?):
        UI.BuildPopup()
        set UI.PopupBuilt = true
    SetLabel(UI.PopupTitle, "ARE YOU SURE?")
    SetLabel(UI.PopupBody, Text)
    ShowWidget(UI.PopupPrimary, false)
    ShowWidget(UI.PopupSecondary, true)
    ShowWidget(UI.PopupCancel, true)
    set UI.PendingConfirm = Action
    UI.PresentPopup()
    if (PlayerUI := GetPlayerUI[UI.Player]):
        PlayerUI.SetFocus(UI.PopupCancel)

# ---------------------------------------------------------------- Overlay --
(UI:player_ui_controller).EnsureOverlay():void =
    if (not UI.OverlayBuilt?):
        set UI.OverlayBackdrop = MakeBlock(ThemeNavyDark, 0.0, 1.0, 1.0)
        set UI.OverlayTitle = MakeCenteredLabel("", 40.0, ThemeCyan)
        set UI.OverlayLine1 = MakeCenteredLabel("", 30.0, ThemeWhite)
        set UI.OverlayLine2 = MakeCenteredLabel("", 22.0, ThemePearl)
        set UI.OverlayLine3 = MakeCenteredLabel("", 26.0, ThemeGold)
        set UI.OverlaySkip = MakeActionButton(UI, "SKIP", ui_action.Skip, 0, 2)
        Card := MakeVStack(array{UI.OverlayTitle, UI.OverlayLine1, UI.OverlayLine2, UI.OverlayLine3}, 6.0)
        set UI.OverlayCanvas = canvas:
            Slots := array:
                FullScreenSlot(UI.OverlayBackdrop)
                AnchoredSlot(Card, 0.5, 0.42, 0.0, 0.0, 0.5, 0.5)
                AnchoredSlot(UI.OverlaySkip, 1.0, 1.0, -60.0, -200.0, 1.0, 1.0)
        set UI.OverlayBuilt = true

(UI:player_ui_controller).PresentOverlay(Interactive:logic):void =
    UI.EnsureOverlay()
    if (PlayerUI := GetPlayerUI[UI.Player]):
        if (UI.OverlayAdded?):
            PlayerUI.RemoveWidget(UI.OverlayCanvas)
        Mode := if (Interactive?) then ui_input_mode.All else ui_input_mode.None
        PlayerUI.AddWidget(UI.OverlayCanvas, player_ui_slot{InputMode := Mode, ZOrder := 7})
        set UI.OverlayAdded = true
        set UI.OverlayInteractive = Interactive
    ShowWidget(UI.OverlaySkip, Interactive)

(UI:player_ui_controller).HideOverlay():void =
    if (UI.OverlayAdded?, PlayerUI := GetPlayerUI[UI.Player]):
        PlayerUI.RemoveWidget(UI.OverlayCanvas)
    set UI.OverlayAdded = false

(UI:player_ui_controller).SetOverlayText(Title:string, Line1:string, Line2:string, Line3:string):void =
    SetLabel(UI.OverlayTitle, Title)
    SetLabel(UI.OverlayLine1, Line1)
    SetLabel(UI.OverlayLine2, Line2)
    SetLabel(UI.OverlayLine3, Line3)

(UI:player_ui_controller).FadeBackdrop(FromStep:int, ToStep:int, StepSeconds:float)<suspends>:void =
    var Step : int = FromStep
    loop:
        UI.OverlayBackdrop.SetOpacity(OpacityStep(Step))
        if (Step = ToStep):
            break
        set Step = if (ToStep > Step) then Step + 1 else Step - 1
        Sleep(StepSeconds)

# ---------------------------------------------------------------- Hatch ----
(UI:player_ui_controller).ShowHatchOverlay(CanSkip:logic):void =
    UI.EnsureOverlay()
    UI.CloseMenu()
    UI.OverlayBackdrop.SetOpacity(0.0)
    UI.SetOverlayText("HATCHING...", "", "", "")
    UI.OverlayTitle.SetTextColor(ThemeCyan)
    UI.PresentOverlay(CanSkip)

(UI:player_ui_controller).ShowHatchSilhouette(TypeID:int):void =
    R := CreatureRarity(TypeID)
    UI.SetOverlayText("???", "A {RarityName(R)} SEA BEAST EMERGES...", "", "")
    UI.OverlayTitle.SetTextColor(ThemeNavyDark)
    UI.OverlayLine1.SetTextColor(RarityColor(R))

(UI:player_ui_controller).ShowHatchReveal(C:owned_creature, IsNew:logic):void =
    R := CreatureRarity(C.TypeID)
    Stats := "SPEED {FormatCompact(CreatureDisplaySpeed(C))}   BREACH {FormatCompact(CreatureDisplayBreach(C))}   INCOME {FormatCash(CreatureIncomePerSecond(C))}/s"
    Trait := if (C.TraitID > 0) then "   TRAIT: {TraitName(C.TraitID)}" else ""
    NewText := if (IsNew?) then "NEW DISCOVERY!" else ""
    UI.SetOverlayText(CreatureName(C.TypeID), RarityName(R), "{Stats}{Trait}", NewText)
    UI.OverlayTitle.SetTextColor(RarityColor(R))
    UI.OverlayLine1.SetTextColor(RarityAccent(R))

(UI:player_ui_controller).HideHatchOverlay():void =
    UI.HideOverlay()

# Compact result used when the player disabled the hatch cinematic.
(UI:player_ui_controller).ShowHatchResultToast(C:owned_creature, IsNew:logic):void =
    R := CreatureRarity(C.TypeID)
    NewText := if (IsNew?) then "  NEW DISCOVERY!" else ""
    UI.ShowBigMessage("{CreatureName(C.TypeID)} ({RarityName(R)}){NewText}", RarityColor(R))

# ---------------------------------------------------------------- Deep Dive
(UI:player_ui_controller).ShowDeepDiveTransition():void =
    UI.EnsureOverlay()
    UI.SetOverlayText("", "", "", "")
    UI.PresentOverlay(false)
    spawn{ UI.FadeBackdrop(0, FadeStepCount, 0.18) }

(UI:player_ui_controller).ShowDeepDiveComplete(OldMultiplier:float, NewMultiplier:float, OldSlots:int, NewSlots:int):void =
    UI.SetOverlayText("DEEP DIVE COMPLETE", "MONEY MULTIPLIER:  {FormatCompact(OldMultiplier)}X  >  {FormatCompact(NewMultiplier)}X", "LAGOON CAPACITY:  {OldSlots}  >  {NewSlots}", "YOUR SEA BEASTS RETURN FROM THE DEEP.")
    UI.OverlayTitle.SetTextColor(ThemeCyan)
    UI.OverlayLine1.SetTextColor(ThemeGold)

(UI:player_ui_controller).HideDeepDiveOverlay():void =
    spawn{ UI.FadeOutAndHide() }

(UI:player_ui_controller).FadeOutAndHide()<suspends>:void =
    UI.FadeBackdrop(FadeStepCount, 0, 0.12)
    UI.HideOverlay()

# ---------------------------------------------------------------- Intro ----
(UI:player_ui_controller).ShowIntroOverlay():void =
    UI.EnsureOverlay()
    UI.OverlayBackdrop.SetOpacity(0.0)
    UI.SetOverlayText("RIDE A SEA BEAST", "", "", "")
    UI.OverlayTitle.SetTextColor(ThemeCyan)
    UI.PresentOverlay(true)

(UI:player_ui_controller).HideIntroOverlay():void =
    UI.HideOverlay()
