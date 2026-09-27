# Test Plan

Run these in a UEFN session first, then in a **private playtest** with real devices (PC, console controller, mobile). The DEV panel speeds up most tests: turn on `DeveloperToolsEnabled` on the game device, then hold Reload and open the DEV tab. It never appears in Live sessions.

Record results as ✅ / ❌ with a note. Any ❌ in sections A, B, C or K blocks publishing.

## A. Fresh player flow (new save)

Use DEV → CLEAR SAVE DATA, then rejoin.

| # | Step | Expected |
|---|---|---|
| A1 | Join | Intro flyover plays (8-12 s) with a SKIP button. |
| A2 | Press SKIP | The intro stops right away and the camera returns. |
| A3 | After the intro | The player stands in their own Lagoon; the sign reads `NAME'S LAGOON`. |
| A4 | HUD | Cash `$25`, income, tide timer, day phase, weather, egg basket `0/1`. |
| A5 | Tutorial 1-2 | "WELCOME TO RIDE A SEA BEAST!", then "THIS IS YOUR LAGOON." |
| A6 | Tutorial 3 | "MOUNT YOUR SEA SLUG." The Sea Slug is in the inventory and is the active mount. |
| A7 | Press RIDE at the dock | The Sea Slug appears at the dock with the player seated. |
| A8 | Swim (hold Fire / Move) | Smooth acceleration, no jitter, camera follows. |
| A9 | Steer with the camera | The creature turns toward the camera direction and banks. |
| A10 | Sprint | FAST SWIM on the HUD, higher speed, wake spray. |
| A11 | Jump while moving | Breach arc with splash on landing. |
| A12 | Hold Crouch | Dives below the surface; surfaces again on release. |
| A13 | Tutorial 4 | A Pearl Egg glows near the Lagoon (tutorial egg). |
| A14 | Swim into the egg | "PEARL EGG 1.0x / BRING IT HOME BEFORE IT CRACKS!", basket `1 / 1`, crack timer on the HUD, glow on the player. |
| A15 | Tutorial 5 | "BRING IT HOME BEFORE IT CRACKS!" |
| A16 | Enter own Lagoon | "EGG SECURED!", the egg appears in an incubator. |
| A17 | Tutorial 6-7 | "PLACE IT IN YOUR INCUBATOR", then "HATCH NEW SEA BEASTS". The timer counts down 20 s. |
| A18 | Interact with HATCH! | The hatch sequence plays with rarity color; the result is at least a Hermit Crab. |
| A19 | Result card | Name, rarity, stats and a "new discovery" note; it is added to the inventory. |
| A20 | Tutorial 8 | "FASTER BEASTS CAN REACH RARER EGGS!", then the tutorial completes. Total time is under 5 min. |
| A21 | Lagoon display | The new creature swims in the Lagoon pool. |
| A22 | Income | Cash rises every second; the income sign updates. |
| A23 | Hatch Luck button | Cost $25; Luck goes 1.0x → 2.0x; the board shows `1/5`. |
| A24 | Five upgrades | The fifth adds +5 (cycle +1,+1,+1,+1,+5). |
| A25 | BUY MAX | Buys as many as affordable; cash never goes negative. |
| A26 | Hold Reload → SEA BEASTS | Menu opens; cards, filters and sorts work; RIDE / PLACE / REMOVE / FEED / LOCK / SELL buttons are there. |
| A27 | PLACE BEST | Slots fill with the highest-income creatures. |
| A28 | Close the menu | Input mode is released and the player can move and aim normally. |
| A29 | Wild egg | Claim a world Pearl/Sandy egg and deliver it. The incubation time matches its rarity (3 min Common). |
| A30 | Egg cracks | Wait more than 45 s while carrying: "YOUR SEA EGG CRACKED!", basket `0 / 1`, the egg is gone. |
| A31 | Ocean Index | Discovered species show; undiscovered ones are silhouettes; milestone progress shows. |
| A32 | Leave and rejoin | Cash, creatures, luck, incubators and tutorial state are all restored. The intro doesn't replay. |

## B. Multiplayer (6 players)

| # | Test | Expected |
|---|---|---|
| B1 | 6 players join | Each gets a different Lagoon; no Lagoon is shared. |
| B2 | Player presses another Lagoon's buttons | Nothing happens except "THIS IS NOT YOUR LAGOON." No purchase, no hatch, no placement. |
| B3 | Two players reach one egg at the same moment | Exactly one gets it; the other sees "EGG CLAIMED!". |
| B4 | Player leaves while carrying an egg | The egg is lost with the player (not duplicated); the Lagoon becomes AVAILABLE. |
| B5 | New player joins after someone left | Gets the freed Lagoon with a clean sign. |
| B6 | Divine egg spawns | Everyone sees a global announcement **without** a location. |
| B7 | Tide reset | Everyone sees "THE TIDE HAS CHANGED!"; unclaimed eggs are replaced. |
| B8 | Party members together | FRIEND BOOST (PARTY) shows +10% per member present (max +50%). |
| B9 | 6 players riding at once | No rider desync; each creature is visible to the others. |

## C. Persistence

| # | Test | Expected |
|---|---|---|
| C1 | Hatch, then leave within 1 s | The creature is there after rejoining (saved before the cinematic). |
| C2 | Buy something, leave, rejoin | Purchase kept, cash deducted once. |
| C3 | Leave with 2 h of income | On rejoin: offline popup with 2 h of income, paid only on CLAIM. |
| C4 | Leave for over 8 h (edit the time or wait) | Reward is capped at 8 h. |
| C5 | Leave with an incubating egg | Incubation progressed while away. |
| C6 | Settings changed | Settings persist across sessions. |
| C7 | Save after a Deep Dive | Dive count, multiplier and slots persist. Cash and luck stay reset. |
| C8 | Save data version | Loading a DataVersion 0 / empty save starts a fresh profile without errors. |

## D. Riding (every creature)

Use DEV → GIVE CREATURE for IDs 1-30 and ride each one.

| # | Check | Expected |
|---|---|---|
| D1 | Mount / dismount | Clean seat and exit; Jump when nearly stopped dismounts at the surface. |
| D2 | Scale and saddle | The rider sits on the model (tune `SaddleHeight`/`SaddleForward`). |
| D3 | Speed | Matches [BALANCE.md](BALANCE.md) (6.5 m/s … 57 m/s). |
| D4 | Turning | Big beasts turn slower; no snapping. |
| D5 | Breach height | Clears pool rims according to the table. |
| D6 | Shores | The beast slides along shores; it never enters land or gets stuck. |
| D7 | Animation variants | Idle when stopped, swim, fast swim (if assigned). |
| D8 | Pool slots full | A 3rd rider of a 2-slot creature uses the static fallback without errors. |
| D9 | Mutations | Electrified → Primordial speeds change the physical speed only moderately. |

## E. Input platforms

| # | Platform | Check |
|---|---|---|
| E1 | Keyboard/mouse | Fire hold to swim, Aim to brake, Sprint, Jump, Crouch, hold Reload for the menu. |
| E2 | Controller | Same actions on triggers and buttons; menus navigable. |
| E3 | Touch | Throttle toggle by default (tap Fire), buttons reachable, menus readable. |
| E4 | Seated input | Actions reach Verse while seated. If not, switch `RiderAttachMode` (setup guide section 4). |

## F. Economy, shops, NPCs

| # | Test | Expected |
|---|---|---|
| F1 | Sonar purchase | Stock decreases; buying at 0 stock is refused ("… IS OUT OF STOCK!"). |
| F2 | Sonar activation with no eggs of that tier | "NO <RARITY> SEA EGGS DETECTED…"; no charge used. |
| F3 | Sonar target claimed by another player | "SIGNAL LOST! SEARCHING…", then it retargets. |
| F4 | Sonar restock | Timer counts down; stock refreshes. |
| F5 | Feeding | XP rises; level-ups raise stats; max level is 100. |
| F6 | Sell | Price matches the formula; locked, mounted and last creatures are refused; the Deep Dive creature needs confirmation. |
| F7 | Index milestone | CLAIM pays once; a second claim is impossible. |
| F8 | Current Tracker | Lists live eggs; sorts by luck and rarity. |

## G. Weather, mutations, day/night

| # | Test | Expected |
|---|---|---|
| G1 | DEV → TRIGGER WEATHER (each) | Announcement, visuals, HUD label, income modifier. |
| G2 | Mutation rolls | Only placed creatures mutate; toast and flash. |
| G3 | Stronger over weaker | Electrified → Abyssal upgrades. An Abyssal creature during a Thunderstorm stays Abyssal. |
| G4 | Primordial | Extremely rare (at most once per hour); ×100 speed. |
| G5 | Night | "NIGHT TIDE 10X EGG GROWTH"; incubators speed up 10x. |
| G6 | Phase visuals | Skydome, lights and post process switch per phase. |

## H. Deep Dive

| # | Test | Expected |
|---|---|---|
| H1 | Requirements missing | The screen shows what is missing; the button is refused. |
| H2 | Requirements met | Confirmation, then the cinematic, then cash and luck reset. Creatures, Index, mutations and slots are kept, with +1X and +1 slot. |
| H3 | Required creature | Still owned afterwards (not consumed). |
| H4 | Leave mid-cinematic | The dive is already saved. |

## I. UI

| # | Test | Expected |
|---|---|---|
| I1 | Every menu | Opens, paginates, closes with the X / Back button. |
| I2 | Spam-click buy buttons | No double purchases beyond what is affordable; no errors. |
| I3 | Large numbers | Formatted as K, M, B, T, Qa, Qi… with no overflow on cards. |
| I4 | Menu while mounted | The menu opens; closing it restores control. |
| I5 | Hatch while a menu is open | No overlapping input-mode lock. |

## J. Settings

| Setting | Expected |
|---|---|
| Music off | The biome track stops for this player only. |
| SFX off | No sound effects for this player. |
| Camera Shake off | No shake sequences for this player. |
| Hatch Cinematic off | Short reveal (the first hatch always shows the full sequence). |
| Other Player Effects off | No announcements or sounds about other players' hatches or mutations. Egg spawn announcements are kept. |
| Low Effects Mode on | No weather post-process, wake spray, carried-egg glow or hatch energy build-up for this player's actions. |
| Throttle mode | Hold vs toggle swimming works. |

## K. Security and edge cases

| # | Test | Expected |
|---|---|---|
| K1 | Buttons of other Lagoons | Refused (B2). |
| K2 | Press hatch twice quickly | Only one creature. |
| K3 | Place an egg with an empty basket | Refused. |
| K4 | Claim a second egg with a full basket | Refused ("YOUR EGG BASKET IS FULL!…"). |
| K5 | Sell the ridden creature | Refused. |
| K6 | Buy with insufficient cash | Refused, with the correct message. |
| K7 | DEV panel in a Live session | Not visible. Commands are refused even if called. |
| K8 | Eliminated or fell off the map | Respawns at their own Lagoon; any carried egg is lost. |
| K9 | Leave during a hatch or dive | No loss, no duplication. |

## L. Performance

| # | Test | Expected |
|---|---|---|
| L1 | 6 players riding and hatching | Server stays stable; no Verse runtime errors in the log. |
| L2 | Memory calculator | Within the platform limits ([PERFORMANCE.md](PERFORMANCE.md)). |
| L3 | Mobile device | Stable frame rate with Low Effects Mode. |
