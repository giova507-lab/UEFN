# ============================================================================
# RIDE A SEA BEAST - SeaNavigation.verse
# Deterministic, server-side navigation for Sea Beasts built from the
# designer-placed sea_zone_devices. No physics queries are needed:
#   * the open ocean surface is SeaLevelZ;
#   * Land zones block movement inside their vertical band;
#   * WaterPool zones raise the surface (reachable only by breaching);
#   * DeepWater zones allow deeper dives;
#   * Biome zones name the region (fallback: distance rings from the hub).
# ============================================================================
using { /Verse.org/Simulation }
using { /UnrealEngine.com/Temporary/SpatialMath }

# Fallback biome rings (cm from the hub) used where no Biome zone is placed.
# Matches the layout in docs/WORLD_DESIGN.md.
BiomeRingRadii : []float = array{20000.0, 45000.0, 70000.0, 95000.0, 120000.0, 145000.0, 165000.0}

# Height tolerance (cm) for being "at" a pool surface.
PoolSurfaceTolerance : float = 60.0

sea_navigator := class:
    LandZones : []sea_zone_device = array{}
    PoolZones : []sea_zone_device = array{}
    BiomeZones : []sea_zone_device = array{}
    DeepZones : []sea_zone_device = array{}
    SeaLevel : float = 0.0
    HubX : float = 0.0
    HubY : float = 0.0

    # Water surface height at (X, Y) for a creature currently at CurrentZ.
    SurfaceZAt(X:float, Y:float, CurrentZ:float)<transacts>:float =
        var Surface : float = SeaLevel
        for (Pool : PoolZones, Pool.ContainsXY[X, Y, 0.0]):
            PoolZ := Pool.GetSurfaceZ()
            if (CurrentZ >= PoolZ - PoolSurfaceTolerance, PoolZ > Surface):
                set Surface = PoolZ
        Surface

    # Succeeds with the first Land zone that blocks a sphere of Radius at (X,Y,Z).
    FindBlockingZone(X:float, Y:float, Z:float, Radius:float)<transacts><decides>:sea_zone_device =
        var Found : ?sea_zone_device = false
        for (Zone : LandZones, not Found?, Zone.ContainsZ[Z], Zone.ContainsXY[X, Y, Radius]):
            set Found = option{Zone}
        Found?

    IsBlocked(X:float, Y:float, Z:float, Radius:float)<transacts><decides>:void =
        FindBlockingZone[X, Y, Z, Radius]

    # Moves from (FromX, FromY) toward (ToX, ToY) at height Z, sliding along
    # blocking shores. Returns (X, Y, WasBlocked).
    ResolveHorizontal(FromX:float, FromY:float, ToX:float, ToY:float, Z:float, Radius:float)<transacts>:tuple(float, float, logic) =
        var X : float = ToX
        var Y : float = ToY
        var Blocked : logic = false
        var Iteration : int = 0
        loop:
            if (Iteration >= 3):
                break
            if (Zone := FindBlockingZone[X, Y, Z, Radius]):
                Pushed := Zone.PushOut(X, Y, Radius)
                set X = Pushed(0)
                set Y = Pushed(1)
                set Blocked = true
            else:
                break
            set Iteration += 1
        if (IsBlocked[X, Y, Z, Radius]):
            # Could not resolve (overlapping zones): stay where we were.
            (FromX, FromY, true)
        else:
            Clamped := ClampToBounds(X, Y)
            (Clamped(0), Clamped(1), Blocked)

    # Keeps positions inside the playable ocean.
    ClampToBounds(X:float, Y:float)<transacts>:tuple(float, float) =
        DX := X - HubX
        DY := Y - HubY
        Len := Sqrt(DX * DX + DY * DY)
        if (Len > WorldBoundsRadius, Len > 0.0):
            (HubX + DX / Len * WorldBoundsRadius, HubY + DY / Len * WorldBoundsRadius)
        else:
            (X, Y)

    # Deepest allowed dive below the local surface at (X, Y).
    MaxDiveDepthAt(X:float, Y:float)<transacts>:float =
        var Depth : float = MountDefaultDiveDepthCm
        for (Zone : DeepZones, Zone.ContainsXY[X, Y, 0.0], Zone.MaxDiveDepth > Depth):
            set Depth = Zone.MaxDiveDepth
        Depth

    # Region at (X, Y): best Biome zone, else the distance ring.
    BiomeAt(X:float, Y:float)<transacts>:biome =
        var Best : ?sea_zone_device = false
        var BestPriority : int = -1000000
        var BestArea : float = 0.0
        for (Zone : BiomeZones, Zone.ContainsXY[X, Y, 0.0]):
            Area := Zone.GetArea()
            if (Zone.Priority > BestPriority or (Zone.Priority = BestPriority and Area < BestArea)):
                set Best = option{Zone}
                set BestPriority = Zone.Priority
                set BestArea = Area
        if (Zone := Best?):
            Zone.ZoneBiome
        else:
            BiomeFromRings(X, Y)

    BiomeFromRings(X:float, Y:float)<transacts>:biome =
        DX := X - HubX
        DY := Y - HubY
        Dist := Sqrt(DX * DX + DY * DY)
        var RingIndex : int = BiomeRingRadii.Length
        for (I -> Limit : BiomeRingRadii, Dist < Limit, RingIndex = BiomeRingRadii.Length):
            set RingIndex = I
        BiomeFromIndex(RingIndex)

BiomeFromIndex(I:int)<computes>:biome =
    if (I <= 0):
        biome.CentralLagoon
    else if (I = 1):
        biome.ShallowReef
    else if (I = 2):
        biome.KelpForest
    else if (I = 3):
        biome.TropicalAtoll
    else if (I = 4):
        biome.FrozenSea
    else if (I = 5):
        biome.VolcanicArchipelago
    else if (I = 6):
        biome.TheAbyss
    else:
        biome.CelestialSea

MakeNavigator(Zones:[]sea_zone_device, SeaLevelZ:float, HubCenter:vector3)<transacts>:sea_navigator =
    sea_navigator:
        LandZones := for (Z : Zones, Z.Kind = zone_kind.Land). Z
        PoolZones := for (Z : Zones, Z.Kind = zone_kind.WaterPool). Z
        BiomeZones := for (Z : Zones, Z.Kind = zone_kind.Biome). Z
        DeepZones := for (Z : Zones, Z.Kind = zone_kind.DeepWater). Z
        SeaLevel := SeaLevelZ
        HubX := HubCenter.X
        HubY := HubCenter.Y
