# ============================================================================
# RIDE A SEA BEAST - SaveManager.verse
# Load / save orchestration and offline progression.
#   * Saves happen immediately after important events (hatch, purchase, sale,
#     mutation, Deep Dive...) and every AutosaveIntervalSeconds.
#   * A player's data cannot be written after they leave, so we never rely on
#     a "save on logout" - LastSeenEpoch is refreshed on every save instead.
#   * Offline income uses the server-computed income snapshot from the last
#     save (never client values) and is capped at OfflineIncomeCapHours.
# ============================================================================
using { /Verse.org/Simulation }

(G:sea_beast_game_device).LoadProfile(Player:player)<transacts>:player_profile =
    if (Saved := ReadSavedProfile[Player], Saved.DataVersion > 0):
        ProfileFromSave(Saved)
    else:
        MakeNewProfile()

(G:sea_beast_game_device).SaveSession(Session:player_session):void =
    if (not Session.Loaded?):
        return
    if (not Session.Player.IsActive[]):
        return
    Now := GetSecondsSinceEpoch()
    set Session.Profile.LastSeenEpoch = Now
    # Offline income uses permanent multipliers only (no weather/party bonus).
    set Session.Profile.IncomeSnapshot = G.ComputeIncomePerSecond(Session, false)
    if (WriteSavedProfile[Session.Player, Session.Profile, Now]):
        set Session.LastSaveTime = G.GetNow()
    else:
        LogSeaWarning("Saving player data failed (player inactive or data too large).")

(G:sea_beast_game_device).RunAutosaveLoop()<suspends>:void =
    loop:
        Sleep(AutosaveIntervalSeconds)
        for (Player -> Session : G.Sessions, Session.Loaded?):
            G.SaveSession(Session)

# Grants offline income (as a pending, claimable reward) and advances
# incubation for the time the player was away.
(G:sea_beast_game_device).ApplyOfflineProgress(Session:player_session):void =
    P := Session.Profile
    if (P.IsNewPlayer?):
        return
    Now := GetSecondsSinceEpoch()
    Elapsed := Now - P.LastSeenEpoch
    if (P.LastSeenEpoch <= 0.0 or Elapsed < OfflineMinimumSeconds):
        return
    CapSeconds := OfflineIncomeCapHours * 3600.0
    IncomeSeconds := MinF(Elapsed, CapSeconds)
    Reward := P.IncomeSnapshot * IncomeSeconds * OfflineIncomeEfficiency
    if (Reward > 0.0):
        set P.PendingOfflineReward += Reward
    # Eggs keep incubating in real time while away (base speed).
    for (Incubator : P.Incubators, Incubator.EggTypeID > 0):
        set Incubator.Progress = MinF(Incubator.Required, Incubator.Progress + Elapsed * OfflineIncubationMultiplier)
    LogSea("Offline progress: {FormatDuration(Elapsed)} away.")

(G:sea_beast_game_device).ClaimOfflineReward(Session:player_session):void =
    Reward := Session.Profile.PendingOfflineReward
    if (Reward > 0.0):
        set Session.Profile.PendingOfflineReward = 0.0
        G.AddCash(Session, Reward)
        G.PlaySfx(Session, sfx_key.Claim)
        G.RefreshHud(Session)
        G.SaveSession(Session)

# Development only: wipe this player's save and restart their profile.
(G:sea_beast_game_device).DevResetSave(Session:player_session):void =
    if (not G.IsDeveloperSession[]):
        return
    G.ForceDismount(Session)
    if (ClearSavedProfile[Session.Player]) {}
    set Session.Profile = MakeNewProfile()
    set Session.Carried = array{}
    G.EnsureStarterCreature(Session)
    G.RefreshLagoon(Session)
    G.RestoreIncubatorVisuals(Session)
    G.RefreshHud(Session)
    G.SaveSession(Session)
