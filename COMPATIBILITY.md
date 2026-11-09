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
Tweaks Anthology, SCS, Tactics Remix, then SadoEE (24 components; the big party was BGEE / EET only until v1.0.5).

**BG2EE + EEex 1.3.1** (2.7.3, v1.0.5 dev): big party (#40) on standalone BG2EE. SoA chapter 1 with 13 members: portrait
bar 7+, combat, a 7+ member's leave dialog, save/load in order. ToB transition not tested yet (same engine sites as EET).

**EET + Infinity UI++ 1.4** (2.7.3, 2026-11-02): EET master, EEex 1.3.1, EET_end, Infinity UI++ 1.4 (core, tooltip
background, strings), then SadoEE from the v1.0.3 dev sources (29 components, 0 errors, 7 minutes). Checked in game:
SadoEE options page (main menu, EEex Options tab, Esc menu button in game; the auto-stash filter: click = next, right
click = off), auto-stash (sword and mace picked up go to the stash; ammo, bag and quest item stay; off = nothing moves),
Party Stash inventory page with its hints, sorted ground pile, camp merchant page, necromancer's bestiary, record
screen, Auto-Roller (28,325 rolls in 10 s, 18/00 kept). Found and fixed on SadoEE's side: a C stack overflow when the
Esc menu button placed itself (its text function re-entered the placement); the camp priestess's GENDER byte (0x275)
stayed male. Small leftover: the inventory page's "Ground" label overlaps its "1/1" counter.

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
| Better item recommender (Person, STATVAL.2DA in override) | Compatible: the "better item" highlight also works for party members 7+ (#40, checked with 30 members on Infinity UI++) |

## Known issues in other mods (not SadoEE)

- **Infinity UI++**: ships a 32x32 icon named `CEFF1INV.BAM`, the game's paper doll of elf female fighters and
  rangers: they have no body in the inventory and on the colour page. SadoEE's recruit component (#15) removes that
  copy so the game's own doll comes back (only when IUI++ is installed before SadoEE).
- **SCS + Infinity UI++**: SCS copies part of `UI.MENU` into `M_DW_OOD.lua`; with Infinity UI++ the copy is broken and the
  game shows a Lua error at launch (`M_DW_OOD.lua:309: unexpected symbol near '}'`).
- **SCS / Tweaks Anthology + Infinity UI++**: the record screen shows class names with their kit tag, e.g. `Fighter{K=0 (0,)`.
- **SCS 4100 + Infinity UI++** (SCS installed after IUI++): SCS's UI patch also matches the `OnOpen` inside IUI++'s
  `rgChooseSpellsMenuOnOpen()` label in the character creation spell menu and cuts it. Checked in game: a blocking
  `Invalid token in menu: [dwOnOpen]` dialog at every launch, and the chargen mage spell list is drawn outside the
  book (still clickable, character creation can go on). Happens with or without SadoEE.
- **SCS 4100** (NPC customization): companions join at level 0 with an "Original class" status until levelled up. This is by design.
- **SCS thief skills rework (BG2EE)**: when a companion made by Faceless (SadoEE camp) levels up, SCS's proficiency
  page can keep its Done greyed (`dw_thief_skills_finished`, `dw_thief_extra` = 40 for a fighter): SCS's thief-skill
  page treats it as a non-chargen level-up. Seen once in the compat test (2026-11-02), not a blocker.

## Not tested yet

- BGEE alone (without EET), and Dragonspear UI++.
- BG1 Unfinished Business (installed on the BGEE side before EET) and Rogue Rebalancing.
- Dialogues and cutscenes that address the whole party, with members 7+.
