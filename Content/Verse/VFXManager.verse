# ============================================================================
# RIDE A SEA BEAST - VFXManager.verse
# Pooled world effects. Each play teleports the next spawner of the pool to
# the location and restarts it, so a handful of devices cover the world.
# Carried-egg glow uses per-rarity VFX Creator devices attached to players.
# Keep particle counts modest (see docs/PERFORMANCE.md).
# ============================================================================
using { /Fortnite.com/Devices }
using { /Verse.org/Simulation }
using { /UnrealEngine.com/Temporary/SpatialMath }

(G:sea_beast_game_device).PlayVfxAt(Key:vfx_key, Position:vector3):void =
    for (I -> Entry : G.VisualEffects, Entry.Key = Key, Entry.Spawners.Length > 0):
        Counter := if (C := G.VfxRoundRobin[I]) then C else 0
        if (Spawner := Entry.Spawners[ModInt(Counter, Entry.Spawners.Length)]):
            if (Spawner.TeleportTo[Position, IdentityRotation()]) {}
            Spawner.Enable()
            Spawner.Restart()
        if (set G.VfxRoundRobin[I] = Counter + 1) {}

HatchVfxForRarity(R:beast_rarity)<computes>:vfx_key =
    case (R):
        beast_rarity.Common => vfx_key.HatchCommon
        beast_rarity.Rare => vfx_key.HatchRare
        beast_rarity.Epic => vfx_key.HatchEpic
        beast_rarity.Legendary => vfx_key.HatchLegendary
        beast_rarity.Mythic => vfx_key.HatchMythic
        beast_rarity.Divine => vfx_key.HatchDivine
        beast_rarity.Ethereal => vfx_key.HatchEthereal

# Carried-egg glow (skipped in LOW EFFECTS MODE).
(G:sea_beast_game_device).ShowCarryEffect(Session:player_session, R:beast_rarity):void =
    G.ReleaseCarryEffect(Session)
    if (not Session.Profile.LowEffectsMode?):
        for (Entry : G.CarriedEggEffects, Entry.ForRarity = R):
            Entry.Effect.Begin(Session.Player)
        set Session.CarryEffectRarity = RarityIndex(R)

# Per-player camera shake (skipped when CAMERA SHAKE is off).
(G:sea_beast_game_device).PlayCameraShake(Session:player_session, Large:logic):void =
    if (Session.Profile.CameraShakeOn?):
        Sequences := if (Large?) then G.CameraShakeLarge else G.CameraShakeSmall
        for (Sequence : Sequences):
            Sequence.Play(Session.Player)

(G:sea_beast_game_device).ReleaseCarryEffect(Session:player_session):void =
    if (Session.CarryEffectRarity >= 0):
        for (Entry : G.CarriedEggEffects, RarityIndex(Entry.ForRarity) = Session.CarryEffectRarity):
            Entry.Effect.End(Session.Player)
    set Session.CarryEffectRarity = -1
