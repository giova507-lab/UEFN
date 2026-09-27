# ============================================================================
# RIDE A SEA BEAST - AudioManager.verse
# Sound effects and per-biome music, respecting each player's settings.
#   * SFX: audio_player_device pools per sfx_key, played per player with
#     Play(Agent) (set devices to be heard by the Instigator).
#   * Music: one looping device per biome set to "Registered Players";
#     players are registered to exactly one biome track at a time, so only
#     one song plays per player and device fades create the crossfade.
# ============================================================================
using { /Fortnite.com/Devices }
using { /Verse.org/Simulation }

(G:sea_beast_game_device).InitAudioVisual():void =
    set G.SfxRoundRobin = for (Entry : G.Sounds). 0
    set G.VfxRoundRobin = for (Entry : G.VisualEffects). 0
    for (Entry : G.BiomeMusic):
        Entry.Music.UnregisterAll()
        Entry.Music.Play()
    for (Entry : G.VisualEffects, Spawner : Entry.Spawners):
        Spawner.Disable()

(G:sea_beast_game_device).PlaySfx(Session:player_session, Key:sfx_key):void =
    if (Session.Profile.SfxOn?):
        for (I -> Entry : G.Sounds, Entry.Key = Key, Entry.Players.Length > 0):
            Counter := if (C := G.SfxRoundRobin[I]) then C else 0
            if (Device := Entry.Players[ModInt(Counter, Entry.Players.Length)]):
                Device.Play(Session.Player)
            if (set G.SfxRoundRobin[I] = Counter + 1) {}

# Server-wide sounds, played for each player whose SFX setting is on.
(G:sea_beast_game_device).PlaySfxGlobal(Key:sfx_key):void =
    for (Player -> Session : G.Sessions, Session.Loaded?):
        G.PlaySfx(Session, Key)

HatchSfxForRarity(R:beast_rarity)<computes>:sfx_key =
    case (R):
        beast_rarity.Common => sfx_key.Hatch
        beast_rarity.Rare => sfx_key.Hatch
        beast_rarity.Epic => sfx_key.RareHatch
        beast_rarity.Legendary => sfx_key.RareHatch
        beast_rarity.Mythic => sfx_key.RareHatch
        beast_rarity.Divine => sfx_key.EtherealHatch
        beast_rarity.Ethereal => sfx_key.EtherealHatch

(G:sea_beast_game_device).UpdateMusic(Session:player_session):void =
    Wanted := if (Session.Profile.MusicOn?) then BiomeIndex(Session.CurrentBiome) else -1
    if (Wanted <> Session.MusicBiomeIndex):
        for (Entry : G.BiomeMusic):
            if (BiomeIndex(Entry.MusicBiome) = Wanted):
                Entry.Music.Register(Session.Player)
            else:
                Entry.Music.Unregister(Session.Player)
        set Session.MusicBiomeIndex = Wanted

(G:sea_beast_game_device).StopMusic(Session:player_session):void =
    for (Entry : G.BiomeMusic):
        Entry.Music.Unregister(Session.Player)
    set Session.MusicBiomeIndex = -1
