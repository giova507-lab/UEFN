# ============================================================================
# RIDE A SEA BEAST - UIKit.verse
# Small widget toolkit for the original ocean UI theme (navy / cyan /
# turquoise / white / pearl / gold). Every screen is built from these helpers
# so fonts, colors, spacing and button feedback stay consistent.
# All widgets are created per player - there is no shared global UI state.
# ============================================================================
using { /Fortnite.com/UI }
using { /Verse.org/Colors }
using { /Verse.org/Simulation }
using { /UnrealEngine.com/Temporary/UI }
using { /UnrealEngine.com/Temporary/SpatialMath }

# Every clickable element dispatches one of these actions (Verse has no
# closures, so buttons carry an action + integer argument instead).
ui_action := enum {
    CloseMenu
    OpenTab
    SetFilter
    SetSort
    PrevPage
    NextPage
    SelectCard
    Ride
    TogglePlace
    Feed
    PrevFood
    NextFood
    ToggleFavorite
    ToggleLock
    Sell
    PlaceBest
    SetIndexTab
    IndexPrev
    IndexNext
    ClaimMilestone
    DoDeepDive
    ToggleSetting
    SetTrackerSort
    TrackerPrev
    TrackerNext
    BuySonar
    UseSonar
    BuyFood
    BuyFood10
    TraderSell
    TraderPrev
    TraderNext
    SellDuplicates
    ConfirmYes
    ConfirmNo
    ClaimOffline
    Skip
    DebugPrevCommand
    DebugNextCommand
    DebugArgMinus
    DebugArgPlus
    DebugArgMinus10
    DebugArgPlus10
    DebugExecute
    Dismount
}

ui_button_handler := class:
    UI : player_ui_controller
    Action : ui_action
    Arg : int
    OnClick(Message:widget_message):void = UI.HandleAction(Action, Arg)
    OnHighlight(Message:widget_message):void = UI.OnButtonHover()

# ---------------------------------------------------------------- Text -----
MakeLabel(Text:string, Size:float, TextColor:color):text_block =
    text_block:
        DefaultText := ToMessage(Text)
        DefaultTextColor := TextColor
        DefaultTextSize := Size
        DefaultShadowOffset := option{vector2{X := 2.0, Y := 2.0}}
        DefaultShadowColor := ThemeNavyDark
        DefaultShadowOpacity := 0.85

MakeCenteredLabel(Text:string, Size:float, TextColor:color):text_block =
    text_block:
        DefaultText := ToMessage(Text)
        DefaultTextColor := TextColor
        DefaultTextSize := Size
        DefaultJustification := text_justification.Center
        DefaultShadowOffset := option{vector2{X := 2.0, Y := 2.0}}
        DefaultShadowColor := ThemeNavyDark
        DefaultShadowOpacity := 0.85

SetLabel(Label:text_block, Text:string):void = Label.SetText(ToMessage(Text))

# ---------------------------------------------------------------- Blocks ---
# Widget opacity is a refinement type in Verse (0..1); callers pass literals.
opacity_value := type{_X:float where 0.0 <= _X, _X <= 1.0}

MakeBlock(BlockColor:color, Opacity:opacity_value, Width:float, Height:float):color_block =
    color_block:
        DefaultColor := BlockColor
        DefaultOpacity := Opacity
        DefaultDesiredSize := vector2{X := Width, Y := Height}

# ---------------------------------------------------------------- Buttons --
# Text button bound to an action. Style: 0 loud, 1 regular, 2 quiet.
MakeActionButton(UI:player_ui_controller, Text:string, Action:ui_action, Arg:int, Style:int):text_button_base =
    Handler := ui_button_handler{UI := UI, Action := Action, Arg := Arg}
    if (Style = 0):
        B := button_loud{DefaultText := ToMessage(Text)}
        B.OnClick().Subscribe(Handler.OnClick)
        B
    else if (Style = 1):
        B := button_regular{DefaultText := ToMessage(Text)}
        B.OnClick().Subscribe(Handler.OnClick)
        B
    else:
        B := button_quiet{DefaultText := ToMessage(Text)}
        B.OnClick().Subscribe(Handler.OnClick)
        B

# Generic button wrapping any widget (cards). Hover plays a sound.
MakeWidgetButton(UI:player_ui_controller, Content:widget, Action:ui_action, Arg:int):button =
    Handler := ui_button_handler{UI := UI, Action := Action, Arg := Arg}
    B := button{Slot := button_slot{Widget := Content, HorizontalAlignment := horizontal_alignment.Fill, VerticalAlignment := vertical_alignment.Fill}}
    B.OnClick().Subscribe(Handler.OnClick)
    B.HighlightEvent().Subscribe(Handler.OnHighlight)
    B

# ---------------------------------------------------------------- Layout ---
StackSlot(Content:widget, Pad:float):stack_box_slot =
    stack_box_slot:
        Widget := Content
        Padding := margin{Left := Pad, Top := Pad, Right := Pad, Bottom := Pad}
        HorizontalAlignment := horizontal_alignment.Fill
        VerticalAlignment := vertical_alignment.Center

StackSlotLeft(Content:widget, Pad:float):stack_box_slot =
    stack_box_slot:
        Widget := Content
        Padding := margin{Left := Pad, Top := Pad, Right := Pad, Bottom := Pad}
        HorizontalAlignment := horizontal_alignment.Left
        VerticalAlignment := vertical_alignment.Center

StackSlotCenter(Content:widget, Pad:float):stack_box_slot =
    stack_box_slot:
        Widget := Content
        Padding := margin{Left := Pad, Top := Pad, Right := Pad, Bottom := Pad}
        HorizontalAlignment := horizontal_alignment.Center
        VerticalAlignment := vertical_alignment.Center

MakeVStack(Contents:[]widget, Pad:float):stack_box =
    stack_box:
        Orientation := orientation.Vertical
        Slots := for (Content : Contents). StackSlot(Content, Pad)

MakeVStackLeft(Contents:[]widget, Pad:float):stack_box =
    stack_box:
        Orientation := orientation.Vertical
        Slots := for (Content : Contents). StackSlotLeft(Content, Pad)

MakeHStack(Contents:[]widget, Pad:float):stack_box =
    stack_box:
        Orientation := orientation.Horizontal
        Slots := for (Content : Contents). StackSlot(Content, Pad)

MakeHStackCenter(Contents:[]widget, Pad:float):stack_box =
    stack_box:
        Orientation := orientation.Horizontal
        Slots := for (Content : Contents). StackSlotCenter(Content, Pad)

OverlayFill(Content:widget):overlay_slot =
    overlay_slot:
        Widget := Content
        HorizontalAlignment := horizontal_alignment.Fill
        VerticalAlignment := vertical_alignment.Fill

OverlayPadded(Content:widget, Pad:float):overlay_slot =
    overlay_slot:
        Widget := Content
        Padding := margin{Left := Pad, Top := Pad, Right := Pad, Bottom := Pad}
        HorizontalAlignment := horizontal_alignment.Fill
        VerticalAlignment := vertical_alignment.Fill

# A panel: colored background with padded content on top.
MakePanel(Content:widget, BackColor:color, Opacity:opacity_value, Pad:float):overlay =
    overlay:
        Slots := array:
            OverlayFill(MakeBlock(BackColor, Opacity, 1.0, 1.0))
            OverlayPadded(Content, Pad)

# A panel with a colored outline (rarity borders).
MakeBorderedPanel(Content:widget, BorderColor:color, BackColor:color, Pad:float):overlay =
    overlay:
        Slots := array:
            OverlayFill(MakeBlock(BorderColor, 1.0, 1.0, 1.0))
            OverlayPadded(MakeBlock(BackColor, 0.94, 1.0, 1.0), 3.0)
            OverlayPadded(Content, Pad)

# Canvas slot anchored at (AnchorX, AnchorY) in 0..1 screen space.
AnchoredSlot(Content:widget, AnchorX:float, AnchorY:float, OffsetX:float, OffsetY:float, AlignX:float, AlignY:float):canvas_slot =
    canvas_slot:
        Widget := Content
        Anchors := anchors{Minimum := vector2{X := AnchorX, Y := AnchorY}, Maximum := vector2{X := AnchorX, Y := AnchorY}}
        Offsets := margin{Left := OffsetX, Top := OffsetY, Right := 0.0, Bottom := 0.0}
        Alignment := vector2{X := AlignX, Y := AlignY}
        SizeToContent := true

# Fixed-size centered window slot.
CenteredWindowSlot(Content:widget, Width:float, Height:float):canvas_slot =
    canvas_slot:
        Widget := Content
        Anchors := anchors{Minimum := vector2{X := 0.5, Y := 0.5}, Maximum := vector2{X := 0.5, Y := 0.5}}
        Offsets := margin{Left := 0.0, Top := 0.0, Right := Width, Bottom := Height}
        Alignment := vector2{X := 0.5, Y := 0.5}
        SizeToContent := false

FullScreenSlot(Content:widget):canvas_slot =
    canvas_slot:
        Widget := Content
        Anchors := anchors{Minimum := vector2{X := 0.0, Y := 0.0}, Maximum := vector2{X := 1.0, Y := 1.0}}
        Offsets := margin{Left := 0.0, Top := 0.0, Right := 0.0, Bottom := 0.0}
        SizeToContent := false

# ---------------------------------------------------------------- Bars -----
# Horizontal progress bar made of two color blocks.
ui_progress_bar := class:
    Width : float
    Height : float
    Back : color_block
    Fill : color_block

    SetProgress(Fraction:float):void =
        Fill.SetDesiredSize(vector2{X := Width * ClampF(Fraction, 0.0, 1.0), Y := Height})

    SetFillColor(FillColor:color):void = Fill.SetColor(FillColor)

    GetWidget():overlay =
        overlay:
            Slots := array:
                overlay_slot{Widget := Back, HorizontalAlignment := horizontal_alignment.Left, VerticalAlignment := vertical_alignment.Center}
                overlay_slot{Widget := Fill, HorizontalAlignment := horizontal_alignment.Left, VerticalAlignment := vertical_alignment.Center}

MakeProgressBar(Width:float, Height:float, FillColor:color):ui_progress_bar =
    ui_progress_bar:
        Width := Width
        Height := Height
        Back := MakeBlock(ThemeNavyDark, 0.85, Width, Height)
        Fill := MakeBlock(FillColor, 1.0, 0.0, Height)

# ---------------------------------------------------------------- Helpers --
OnOffText(Value:logic)<computes>:string = if (Value?) then "ON" else "OFF"

ShowWidget(W:widget, Visible:logic):void =
    if (Visible?):
        W.SetVisibility(widget_visibility.Visible)
    else:
        W.SetVisibility(widget_visibility.Collapsed)
