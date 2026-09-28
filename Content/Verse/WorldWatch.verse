# ============================================================================
# RIDE A SEA BEAST - WorldWatch.verse
# Light periodic loops: biome tracking for walkers (riders are tracked by the
# mount loop), the HUD timer loop, and the message helpers every system uses
# to talk to a player's UI.
# ============================================================================
using { /Fortnite.com/Characters }
using { /Verse.org/Simulation }
using { /Verse.org/Colors }
using { /UnrealEngine.com/Temporary/SpatialMath }

(G:sea_beast_game_device).RunWorldWatchLoop()<suspends>:void =
    loop:
        Sleep(1.0)
        for (Player -> Session : G.Sessions, Session.Loaded?, Session.Mount.State = mount_state.Dismounted, Character := Player.GetFortCharacter[]):
            G.UpdateBiome(Session, Character.GetTransform().Translation)

(G:sea_beast_game_device).UpdateBiome(Session:player_session, Position:vector3):void =
    NewBiome := G.Navigator.BiomeAt(Position.X, Position.Y)
    if (NewBiome <> Session.CurrentBiome):
        set Session.CurrentBiome = NewBiome
        G.UpdateMusic(Session)
        G.TrackBiomeReached(Session, NewBiome)
        Index := BiomeIndex(NewBiome)
        if (Visited := Session.VisitedBiomes[Index], not Visited?):
            if (set Session.VisitedBiomes[Index] = true) {}
            G.ShowToast(Session, "ENTERING {BiomeName(NewBiome)}", ThemeTurquoise)
        G.RefreshHud(Session)

(G:sea_beast_game_device).RunHudLoop()<suspends>:void =
    loop:
        Sleep(HudRefreshSeconds)
        Now := G.GetNow()
        for (Player -> Session : G.Sessions, Session.Loaded?):
            Session.UI.Tick(Now)

# ---------------------------------------------------------------- Messages -
(G:sea_beast_game_device).RefreshHud(Session:player_session):void =
    Session.UI.RefreshHud()
    # Purchases, sales and claims all refresh the HUD; the Hatch Luck board's
    # MAX line follows the same cash.
    G.RefreshHatchLuckSign(Session)

(G:sea_beast_game_device).ShowToast(Session:player_session, Text:string, TextColor:color):void =
    Session.UI.ShowToast(Text, TextColor)

(G:sea_beast_game_device).AnnounceToPlayer(Session:player_session, Text:string, TextColor:color):void =
    Session.UI.ShowAnnouncement(ToMessage(Text), TextColor)

(G:sea_beast_game_device).AnnounceGlobal(Text:string, TextColor:color):void =
    for (Player -> Session : G.Sessions, Session.Loaded?):
        Session.UI.ShowAnnouncement(ToMessage(Text), TextColor)

# "{Player} FOUND {What}!" / "{Player} HATCHED {What}!" - names are only
# available through localized messages. Players who turned OTHER PLAYER
# EFFECTS off only see these for their own finds.
(G:sea_beast_game_device).AnnounceGlobalAgent(Who:player, What:string, IsFind:logic):void =
    Message := if (IsFind?) then PlayerFoundMessage(Who, What) else PlayerHatchedMessage(Who, What)
    for (Player -> Session : G.Sessions, Session.Loaded?, Player = Who or Session.Profile.OtherPlayerEffectsOn?):
        Session.UI.ShowAnnouncement(Message, ThemeGold)

(G:sea_beast_game_device).AnnounceGlobalText(Who:player, Text:string):void =
    Message := PlayerDidMessage(Who, Text)
    for (Player -> Session : G.Sessions, Session.Loaded?, Player = Who or Session.Profile.OtherPlayerEffectsOn?):
        Session.UI.ShowAnnouncement(Message, ThemeCyan)
