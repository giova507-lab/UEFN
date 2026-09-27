# ============================================================================
# RIDE A SEA BEAST - AnalyticsManager.verse
# Progression analytics through analytics_device instances configured on the
# game device (one device per event; per-biome devices for BiomeReached).
# Only "event happened for this player" is recorded - no personal data.
# "First..." events fire once per player ever (tracked in the save).
# ============================================================================
using { /Fortnite.com/Devices }
using { /Verse.org/Simulation }

# FiredFirsts stores analytics_key indices; biome firsts use this offset.
BiomeFirstOffset : int = 100

(G:sea_beast_game_device).Track(Session:player_session, Key:analytics_key):void =
    for (Entry : G.Analytics, Entry.Key = Key, Key <> analytics_key.BiomeReached):
        Entry.Device.Submit(Session.Player)

(G:sea_beast_game_device).TrackFirst(Session:player_session, Key:analytics_key):void =
    Index := AnalyticsKeyIndex(Key)
    if (not Session.Profile.FiredFirsts.Find[Index]):
        set Session.Profile.FiredFirsts += array{Index}
        G.Track(Session, Key)

# BiomeReached fires the first time a player ever enters each biome.
(G:sea_beast_game_device).TrackBiomeReached(Session:player_session, B:biome):void =
    Index := BiomeFirstOffset + BiomeIndex(B)
    if (not Session.Profile.FiredFirsts.Find[Index]):
        set Session.Profile.FiredFirsts += array{Index}
        for (Entry : G.Analytics, Entry.Key = analytics_key.BiomeReached, Entry.ForBiome = B):
            Entry.Device.Submit(Session.Player)
