# ============================================================================
# RIDE A SEA BEAST - Text.verse
# Localizable message builders. Static player-facing strings are defined here
# so they can be translated in one place. Dynamic values are formatted by
# NumberFormatter.verse and injected through ToMessage.
# ============================================================================

ToMessage<localizes>(Text:string):message = "{Text}"
EmptyMessage<localizes>:message = ""

# Player names can only reach the screen through localized messages - Verse
# never exposes a player's name as a string.
PlayerNameMessage<localizes>(Agent:agent):message = "{Agent}"
LagoonTitleMessage<localizes>(Owner:agent):message = "{Owner}'S LAGOON"
LagoonTitleWithCosmeticMessage<localizes>(Owner:agent, Title:string):message = "{Owner}'S LAGOON\n{Title}"
AvailableLagoonMessage<localizes>:message = "AVAILABLE LAGOON"

# Interaction prompts.
TakeEggPrompt<localizes>:message = "TAKE SEA EGG"
PlaceEggPrompt<localizes>:message = "PLACE EGG"
HatchPrompt<localizes>:message = "HATCH!"
IncubatingPrompt<localizes>(Remaining:string):message = "INCUBATING {Remaining}"
EmptyIncubatorPrompt<localizes>:message = "EMPTY INCUBATOR"
NotYourIncubatorPrompt<localizes>:message = "NOT YOUR LAGOON"
HatchingPrompt<localizes>:message = "HATCHING..."
UpgradePrompt<localizes>(Cost:string):message = "UPGRADE HATCH LUCK ({Cost})"
UpgradeMaxPrompt<localizes>:message = "BUY MAX HATCH LUCK"
HatchLuckIdlePrompt<localizes>:message = "HATCH LUCK"
PlaceBestPrompt<localizes>:message = "PLACE BEST"
ManageBeastsPrompt<localizes>:message = "SEA BEASTS"
DeepDivePrompt<localizes>:message = "DEEP DIVE"
RideDockPrompt<localizes>:message = "RIDE SEA BEAST"
TalkPrompt<localizes>(Name:string):message = "TALK TO {Name}"
OpenStationPrompt<localizes>(Name:string):message = "OPEN {Name}"

# Announcements (global).
TideChangedMessage<localizes>:message = "THE TIDE HAS CHANGED!\nNEW SEA EGGS HAVE APPEARED!"
RareEggSurfacedMessage<localizes>(EggText:string):message = "AN {EggText} HAS SURFACED!"
RareEggAppearedMessage<localizes>(EggText:string):message = "A {EggText} HAS APPEARED!"
PlayerFoundMessage<localizes>(Agent:agent, What:string):message = "{Agent} FOUND {What}!"
PlayerHatchedMessage<localizes>(Agent:agent, What:string):message = "{Agent} HATCHED {What}!"
PlayerDidMessage<localizes>(Agent:agent, What:string):message = "{Agent} {What}"

# Tutorial.
TutorialText(Step:tutorial_step)<computes>:string =
    case (Step):
        tutorial_step.Welcome => "WELCOME TO RIDE A SEA BEAST!"
        tutorial_step.ThisIsYourLagoon => "THIS IS YOUR LAGOON."
        tutorial_step.MountSeaSlug => "MOUNT YOUR SEA SLUG."
        tutorial_step.FindEgg => "SEARCH THE NEARBY REEF FOR A SEA EGG."
        tutorial_step.BringItHome => "BRING IT HOME BEFORE IT CRACKS!"
        tutorial_step.PlaceInIncubator => "PLACE IT IN YOUR INCUBATOR."
        tutorial_step.HatchIt => "HATCH NEW SEA BEASTS."
        tutorial_step.FasterBeasts => "FASTER BEASTS CAN REACH RARER EGGS!"
        tutorial_step.Done => ""

TutorialHint(Step:tutorial_step)<computes>:string =
    case (Step):
        tutorial_step.MountSeaSlug => "Use the RIDE dock at your Lagoon, or hold RELOAD and press RIDE."
        tutorial_step.FindEgg => "Look for a glowing Pearl Egg near your Lagoon."
        tutorial_step.BringItHome => "Ride back into your Lagoon to secure it."
        tutorial_step.PlaceInIncubator => "Interact with an empty incubator."
        tutorial_step.HatchIt => "Interact with the incubator when it says HATCH!"
        _ => ""

# Mounted control hints for the bottom of the HUD.
MountControlsHint(HasAnalogMove:logic, Mode:throttle_mode)<computes>:string =
    if (HasAnalogMove?):
        "MOVE: SWIM   SPRINT: FAST SWIM   JUMP: BREACH   CROUCH: DIVE   STOP + JUMP: DISMOUNT"
    else if (Mode = throttle_mode.Toggle):
        "LOOK: STEER   FIRE: START/STOP   SPRINT: FAST SWIM   JUMP: BREACH   CROUCH: DIVE   STOP + JUMP: DISMOUNT"
    else:
        "LOOK: STEER   HOLD FIRE: SWIM   HOLD AIM: BRAKE   SPRINT: FAST SWIM   JUMP: BREACH   CROUCH: DIVE   STOP + JUMP: DISMOUNT"

OnFootControlsHint<localizes>:message = "HOLD RELOAD: MENU"
