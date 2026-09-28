# ============================================================================
# RIDE A SEA BEAST - TutorialManager.verse
# Onboarding (target: under 5 minutes):
#   1 WELCOME TO RIDE A SEA BEAST!      (auto)
#   2 THIS IS YOUR LAGOON.              (auto)
#   3 MOUNT YOUR SEA SLUG.              (until mounted)
#   4 SEARCH THE NEARBY REEF FOR A SEA EGG. (a personal Pearl Egg spawns
#                                        next to the Lagoon)
#   5 BRING IT HOME BEFORE IT CRACKS!   (until secured)
#   6 PLACE IT IN YOUR INCUBATOR.       (until incubating)
#   7 HATCH NEW SEA BEASTS.             (tutorial egg incubates in 20 s and
#                                        the first hatch is at least a
#                                        Hermit Crab)
#   8 FASTER BEASTS CAN REACH RARER EGGS! (auto) -> done
# Progress is saved, so a player who leaves mid-tutorial resumes the step.
# ============================================================================
using { /Verse.org/Simulation }

TutorialAutoStepSeconds : float = 4.0
TutorialPollSeconds : float = 0.5

(G:sea_beast_game_device).StartTutorialIfNeeded(Session:player_session):void =
    P := Session.Profile
    if (Session.Loaded?, not P.TutorialComplete?, not Session.TutorialTaskRunning?):
        if (P.TutorialStep = 0):
            G.TrackFirst(Session, analytics_key.TutorialStarted)
        spawn{ G.RunTutorial(Session) }

(G:sea_beast_game_device).AdvanceTutorial(Session:player_session):void =
    set Session.Profile.TutorialStep += 1
    G.SaveSession(Session)

(G:sea_beast_game_device).HasIncubatingEgg(Session:player_session)<transacts><decides>:void =
    var Found : logic = false
    for (Incubator : Session.Profile.Incubators, Incubator.EggTypeID > 0):
        set Found = true
    Found?

# Before a player's first hatch, ONE incubating egg (the closest to hatching)
# is shortened to the tutorial incubation time, unless an egg is already
# that close. Only one: the tutorial must not speed up other eggs.
(G:sea_beast_game_device).CapFirstHatchTime(Session:player_session):void =
    P := Session.Profile
    if (P.TotalHatches = 0):
        var BestIndex : int = -1
        var BestRemaining : float = 1000000000.0
        for (I -> Incubator : P.Incubators, Incubator.EggTypeID > 0, Incubator.Required - Incubator.Progress < BestRemaining):
            set BestIndex = I
            set BestRemaining = Incubator.Required - Incubator.Progress
        if (BestIndex >= 0, BestRemaining > TutorialIncubationSeconds, Incubator := P.Incubators[BestIndex]):
            set Incubator.Required = Incubator.Progress + TutorialIncubationSeconds
            G.UpdateIncubatorSign(Session, BestIndex)

(G:sea_beast_game_device).RunTutorial(Session:player_session)<suspends>:void =
    set Session.TutorialTaskRunning = true
    P := Session.Profile
    loop:
        if (not Session.Loaded? or not G.Sessions[Session.Player]):
            break
        Step := TutorialStepFromIndex(P.TutorialStep)
        if (Step = tutorial_step.Done):
            break
        Session.UI.ShowTutorial(TutorialText(Step), TutorialHint(Step), P.TutorialStep + 1, 8)
        if (Step = tutorial_step.Welcome or Step = tutorial_step.ThisIsYourLagoon or Step = tutorial_step.FasterBeasts):
            Sleep(TutorialAutoStepSeconds)
            G.AdvanceTutorial(Session)
        else if (Step = tutorial_step.MountSeaSlug):
            if (Session.Mount.State = mount_state.Mounted):
                G.AdvanceTutorial(Session)
            else:
                Sleep(TutorialPollSeconds)
        else if (Step = tutorial_step.FindEgg):
            if (Session.Carried.Length > 0 or G.HasIncubatingEgg[Session] or P.TotalHatches > 0):
                G.AdvanceTutorial(Session)
            else:
                if (Session.TutorialEggUID = 0):
                    G.SpawnTutorialEgg(Session)
                Sleep(TutorialPollSeconds)
        else if (Step = tutorial_step.BringItHome):
            if (G.HasIncubatingEgg[Session] or P.TotalHatches > 0):
                G.AdvanceTutorial(Session)
            else if (Session.Carried.Length = 0):
                # The egg cracked: go back to finding one.
                set P.TutorialStep = TutorialStepIndex(tutorial_step.FindEgg)
            else:
                Sleep(TutorialPollSeconds)
        else if (Step = tutorial_step.PlaceInIncubator):
            if (G.HasIncubatingEgg[Session] or P.TotalHatches > 0):
                G.AdvanceTutorial(Session)
            else if (Session.Carried.Length = 0):
                set P.TutorialStep = TutorialStepIndex(tutorial_step.FindEgg)
            else:
                Sleep(TutorialPollSeconds)
        else if (Step = tutorial_step.HatchIt):
            if (P.TotalHatches > 0):
                G.AdvanceTutorial(Session)
            else if (not G.HasIncubatingEgg[Session] and Session.Carried.Length = 0):
                set P.TutorialStep = TutorialStepIndex(tutorial_step.FindEgg)
            else:
                # The very first hatch is always quick, even when a returning
                # player's incubator holds a slow egg from an earlier visit.
                G.CapFirstHatchTime(Session)
                Sleep(TutorialPollSeconds)
        else:
            Sleep(TutorialPollSeconds)
    if (Session.Loaded?, TutorialStepFromIndex(P.TutorialStep) = tutorial_step.Done, not P.TutorialComplete?):
        set P.TutorialComplete = true
        # A personal tutorial egg that was never picked up is removed.
        G.ReleaseTutorialEgg(Session)
        G.TrackFirst(Session, analytics_key.TutorialComplete)
        Session.UI.HideTutorial()
        G.ShowToast(Session, "TUTORIAL COMPLETE! VISIT MARINA'S CURRENT TRACKER AND FINN'S SONAR SHACK.", ThemeGold)
        G.SaveSession(Session)
    set Session.TutorialTaskRunning = false

# Event nudges from other systems (the tutorial loop also polls, so these
# only make the response feel instant).
# Only the personal tutorial egg itself clears the reference; picking up a
# public egg leaves the tutorial egg tracked so it can still be released.
(G:sea_beast_game_device).OnTutorialEggClaimed(Session:player_session, EggUID:int):void =
    if (EggUID = Session.TutorialEggUID):
        set Session.TutorialEggUID = 0

(G:sea_beast_game_device).OnTutorialEggSecured(Session:player_session):void = {}
(G:sea_beast_game_device).OnTutorialEggReady(Session:player_session):void = {}
(G:sea_beast_game_device).OnTutorialHatched(Session:player_session):void = {}
