# ============================================================================
# RIDE A SEA BEAST - SeaZoneDevice.verse
# Designer-placed navigation zones. Drop one of these on every island shore,
# reef wall, raised pool, trench and biome region. Zones self-register with
# the WorldRegistry, so no manual wiring is required.
#
#   Land      : Sea Beasts cannot enter between BottomOffset and TopOffset
#               (relative to the device). A high Breach can jump over a zone
#               whose top is low enough; a dive can pass under a zone whose
#               bottom is above the dive depth (arches, tunnels).
#   WaterPool : the water surface inside the shape is at the device's Z.
#               Use for pools above waterfalls and floating caves - reachable
#               only by breaching high enough.
#   Biome     : names the region (music, HUD, analytics). Highest Priority wins.
#   DeepWater : dives inside may go down to MaxDiveDepth below the surface.
# ============================================================================
using { /Fortnite.com/Devices }
using { /Verse.org/Simulation }
using { /UnrealEngine.com/Temporary/SpatialMath }

sea_zone_device := class(creative_device):
    @editable
    Kind : zone_kind = zone_kind.Land
    @editable
    Shape : zone_shape = zone_shape.Cylinder
    # Cylinder radius in cm.
    @editable
    Radius : float = 2000.0
    # Box half extents in cm, in the device's local (rotated) space.
    @editable
    HalfExtentX : float = 2000.0
    @editable
    HalfExtentY : float = 2000.0
    # Vertical extent relative to the device location (Land zones).
    @editable
    BottomOffset : float = -3000.0
    @editable
    TopOffset : float = 3000.0
    @editable
    ZoneBiome : biome = biome.ShallowReef
    @editable
    Priority : int = 0
    # DeepWater zones: maximum dive depth below the local surface (cm).
    @editable
    MaxDiveDepth : float = 4000.0

    var CenterX : float = 0.0
    var CenterY : float = 0.0
    var CenterZ : float = 0.0
    var CosYaw : float = 1.0
    var SinYaw : float = 0.0

    OnBegin<override>()<suspends>:void =
        CacheTransform()
        GetWorldRegistry().RegisterZone(Self)

    CacheTransform():void =
        T := GetTransform()
        set CenterX = T.Translation.X
        set CenterY = T.Translation.Y
        set CenterZ = T.Translation.Z
        Angles := T.Rotation.GetYawPitchRollDegrees()
        YawDegrees := if (Y := Angles[0]) then Y else 0.0
        YawRadians := YawDegrees * PiFloat / 180.0
        set CosYaw = Cos(YawRadians)
        set SinYaw = Sin(YawRadians)

    GetBottomZ()<transacts>:float = CenterZ + BottomOffset
    GetTopZ()<transacts>:float = CenterZ + TopOffset
    GetSurfaceZ()<transacts>:float = CenterZ

    # Succeeds when (X, Y) is inside the shape grown by Expand cm.
    ContainsXY(X:float, Y:float, Expand:float)<transacts><decides>:void =
        DX := X - CenterX
        DY := Y - CenterY
        R := Radius + Expand
        LX := DX * CosYaw + DY * SinYaw
        LY := -DX * SinYaw + DY * CosYaw
        (Shape = zone_shape.Cylinder and DX * DX + DY * DY <= R * R) or (Shape = zone_shape.Box and AbsF(LX) <= HalfExtentX + Expand and AbsF(LY) <= HalfExtentY + Expand)

    # Succeeds when height Z is inside the zone's vertical band.
    ContainsZ(Z:float)<transacts><decides>:void =
        Z >= GetBottomZ()
        Z <= GetTopZ()

    # Nearest point on the boundary of the shape grown by Expand, returned as
    # (X, Y). Used to slide Sea Beasts along shorelines.
    PushOut(X:float, Y:float, Expand:float)<transacts>:tuple(float, float) =
        DX := X - CenterX
        DY := Y - CenterY
        if (Shape = zone_shape.Cylinder):
            R := Radius + Expand + 5.0
            Len := Sqrt(DX * DX + DY * DY)
            if (Len < 1.0):
                (CenterX + R, CenterY)
            else:
                (CenterX + DX / Len * R, CenterY + DY / Len * R)
        else:
            LX := DX * CosYaw + DY * SinYaw
            LY := -DX * SinYaw + DY * CosYaw
            HX := HalfExtentX + Expand + 5.0
            HY := HalfExtentY + Expand + 5.0
            PenX := HX - AbsF(LX)
            PenY := HY - AbsF(LY)
            var NewLX : float = LX
            var NewLY : float = LY
            if (PenX < PenY):
                set NewLX = if (LX < 0.0) then -HX else HX
            else:
                set NewLY = if (LY < 0.0) then -HY else HY
            WX := NewLX * CosYaw - NewLY * SinYaw
            WY := NewLX * SinYaw + NewLY * CosYaw
            (CenterX + WX, CenterY + WY)

    # Rough area used to prefer the most specific zone when zones overlap.
    GetArea()<transacts>:float =
        if (Shape = zone_shape.Cylinder):
            PiFloat * Radius * Radius
        else:
            4.0 * HalfExtentX * HalfExtentY
