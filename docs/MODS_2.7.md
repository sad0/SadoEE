# Why players stay on 2.6.6: the popular mods on 2.6.6 vs 2.7.3

Study of 2026-10-26 (not a SadoEE component: facts for upstream fixes or a separate helper).
49 mods, each installed **alone** on a clean English copy of BGEE (+SoD) or BG2EE, once on **2.6.6** and once on
**2.7.3** (EEex 1.3.1 only where the mod requires it), every component that applies (one choice per group).
In-game results come from the full compat stacks played on 2.7.3 (see [COMPATIBILITY.md](../COMPATIBILITY.md)).
Tools and raw results: `Environnement de test\Compat\tools\test_mod_27.ps1`, `Compat\mods27\results-*.jsonl`, `mods27\logs`.

## Findings

1. **Installation is not the problem.** All 49 mods give exactly the same WeiDU result on 2.6.6 and 2.7.3
   (same components installed, same skips, same failures). No tp2 refuses 2.7.3 through a version check.
2. **The 2.7 breaker is the UI text function.** Beamdog renamed the UI Lua function `t()` to `getUiString()` in 2.7:
   the vanilla `UI.MENU` of 2.6.6 calls `t()` 235 times and `getUiString()` never; the one of 2.7.3 calls
   `getUiString()` 252 times and `t()` never. A UI mod built from the 2.6 `UI.MENU`, or code inserting `t(...)` into it,
   calls a function that no longer exists: its labels come out empty on 2.7.3.
3. **One installed alias fixes them all.** These restore `t` on 2.7: **EEex 1.3.1** (`EEex_Fix.lua`, both directions),
   **EE Fixpack master** (July 2026; not Beta_2) and **Reveal Hidden Gameplay Options 5.2** (`t = getUiString` in
   util.lua on 2.7). On the 2.7.3 compat stacks (EEex installed), LeUI, EEUITweaks and Infinity UI++ showed their text.
4. **EET needs master on 2.7.** EET 14.1 (the last release) installs on 2.7.3, but its GUI part fails at runtime
   (upstream issue #209, `sodZipLanguages` nil; the campaign selection is the vanilla BG2 one). EET master (2026-06/07
   commits) works: played on 2.7.3 through BG1, SoD and BG2 areas.
5. **EEex supports both** since 1.1.0 (2.7.3.0 build only, not earlier 2.7.x). Mods that require EEex (Bubb's Spell
   Menu Extended, BuffBot, many Tweaks Anthology / Tactics Remix components) install the same on both versions.

So players stay on 2.6.6 mostly because of **UI mods without EEex / EE Fixpack master** (empty labels), **EET 14.1**
(broken GUI on 2.7) and the general advice "2.7 is new, mods are not updated", while in practice the tested gameplay,
NPC, quest and kit mods install and run the same.

## Table

Install = components installed / asked (same on both versions unless noted). "partial" = components skipped by the
mod's own conditions (other game, missing dependency, mutually exclusive choice), identical on 2.6.6 and 2.7.3.
`t()` = mod files calling the old UI function.

| Mod | Version | 2.6.6 install | 2.7.3 install | 2.7.3 at runtime | Cause | Workaround / fix |
|---|---|---|---|---|---|---|
| EET | 14.1 / master | ok | 14.1: installs, GUI fails; master ok | 14.1 broken, master ok | EET_gui on 2.7 (issue #209) | Use EET master |
| EE Fixpack | Beta_2 / master | 2/3 | 2/3 | ok | - | master adds the `t()` alias |
| EEex | 1.3.1 | ok 10/10 | ok 10/10 | ok | - | needs 2.7.3.0 exactly |
| Infinity UI++ | 1.31 | ok 4/4 | ok 4/4 | ok (played) | 2.7 aware | - |
| Infinity UI++ | 1.23 | ok 4/4 | ok 4/4 | empty labels expected | `t()` (3 files) | 1.31, or EEex / EEFP master |
| LeUI (BG2 / BG1 / SoD skins) | 4.9.1 | ok 3/3 | ok 3/3 | ok with EEex (played); empty labels expected without | `t()` | EEex or EEFP master or Hidden Gameplay Options |
| EEUITweaks | 4.0.7 | 32/49 | 32/49 | ok with EEex (played); empty labels expected without | `t()` (70 files) | same as LeUI |
| Dragonspear UI++ | 2.42 | 5/6 | 5/6 | empty labels (upstream issue #3, open) | `t()` (1532 calls) | EEex / EEFP master alias |
| Tipun's GUI | 2.1.2 | ok 2/2 | ok 2/2 | empty labels expected | `t()`, UI.MENU fork | EEex / EEFP master alias |
| Reveal Hidden Gameplay Options | 5.2 | 6/42 | 6/42 | ok | 2.7 aware (adds the alias) | - |
| Bubb's Spell Menu Extended | 5.2 | ok 1/1 | ok 1/1 | ok | needs EEex (which aliases `t`) | - |
| EEex BuffBot | 1.11.0 | ok 2/2 | ok 2/2 | not checked | needs EEex; uses `goto` (LuaJIT, installs EEex's LuaJIT component itself) | - |
| Bubb's Auto Loot | 1.3 | ok 1/1 | ok 1/1 | not checked | - | - |
| Tweaks Anthology | 18 | 156/278 | 156/278 | ok (played) | - | - |
| SCS | 35.21 | 18/18 (stack selection) | 18/18 (stack selection) | ok (played) | - | with Infinity UI++: see note 1 |
| Tactics Remix | 8.2 | 67/85 | 67/85 | ok (played) | - | - |
| Item Revisions | v4 beta 10 | 15/16 | 15/16 | ok (played) | - | - |
| Spell Revisions | 4.21 | ok 8/8 | ok 8/8 | not checked | - | - |
| IWDification | 11 | 19/21 | 19/21 | ok (played) | inserts `t()` in UI.MENU (12) | alias |
| Might & Guile | 5.9.1 | 34/36 | 34/36 | ok (played) | inserts `t()` (2, sequencer menu) | alias |
| Faiths & Powers | 0.92 | timeout (machine load) | 11/14 | ok (played) | inserts `t()` (2) | alias |
| Tome and Blood | 1.4.1 | 17/18 | 17/18 | not checked | inserts `t()` (2) | alias |
| The Artisan's Kitpack | 4.81 | 51/61 | 51/61 | not checked | monk kits need EEex | - |
| Rogue Rebalancing | 4.92 | ok 13/13 | ok 13/13 | not checked | - | - |
| Klatu Tweaks and Fixes | 1.7.4 | 31/43 | 31/43 | not checked | - | - |
| aTweaks (TotoR) | 4.53 | 47/49 | 47/49 | not checked | - | - |
| A7 Golem Construction | 6.4 | ok 10/10 | ok 10/10 | not checked | - | - |
| Ascension | 2.1.0 | ok 18/18 | ok 18/18 | ok (played) | - | - |
| Unfinished Business | 28 | 24/26 | 24/26 | ok (played) | - | - |
| BG1 NPC Project | 32 | 18/19 | 18/19 | ok (played) | - | - |
| BG1 Unfinished Business | 17.1 | 16/35 | 16/35 | not checked | - | - |
| BGEE Classic Movies | 2.4.1 | ok 4/4 | ok 4/4 | ok (played) | - | - |
| Jastey's SoD Tweaks | 13 | 9/10 | 9/10 | not checked | - | - |
| BG1 Romantic Encounters | 16 | 36/45 | 36/45 | not checked | - | - |
| Northern Tales of the Sword Coast | 5.0.0 | ok 14/14 | ok 14/14 | not checked | - | - |
| Thalantyr Item Upgrade | 4.5.1 | ok 1/1 | ok 1/1 | not checked | - | - |
| Ruad Ro'fhessa Item Upgrade | 29.4.0 | ok 2/2 | ok 2/2 | not checked | - | - |
| Stuff of the Magi | 6.0.0 | ok 1/1 | ok 1/1 | not checked | - | - |
| Edwin Romance | 4.0 | ok 5/5 | ok 5/5 | not checked | - | - |
| Imoen Romance | 4.1.3 | ok 2/2 | ok 2/2 | not checked | - | - |
| Yoshimo's Friendship | 5.0 | ok 1/1 | ok 1/1 | not checked | - | - |
| Wheels of Prophecy | 8.5 | ok 1/1 | ok 1/1 | not checked | - | - |
| Sirene (BG2EE) | 2.02 | 2/3 | 2/3 | not checked | an alternate portrait file missing in the archive | packaging, any version |
| Ascalon's Questpack | 7.0 | 1/10 | 1/10 | not checked | German chosen as language 0 by the test | test setup, not version |
| Region of Terror | 5.0 | 0/4 | 0/4 | - | needs AELOTUS.DLG (another mod) | dependency, any version |
| Haldamir | 4 | 0/1 | 0/1 | - | Linux package needs iconv | use the Windows package |
| The Longer Road | 2.0.7 | 0/2 | 0/2 | - | requires Ascension first | dependency, any version |

Note 1: SCS + Infinity UI++ (both versions): SCS copies part of `UI.MENU` into `M_DW_OOD.lua`; with Infinity UI++ the
copy breaks (Lua error at launch). Note 2: "expected" = the mod calls `t()` and nothing restores it; not yet seen in
game on a copy without EEex (the study copies render no picture while in the background; to confirm with a foreground
run).

## What would help players move to 2.7

- A one-line alias shipped by every UI mod (or a tiny "2.7 compat" mod): `if not t and getUiString then t = getUiString end`
  in a Lua file loaded early (the approach of EE Fixpack master and Hidden Gameplay Options).
- An EET release from master (14.2).
- Mod pages stating "2.7.3 OK with EEex 1.3.1 / EE Fixpack master".
