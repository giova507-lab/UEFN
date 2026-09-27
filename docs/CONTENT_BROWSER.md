# Content Browser

## Folder structure

Keep all project content under one root, so it's easy to find, audit and migrate:

```
/RideASeaBeast/
  Verse/                      ← the .verse files (the project's Verse folder)
  Creatures/
    01_SeaSlug/               SK_SeaSlug, SKEL_, A_Swim, A_Idle, A_FastSwim,
    ...                       M_/MI_ materials, BP_Prop_SeaSlug (display prop)
    30_AncientLeviathan/
  Eggs/
    SM_SeaEgg                 one shared mesh
    MI_Egg_01_Pearl ... MI_Egg_22_CelestialPearl
    BP_Prop_Egg_01 ... BP_Prop_Egg_22
  Lagoon/                     modular pool kit, incubator pad, signs, dock
  Hub/                        boardwalk, 4 NPC shops, kiosks, lighthouse
  Environment/
    Shared/                   water materials, rocks, sand
    CentralLagoon/  ShallowReef/  KelpForest/  TropicalAtoll/
    FrozenSea/  VolcanicArchipelago/  TheAbyss/  CelestialSea/
  NPCs/                       character definitions (sea_npc_behavior), outfits
  VFX/                        Niagara systems (see list below)
  Audio/
    Music/                    8 biome loops
    SFX/                      27 effect sounds
    Ambience/                 waves, wind, thunder, deep hum
  Cinematics/                 LS_Intro, LS_DeepDive
  PostProcess/                underwater, night, per-weather grading
```

Naming: `SK_` skeletal mesh, `SM_` static mesh, `A_` animation, `M_` material, `MI_` material instance, `T_` texture, `NS_` Niagara system, `BP_Prop_` creative prop blueprint, `LS_` level sequence.

## Asset list

### Creatures (30)

For each creature: a skeletal mesh facing **+X**, looping animations **Swim**, **Idle** and (optional) **FastSwim**, and a **display prop** (a creative prop built from the mesh). Creatures of one family can share a skeleton and animations:

| Family | Creatures |
|---|---|
| Small reef fish | Clownfish, Blue Tang, Lionfish, Pufferfish, Seahorse |
| Crawlers | Sea Slug, Hermit Crab, Starfish, Mantis Shrimp |
| Rays | Stingray, Giant Manta |
| Cephalopods | Octopus, Giant Squid, Kraken |
| Predator fish | Barracuda, Swordfish, Moray Eel |
| Sharks | Hammerhead, Great White, Tiger Shark, Whale Shark, Megalodon |
| Whales | Orca, Narwhal, Sperm Whale |
| Reptiles / myth | Mosasaurus, Sea Dragon, Abyssal Hydra, Celestial Serpent, Ancient Leviathan |

Style: bright, readable, slightly stylized silhouettes that read well at a distance and at night (emissive details for rare tiers).

### Eggs (22)

One mesh with rarity-colored material instances. Higher tiers add emissive patterns (Divine: aurora swirl; Ethereal: starfield or rift crack).

### Lagoon kit

Pool (octagon), 4 incubator pads with a glass dome, a HATCH LUCK board, an income sign, a name sign, a ride dock, and buttons hidden in props.

### Hub

Boardwalk, lighthouse, and the buildings for Marina (Current Tracker), Finn (Sonar Shack), Chef Kelp (Feed Dock) and Captain Pearl (Harbor Trader), plus Ocean Index and Settings kiosks.

### VFX

| Group | Effects |
|---|---|
| Keys (`vfx_key`) | Splash, SonarPulse, EggCrackBurst, HatchEnergy, HatchCommon … HatchEthereal (7 colors), RareSpawnBeacon, MutationFlash, DeepDiveWave, FeedSparkle, SellCoins, IndexReward, EggSecured |
| Carried egg glow | 7 rarity colors (VFX Creator devices, attached to the player) |
| Rig | Wake / spray |
| Mutation auras | Electrified (sparks), Stormcharged (swirl), Bloodtide (red mist), Abyssal (purple smoke), Primordial (gold halo) |
| Weather | Rain + lightning, maelstrom swirl, red fog, abyss fog + dark lightning, cosmic storm |
| Night | Bioluminescent reef glow, plankton sparkles |

### Audio

* **Music (8):** calm tropical hub; bright reef; mysterious kelp; upbeat atoll; airy frozen; heavy volcanic; dark ambient abyss; ethereal celestial.
* **SFX (27):** one per `sfx_key` (see [UEFN_SETUP_GUIDE.md](UEFN_SETUP_GUIDE.md#9-audio)).
* **Ambience:** waves, wind, thunder, the deep hum of the Abyss.

### Cinematics

* `LS_Intro` (10 s): flyover hub → biomes → the player's Lagoon.
* `LS_DeepDive` (about 9 s): descent, darkening water, leviathan silhouette, light burst.

## Asset rules

* Use only assets you created or licensed for use in Fortnite islands (Fab listings whose license allows UEFN use, Epic's Fortnite asset library). Keep license records.
* **Never** import assets ripped from other games, including Roblox experiences.
* Keep textures at 2K maximum, use Nanite on static meshes and LODs on creatures ([PERFORMANCE.md](PERFORMANCE.md)).
* Test every imported creature in the Lagoon display (prop) and while riding (animated mesh) before you add the next one.
