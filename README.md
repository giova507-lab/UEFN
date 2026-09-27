# RIDE A SEA BEAST

A multiplayer ride-and-collect experience for **Fortnite / UEFN**, written in **Verse**.

You ride Sea Beasts across the ocean and grab Sea Eggs before other players do. You race each egg home before it cracks, hatch it in your private Lagoon and fill your Ocean Index. Faster beasts reach rarer eggs further out. All 30 creatures, 22 eggs, the economy, weather mutations and Deep Dive resets are run by the server in Verse.

> **Status:** this repository contains the complete Verse gameplay code (about 8,000 lines, 51 files) plus setup documentation. The code was written against the UEFN 42.x Verse API digests. It passes this repo's static checkers (`Tools/`), but **it has not yet been compiled or play-tested inside UEFN**. Expect a round of compile fixes on the first build. You also have to build the island itself (terrain, water, Lagoons, props, devices) in the editor by following [docs/UEFN_SETUP_GUIDE.md](docs/UEFN_SETUP_GUIDE.md).

## Features

| System | Summary |
|---|---|
| 6 private Lagoons | One per player, titled `[PLAYER]'S LAGOON`. Every action checks that the player owns the Lagoon. Includes incubators, Hatch Luck board, PLACE BEST and a ride dock. |
| Sea Beast riding | Custom server-side mount controller running at 10 Hz. Supports swim, fast swim, turning with banking, breach arcs, dives and mount/dismount. It uses only publishable input actions, so it works on keyboard/mouse, controller and touch. Display speed maps to physical speed on a log curve: a 15-speed Sea Slug swims at 6.5 m/s and a 1,000,000,000-speed Celestial Serpent at 57 m/s. |
| World | A central hub plus 7 biome rings: Shallow Reef, Kelp Forest, Tropical Atoll, Frozen Sea, Volcanic Archipelago, The Abyss and Celestial Sea. Navigation comes from designer-placed zone devices (shores, raised pools reachable only by breaching, dive arches), so no physics queries are needed. |
| Shared Sea Eggs | Eggs are shared server-wide and claimed atomically, so two players can never get the same egg. Tides reset every 480 s. You can carry one egg at a time for 45 s before it cracks. Divine and Ethereal eggs are announced to everyone without revealing where they are. |
| Hatching | Incubation takes 180 s to 6 h depending on rarity, and runs 10x faster at night. Hatch results use `EffectiveLuck = EggLuck × HatchLuck`, rolled from rarest to most common, and always give exactly one creature. The result is saved before the cinematic plays, and the cinematic can be skipped after the first time. |
| Economy | One central income tick. Offline income is capped at 8 h and collected from a CLAIM popup. The Hatch Luck cycle gives +1, +1, +1, +1, +5 with an exponential cost set by one central formula. Friend Boost counts party members on the same server. |
| Shops and NPCs | Current Tracker (Marina), Sonar Shack with 6 tiers, limited stock and SIGNAL LOST retargeting (Finn), Feed Dock with 5 foods and creature levels (Chef Kelp), and Harbor Trader with sell rules (Captain Pearl). |
| Progression | Ocean Index milestones, 5 weather events that permanently mutate placed creatures (x2 up to x100 speed; a mutation is only ever replaced by a stronger one), and Deep Dive resets with 7 tiers (+1X money multiplier and +1 Lagoon slot each). |
| Persistence | `weak_map(player, sea_beast_save)` with `DataVersion = 1`, compact creature records and a migration hook. |
| UI | Custom Verse UI: HUD, Sea Beasts inventory (filters, sorts, RIDE / PLACE / FEED / LOCK / SELL), shops, Ocean Index, Deep Dive, settings, a skippable intro and an 8-step tutorial. |
| Dev tools | Hidden debug panel. It only works when `DeveloperToolsEnabled` is on **and** the session is not Live, so published players can never open it. |

## Repository layout

```
Content/Verse/        All Verse source (one module). Copy into your UEFN project.
Optional/             ExperimentalMoveInput.verse - analog WASD/stick steering
                      using the @experimental Move action (NOT publishable).
Tools/                Static checkers for the Verse code (Python 3).
docs/                 Setup, world design, balance, tests, publishing.
```

## Quick start

1. Create (or open) a UEFN project. Copy `Content/Verse/*.verse` into the project's Verse folder, `<Project>/Plugins/<Project>/Content/` (the folder UEFN opens with **Verse > Open Verse Explorer**). Keep all files together in one folder: they form one module.
2. Build the code with **Verse > Build Verse Code**. Fix any compile errors the editor reports (see status above).
3. Place devices and build the world as described in [docs/UEFN_SETUP_GUIDE.md](docs/UEFN_SETUP_GUIDE.md), starting with its minimum playable setup. Import the assets listed in [docs/CONTENT_BROWSER.md](docs/CONTENT_BROWSER.md).
4. Launch a session and follow [docs/TEST_PLAN.md](docs/TEST_PLAN.md).
5. Before publishing, go through [docs/PUBLISHING_CHECKLIST.md](docs/PUBLISHING_CHECKLIST.md).

## Documentation

| Document | Contents |
|---|---|
| [ARCHITECTURE.md](docs/ARCHITECTURE.md) | How the code is organized, where state lives, loops, data flow, validation rules. |
| [UEFN_SETUP_GUIDE.md](docs/UEFN_SETUP_GUIDE.md) | Every device to place and every field to fill in. |
| [CONTENT_BROWSER.md](docs/CONTENT_BROWSER.md) | Content folder structure and the asset list. |
| [WORLD_DESIGN.md](docs/WORLD_DESIGN.md) | Biome rings, distances vs. speed, egg placement, breach heights. |
| [BALANCE.md](docs/BALANCE.md) | All tables (creatures, eggs, prices, curves) and how to tune them. |
| [TEST_PLAN.md](docs/TEST_PLAN.md) | Fresh-player flow, multiplayer, persistence and edge-case tests. |
| [PERFORMANCE.md](docs/PERFORMANCE.md) | Spawn limits, memory and effect budgets. |
| [PUBLISHING_CHECKLIST.md](docs/PUBLISHING_CHECKLIST.md) | What to verify before you publish. |

## Static checks

No Verse compiler runs outside UEFN, so two heuristic checkers catch common mistakes early. Both need the API digests; UEFN writes them into your project (search for `Fortnite.digest.verse`).

```bash
python3 Tools/verse_check.py --digests <folder with *.digest.verse> Content/Verse
python3 Tools/verse_effects_check.py --digests <folder with *.digest.verse> Content/Verse
```

`verse_check.py` looks for unknown members, missing `using`s, shadowing and indentation problems. `verse_effects_check.py` checks effect specifiers: rollback safety, `<suspends>` outside `spawn`, `<decides>` calls with `[]`, and failure contexts. Neither replaces the real compiler.

## Originality

This project follows the progression style of ride-and-collect games but uses its own marine theme, names, UI and code. It contains no assets, UI or code from other games.
