# ============================================================================
# RIDE A SEA BEAST - MutationManager.verse
# Weather mutations. Only creatures currently PLACED in a Lagoon roll.
# One weather mutation per creature; a stronger mutation replaces a weaker
# one, a weaker one NEVER replaces a stronger one. Mutations are permanent
# and saved immediately. Multipliers (Speed) live in ProgressionConfig.verse.
# ============================================================================
using { /Verse.org/Simulation }
using { /Verse.org/Random }

# Runs while a mutation weather is active (canceled by the weather loop).
(G:sea_beast_game_device).RunMutationRolls(Kind:weather_kind)<suspends>:void =
    if (Def := GetWeatherDef[Kind], Def.MutationID > 0, Mutation := GetMutationDef[Def.MutationID]):
        loop:
            Sleep(MutationRollIntervalSeconds)
            for (Player -> Session : G.Sessions, Session.Loaded?, C : G.GetPlacedCreatures(Session)):
                if (GetRandomFloat(0.0, 1.0) < Mutation.RollChance):
                    G.TryApplyMutation(Session, C, Def.MutationID)
    else:
        Sleep(1000000.0)

# Returns true when the mutation was applied.
(G:sea_beast_game_device).TryApplyMutation(Session:player_session, C:owned_creature, MutationID:int):logic =
    if (MutationTier(MutationID) <= MutationTier(C.MutationID)):
        return false
    set C.MutationID = MutationID
    G.RegisterCreatureDiscovery(Session, C.TypeID, MutationID)
    G.PlaySfx(Session, sfx_key.Mutation)
    if (Lagoon := G.GetLagoonForSession[Session]):
        G.PlayVfxAt(vfx_key.MutationFlash, Lagoon.GetCenter())
    Session.UI.ShowBigMessage("YOUR {CreatureName(C.TypeID)} BECAME {MutationName(MutationID)}!", MutationColor(MutationID))
    G.TrackFirst(Session, analytics_key.FirstMutation)
    if (Session.Mount.State = mount_state.Mounted, Session.Mount.CreatureUID = C.UniqueID):
        G.RefreshMountStats(Session)
    G.RefreshLagoon(Session)
    Session.UI.RefreshOpenMenu()
    G.SaveSession(Session)
    true
