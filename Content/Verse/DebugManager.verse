# ============================================================================
# RIDE A SEA BEAST - DebugManager.verse
# Hidden developer tools (opened from the main menu's DEV tab).
# HARD GATE: only in Edit or Private sessions (UEFN sessions / playtests) and
# only when DeveloperToolsEnabled is true on the game device. In a Live
# (published) session IsDeveloperSession always fails, so no public player
# can ever reach these commands.
# ============================================================================
using { /Fortnite.com/Characters }
using { /Verse.org/Simulation }
using { /UnrealEngine.com/Temporary/SpatialMath }

(G:sea_beast_game_device).IsDeveloperSession()<transacts><decides>:void =
    G.DeveloperToolsEnabled?
    GetSession().Environment() <> session_environment.Live

DebugCommandName(Command:debug_command)<computes>:string =
    case (Command):
        debug_command.GiveCash => "GIVE CASH"
        debug_command.SetHatchLuck => "SET HATCH LUCK"
        debug_command.SpawnEgg => "SPAWN EGG"
        debug_command.ForceTideReset => "FORCE TIDE RESET"
        debug_command.GiveCreature => "GIVE CREATURE"
        debug_command.SetMutation => "SET MUTATION (ACTIVE)"
        debug_command.TriggerWeather => "TRIGGER WEATHER"
        debug_command.SetDayPhase => "SET DAY PHASE"
        debug_command.CompleteIncubation => "COMPLETE INCUBATION"
        debug_command.SetDeepDive => "SET DEEP DIVE LEVEL"
        debug_command.TeleportBiome => "TELEPORT TO BIOME"
        debug_command.ClearSave => "CLEAR SAVE DATA"

# Executes a developer command with an integer argument chosen in the panel.
(G:sea_beast_game_device).ExecuteDebugCommand(Session:player_session, Command:debug_command, Arg:int):void =
    if (not G.IsDeveloperSession[]):
        return
    P := Session.Profile
    case (Command):
        debug_command.GiveCash =>
            Amount := Pow(10.0, ToFloat(Clamp(Arg, 1, 18)))
            G.AddCash(Session, Amount)
            G.ShowToast(Session, "DEV: +{FormatCash(Amount)}", ThemeCash)
        debug_command.SetHatchLuck =>
            set P.HatchLuckUpgrades = Max(0, Arg)
            G.RefreshHatchLuckSign(Session)
            G.ShowToast(Session, "DEV: HATCH LUCK {FormatMultiplier(HatchLuckForUpgrades(P.HatchLuckUpgrades))}", ThemeGold)
        debug_command.SpawnEgg =>
            G.DevSpawnEggNearPlayer(Session, Clamp(Arg, 1, EggCount))
        debug_command.ForceTideReset =>
            G.ForceTideEvent.Signal()
            G.ShowToast(Session, "DEV: TIDE RESET", ThemeCyan)
        debug_command.GiveCreature =>
            TypeID := Clamp(Arg, 1, CreatureCount)
            NewCreature := G.GrantCreature(Session, TypeID, 0, 0)
            G.RegisterCreatureDiscovery(Session, TypeID, 0)
            G.AutoPlaceIfRoom(Session, NewCreature.UniqueID)
            G.RefreshLagoon(Session)
            G.ShowToast(Session, "DEV: GAVE {CreatureName(TypeID)}", ThemeCyan)
        debug_command.SetMutation =>
            MutationID := Clamp(Arg, 0, MutationCount - 1)
            if (C := G.FindCreature[Session, P.ActiveMountID]):
                # Developer override: may also downgrade, unlike gameplay.
                set C.MutationID = MutationID
                G.RegisterCreatureDiscovery(Session, C.TypeID, MutationID)
                G.RefreshMountStats(Session)
                G.RefreshLagoon(Session)
                G.ShowToast(Session, "DEV: {CreatureName(C.TypeID)} -> {MutationName(MutationID)}", MutationColor(MutationID))
        debug_command.TriggerWeather =>
            G.ForceWeather(WeatherFromIndex(Arg))
        debug_command.SetDayPhase =>
            Phase := if (Arg <= 0) then day_phase.Day else if (Arg = 1) then day_phase.Sunset else day_phase.Night
            G.DevSetDayPhase(Phase)
        debug_command.CompleteIncubation =>
            for (Incubator : P.Incubators, Incubator.EggTypeID > 0):
                set Incubator.Progress = Incubator.Required
            for (I -> Incubator : P.Incubators, Incubator.EggTypeID > 0):
                G.OnIncubatorReady(Session, I)
        debug_command.SetDeepDive =>
            set P.DeepDiveCount = Clamp(Arg, 0, MaxDeepDives)
            set P.PermanentMoneyMultiplier = PermanentMultiplierForDives(P.DeepDiveCount)
            G.RefreshLagoon(Session)
            G.ShowToast(Session, "DEV: DEEP DIVE {P.DeepDiveCount}", ThemeCyan)
        debug_command.TeleportBiome =>
            G.DevTeleportToBiome(Session, BiomeFromIndex(Arg))
        debug_command.ClearSave =>
            G.DevResetSave(Session)
            G.ShowToast(Session, "DEV: SAVE DATA CLEARED", ThemeDanger)
    G.RefreshHud(Session)
    Session.UI.RefreshOpenMenu()
    G.SaveSession(Session)

WeatherFromIndex(I:int)<computes>:weather_kind =
    if (I <= 0):
        weather_kind.Clear
    else if (I = 1):
        weather_kind.Thunderstorm
    else if (I = 2):
        weather_kind.Maelstrom
    else if (I = 3):
        weather_kind.BloodTide
    else if (I = 4):
        weather_kind.AbyssStorm
    else:
        weather_kind.PrimordialStorm

# Spawns an egg of EggID at the nearest free spawn point that accepts it,
# or reports that no point exists.
(G:sea_beast_game_device).DevSpawnEggNearPlayer(Session:player_session, EggID:int):void =
    if (Def := GetEggDef[EggID], Center := G.GetPickupCenter[Session]):
        var Best : int = -1
        var BestDistance : float = 100000000000.0
        for (I -> Point : G.SpawnPoints, not Point.IsOccupied[], Point.AcceptsEgg[Def]):
            D := DistanceSquared(Center, Point.GetEggPosition())
            if (D < BestDistance):
                set BestDistance = D
                set Best = I
        if (Best >= 0):
            G.SpawnWorldEgg(EggID, Best)
            G.ShowToast(Session, "DEV: SPAWNED {Def.Name}", RarityColor(Def.Rarity))
            for (Player -> Other : G.Sessions):
                Other.UI.RefreshTrackerIfOpen()
        else:
            G.ShowToast(Session, "DEV: NO FREE SPAWN POINT ACCEPTS {Def.Name}", ThemeDanger)

(G:sea_beast_game_device).DevTeleportToBiome(Session:player_session, Target:biome):void =
    G.ForceDismount(Session)
    var Destination : ?vector3 = false
    for (Point : G.SpawnPoints, not Destination?, Point.Biome = Target):
        set Destination = option{Point.GetEggPosition() + vector3{X := 0.0, Y := 0.0, Z := 300.0}}
    if (not Destination?):
        # Fallback: middle of the biome ring east of the hub.
        Index := BiomeIndex(Target)
        Inner := if (Index > 0, R := BiomeRingRadii[Index - 1]) then R else 0.0
        Outer := if (R := BiomeRingRadii[Index]) then R else Inner + 20000.0
        Hub := G.GetTransform().Translation
        set Destination = option{vector3{X := Hub.X + (Inner + Outer) * 0.5, Y := Hub.Y, Z := G.SeaLevelZ + 300.0}}
    if (Position := Destination?, Character := Session.Player.GetFortCharacter[]):
        if (Character.TeleportTo[Position, IdentityRotation()]):
            G.ShowToast(Session, "DEV: TELEPORTED TO {BiomeName(Target)}", ThemeCyan)
