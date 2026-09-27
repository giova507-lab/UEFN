# Performance

The design goal is constant server cost, whatever the number of creatures or eggs a player owns. Nothing runs per creature or per egg: a few central loops (see [ARCHITECTURE.md](ARCHITECTURE.md#loops)) walk compact arrays.

## Spawned props budget

At the time of writing, Epic documents a limit on props spawned with `SpawnProp`: 100 per Verse device, plus an island-wide cap (200). The code spreads its spawn calls across devices and keeps the worst case under the island cap:

| Spawned by | What | Worst case |
|---|---|---|
| Each `egg_spawn_point_device` (own task) | World egg prop when no `PlacedEggProps` entry exists | 81 (one per tide egg) |
| Each `lagoon_device` (own task) | Up to 8 swimming displays + 4 incubator eggs + 1 hatch reveal | 6 × 13 = 78 |
| Lagoon (tutorial) | Tutorial egg | 6 |
| Game device | Riding fallback prop, only when a creature's animated pool is exhausted | 6 |
| **Total** | | **171** |

Keep it lower:

* Give common spawn points `PlacedEggProps` (a hidden Pearl and Sandy egg placed in the editor). That removes up to 40 spawns.
* `MaxDisplayedLagoonCreatures` (8) controls the Lagoon displays.
* Props are disposed when an egg is claimed or cracks, when a display changes, and when a player leaves.

## Devices

| Kind | Suggested count |
|---|---|
| Egg spawn points | ~140 (see [WORLD_DESIGN.md](WORLD_DESIGN.md#egg-spawn-points)) |
| Navigation zones | As many as the shoreline needs (these are only data; the checks are cheap math) |
| Animated mesh devices | 1-2 per creature for 30 creatures (and variants). **This is usually the biggest memory item**, so prefer 1 slot per rare creature. |
| VFX spawners | 2-4 per `vfx_key` (18 keys), 1-2 wake spawners per rig, a few per mutation aura |
| Audio players | 1-3 per `sfx_key` (27 keys) + 8 music tracks |
| Buttons and billboards | About 10 buttons and 8 billboards per Lagoon; 1-2 per station |

## Server work per second

| Work | Rate |
|---|---|
| Economy tick | 1/s: one pass over each player's placed creatures (≤ 12 + bonus) |
| Egg watch | 5/s: carry timers and Lagoon delivery for every player, plus distance checks against live eggs (≤ 81) for players with an empty basket |
| Incubation | 1/s: 4 incubators × 6 players |
| Mount loop | 10/s per rider (≤ 6): a handful of zone checks and 2-4 `MoveTo` calls |
| Sonar | 5/s, only while a sonar is active |
| HUD | 2/s per player: timer labels (tide, carry, weather, phase) |

## Client and memory

* Use the UEFN **Memory Calculator** often. Test with every biome loaded.
* Meshes: Nanite for static environment meshes, LODs for skeletal meshes (creatures), 2K textures at most (1K for small props).
* Creatures: share skeletons between similar species (sharks, rays, whales) and reuse animations with different meshes.
* Eggs: one egg mesh with 22 material instances.
* VFX: low particle counts, short lifetimes, no heavy translucency stacks. The Primordial Storm is the most expensive event, so test it on mobile.
* **Low Effects Mode** (player setting) skips weather post-process, wake spray, carried-egg glow and hatch energy build-up for that player.
* UI: widgets are created once per player. Only the open menu is rebuilt, and pages hold 6-10 cards.

## Checklist before a playtest

- [ ] Memory Calculator within limits on all platforms.
- [ ] No `SpawnProp` failures in the Output Log (they show up as missing eggs or displays).
- [ ] 6-player session: no Verse runtime errors, no server hitches when a tide resets.
- [ ] Mobile: stable frame rate with Low Effects Mode on during a storm.
