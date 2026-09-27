# ============================================================================
# RIDE A SEA BEAST - EditorLibraries.verse
# Editable entry types that bind level devices and imported assets to the
# data tables. They are edited on the game device (sea_beast_game_device) in
# the Details panel. Keeping asset bindings in the editor means the Verse
# code compiles before any art exists, and artists can swap assets freely.
# ============================================================================
using { /Fortnite.com/Devices }
using { /Verse.org/Simulation }
using { /UnrealEngine.com/Temporary/SpatialMath }

# ---------------------------------------------------------------- Creatures -
# One entry per creature ID (1..30).
creature_visual_entry := class<concrete>:
    @editable
    CreatureID : int = 1
    # Static display model used in Lagoons, hatch reveals and as the riding
    # fallback. Create it in UEFN as a Creative prop from the creature mesh.
    @editable
    DisplayProp : creative_prop_asset = DefaultCreativePropAsset
    # Set to true once DisplayProp has been assigned to the real asset.
    @editable
    HasDisplayProp : logic = false
    # Multiplier on the size-class default scale (visual only).
    @editable
    DisplayScale : float = 1.0
    # Animated riding visuals (Animated Mesh devices placed out of sight).
    # Index i of each list forms one pool slot; Swim is required, Idle and
    # Fast are optional state variants for the same slot.
    @editable
    MountSwim : []animated_mesh_device = array{}
    @editable
    MountIdle : []animated_mesh_device = array{}
    @editable
    MountFast : []animated_mesh_device = array{}
    # Seat height above the creature root in cm (<0 = size class default).
    @editable
    SaddleHeight : float = -1.0
    # Seat offset along the creature's forward axis in cm.
    @editable
    SaddleForward : float = 0.0

# ---------------------------------------------------------------- Eggs ------
egg_visual_entry := class<concrete>:
    @editable
    EggID : int = 1
    @editable
    EggProp : creative_prop_asset = DefaultCreativePropAsset
    @editable
    HasEggProp : logic = false

# Carried-egg glow per rarity. Configure each VFX Creator to follow/attach to
# the instigating player; Verse calls Begin(Agent) / End(Agent).
carried_egg_effect_entry := class<concrete>:
    @editable
    ForRarity : beast_rarity = beast_rarity.Common
    @editable
    Effect : vfx_creator_device = vfx_creator_device{}

# ---------------------------------------------------------------- Mount rigs
# One rig per Lagoon, in the same order as the Lagoons list.
mount_rig_setup := class<concrete>:
    # Rider seat (Chair attach mode). Set its style to the least visible
    # option and disable "Visible in game" if available.
    @editable
    Seat : chair_device = chair_device{}
    # Invisible collision platform (PlatformStasis attach mode).
    @editable
    Saddle : []creative_prop = array{}
    # Wake / spray effect that follows the creature at the surface.
    @editable
    Wake : []vfx_spawner_device = array{}

# ---------------------------------------------------------------- Audio -----
sfx_entry := class<concrete>:
    @editable
    Key : sfx_key = sfx_key.UIClick
    # Several players = round-robin so overlapping sounds do not cut off.
    # Set each device's "Can Be Heard By" to Instigator for per-player sounds.
    @editable
    Players : []audio_player_device = array{}
    # True for server-wide sounds (tide reset, divine egg...). Played for
    # every player whose SFX setting is on.
    @editable
    Global : logic = false

biome_music_entry := class<concrete>:
    @editable
    MusicBiome : biome = biome.CentralLagoon
    # Looping music device with "Can Be Heard By: Registered Players" and a
    # fade in/out so switching biomes crossfades.
    @editable
    Music : audio_player_device = audio_player_device{}

# ---------------------------------------------------------------- VFX -------
vfx_entry := class<concrete>:
    @editable
    Key : vfx_key = vfx_key.Splash
    # Pool of spawners; each play teleports the next one and restarts it.
    @editable
    Spawners : []vfx_spawner_device = array{}

# ---------------------------------------------------------------- Analytics -
analytics_entry := class<concrete>:
    @editable
    Key : analytics_key = analytics_key.TutorialStarted
    # Only used by BiomeReached entries (one analytics device per biome).
    @editable
    ForBiome : biome = biome.CentralLagoon
    @editable
    Device : analytics_device = analytics_device{}

# ---------------------------------------------------------------- World FX --
# Devices toggled when a day phase or weather event starts / ends.
environment_hooks := class<concrete>:
    @editable
    EnableSkydomes : []skydome_device = array{}
    @editable
    DisableSkydomes : []skydome_device = array{}
    @editable
    PostProcess : []post_process_device = array{}
    @editable
    Lights : []customizable_light_device = array{}
    @editable
    Effects : []vfx_spawner_device = array{}
    @editable
    Sounds : []audio_player_device = array{}
    # Generic hooks: wire these triggers to any device (Day Sequence, fog,
    # water material swaps, cinematic sequences...).
    @editable
    EnterTriggers : []trigger_device = array{}
    @editable
    ExitTriggers : []trigger_device = array{}

phase_visual_entry := class<concrete>:
    @editable
    Phase : day_phase = day_phase.Day
    @editable
    Hooks : environment_hooks = environment_hooks{}

weather_visual_entry := class<concrete>:
    @editable
    Weather : weather_kind = weather_kind.Thunderstorm
    @editable
    Hooks : environment_hooks = environment_hooks{}
