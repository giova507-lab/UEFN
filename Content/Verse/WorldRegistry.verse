# ============================================================================
# RIDE A SEA BEAST - WorldRegistry.verse
# Many level objects (egg spawn points, navigation zones, hub stations) are
# placed in large numbers. Instead of wiring hundreds of references by hand,
# each of those devices registers itself here in OnBegin. The game device
# reads the registry after RegistrySettleSeconds.
#
# The registry is stored in a module-scoped weak_map keyed by the current
# session, which is the supported way to hold global state in Verse.
# ============================================================================
using { /Verse.org/Simulation }

world_registry := class:
    var SpawnPoints : []egg_spawn_point_device = array{}
    var Zones : []sea_zone_device = array{}
    var Stations : []menu_station_device = array{}

    RegisterSpawnPoint(Point:egg_spawn_point_device)<transacts>:void =
        set SpawnPoints += array{Point}

    RegisterZone(Zone:sea_zone_device)<transacts>:void =
        set Zones += array{Zone}

    RegisterStation(Station:menu_station_device)<transacts>:void =
        set Stations += array{Station}

var WorldRegistryMap : weak_map(session, world_registry) = map{}

GetWorldRegistry()<transacts>:world_registry =
    CurrentSession := GetSession()
    if (Existing := WorldRegistryMap[CurrentSession]):
        Existing
    else:
        Created := world_registry{}
        if (set WorldRegistryMap[CurrentSession] = Created) {}
        Created
