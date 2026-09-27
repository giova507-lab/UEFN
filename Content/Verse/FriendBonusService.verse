# ============================================================================
# RIDE A SEA BEAST - FriendBonusService.verse
# Friend Boost, implemented with the officially supported party API
# (/UnrealEngine.com/Social GetLocalParty, available since 42.10). Verse has
# no API that reads a player's friends list, so we do NOT pretend to: the
# boost counts members of the player's own party who are on this server.
# The HUD labels it "FRIEND BOOST (PARTY)" to stay truthful.
#
# Default: +10% cash per party member present, capped at +50%.
# The boost only affects Cash generation - never hatch odds.
# Disable with FriendBoostEnabled in GameConfig.verse.
# ============================================================================
using { /Verse.org/Simulation }
using { /Verse.org/AgentGroup }
using { /UnrealEngine.com/Social }

(G:sea_beast_game_device).ComputeFriendBoost(Session:player_session)<transacts>:float =
    if (not FriendBoostEnabled?):
        return 0.0
    Party := Session.Player.GetLocalParty()
    var Count : int = 0
    for (Member -> Info : Party.GetMemberMap(), Member <> Session.Player, MemberPlayer := player[Member], G.Sessions[MemberPlayer]):
        set Count += 1
    MinF(FriendBoostMax, FriendBoostPerMember * ToFloat(Count))
