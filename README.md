# SadoEE

Party Stash and SadoQoL in one WeiDU mod for **Baldur's Gate: Enhanced Edition**, **EET** and **Baldur's Gate II: Enhanced Edition** (game versions 2.6.6 and 2.7.3). Every feature is an optional component. Requires [EEex](https://github.com/Bubb13/EEex).

## Components

| # | Group | Component |
|---|---|---|
| 0-4 | Party Stash | One infinite stash shared by the whole party, on a redesigned inventory page (Baldur's Gate 1 or II look) |
| 1 | Party Stash | Sorted loot: quest items, then weightless items, then the rest by value/weight |
| 5-7 | Party Stash | Options: weightless stash, keep the gold through campaign changes, hardcore |
| 10 | Rest camp | A quiet camp reached from the world map (0 h there and back, rest without ambush) and its wandering priest |
| 11 | Rest camp | Grand merchant: sells every item seen at the stores already visited |
| 12 | Rest camp | The Old Scholar: identifies everything |
| 13 | Rest camp | Ex-members can wait for you at the camp |
| 14 | Rest camp | Withers: a lich who fully recreates a party member |
| 15 | Rest camp | Withers can also recruit new members |
| 20-32 | Quality of life | Passive trap detection, valuable containers, automatic disarming, FPS counter, endless ammo, small party footprint, lasting modes, attack-move, mouse buttons, keep gear on death, chests in the ground bar, Auto-Roller |
| 40 | Engine extension | Big party: 7 to 32 members (experimental) |

The rest camp (#10-#15) is for BGEE and EET for now; the big party for BGEE and EET.

## Installation

1. Install EEex.
2. Coming from Party Stash or SadoQoL: uninstall them first (SadoEE replaces both; saves keep working).
3. Extract the release into the game folder (where chitin.key is) and run `setup-SadoEE.exe`.
4. Start the game with `InfinityLoader.exe`.

Before uninstalling, empty the stash in game: Ctrl + left click on the big bag next to the weight.

Readme in 15 languages: `SadoEE/readme/`.

## Building (for the author)

`build_sadoee.py` generates the mod folder from the Party Stash and SadoQoL dev folders; `make_release.py vX` writes the release zips.

## License

MIT. Author: sad0.
