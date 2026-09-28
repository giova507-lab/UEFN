# Architecture

## Principles

1. **One authority.** Everything that matters (cash, eggs, creatures, luck, mutations, ownership) lives on one server-side object: the `sea_beast_game_device`. UI never holds game state. It renders what the game device tells it and sends requests back.
2. **Validate every action.** Every button, menu click and input is re-checked on the game device: the player owns the Lagoon, the creature exists, the player can afford the price, the egg is still free, the incubator is ready. A stale or duplicated request fails safely.
3. **Configuration in one place.** Tables and formulas live in `GameConfig`, `CreatureConfig`, `EggConfig`, `ProgressionConfig` and `MovementBalance`. The UI and the gameplay code call the same functions, so a displayed price can never differ from the charged price.
4. **Atomic critical sections.** Claims (eggs, Lagoons, purchases) never suspend between "check" and "commit". Verse runs one task at a time between suspension points, so two players can't both win the same egg.
5. **Publishable APIs only.** The shipped code uses only non-experimental Verse APIs. The one experimental feature (the `Move` input action) is kept in `Optional/`.

## Composition root

```
sea_beast_game_device (GameManager.verse)
 ├─ runtime state: Sessions[player], LagoonOwners, WorldEggs, weather, day phase,
 │                 sonar stock, rig users, visual pools, navigator
 ├─ subsystems = extension methods (G:sea_beast_game_device).Foo() in their own files
 └─ binds level devices:
      lagoon_device ×6            (editable list)
      mount_rig_setup ×6          (editable list: chair + saddle + wake)
      egg_spawn_point_device ×N   (self-registering)
      sea_zone_device ×N          (self-registering)
      menu_station_device ×N      (self-registering)
```

Each subsystem is written as extension methods on the game device in its own file. The subsystems share one state object without singletons or duplicated data, and each file stays focused on one topic.

Level devices that exist in large numbers (spawn points, zones, stations) **register themselves** in `OnBegin` through a session-scoped `weak_map(session, world_registry)` (`WorldRegistry.verse`). The game device waits `RegistrySettleSeconds` and then reads the registry, so designers never have to fill in long lists.

## Files

| Area | Files |
|---|---|
| Types and config | `Types.verse` (enums), `GameConfig.verse` (constants, colors, helpers), `CreatureConfig.verse`, `EggConfig.verse`, `ProgressionConfig.verse`, `MovementBalance.verse`, `NumberFormatter.verse`, `Text.verse` (localizable messages) |
| State | `RuntimeTypes.verse` (session, mount, egg records), `SaveData.verse` (persistable schema, conversion, migration) |
| Root and players | `GameManager.verse`, `PlayerManager.verse` (join/leave/spawn), `SaveManager.verse` (autosave, offline progress) |
| World | `WorldRegistry.verse`, `SeaZoneDevice.verse`, `SeaNavigation.verse`, `EggSpawnPoint.verse`, `LagoonDevice.verse`, `MenuStationDevice.verse`, `SeaNpcBehavior.verse` |
| Gameplay | `LagoonManager`, `CreatureManager`, `EconomyManager`, `FriendBonusService`, `EggManager`, `IncubatorManager`, `HatchManager`, `SonarManager`, `FeedManager`, `HatchLuckManager`, `IndexManager`, `SellManager`, `WeatherManager`, `MutationManager`, `DayNightManager`, `DeepDiveManager`, `TutorialManager` |
| Riding | `MountInput.verse` (Player Input API), `SeaBeastMountSystem.verse` (controller, rig, visuals) |
| Presentation | `AudioManager`, `VFXManager`, `AnalyticsManager`, `WorldWatch` (biome tracking, HUD timer, message helpers) |
| UI | `UIKit.verse` (widgets, theme), `HUD.verse`, `UIManager.verse` (per-player controller), `UIMenus.verse`, `UIShops.verse`, `UIPopups.verse` |
| Tools | `DebugManager.verse` (developer panel, gated) |
| Editor bindings | `EditorLibraries.verse` (editable entry classes for visuals, audio, VFX, analytics, environment hooks) |

## Loops

All loops start in `OnBegin` of the game device. Nothing runs per creature or per egg; the loops iterate over compact state.

| Loop | Period | Job |
|---|---|---|
| `RunTideLoop` | 480 s (or forced) | Clears eggs nobody claimed, then spawns a fresh set on randomly chosen eligible points. Announces rare eggs. |
| `RunEggWatchLoop` | 0.2 s | Proximity pickups for riders, carry timers, cracking, delivery into the Lagoon. |
| `RunEconomyLoop` | 1 s | Pays every player: `sum(placed income) × deep-dive multiplier × (1 + friend boost) × weather modifier`. |
| `RunIncubationLoop` | 1 s | Advances incubators (10x at night) and updates timer signs. |
| `RunSonarLoop` / `RunSonarRestockLoop` | 0.2 s / 300 s | Sonar bearing, distance and ping cadence; shop restock. |
| `RunWeatherLoop` | event based | Clear → weighted event → Clear. Starts `RunMutationRolls` (every 15 s) while an event is active. |
| `RunDayNightLoop` | 1 s | DAY 600 s → SUNSET 120 s → NIGHT 360 s. Fires environment hooks. |
| `RunAutosaveLoop` | 30 s | Saves every loaded player. Important events also save immediately. |
| `RunHudLoop` | 0.5 s | Timers on the HUD (tide, carry, weather, phase). |
| `RunWorldWatchLoop` | 1 s | Tracks the biome of players on foot (music, analytics, discovery). |
| `RunMountLoop` (per rider) | 0.1 s | Mount simulation. Only runs while mounted. |

## Riding pipeline

```
Player Input API (Jump, Crouch, Sprint, WeaponPrimary/Secondary, Reload)
   │  + camera view rotation for steering (+ optional analog Move provider)
   ▼
RunMountLoop, 10 Hz, server
   ├─ throttle / brake / cruise / fast swim → target speed (log speed curve)
   ├─ yaw toward the camera heading, limited by size-class turn rate
   ├─ modes: Surface ⇄ Diving (hold Crouch), Surface → Airborne (Jump = breach arc)
   ├─ SeaNavigation: blocked by Land zones, pushed out along the shore,
   │  raised WaterPool surfaces, DeepWater dive limits, world bounds
   ├─ visuals: bank into turns, pitch on breach/dive, surface bob, wake VFX
   └─ transforms: rig and creature moved with overlapping MoveTo segments
      (MountTickSeconds + MountMoveLeadSeconds), so motion is continuous
      on clients even though the server ticks at 10 Hz.
Rider: seated in the rig's chair_device, which moves with the creature
       (fallback: invisible saddle prop + stasis, RiderAttachMode = PlatformStasis)
Creature visual: animated_mesh_device from the creature's pool (swim / idle /
       fast variants), or a spawned display prop when the pool is empty.
```

The speed conversion is in `MovementBalance.verse`. Physical speed is interpolated in log space between anchor points, so each rarity step feels faster while the endgame stays controllable (about 60 m/s at most).

## Egg lifecycle

```
Tide Reset → spawn points chosen (weighted, biome + tier eligible; the point
             an egg type used last tide is skipped when others exist) → egg visible
   ├─ claim (proximity when mounted / button when on foot)
   │     TryClaimEgg: free? → mine (no suspension in between) → removed from world
   ├─ carry: 45 s timer on HUD, per-rarity glow VFX on the player
   │     ├─ timer ends → egg cracks (lost), announcement to the player
   │     └─ enter own Lagoon radius → secured in the basket
   ├─ place in an empty incubator (validated owner + empty + egg in basket)
   └─ incubate → HATCH! → roll → grant + save → cinematic (skippable)
```

## Hatch roll

`HatchManager.RollCreatureFromEgg`:

```
EffectiveLuck = EggLuck × HatchLuck
for creature from rarest to most common:
    chance = EffectiveLuck / Odds
    if chance >= 1 or random < chance: return creature
return most common creature
```

Exactly one creature per hatch. The first-ever hatch uses `FirstHatchMinCreatureID`, so a new player always gets something better than a second Sea Slug.

## Persistence

* `sea_beast_save` (persistable class) is stored in `var SeaBeastSaveMap : weak_map(player, sea_beast_save)`.
* At runtime, players use a mutable `player_profile`. Saving converts it into a new `sea_beast_save`, which persistable classes require.
* `DataVersion` (currently 1) is written with every save. `MigrateProfile` upgrades older versions. Add new fields with defaults and bump the version; never rename or remove fields after publishing.
* Creature records are compact (`creature_save`: unique ID, type ID, level, XP, trait, mutation, flags).
* Saves happen after every important event (hatch, purchase, sale, mutation, Deep Dive, milestone claim) and every 30 s. Verse can't write a player's data after they leave, so nothing depends on "save on logout". `LastSeenEpoch` is refreshed on every save and drives offline progress.
* Offline income = saved income snapshot × time away, capped at 8 h. It is offered as a claimable reward, never added silently.

## UI

* One `player_ui_controller` per player, created on join. It owns the player's canvas and widgets and rebuilds only the open screen.
* Menu input mode is enabled only while a menu or popup is open and is always released on close. The HUD never captures input.
* All numbers go through `NumberFormatter.verse` (K, M, B, T, Qa, Qi …).
* Player names reach the screen only through `message` values (`Text.verse`). Verse does not expose player names as strings.

## Security and validation checklist

| Action | Checks |
|---|---|
| Any Lagoon button | Player is the owner of that Lagoon index |
| Take egg | Egg still in the world, basket empty, within reach, not in a menu/cinematic |
| Place egg | Owner, incubator empty, egg in basket and not cracked |
| Hatch | Owner, incubator ready, not already hatching |
| Buy (sonar, food, luck) | Stock (sonar), price from the central formula, atomic `TrySpend` |
| Sell | Creature exists, not locked, not being ridden, not the player's last creature. Placed, favorite, mutated and Epic+ creatures, and the last copy the next Deep Dive requires, ask for confirmation. Presses within 0.6 s of a sale are ignored. Everything is re-checked when the sale executes. |
| Sequences | Hatch, Deep Dive, intro and menus never overlap (`IsInSequence`). A leaving player's running sequence stops at once (`Ended` event), before the Lagoon can be reassigned. |
| Place / remove | Creature exists, slot limit from `SlotsForDives` |
| Deep Dive | Cash requirement, owns the required creature (checked, not consumed), confirmation |
| Debug commands | `DeveloperToolsEnabled` and session environment ≠ Live |

## Extending

* **New creature:** append to `CreatureDefs` (ID = index + 1), add a visual entry on the game device and an Index card appears automatically.
* **New egg:** append to `EggDefs`, add an `egg_visual_entry` and place spawn points that accept its rarity or ID.
* **New save field:** add it with a default to `sea_beast_save` and `player_profile`, copy it in `ProfileFromSave`/`SaveFromProfile`, and bump `CurrentDataVersion` if old saves need a migration step.
