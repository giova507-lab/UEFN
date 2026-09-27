# Publishing Checklist

## Code

- [ ] `Optional/ExperimentalMoveInput.verse` is **not** in the project's Verse folder, and the game device's `InputProviders` list is empty. Islands that use `@experimental` APIs can't be published.
- [ ] `DeveloperToolsEnabled` is `false` on the game device. The DEV panel is also locked out in Live sessions by code; this is a second safety.
- [ ] Verse builds with no errors and no warnings you haven't reviewed.
- [ ] The Output Log shows no `sea_beast_log` warnings in a full session (config tables, Lagoons, rigs and visuals all valid).
- [ ] `CurrentDataVersion` is still `1` for the first release. For later updates, **never** remove or rename persistable fields, and never change or reuse creature or egg IDs.

## Content

- [ ] Every creature ID 1-30 has a `creature_visual_entry` with `HasDisplayProp = true` and at least one `MountSwim` animated mesh.
- [ ] Every egg ID 1-22 has an `egg_visual_entry` with `HasEggProp = true`.
- [ ] Every rarity has a carried-egg glow, and every `sfx_key` and `vfx_key` has at least one device (missing ones stay silent or invisible without errors, but they feel broken).
- [ ] Each biome has enough egg spawn points ([WORLD_DESIGN.md](WORLD_DESIGN.md#egg-spawn-points)) and every egg type spawns (no "only N eligible spawn points free" warnings).
- [ ] Shorelines are covered by Land zones, and no beast can get stuck (test plan D6).
- [ ] Intro and Deep Dive cinematics are set to instigator-only and don't loop.
- [ ] NPCs use the `sea_npc_behavior` character definition.

## Originality and rules

- [ ] All art, audio, names and UI are original or properly licensed for Fortnite islands. Keep proof of licenses (e.g. Fab purchases).
- [ ] No assets, names, UI layouts, logos or code from Roblox games or any other game. The experience uses its own marine identity.
- [ ] Friend Boost is labeled "FRIEND BOOST (PARTY)". It counts party members on the server. Don't advertise it as a friends-list feature.
- [ ] No real-money purchases or paid items are included. If you add in-island transactions later, follow Epic's current rules for them.
- [ ] Content rating questionnaire answered honestly. "Blood Tide" is a supernatural red ocean with no gore. If you would rather avoid the word, change the display name in `WeatherName` / `WeatherDefs` (IDs are unaffected).
- [ ] Island description, thumbnail and tags don't reference other games.

## Quality

- [ ] [TEST_PLAN.md](TEST_PLAN.md) sections A, B, C and K all pass in a private playtest with real players.
- [ ] Tested on PC, console (controller) and mobile (touch).
- [ ] Memory Calculator within limits ([PERFORMANCE.md](PERFORMANCE.md)).
- [ ] Analytics devices configured for every `analytics_key`, so you can watch the tutorial funnel after launch.

## After launch

- Watch the analytics funnel: TutorialStarted → FirstEggDelivered → FirstHatch → TutorialComplete → FirstRare.
- Tune only through the config files ([BALANCE.md](BALANCE.md)). Append new creatures and eggs; never reorder them.
