# UEFN Setup Guide

This guide lists everything to place in the level and every field to fill in on the Verse devices. Field names match the `@editable` names in the code.

Units: Unreal units are **centimeters** (1 m = 100 cm). Rotations are in degrees.

---

## 0. Project and island settings

1. Create a UEFN project (a blank island works best). Copy every file from `Content/Verse/` into the project's Verse folder (**Verse > Open Verse Explorer** shows it) and click **Verse > Build Verse Code**.
2. Island settings (World Settings / Island Settings; names differ slightly between UEFN versions):
   * **Max Players: 6.** Free-for-all (no teams needed).
   * **Join in Progress:** Spawn. **Spawn Location:** player spawn pads.
   * **Building:** off. **Fall Damage:** off (riders can be ejected mid-breach). **Player / environment damage:** off.
   * **Time limit / end conditions:** none. The experience never ends a round by itself.
   * **Respawn:** on, with a short delay. If a player is eliminated anyway, the game moves them back to their Lagoon.
3. Build an ocean: a Water Body (Ocean) or a large water plane. Its surface height must equal the game device's `SeaLevelZ` (default `0`).

> **Tip:** name devices in the Outliner (`Lagoon_1`, `Rig_1`, `Reef_Common_01`, …). The Output Log names devices when something is misconfigured.

---

## 1. Minimum playable setup

Get this working first, then add the rest:

1. One `sea_beast_game_device` at the hub center at sea level.
2. Six `lagoon_device`s (section 3), each with at least a `NameSign`, a `RideButton`, `ManageButton` and 4 `Incubators` (button + billboard each).
3. Six mount rigs (section 4), each with a Chair device.
4. Creature visual entries for creature IDs **1-5** with a display prop and at least one **MountSwim** animated mesh (section 5).
5. An egg visual entry for **Pearl Egg (ID 1)** and **Sandy Egg (ID 2)**, plus about 20 `egg_spawn_point_device`s in the Shallow Reef accepting `Common` (section 6).
6. A few `sea_zone_device` Land zones around the hub island (section 7).
7. One Player Spawner per Lagoon, added to `PlayerSpawners`.

The Output Log should show:

```
RIDE A SEA BEAST - starting
Registry: <N> egg spawn points, <N> zones, <N> stations
RIDE A SEA BEAST - running
```

Any `WARNING` line under the `sea_beast_log` channel names what's missing.

---

## 2. The game device - `sea_beast_game_device`

Place **exactly one**, at the center of the hub island at sea level. The biome ring fallback and the dev teleport both measure from its position.

| Field | What to set |
|---|---|
| `Lagoons` | The six `lagoon_device`s. Their order is the Lagoon index (1-6). |
| `MountRigs` | Six `mount_rig_setup` entries, in the same order as `Lagoons`. |
| `RiderAttachMode` | `Chair` (default). Use `PlatformStasis` only if seated players don't follow the moving chair on your build (see section 4). |
| `InputProviders` | Leave empty for publishing. For playtests you can add the optional experimental analog device (section 13). |
| `SeaLevelZ` | Height of the ocean surface in cm. |
| `ParkingLocation` | A hidden spot **inside the island bounds**, e.g. under the hub (Z −30000 by default). Unused rigs and creature visuals wait here. |
| `PlayerSpawners` | All Player Spawner devices. Players are moved to their own Lagoon right after spawning. |
| `CreatureVisuals` | One `creature_visual_entry` per creature ID (section 5). |
| `EggVisuals` | One `egg_visual_entry` per egg ID (section 6). |
| `CarriedEggEffects` | One `carried_egg_effect_entry` per rarity: a VFX Creator set to attach to its instigator (glow while carrying). |
| `Sounds` | `sfx_entry` list (section 9). |
| `BiomeMusic` | One `biome_music_entry` per biome (section 9). |
| `VisualEffects` | `vfx_entry` list (section 10). |
| `Analytics` | `analytics_entry` list (section 12). |
| `DayPhaseVisuals` | `phase_visual_entry` for Day, Sunset and Night (section 11). |
| `WeatherVisuals` | `weather_visual_entry` per weather event (section 11). |
| `IntroCinematic` | Cinematic Sequence device for the first-join flyover (8-12 s). Set **Visibility** to the instigator only. |
| `DeepDiveCinematic` | Cinematic Sequence device for the Deep Dive (instigator only). |
| `UnderwaterPostProcess` | Post Process device blended in per player during the Deep Dive. |
| `CameraShakeSmall` / `CameraShakeLarge` | Optional Cinematic Sequence devices containing only a camera shake (instigator only). Small plays on Legendary/Mythic hatches and heavy breach landings; large plays on Divine/Ethereal hatches and the Deep Dive. Skipped for players with CAMERA SHAKE off. |
| `DeveloperToolsEnabled` | Default `false`. Turn it on while developing to get the DEV tab in the menu. The DEV panel never opens in Live sessions, whatever this is set to. Turn it off again before publishing. |

---

## 3. Lagoons - `lagoon_device` ×6

Build one Lagoon completely, then duplicate it five times around the hub. Every offset is **local to the device and rotates with it**. Place the device at the **center of the Lagoon pool, at water level**, rotated so its +X axis points out of the Lagoon toward the open sea.

Default local layout (cm):

```
          +Y
           │   TutorialEggOffset (2600, 900, 60)   ← first tutorial egg
           │
 Spawn ────┼──── Mount dock ─── device ──────────────────► +X (open sea)
(−1800,0,150) (−1200,0,0)    (pool center)
           │   creature ring: radius 1300, depth −30
           │   AreaRadius 2600 = "inside my Lagoon" (egg delivery, biome)
```

| Field | Purpose |
|---|---|
| `NameSign` | Billboard. Verse writes `PLAYER'S LAGOON` (and the equipped title) or `AVAILABLE LAGOON`. |
| `IncomeSign` | Billboard with income per second. |
| `HatchLuckSign` | Billboard with four lines: `HATCH LUCK`, `590.0x > 595.0x`, `4/5  $539,545` (cycle step and next price), and `MAX +12  $3.4M` (what BUY MAX would buy right now). |
| `DeepDiveSign` | Billboard: next Deep Dive requirement. |
| `HatchLuckButton` | Button: buy one Hatch Luck upgrade. |
| `HatchLuckMaxButton` | Button: buy as many as the player can afford. |
| `PlaceBestButton` | Button: fills Lagoon slots with the highest-income creatures. |
| `ManageButton` | Button: opens the SEA BEASTS menu. |
| `DeepDiveButton` | Button: opens the Deep Dive screen. |
| `RideButton` | Button at the dock: mounts the active Sea Beast at `MountOffset`. |
| `Incubators` | **Four** `incubator_setup` entries (`IncubatorsPerLagoon`). Each has a `Button` (placed on the incubator pad), a `TimerSign` billboard, optional `ReadyEffect` VFX spawners, and `EggOffset` (egg position relative to the button, world axes, default 90 cm up). |
| `HatchCamera` | Fixed Point Camera aimed at the incubators (used during hatching). |
| `DeepDiveCamera` | Fixed Point Camera for the Deep Dive wave. Falls back to `HatchCamera`. |
| `DeepDiveWave` | VFX spawners played in the Lagoon when its owner Deep Dives. |
| `MutationAuras` | One `mutation_aura_pool` per mutation ID (1-5) with a few VFX spawners each. Placed mutated creatures get an aura while displayed. |
| `SpawnOffset`, `MountOffset`, `TutorialEggOffset`, `CreatureRingRadius`, `CreatureDepth`, `AreaRadius` | Layout (above). |

Button device settings for all Lagoon and station buttons: **Interact Time** instant (or 0.2 s), **Interaction Radius** about 2-3 m, and the device model hidden in game (put a prop there instead). Verse sets the interaction text and enables or disables buttons per owner.

Billboards: large text, border off, **not** tied to any channel. Verse calls `SetText`.

Lagoons show up to 8 placed creatures swimming in a ring (`MaxDisplayedLagoonCreatures`). Display models are spawned from the creature's display prop, so an unassigned prop simply isn't shown.

---

## 4. Mount rigs - `mount_rig_setup` ×6

One rig per Lagoon, in the same order. A rig is the part that moves with the rider:

| Field | What to place |
|---|---|
| `Seat` | A **Chair** device. Choose the least visible style and hide it in game if your version has that option. Verse seats the rider (`Seat`), locks exit while riding (`DisableExit`) and moves the chair with the creature. |
| `Saddle` | (PlatformStasis mode only) One small invisible creative prop with collision, e.g. a 1×1 m floor tile set to invisible. |
| `Wake` | One or two VFX Spawners with a spray/wake effect (`Enabled at Game Start` off). |

Place rigs anywhere; they are parked at `ParkingLocation` on start.

**Riding checks to do first (section 15 of the test plan):**

1. Mount at the dock. The rider should stay seated while the creature swims. If the rider pops out or stays behind, switch `RiderAttachMode` to `PlatformStasis` and fill in `Saddle`.
2. Press Jump, Crouch, Sprint, Fire and Aim while seated. The HUD should react (breach, dive, fast swim, swim, brake). If a seated player's inputs don't reach Verse on your build, use `PlatformStasis` mode.

---

## 5. Creature visuals - `creature_visual_entry` (IDs 1-30)

One entry per creature on the game device's `CreatureVisuals` list:

| Field | Purpose |
|---|---|
| `CreatureID` | 1-30 (see [BALANCE.md](BALANCE.md)). |
| `DisplayProp` / `HasDisplayProp` | Static display model used in Lagoons, hatch reveals and as the riding fallback. Create it as a **Creative Prop** from the creature mesh (right-click mesh > Create Blueprint Class > Creative Prop, or the Prop-o-Matic workflow). Set `HasDisplayProp` to `true` after assigning it. |
| `DisplayScale` | Visual multiplier on top of the size class scale. Collision is separate. |
| `MountSwim` | **Animated Mesh** devices playing the swim loop. Each list index is one pool slot: 2 slots means 2 players can ride this creature type at the same time with animation. More riders fall back to the static display prop. |
| `MountIdle` | Optional idle-loop variant per slot (same index). |
| `MountFast` | Optional fast-swim variant per slot (same index). |
| `SaddleHeight` / `SaddleForward` | Seat position on this creature (cm). `-1` = size class default. |

Animated Mesh device settings: skeletal mesh + looping animation, **Loop** on, no collision. Verse parks and pauses unused ones.

Scale: author every creature mesh at one common base size, with the smallest creatures at scale 1. Verse scales the display prop and the riding visual by the size class (1.0 up to about 4) × `DisplayScale`. Leave the Animated Mesh devices' editor scale at 1. Verse sets the scale when it moves them, so the saddle height always matches.

Recommended pools: 1 slot for common early creatures, 2 slots for popular mid creatures, and 1 slot for each late creature (only a few players will own them). Every animated mesh costs memory, so watch the memory calculator.

The model's forward axis must point along **+X**. If an imported mesh faces another way, fix its rotation inside the prop or animated-mesh blueprint, not in Verse.

---

## 6. Eggs

### 6.1 `egg_visual_entry` (IDs 1-22)

| Field | Purpose |
|---|---|
| `EggID` | 1-22 (see [BALANCE.md](BALANCE.md)). |
| `EggProp` / `HasEggProp` | Creative prop of the egg model. Used in the world, while carried (HUD) and in incubators. |

### 6.2 `egg_spawn_point_device` (many)

Place spawn points all over each biome and name them `<Biome>_<Tier>_<NN>` (`Reef_Common_01`, `Kelp_Rare_03`, `Abyss_Ethereal_01`). They register themselves; nothing needs wiring.

| Field | Purpose |
|---|---|
| `Biome` | The biome this point is in. It must be listed in an egg's `Biomes` for that egg to spawn here. |
| `AcceptedTiers` | Rarity tiers the point accepts. |
| `AllowedEggIDs` | Optional whitelist; overrides `AcceptedTiers`. |
| `PlacedEggProps` | Optional pre-placed hidden egg props (per egg ID). They cost nothing at runtime, so use them for the many common eggs. |
| `PickupButton` | Optional button so players on foot see "TAKE SEA EGG". Riders claim by proximity. |
| `HeightOffset` | Egg height above the device (cm). |
| `SelectionWeight` | Relative chance to be picked among eligible points. |
| `TutorialOnly` | Excludes the point from normal tides. |

**How many:** each tide places 81 eggs (Pearl 30, Sandy 10, Barnacle 6 …). Give every egg type at least 1.5x as many eligible points as its per-tide count so locations vary. Recommended counts are in [WORLD_DESIGN.md](WORLD_DESIGN.md#egg-spawn-points).

Rare-egg points belong in hard-to-reach spots: raised pools (breach only), under arches (dive only), behind reef walls and at the far edge of each biome ring.

---

## 7. Navigation zones - `sea_zone_device`

Sea Beasts don't use physics. They follow zones you place. Zones register themselves.

| Kind | Use | Key fields |
|---|---|---|
| `Land` | Islands, rocks, reef walls, docks, arches | `Shape`, `Radius` or `HalfExtentX/Y`, `BottomOffset`, `TopOffset` |
| `WaterPool` | Raised pools above waterfalls, cave lakes. The pool surface is the device's Z. Reachable only by a breach that clears the rim. | Shape + size |
| `Biome` | Names a region for the HUD, music, analytics and the Index. Highest `Priority` wins. | `ZoneBiome`, `Priority` |
| `DeepWater` | Allows dives down to `MaxDiveDepth` (trenches, the Abyss). | `MaxDiveDepth` |

* **Cylinder** zones use `Radius`. **Box** zones use `HalfExtentX/Y` and rotate with the device's yaw. The device's **scale is ignored**, so size zones only with these fields.
* `BottomOffset` / `TopOffset` are relative to the device's Z. A beast is blocked only inside that vertical band. An arch is a Land zone whose bottom is above the dive depth: beasts can dive under it. A low rock whose top is below a strong breach height can be jumped over.
* Cover every shoreline with overlapping Land zones, with a margin of about 2 m into the water, so beasts slide along shores instead of beaching.
* Where there is no Biome zone, the biome comes from distance rings around the game device (`BiomeRingRadii`, see [WORLD_DESIGN.md](WORLD_DESIGN.md)).

---

## 8. Hub stations and NPCs - `menu_station_device`

One device per interactable station. Stations register themselves.

| Station (`Station`) | NPC (`NPCName`) | Opens |
|---|---|---|
| `CurrentTracker` | MARINA | Current Tracker: which eggs are in the ocean right now, sorted by luck or rarity (never where they are) |
| `SonarShack` | FINN | Sonar Shop (6 tiers, limited stock, restock timer) |
| `FeedDock` | CHEF KELP | Feed Dock (5 foods, creature levels) |
| `HarborTrader` | CAPTAIN PEARL | Harbor Trader (sell creatures) |
| `OceanIndex` | kiosk | Ocean Index and milestones |
| `Settings` | kiosk | Settings |
| `SeaBeasts` / `DeepDive` | kiosk | Those menus, as hub shortcuts |

Fields: `InteractButton` (the prompt), `NameSign` (optional billboards), `Greetings` (random lines shown when opening), `NPCSpawner` (optional NPC Spawner).

**NPCs:** create an NPC Character Definition (Custom type), assign the Verse behavior `sea_npc_behavior` and pick an original outfit or model. Put it on an NPC Spawner next to the station. The NPC stands still and turns to face nearby players.

---

## 9. Audio

**Sound effects** (`Sounds`): one `sfx_entry` per `sfx_key`. Put 1-3 Audio Player devices with the same sound in `Players` so overlapping sounds don't cut each other off.

* Per-player sounds: Audio Player **Can Be Heard By: Instigator**, non-spatial for UI sounds.
* `Global = true` for server-wide sounds (`TideReset`, `DivineEggSpawn`, `EtherealEggSpawn`, `Weather`). They play for every player who has SFX enabled.

`sfx_key` values: `UIClick, UIHover, Cash, Purchase, EggPickup, EggCrack, EggPlace, Hatch, RareHatch, EtherealHatch, Mount, Dismount, Splash, FastSwim, SonarPing, SonarLost, TideReset, DivineEggSpawn, EtherealEggSpawn, Weather, Mutation, DeepDive, Feeding, Selling, IndexReward, Error, Claim`.

**Music** (`BiomeMusic`): one looping Audio Player per biome with **Can Be Heard By: Registered Players** and fade in/out times (1-2 s). Verse registers each player to exactly one track and respects the Music setting.

---

## 10. Visual effects - `vfx_entry`

One entry per `vfx_key`, each with a small pool (2-4) of VFX Spawners (`Enabled at Game Start` off). Verse teleports the next spawner in the pool to the event and restarts it.

`vfx_key` values: `Splash, SonarPulse, EggCrackBurst, HatchEnergy, HatchCommon, HatchRare, HatchEpic, HatchLegendary, HatchMythic, HatchDivine, HatchEthereal, RareSpawnBeacon, MutationFlash, DeepDiveWave, FeedSparkle, SellCoins, IndexReward, EggSecured`.

All pooled effects must be **one-shot** (non-looping), because a spawner is only turned off when the pool reuses it. `RareSpawnBeacon` plays when a Legendary or Mythic egg surfaces. Keep it a short, low burst rather than a tall pillar. Divine and Ethereal eggs get no beacon, so their location stays secret.

Players with **Low Effects Mode** or **Other Player Effects** off get fewer effects. Keep particle counts modest ([PERFORMANCE.md](PERFORMANCE.md)).

---

## 11. Day/night and weather

Verse owns the clock (DAY 600 s → SUNSET 120 s → NIGHT 360 s) and the weather cycle. Visuals come through `environment_hooks`:

| Hook field | Effect when the phase or weather starts / ends |
|---|---|
| `EnableSkydomes` / `DisableSkydomes` | Skydome devices enabled / disabled (swapped back at the end) |
| `PostProcess` | Post Process devices blended in per player (skipped with Low Effects Mode) |
| `Lights` | Customizable Light devices turned on / off (e.g. bioluminescence at night) |
| `Effects` | VFX Spawners enabled / disabled (rain, lightning, red fog, embers) |
| `Sounds` | Audio Players played / stopped (thunder, wind) |
| `EnterTriggers` / `ExitTriggers` | Trigger devices fired, to drive anything else (Day Sequence device, water material swap, fog) |

* `DayPhaseVisuals`: one entry each for `Day`, `Sunset`, `Night`. Night should feel magical: glowing reefs and bioluminescent water. The HUD shows **NIGHT TIDE: EGGS INCUBATE 10x FASTER**.
* `WeatherVisuals`: one entry per event: `Thunderstorm` (lightning, rain), `Maelstrom` (swirl VFX, wind), `BloodTide` (red-tinted water and sky, **no gore**), `AbyssStorm` (purple/black fog, dark lightning) and `PrimordialStorm` (gold/white cosmic sky, the rarest event).

---

## 12. Analytics - `analytics_entry`

Place one Analytics device per event and add it with its `Key`. For `BiomeReached`, add one entry per biome with `ForBiome` set. Verse calls `Submit(Agent)` once per event, and "First…" events fire once per player ever.

Keys: `TutorialStarted, TutorialComplete, FirstEggFound, FirstEggDelivered, FirstHatch, FirstRare, FirstEpic, FirstLegendary, FirstMythic, FirstDivine, FirstEthereal, FirstSonar, FirstLuckUpgrade, FirstMutation, FirstDeepDive, EggLost, EggSecured, CreatureSold, BiomeReached`.

---

## 13. Optional: analog movement (NOT publishable)

`Optional/ExperimentalMoveInput.verse` adds WASD / left-stick / virtual-joystick steering using the `Move` input action, which is **@experimental** in the current API. Islands containing experimental APIs cannot be published. To try it in a private playtest:

1. Copy the file into the Verse folder and build.
2. Place an `experimental_move_input_device` and add it to the game device's `InputProviders`.
3. Check that moving the stick or WASD while riding steers. The digest doesn't say which input mapping contains `Move`; the device adds `TraversalMapping`. If no events arrive, try another mapping. Use `SwapAxes` / `Invert…` if the directions are wrong.
4. Remove both before publishing. Without an analog provider, steering uses the camera direction with Fire to swim (hold, or tap to toggle on touch).

---

## 14. Cinematics

* **Intro (first join):** a 10-second flyover (`IntroCinematicSeconds`) of the hub → reef → atoll → frozen sea → volcanic → abyss glow → back to the player's Lagoon. It is skippable with the SKIP button and plays only on the first visit (`SeenIntro`).
* **Deep Dive:** underwater descent, darkening water, a giant leviathan silhouette, then a burst of light back at the Lagoon (about 9 s). Verse also shows the UI overlay, the camera and the Lagoon wave.
* **Camera shakes (optional):** two short sequences with only a camera shake track (small, large) for `CameraShakeSmall` / `CameraShakeLarge`.
* Set every sequence device to play for the **instigator only**, and don't let them loop.

---

## 15. Verify

1. Output Log: no `sea_beast_log` warnings.
2. Join with 2+ players (UEFN multi-client or a private playtest). Each player spawns in a different Lagoon titled with their name.
3. Run [TEST_PLAN.md](TEST_PLAN.md).
