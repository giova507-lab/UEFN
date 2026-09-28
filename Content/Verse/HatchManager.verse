# ============================================================================
# RIDE A SEA BEAST - HatchManager.verse
# Hatch RNG and the hatch sequence. Verse-authoritative:
#   EffectiveLuck = EggLuck x PlayerHatchLuck
#   For each creature from RAREST to most common:
#       chance = EffectiveLuck / Odds   (>= 1 means guaranteed)
#       roll once; the first success is the result -> exactly ONE creature.
#   If nothing succeeds, the most common allowed creature is the result.
# The result is granted and saved BEFORE the cinematic starts, so leaving
# mid-sequence never loses a creature.
# ============================================================================
using { /Fortnite.com/Devices }
using { /Verse.org/Simulation }
using { /Verse.org/Random }
using { /UnrealEngine.com/Temporary/SpatialMath }

# Pure roll used by gameplay and the developer tools.
RollCreatureFromEgg(EggID:int, HatchLuck:float, MinCreatureID:int)<transacts>:int =
    EffectiveLuck := EggLuck(EggID) * MaxF(HatchLuck, 1.0)
    MinID := Clamp(MinCreatureID, 1, CreatureCount)
    var Result : int = 0
    var Index : int = CreatureDefs.Length - 1
    loop:
        if (Index < 0 or Result > 0):
            break
        if (Def := CreatureDefs[Index], Def.ID >= MinID):
            Chance := EffectiveLuck / MaxF(Def.Odds, 1.0)
            if (Chance >= 1.0 or GetRandomFloat(0.0, 1.0) < Chance):
                set Result = Def.ID
        set Index -= 1
    if (Result = 0) then MinID else Result

(G:sea_beast_game_device).GetHatchLuck(Session:player_session)<transacts>:float =
    HatchLuckForUpgrades(Session.Profile.HatchLuckUpgrades)

(G:sea_beast_game_device).StartHatch(Session:player_session, Index:int):void =
    if (Session.HatchingIncubator >= 0):
        G.ShowToast(Session, "ALREADY HATCHING!", ThemeMuted)
        return
    if (Session.DeepDiveRunning? or Session.IntroRunning?):
        return
    P := Session.Profile
    # Keeps the save within the per-player persistence budget.
    if (P.Creatures.Length >= MaxCreatureInventory):
        G.ShowToast(Session, "YOUR COLLECTION IS FULL ({MaxCreatureInventory} SEA BEASTS)! SELL SOME AT THE HARBOR TRADER.", ThemeWarning)
        G.PlaySfx(Session, sfx_key.Error)
        return
    if (Incubator := P.Incubators[Index], Incubator.IsReady[]):
        EggID := Incubator.EggTypeID
        IsFirst := logic{P.TotalHatches = 0}
        MinID := if (IsFirst?) then FirstHatchMinCreatureID else 1
        TypeID := RollCreatureFromEgg(EggID, G.GetHatchLuck(Session), MinID)
        TraitID := RollTraitID()
        # ---- Commit immediately ----
        set Incubator.EggTypeID = 0
        set Incubator.Progress = 0.0
        set Incubator.Required = 0.0
        NewCreature := G.GrantCreature(Session, TypeID, TraitID, 0)
        IsNew := G.RegisterCreatureDiscovery(Session, TypeID, 0)
        set P.TotalHatches += 1
        G.AutoPlaceIfRoom(Session, NewCreature.UniqueID)
        G.TrackHatchAnalytics(Session, TypeID)
        G.SaveSession(Session)
        set Session.HatchingIncubator = Index
        G.UpdateIncubatorSign(Session, Index)
        spawn{ G.RunHatchSequence(Session, Index, NewCreature, IsNew) }

# Completes when the player leaves (OnPlayerRemoved signals Ended and then
# unloads the session, so a late caller returns at once).
(G:sea_beast_game_device).AwaitSessionEnd(Session:player_session)<suspends>:void =
    if (Session.Loaded?):
        Session.Ended.Await()

(G:sea_beast_game_device).TrackHatchAnalytics(Session:player_session, TypeID:int):void =
    G.TrackFirst(Session, analytics_key.FirstHatch)
    R := CreatureRarity(TypeID)
    if (R = beast_rarity.Rare):
        G.TrackFirst(Session, analytics_key.FirstRare)
    else if (R = beast_rarity.Epic):
        G.TrackFirst(Session, analytics_key.FirstEpic)
    else if (R = beast_rarity.Legendary):
        G.TrackFirst(Session, analytics_key.FirstLegendary)
    else if (R = beast_rarity.Mythic):
        G.TrackFirst(Session, analytics_key.FirstMythic)
    else if (R = beast_rarity.Divine):
        G.TrackFirst(Session, analytics_key.FirstDivine)
    else if (R = beast_rarity.Ethereal):
        G.TrackFirst(Session, analytics_key.FirstEthereal)

(G:sea_beast_game_device).RunHatchSequence(Session:player_session, Index:int, NewCreature:owned_creature, IsNew:logic)<suspends>:void =
    P := Session.Profile
    TypeID := NewCreature.TypeID
    R := CreatureRarity(TypeID)
    Tier := RarityIndex(R)
    ShowCinematic := logic{P.HatchCinematicOn? or not P.SeenHatchCinematic?}
    CanSkip := P.SeenHatchCinematic
    if (Lagoon := G.GetLagoonForSession[Session]):
        EggPosition := Lagoon.IncubatorEggTransform(Index).Translation
        if (ShowCinematic?):
            # 1. Camera focuses on the egg.
            Lagoon.FocusHatchCamera(Session.Player)
            Session.UI.ShowHatchOverlay(CanSkip)
            race:
                block:
                    # 2-3. The egg shakes and cracks.
                    G.PlaySfx(Session, sfx_key.EggCrack)
                    Lagoon.ShakeIncubatorEgg(Index, 1.0 + 0.25 * ToFloat(Tier))
                    # 4. Energy builds (longer for rarer creatures).
                    if (not P.LowEffectsMode?):
                        G.PlayVfxAt(vfx_key.HatchEnergy, EggPosition)
                    G.PlaySfx(Session, HatchSfxForRarity(R))
                    Sleep(0.4 + 0.2 * ToFloat(Tier))
                    # 5. The egg bursts with a rarity colored explosion.
                    # (Lagoon calls check Loaded: if the player just left,
                    # the Lagoon may already belong to someone else.)
                    if (Session.Loaded?):
                        Lagoon.BurstIncubatorEgg(Index)
                    G.PlayVfxAt(HatchVfxForRarity(R), EggPosition)
                    if (Tier >= RarityIndex(beast_rarity.Legendary)):
                        G.PlayCameraShake(Session, logic{Tier >= RarityIndex(beast_rarity.Divine)})
                    # 6. Silhouette.
                    Session.UI.ShowHatchSilhouette(TypeID)
                    Sleep(0.9)
                    # 7-10. Reveal, rarity, stats, NEW DISCOVERY.
                    if (Session.Loaded?, Asset := G.GetCreatureDisplayAsset[TypeID]):
                        spawn{ Lagoon.PlayHatchReveal(Index, Asset, G.GetCreatureVisualScale(TypeID)) }
                    Session.UI.ShowHatchReveal(NewCreature, IsNew)
                    Sleep(3.0 + 0.4 * ToFloat(Tier))
                block:
                    if (CanSkip?):
                        Session.UI.SkipRequested.Await()
                    else:
                        Sleep(1000000.0)
                # Stop at once if the player leaves: their Lagoon may be
                # handed to someone else.
                G.AwaitSessionEnd(Session)
            Lagoon.ReleaseHatchCamera(Session.Player)
            if (Session.Loaded?):
                Lagoon.BurstIncubatorEgg(Index)
                Session.UI.HideHatchOverlay()
                set P.SeenHatchCinematic = true
        else:
            Lagoon.BurstIncubatorEgg(Index)
            G.PlayVfxAt(HatchVfxForRarity(R), EggPosition)
            G.PlaySfx(Session, HatchSfxForRarity(R))
            if (Tier >= RarityIndex(beast_rarity.Legendary)):
                G.PlayCameraShake(Session, logic{Tier >= RarityIndex(beast_rarity.Divine)})
            Session.UI.ShowHatchResultToast(NewCreature, IsNew)
    set Session.HatchingIncubator = -1
    if (not Session.Loaded?):
        return
    # Restores the incubator's visual (normally empty now).
    G.ShowIncubatorEggVisual(Session, Index)
    G.UpdateIncubatorSign(Session, Index)
    G.RefreshLagoon(Session)
    G.RefreshHud(Session)
    Session.UI.RefreshOpenMenu()
    G.OnTutorialHatched(Session)
    if (Tier >= RarityIndex(beast_rarity.Legendary)):
        G.AnnounceGlobalAgent(Session.Player, CreatureName(TypeID), false)
    G.SaveSession(Session)
