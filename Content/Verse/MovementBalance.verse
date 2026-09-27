# ============================================================================
# RIDE A SEA BEAST - MovementBalance.verse
# Converts huge DISPLAY stats into stable physical movement.
#
# Display Speed spans 15 .. 100,000,000,000 (mutated endgame). Physical speed
# must stay controllable, so we interpolate in LOG space between anchors:
#
#   PhysicalSpeed = Anchor(i).MetersPerSecond
#                 + t * (Anchor(i+1).MetersPerSecond - Anchor(i).MetersPerSecond)
#   t = (log10(Display) - log10(Anchor(i).Display))
#     / (log10(Anchor(i+1).Display) - log10(Anchor(i).Display))
#
# Target bands (from the design): beginner 6-8 m/s, early 10-15, mid 18-25,
# late 30-40, endgame 45-60. World distances in WORLD_DESIGN.md are balanced
# around these values and the 45 s egg carry timer.
# ============================================================================

# (display speed, physical meters per second). Must be sorted ascending.
SpeedCurveAnchors : []tuple(float, float) = array:
    (15.0, 6.5)
    (90.0, 7.8)
    (300.0, 9.5)
    (750.0, 11.5)
    (1020.0, 13.0)
    (3050.0, 18.0)
    (4480.0, 21.0)
    (6100.0, 24.5)
    (6960.0, 27.0)
    (19500.0, 31.0)
    (38400.0, 36.0)
    (137000.0, 42.0)
    (1000000.0, 47.0)
    (100000000.0, 53.0)
    (1000000000.0, 57.0)
    (100000000000.0, 60.0)

# Physical speed in meters per second for a display speed.
DisplaySpeedToMetersPerSecond(DisplaySpeed:float)<transacts>:float =
    Display := MaxF(DisplaySpeed, 1.0)
    if (First := SpeedCurveAnchors[0], Display <= First(0)):
        return First(1)
    for (I := 0..SpeedCurveAnchors.Length - 2):
        if:
            A := SpeedCurveAnchors[I]
            B := SpeedCurveAnchors[I + 1]
            Display <= B(0)
        then:
            LogA := Log(10.0, A(0))
            LogB := Log(10.0, B(0))
            T := if (LogB > LogA) then (Log(10.0, Display) - LogA) / (LogB - LogA) else 1.0
            return A(1) + ClampF(T, 0.0, 1.0) * (B(1) - A(1))
    if (Last := SpeedCurveAnchors[SpeedCurveAnchors.Length - 1]):
        return Last(1)
    6.5

# Physical speed in centimeters per second (Unreal units).
DisplaySpeedToCmPerSecond(DisplaySpeed:float)<transacts>:float =
    DisplaySpeedToMetersPerSecond(DisplaySpeed) * 100.0

# Breach -> maximum launch height in cm. Breach 78 ~ 2.5 m, 170 ~ 13.5 m.
BreachHeightBaseCm : float = 150.0
BreachHeightPerPointCm : float = 12.0
BreachHeightReferenceBreach : float = 70.0
BreachHeightMaxCm : float = 1600.0

BreachToLaunchHeightCm(Breach:float)<computes>:float =
    ClampF(BreachHeightBaseCm + (Breach - BreachHeightReferenceBreach) * BreachHeightPerPointCm, BreachHeightBaseCm, BreachHeightMaxCm)

# Initial vertical velocity (cm/s) needed to reach the launch height.
BreachLaunchVelocity(Breach:float)<reads>:float =
    Sqrt(2.0 * MountGravityCmPerSec2 * BreachToLaunchHeightCm(Breach))

# Egg claim reach while mounted grows with creature size.
MountedPickupRadius(SizeClass:int)<computes>:float =
    EggPickupRadiusMounted * (1.0 + 0.15 * ToFloat(Max(0, SizeClass)))

# Dive depth scales with Breach (0.75x - 1.6x of the default depth), capped by
# the local limit: MountDefaultDiveDepthCm in open water, so the extra depth
# of strong swimmers only shows inside DeepWater zones.
DiveDepthForBreach(Breach:float, ZoneMaxDepth:float)<computes>:float =
    Depth := MountDefaultDiveDepthCm * ClampF(Breach / 100.0, 0.75, 1.6)
    MinF(Depth, ZoneMaxDepth)

# Human readable speed bands, used by the Sea Beasts menu tooltip.
SpeedBandName(MetersPerSecond:float)<computes>:string =
    if (MetersPerSecond < 9.0):
        "BEGINNER"
    else if (MetersPerSecond < 16.0):
        "EARLY"
    else if (MetersPerSecond < 28.0):
        "MID"
    else if (MetersPerSecond < 44.0):
        "LATE"
    else:
        "ENDGAME"
