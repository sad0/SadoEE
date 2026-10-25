# SadoEE

Party Stash and SadoQoL in one WeiDU mod for **Baldur's Gate: Enhanced Edition**, **EET** and **Baldur's Gate II: Enhanced Edition** (game versions 2.6.6 and 2.7.3). Every feature is an optional component. Requires [EEex](https://github.com/Bubb13/EEex).

## Components

Full documentation: [docs/README.md](docs/README.md).

| # | Group | Component |
|---|---|---|
| 0-4 | Party Stash | One infinite stash shared by the whole party, on a redesigned inventory page (Baldur's Gate 1 or II look) |
| 1 | Party Stash | Sorted loot: quest items, then weightless items, then the rest by value/weight |
| 5-7 | Party Stash | Options: weightless stash, keep the gold through campaign changes, hardcore |
| 10 | Rest camp | A quiet camp reached from the world map (0 h there and back, rest without ambush) and its priestess: free healing of HP, poison and disease (also while you sleep there), paid resurrection, restoration and curse removal, donations |
| 11 | Rest camp | Grand merchant: sells every item seen at the stores already visited |
| 12 | Rest camp | The Old Scholar: identifies everything |
| 13 | Rest camp | Ex-members can wait for you at the camp |
| 14 | Rest camp | Withers: a lich who fully recreates a party member |
| 15 | Rest camp | Withers can also recruit new members |
| 16 | Rest camp | The Old Scholar's quest chronicle: every quest of the game and how far you are |
| 17 | Rest camp | The necromancer: raises any creature of the game as a target dummy (damage meter), to fight or to recruit |
| 50-53 | Rest camp | Priestess prices for her paid healing: 75 %, 50 %, 25 % or free (default: the game's temple prices) |
| 20-32 | Quality of life | Passive trap detection, valuable containers, automatic disarming, FPS counter, endless ammo, small party footprint, lasting modes, attack-move, mouse buttons, keep gear on death, chests in the ground bar, Auto-Roller |
| 40 | Engine extension | Big party: 7 to 32 members, with working banter and interjections for members 7+ (experimental) |

The rest camp (#10-#17, #50-#53) works on BGEE, EET and BG2EE (on BG2EE in the Helmite Camp); the big party on BGEE and EET.

## Installation

1. Install EEex. **Install SadoEE at the very end, after every other mod** (on EET also after EET_end): see [COMPATIBILITY.md](COMPATIBILITY.md).
   SadoEE reads and patches the scripts and dialogues present in the game at install time: the big party extends every
   script and dialogue (other mods' banters included) to members 7+, and the sorted loot, the Grand merchant, the Codex
   and the quest chronicle index the items, stores and quests of every mod installed before it. A mod installed after
   SadoEE is missed: reinstall SadoEE after it.
2. Coming from Party Stash or SadoQoL: uninstall them first (SadoEE replaces both; saves keep working). No need to empty the Party Stash stash: SadoEE keeps the same stash.
3. Extract the release into the game folder (where chitin.key is) and run `setup-SadoEE.exe`.
4. Start the game with `InfinityLoader.exe`.

Uninstalling SadoEE for good: empty the stash in game first (Ctrl + left click on the big bag next to the weight), otherwise its contents stay in your saves but out of reach.

Readme in 15 languages: `SadoEE/readme/`.

## Building (for the author)

`build_sadoee.py` generates the mod folder from the Party Stash and SadoQoL dev folders; `make_release.py vX` writes the release zips.

## License

MIT. Author: sad0.
