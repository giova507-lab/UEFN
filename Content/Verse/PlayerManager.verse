# ============================================================================
# RIDE A SEA BEAST - PlayerManager.verse
# Join / leave / respawn flow and session lookups.
# Join: assign a Lagoon -> load save -> starter creature -> UI -> input ->
#       teleport home -> offline rewards -> intro (first join) -> tutorial.
# ============================================================================
using { /Fortnite.com/Devices }
using { /Fortnite.com/Characters }
using { /Fortnite.com/Playspaces }
using { /Fortnite.com/UI }
using { /Verse.org/Simulation }
using { /UnrealEngine.com/Temporary/SpatialMath }
using { /UnrealEngine.com/Temporary/UI }

(G:sea_beast_game_device).GetPlayerSession(Player:player)<transacts><decides>:player_session =
    G.Sessions[Player]

(G:sea_beast_game_device).GetAgentSession(Agent:agent)<transacts><decides>:player_session =
    Player := player[Agent]
    G.Sessions[Player]

(G:sea_beast_game_device).OnPlayerAdded(Player:player):void =
    spawn{ G.HandlePlayerJoin(Player) }

(G:sea_beast_game_device).HandlePlayerJoin(Player:player)<suspends>:void =
    if (G.Sessions[Player]):
        return
    Session := player_session{Player := Player, UI := player_ui_controller{Game := G, Player := Player}}
    set Session.JoinTime = G.GetNow()
    set Session.VisitedBiomes = for (I := 0..BiomeCount - 1). false
    if (set G.Sessions[Player] = Session) {}
    # 1. Lagoon.
    if (Index := G.AssignLagoon[Session]):
        set Session.LagoonIndex = Index
    else:
        LogSeaWarning("No free Lagoon for a joining player (MaxPlayers is {MaxPlayers}).")
    # 2. Save data.
    set Session.Profile = G.LoadProfile(Player)
    MigrateProfile(Session.Profile)
    # 3. Starter creature for brand new players.
    G.EnsureStarterCreature(Session)
    G.ValidateProfileReferences(Session)
    # 4. Input, preferred controls.
    G.RegisterPlayerInput(Session)
    G.InitDefaultSettings(Session)
    # 5. UI.
    Session.UI.BuildHud()
    G.HideUnusedFortniteHud(Player)
    # 6. Sonar stock for this player.
    G.InitSessionSonarStock(Session)
    # 7. Offline progress (income + incubation) before anything is shown.
    G.ApplyOfflineProgress(Session)
    set Session.Loaded = true
    # 8. Lagoon visuals and signs.
    G.RefreshLagoon(Session)
    G.RestoreIncubatorVisuals(Session)
    # 9. Home.
    G.TeleportToLagoon(Session)
    G.RefreshHud(Session)
    G.UpdateMusic(Session)
    G.SaveSession(Session)
    # 10. Intro, offline popup, tutorial.
    if (not Session.Profile.SeenIntro?):
        G.PlayIntroCinematic(Session)
    if (Session.Profile.PendingOfflineReward > 0.0):
        Session.UI.ShowOfflineRewards(Session.Profile.PendingOfflineReward)
    G.StartTutorialIfNeeded(Session)
    G.AnnounceToPlayer(Session, "WELCOME TO RIDE A SEA BEAST!", ThemeCyan)

(G:sea_beast_game_device).OnPlayerRemoved(Player:player):void =
    if (Session := G.Sessions[Player]):
        # The player is no longer active, so their save cannot be written
        # now - autosave and event saves keep it current while they play.
        G.ForceDismount(Session)
        if (Session.Carried.Length > 0):
            G.ReleaseCarryEffect(Session)
        set Session.Carried = array{}
        G.StopSonar(Session, false)
        G.ReleaseTutorialEgg(Session)
        G.ReleaseLagoon(Session)
        G.StopMusic(Session)
    set G.Sessions = G.RemoveSessionEntry(Player)

(G:sea_beast_game_device).RemoveSessionEntry(Removed:player)<transacts>:[player]player_session =
    var NewMap : [player]player_session = map{}
    for (Key -> Value : G.Sessions, Key <> Removed):
        if (set NewMap[Key] = Value) {}
    NewMap

# Every respawn goes back to the player's own Lagoon.
(G:sea_beast_game_device).OnPlayerSpawned(Agent:agent):void =
    if (Session := G.GetAgentSession[Agent], Session.Loaded?):
        G.ForceDismount(Session)
        G.TeleportToLagoon(Session)

(G:sea_beast_game_device).TeleportToLagoon(Session:player_session):void =
    if (Lagoon := G.Lagoons[Session.LagoonIndex], Character := Session.Player.GetFortCharacter[]):
        Position := Lagoon.GetSpawnPosition()
        FacingYaw := Lagoon.GetYawDegrees()
        if (Character.TeleportTo[Position, MakeRotationFromYawPitchRollDegrees(FacingYaw, 0.0, 0.0)]) {}

# Hides Fortnite HUD elements that have no use in this experience.
(G:sea_beast_game_device).HideUnusedFortniteHud(Player:player):void =
    Controller := G.GetPlayspace().GetHUDController()
    Hidden : []hud_element_identifier = array:
        creative_hud_identifier_build_menu{}
        creative_hud_identifier_crafting_resources{}
        creative_hud_identifier_elimination_counter{}
        creative_hud_identifier_experience_supercharged{}
        creative_hud_identifier_round_info{}
        creative_hud_identifier_round_timer{}
        creative_hud_identifier_storm_notifications{}
        creative_hud_identifier_storm_timer{}
        creative_hud_identifier_player_count{}
    Controller.HideElementsForPlayer(Player, Hidden)

# First launch defaults: touch players get tap-to-toggle throttle.
(G:sea_beast_game_device).InitDefaultSettings(Session:player_session):void =
    if (not Session.Profile.SettingsInitialized?):
        set Session.Profile.ThrottleToggle = Session.IsTouch
        set Session.Profile.SettingsInitialized = true

# Removes references to creatures that no longer exist (e.g. after sales).
(G:sea_beast_game_device).ValidateProfileReferences(Session:player_session):void =
    P := Session.Profile
    set P.PlacedCreatureIDs = for (UID : P.PlacedCreatureIDs, G.FindCreature[Session, UID]). UID
    if (not G.FindCreature[Session, P.ActiveMountID]):
        if (First := P.Creatures[0]):
            set P.ActiveMountID = First.UniqueID
    Slots := G.GetLagoonSlots(Session)
    if (P.PlacedCreatureIDs.Length > Slots):
        if (Trimmed := P.PlacedCreatureIDs.Slice[0, Slots]):
            set P.PlacedCreatureIDs = Trimmed

(G:sea_beast_game_device).PlayIntroCinematic(Session:player_session)<suspends>:void =
    set Session.IntroRunning = true
    for (Sequence : G.IntroCinematic):
        Sequence.Play(Session.Player)
    Session.UI.ShowIntroOverlay()
    race:
        Sleep(IntroCinematicSeconds)
        Session.UI.SkipRequested.Await()
    for (Sequence : G.IntroCinematic):
        Sequence.Stop(Session.Player)
    Session.UI.HideIntroOverlay()
    set Session.Profile.SeenIntro = true
    set Session.IntroRunning = false
    G.SaveSession(Session)
