# SadoEE compatibility

Tested on 2026-10-25 with SadoEE v1.0-dev, on game versions **2.6.6 and 2.7.3**, in English.

## Install order

Install SadoEE **last of all**:

- after every UI mod (LeUI, Infinity UI++, Dragonspear UI++, EEUITweaks): they replace `UI.MENU`, and SadoEE patches the final one;
- on EET, also after **EET_end**, **Tactics Remix** and **SCS's late components** (4100 NPC customization, 4190 Watcher's Keep). SadoEE's big party (#40) extends the scripts it finds to members 7-32, so it must see every other mod's scripts.

## Tested stacks

**EET + LeUI** (EET 14.1 on 2.6.6, EET master on 2.7.3; BGEE side: DLC Merger):
EE Fixpack, EET, EEex 1.3.1, LeUI 4.9.1, Bubb's Spell Menu Extended 5.2, EEUITweaks 4.0.7, BGEE Classic Movies 2.4.1,
BG1 NPC Project 32, Ascension 2.1.0, Unfinished Business 28, Item Revisions v4 beta 10, IWDification 11,
Tweaks Anthology 18, SCS 35.21, Might & Guile 5.9.1, Faiths & Powers 0.92, EET_end, Tactics Remix 8.2, then SadoEE (25 components).

**BG2EE + Infinity UI++ 1.31**: EE Fixpack, EEex, Infinity UI++, Ascension, Unfinished Business, IWDification,
Tweaks Anthology, SCS, Tactics Remix, then SadoEE (24 components; the big party is BGEE / EET only).

Tweaks Anthology and SCS were installed with the components closest to SadoEE's features: bags, stacking, stores,
infinite ammo, identification, resting, death, NPC customization, Spellhold item removal.

## Results

| Feature | Result |
|---|---|
| Installation | All components install on both stacks and both versions. About 12 minutes on the full EET stack. |
| Party Stash, sorted loot | Works with LeUI, Infinity UI++ and EEUITweaks' Better Quick Loot window (the window's own position after closing the inventory: fixed, to recheck in game) |
| Big party (#40) | 16 members in combat with SCS and Tactics Remix (Durlag's Tower demon knight); members 7+ are targeted and fight |
| Rest camp, grand merchant, Old Scholar | Work on EET (stocks include Item Revisions items). A duplicate Old Scholar when the leader was busy is fixed (to recheck). LeUI store: Sell Marked moved under SELL (to recheck). |
| Auto-Roller (#32) | Own layouts for Infinity UI++ (checked) and LeUI (to recheck in game); coexists with EEUITweaks' own auto-roller |
| Stores (Tweaks Anthology changes) | Buying and selling from the stash work |

## Known issues in other mods (not SadoEE)

- **SCS + Infinity UI++**: SCS copies part of `UI.MENU` into `M_DW_OOD.lua`; with Infinity UI++ the copy is broken and the
  game shows a Lua error at launch (`M_DW_OOD.lua:309: unexpected symbol near '}'`).
- **SCS / Tweaks Anthology + Infinity UI++**: the record screen shows class names with their kit tag, e.g. `Fighter{K=0 (0,)`.
- **SCS 4100** (NPC customization): companions join at level 0 with an "Original class" status until levelled up. This is by design.

## Not tested yet

- BGEE alone (without EET), and Dragonspear UI++.
- BG1 Unfinished Business (installed on the BGEE side before EET) and Rogue Rebalancing.
- Dialogues and cutscenes that address the whole party, with members 7+.
