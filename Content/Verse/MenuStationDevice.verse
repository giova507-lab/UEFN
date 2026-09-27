# ============================================================================
# RIDE A SEA BEAST - MenuStationDevice.verse
# Interactable hub stations: MARINA (Current Tracker), FINN (Sonar Shack),
# CHEF KELP (Feed Dock), CAPTAIN PEARL (Harbor Trader), the Ocean Index
# kiosk and Settings kiosks. Place one device per station next to its
# building, link a button (the interaction prompt) and optionally an NPC
# spawner whose character definition uses `sea_npc_behavior`.
# Stations self-register, so any number can be placed.
# ============================================================================
using { /Fortnite.com/Devices }
using { /Verse.org/Simulation }
using { /Verse.org/Random }

menu_station_device := class(creative_device):
    @editable
    Station : station_kind = station_kind.CurrentTracker
    # Shown in the menu header and interaction prompt, e.g. "MARINA".
    @editable
    NPCName : string = "MARINA"
    # Short lines of dialogue; one is picked each time the menu opens.
    @editable
    Greetings : []string = array{}
    @editable
    InteractButton : button_device = button_device{}
    @editable
    NPCSpawner : []npc_spawner_device = array{}
    @editable
    NameSign : []billboard_device = array{}

    var Game : ?sea_beast_game_device = false

    OnBegin<override>()<suspends>:void =
        InteractButton.SetInteractionText(TalkPrompt(NPCName))
        InteractButton.InteractedWithEvent.Subscribe(OnInteracted)
        for (Sign : NameSign):
            Sign.SetText(ToMessage(StationTitle()))
        for (Spawner : NPCSpawner):
            Spawner.Enable()
            Spawner.Spawn()
        GetWorldRegistry().RegisterStation(Self)

    BindGame(G:sea_beast_game_device):void =
        set Game = option{G}

    OnInteracted(Agent:agent):void =
        if (G := Game?, Player := player[Agent]):
            G.OpenStation(Player, Self)

    PickGreeting()<transacts>:string =
        if (Greetings.Length > 0, Line := Greetings[GetRandomInt(0, Greetings.Length - 1)]):
            Line
        else:
            DefaultGreeting()

    DefaultGreeting()<computes>:string =
        case (Station):
            station_kind.CurrentTracker => "The tide never lies. Here's what's out there right now!"
            station_kind.SonarShack => "Beep boop! My sonars can hear an egg sneeze across the ocean!"
            station_kind.FeedDock => "Hungry beasts are happy beasts! Fresh from the kitchen!"
            station_kind.HarborTrader => "Arr, I'll give ye a fair price for yer spare beasts."
            station_kind.OceanIndex => "Every creature of the sea, recorded by explorers like you."
            station_kind.Settings => "Adjust your ocean experience."
            station_kind.SeaBeasts => "Manage your Sea Beasts."
            station_kind.DeepDive => "The deep calls to those who are ready."

    StationTitle()<computes>:string =
        case (Station):
            station_kind.CurrentTracker => "CURRENT TRACKER"
            station_kind.SonarShack => "SONAR SHACK"
            station_kind.FeedDock => "FEED DOCK"
            station_kind.HarborTrader => "HARBOR TRADER"
            station_kind.OceanIndex => "OCEAN INDEX"
            station_kind.Settings => "SETTINGS"
            station_kind.SeaBeasts => "SEA BEASTS"
            station_kind.DeepDive => "DEEP DIVE"
