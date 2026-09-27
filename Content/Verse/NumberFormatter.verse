# ============================================================================
# RIDE A SEA BEAST - NumberFormatter.verse
# The ONLY place numbers are turned into display strings. Every UI, sign and
# message uses these helpers - never format numbers inline elsewhere.
#   1,000 -> 1K   1,000,000 -> 1M   1e9 -> 1B   1e12 -> 1T   1e15 -> 1Qa
#   1e18 -> 1Qi   ... continues through 1e63 (Vg).
# ============================================================================

NumberSuffixes : []string = array{"", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc", "Ud", "Dd", "Td", "Qad", "Qid", "Sxd", "Spd", "Ocd", "Nod", "Vg"}

# Left-pads a non-negative int with zeros to Width digits.
PadInt(Value:int, Width:int)<transacts>:string =
    var S : string = ToString(Max(0, Value))
    loop:
        if (S.Length >= Width):
            break
        set S = "0" + S
    S

# Inserts thousands separators: 1234567 -> "1,234,567".
FormatWithCommas(Value:int)<transacts>:string =
    var Remaining : int = if (Value < 0) then -Value else Value
    var Out : string = ""
    if (Remaining = 0):
        set Out = "0"
    loop:
        if (Remaining <= 0):
            break
        Group := ModInt(Remaining, 1000)
        set Remaining = QuotInt(Remaining, 1000)
        if (Remaining > 0):
            set Out = "," + PadInt(Group, 3) + Out
        else:
            set Out = ToString(Group) + Out
    if (Value < 0) then "-" + Out else Out

# Formats X with at most Decimals decimals, trimming trailing zeros.
FormatDecimal(X:float, Decimals:int)<transacts>:string =
    Negative := logic{X < 0.0}
    AbsX := AbsF(X)
    Scale := Pow(10.0, ToFloat(Decimals))
    ScaledInt := RoundToInt(AbsX * Scale, 0)
    IntPart := QuotInt(ScaledInt, FloorToInt(Scale, 1))
    FracPart := ModInt(ScaledInt, FloorToInt(Scale, 1))
    var FracText : string = if (Decimals > 0) then PadInt(FracPart, Decimals) else ""
    # Trim trailing zeros.
    loop:
        if (FracText.Length = 0):
            break
        if (Last := FracText[FracText.Length - 1], Last = '0', Trimmed := FracText.Slice[0, FracText.Length - 1]):
            set FracText = Trimmed
        else:
            break
    Body := if (FracText.Length > 0) then "{ToString(IntPart)}.{FracText}" else ToString(IntPart)
    if (Negative?) then "-" + Body else Body

# 3-significant-digit compact format with suffixes: 999, 1.25K, 12.5K, 125K, 1.25M...
FormatCompact(Value:float)<transacts>:string =
    if (not Value.IsFinite[]):
        return "0"
    Negative := logic{Value < 0.0}
    var Scaled : float = AbsF(Value)
    var Group : int = 0
    loop:
        if (Scaled < 1000.0 or Group >= NumberSuffixes.Length - 1):
            break
        set Scaled = Scaled / 1000.0
        set Group += 1
    var Text : string = ""
    if (Group = 0):
        # Below 1000: whole numbers, one decimal for tiny fractional values.
        if (Scaled < 10.0 and Scaled <> ToFloat(FloorToInt(Scaled, 0))):
            set Text = FormatDecimal(Scaled, 1)
        else:
            set Text = ToString(FloorToInt(Scaled, 0))
    else:
        Decimals := if (Scaled < 10.0) then 2 else if (Scaled < 100.0) then 1 else 0
        # Rounding can push 999.95K to 1000K - carry into the next suffix.
        Rounded := ToFloat(RoundToInt(Scaled * Pow(10.0, ToFloat(Decimals)), 0)) / Pow(10.0, ToFloat(Decimals))
        if (Rounded >= 1000.0 and Group < NumberSuffixes.Length - 1):
            set Text = "1{GetSuffix(Group + 1)}"
        else:
            set Text = FormatDecimal(Rounded, Decimals) + GetSuffix(Group)
    if (Negative?) then "-" + Text else Text

GetSuffix(Group:int)<computes>:string =
    if (S := NumberSuffixes[Group]) then S else ""

# "$12.4K"
FormatCash(Value:float)<transacts>:string = "$" + FormatCompact(Value)

# "+$375/s"
FormatIncome(PerSecond:float)<transacts>:string = "+$" + FormatCompact(PerSecond) + "/s"

# "1 IN 5T"
FormatOdds(Denominator:float)<transacts>:string = "1 IN " + FormatCompact(Denominator)

# "1T LUCK"
FormatLuck(Luck:float)<transacts>:string = FormatCompact(Luck) + " LUCK"

# "595X" for Hatch Luck style multipliers.
FormatMultiplier(Value:float)<transacts>:string = FormatCompact(Value) + "X"

# "+10%"
FormatPercent(Fraction:float)<transacts>:string =
    "+" + ToString(RoundToInt(Fraction * 100.0, 0)) + "%"

# "03:42" or "1:02:03".
FormatClock(Seconds:float)<transacts>:string =
    Total := Max(0, FloorToInt(Seconds + 0.999, 0))
    Hours := QuotInt(Total, 3600)
    Minutes := QuotInt(ModInt(Total, 3600), 60)
    Secs := ModInt(Total, 60)
    if (Hours > 0):
        "{ToString(Hours)}:{PadInt(Minutes, 2)}:{PadInt(Secs, 2)}"
    else:
        "{PadInt(Minutes, 2)}:{PadInt(Secs, 2)}"

# "2h 5m", "4m 34s", "45s".
FormatDuration(Seconds:float)<transacts>:string =
    Total := Max(0, FloorToInt(Seconds + 0.999, 0))
    Hours := QuotInt(Total, 3600)
    Minutes := QuotInt(ModInt(Total, 3600), 60)
    Secs := ModInt(Total, 60)
    if (Hours > 0):
        "{ToString(Hours)}h {ToString(Minutes)}m"
    else if (Minutes > 0):
        "{ToString(Minutes)}m {ToString(Secs)}s"
    else:
        "{ToString(Secs)}s"

# Distance in cm -> "824m" / "1.25km".
FormatDistance(Centimeters:float)<transacts>:string =
    Meters := Centimeters / 100.0
    if (Meters >= 1000.0):
        FormatDecimal(Meters / 1000.0, 2) + "km"
    else:
        ToString(Max(0, FloorToInt(Meters, 0))) + "m"
