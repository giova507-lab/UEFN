# ============================================================================
# RIDE A SEA BEAST - WeatherManager.verse
# One centralized ocean event cycle:
#   Clear -> (weighted) Thunderstorm / Maelstrom / Blood Tide / Abyss Storm /
#   Primordial Storm -> Clear -> ...
# Primordial Storms are extremely rare (weight 1 and a minimum interval).
# Visual changes are driven through environment_hooks configured on the game
# device (skydomes, post process, lights, VFX, audio, triggers).
# "Blood Tide" is a supernatural red ocean - no gore of any kind.
# ============================================================================
using { /Fortnite.com/Devices }
using { /Verse.org/Simulation }
using { /Verse.org/Random }

(G:sea_beast_game_device).RunWeatherLoop()<suspends>:void =
    G.SetWeather(weather_kind.Clear)
    loop:
        var Next : weather_kind = weather_kind.Clear
        if (G.CurrentWeather = weather_kind.Clear):
            Duration := GetRandomFloat(ClearWeatherMinSeconds, ClearWeatherMaxSeconds)
            set G.WeatherEndTime = G.GetNow() + Duration
            Forced := race:
                block:
                    Sleep(Duration)
                    G.NoForcedWeather()
                block:
                    ForcedKind := G.ForceWeatherEvent.Await()
                    option{ForcedKind}
            set Next = if (F := Forced?) then F else G.PickNextWeather()
        else:
            Duration := GetRandomFloat(WeatherEventMinSeconds, WeatherEventMaxSeconds)
            set G.WeatherEndTime = G.GetNow() + Duration
            Forced := race:
                block:
                    Sleep(Duration)
                    G.NoForcedWeather()
                block:
                    G.RunMutationRolls(G.CurrentWeather)
                    G.NoForcedWeather()
                block:
                    ForcedKind := G.ForceWeatherEvent.Await()
                    option{ForcedKind}
            set Next = if (F := Forced?) then F else weather_kind.Clear
        G.SetWeather(Next)

(G:sea_beast_game_device).NoForcedWeather()<computes>:?weather_kind = false

(G:sea_beast_game_device).GetWeatherRemaining()<transacts>:float =
    MaxF(0.0, G.WeatherEndTime - G.GetNow())

(G:sea_beast_game_device).PickNextWeather()<transacts>:weather_kind =
    Now := G.GetNow()
    AllowPrimordial := logic{Now - G.LastPrimordialTime >= PrimordialMinIntervalSeconds}
    var Total : float = 0.0
    for (Def : WeatherDefs, Def.Weight > 0.0, Def.Kind <> weather_kind.PrimordialStorm or AllowPrimordial?):
        set Total += Def.Weight
    Roll := GetRandomFloat(0.0, Total)
    var Accumulated : float = 0.0
    var Chosen : weather_kind = weather_kind.Thunderstorm
    var Done : logic = false
    for (Def : WeatherDefs, not Done?, Def.Weight > 0.0, Def.Kind <> weather_kind.PrimordialStorm or AllowPrimordial?):
        set Accumulated += Def.Weight
        if (Roll <= Accumulated):
            set Chosen = Def.Kind
            set Done = true
    Chosen

(G:sea_beast_game_device).SetWeather(Kind:weather_kind):void =
    Previous := G.CurrentWeather
    if (Previous <> weather_kind.Clear):
        G.ApplyWeatherHooks(Previous, false)
        # Leaving an event must not undo the current day phase's look.
        for (Entry : G.DayPhaseVisuals, Entry.Phase = G.CurrentPhase):
            G.RestoreHookState(Entry.Hooks)
    set G.CurrentWeather = Kind
    if (Kind = weather_kind.PrimordialStorm):
        set G.LastPrimordialTime = G.GetNow()
    if (Kind <> weather_kind.Clear):
        G.ApplyWeatherHooks(Kind, true)
    if (Previous <> Kind, Def := GetWeatherDef[Kind]):
        G.AnnounceGlobal(Def.Announcement, WeatherColor(Kind))
        if (Kind <> weather_kind.Clear):
            G.PlaySfxGlobal(sfx_key.Weather)
    for (Player -> Session : G.Sessions):
        G.RefreshHud(Session)
    LogSea("Weather: {WeatherName(Kind)}")

(G:sea_beast_game_device).CurrentIncomeModifier()<transacts>:float =
    if (Def := GetWeatherDef[G.CurrentWeather]) then Def.IncomeModifier else 1.0

(G:sea_beast_game_device).ApplyWeatherHooks(Kind:weather_kind, Enter:logic):void =
    for (Entry : G.WeatherVisuals, Entry.Weather = Kind):
        G.ApplyEnvironmentHooks(Entry.Hooks, Enter)

# Shared by weather and day/night. Post process is applied per player so the
# Low Effects setting can skip it.
(G:sea_beast_game_device).ApplyEnvironmentHooks(Hooks:environment_hooks, Enter:logic):void =
    if (Enter?):
        for (Sky : Hooks.EnableSkydomes):
            Sky.Enable()
        for (Sky : Hooks.DisableSkydomes):
            Sky.Disable()
        for (Post : Hooks.PostProcess, Player -> Session : G.Sessions, not Session.Profile.LowEffectsMode?):
            Post.BlendIn(Player)
        for (Light : Hooks.Lights):
            Light.TurnOn()
        for (Effect : Hooks.Effects):
            Effect.Enable()
        for (Sound : Hooks.Sounds):
            Sound.Play()
        for (Trigger : Hooks.EnterTriggers):
            Trigger.Trigger()
    else:
        for (Sky : Hooks.EnableSkydomes):
            Sky.Disable()
        for (Sky : Hooks.DisableSkydomes):
            Sky.Enable()
        for (Post : Hooks.PostProcess):
            Post.BlendOutForAll()
        for (Light : Hooks.Lights):
            Light.TurnOff()
        for (Effect : Hooks.Effects):
            Effect.Disable()
        for (Sound : Hooks.Sounds):
            Sound.Stop()
        for (Trigger : Hooks.ExitTriggers):
            Trigger.Trigger()

# Re-applies only the state-like parts of hooks (skydomes, post process,
# lights, effects) without replaying their sounds or triggers. Used when a
# weather event ends during a phase, or a phase changes during an event.
(G:sea_beast_game_device).RestoreHookState(Hooks:environment_hooks):void =
    for (Sky : Hooks.EnableSkydomes):
        Sky.Enable()
    for (Sky : Hooks.DisableSkydomes):
        Sky.Disable()
    for (Post : Hooks.PostProcess, Player -> Session : G.Sessions, not Session.Profile.LowEffectsMode?):
        Post.BlendIn(Player)
    for (Light : Hooks.Lights):
        Light.TurnOn()
    for (Effect : Hooks.Effects):
        Effect.Enable()

# Applies the current weather/phase post process to a newly joined player.
(G:sea_beast_game_device).ApplyEnvironmentForPlayer(Session:player_session):void =
    if (not Session.Profile.LowEffectsMode?):
        for (Entry : G.WeatherVisuals, Entry.Weather = G.CurrentWeather, Post : Entry.Hooks.PostProcess):
            Post.BlendIn(Session.Player)
        for (Entry : G.DayPhaseVisuals, Entry.Phase = G.CurrentPhase, Post : Entry.Hooks.PostProcess):
            Post.BlendIn(Session.Player)

# Removes weather/phase post process for a player who enabled Low Effects.
(G:sea_beast_game_device).RemoveEnvironmentForPlayer(Session:player_session):void =
    for (Entry : G.WeatherVisuals, Post : Entry.Hooks.PostProcess):
        Post.BlendOut(Session.Player)
    for (Entry : G.DayPhaseVisuals, Post : Entry.Hooks.PostProcess):
        Post.BlendOut(Session.Player)

# Developer tool: jump straight to a weather event.
(G:sea_beast_game_device).ForceWeather(Kind:weather_kind):void =
    G.ForceWeatherEvent.Signal(Kind)
