# ============================================================================
# RIDE A SEA BEAST - DayNightManager.verse
# World cycle: DAY -> SUNSET -> NIGHT. Verse owns the clock; the visuals are
# driven through the Day Phase Visuals hooks on the game device (skydome /
# post process / bioluminescent lights / triggers for a Day Sequence device).
# NIGHT TIDE: eggs incubate NightIncubationMultiplier (10x) faster.
# ============================================================================
using { /Verse.org/Simulation }

DayCycleLength()<computes>:float = DaySeconds + SunsetSeconds + NightSeconds

(G:sea_beast_game_device).InitDayNight():void =
    set G.DayCycleStart = G.GetNow()
    set G.CurrentPhase = day_phase.Day
    for (Entry : G.DayPhaseVisuals, Entry.Phase = day_phase.Day):
        G.ApplyEnvironmentHooks(Entry.Hooks, true)

# (phase, progress 0..1 within the phase, seconds remaining in the phase)
(G:sea_beast_game_device).GetDayPhaseInfo()<transacts>:tuple(day_phase, float, float) =
    Cycle := DayCycleLength()
    Elapsed := G.GetNow() - G.DayCycleStart
    Turns := FloorToInt(Elapsed / Cycle, 0)
    T := Elapsed - ToFloat(Turns) * Cycle
    if (T < DaySeconds):
        (day_phase.Day, T / DaySeconds, DaySeconds - T)
    else if (T < DaySeconds + SunsetSeconds):
        Local := T - DaySeconds
        (day_phase.Sunset, Local / SunsetSeconds, SunsetSeconds - Local)
    else:
        Local := T - DaySeconds - SunsetSeconds
        (day_phase.Night, Local / NightSeconds, NightSeconds - Local)

(G:sea_beast_game_device).IsNight()<transacts><decides>:void =
    G.CurrentPhase = day_phase.Night

(G:sea_beast_game_device).IncubationMultiplier()<transacts>:float =
    if (G.IsNight[]) then NightIncubationMultiplier else 1.0

(G:sea_beast_game_device).RunDayNightLoop()<suspends>:void =
    loop:
        Sleep(1.0)
        Info := G.GetDayPhaseInfo()
        Phase := Info(0)
        if (Phase <> G.CurrentPhase):
            G.EnterDayPhase(Phase)

(G:sea_beast_game_device).EnterDayPhase(Phase:day_phase):void =
    Old := G.CurrentPhase
    for (Entry : G.DayPhaseVisuals, Entry.Phase = Old):
        G.ApplyEnvironmentHooks(Entry.Hooks, false)
    set G.CurrentPhase = Phase
    for (Entry : G.DayPhaseVisuals, Entry.Phase = Phase):
        G.ApplyEnvironmentHooks(Entry.Hooks, true)
    # An active weather event keeps its look on top of the new phase.
    if (G.CurrentWeather <> weather_kind.Clear):
        for (Entry : G.WeatherVisuals, Entry.Weather = G.CurrentWeather):
            G.RestoreHookState(Entry.Hooks)
    if (Phase = day_phase.Night):
        G.AnnounceGlobal("NIGHT TIDE\n10X EGG GROWTH", ThemeNight)
    else if (Phase = day_phase.Day):
        G.AnnounceGlobal("A NEW DAY DAWNS OVER THE OCEAN.", ThemeGold)
    for (Player -> Session : G.Sessions, Session.Loaded?):
        G.RefreshHud(Session)
        for (I := 0..Session.Profile.Incubators.Length - 1):
            G.UpdateIncubatorSign(Session, I)

# Developer tool: jump to the start of a phase.
(G:sea_beast_game_device).DevSetDayPhase(Phase:day_phase):void =
    Offset := case (Phase):
        day_phase.Day => 0.0
        day_phase.Sunset => DaySeconds
        day_phase.Night => DaySeconds + SunsetSeconds
    set G.DayCycleStart = G.GetNow() - Offset
    G.EnterDayPhase(Phase)
