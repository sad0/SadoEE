# Camp NPC introductions (design, not built)

John's choices, quiz 2026-10-25. Nothing implemented or installed yet.

## Global rules
- Camp NPCs are ABSENT from the camp until met in the world (except Withers, see below). Camp fills up as you go.
- Missed trigger / late save / other campaign: replacement encounters (see Deckard BG2).

## Grand merchant
- **Superseded 2026-11-02 by "the Grand Merchant's ambush"** (John, via session LoRA - Camp): full design in
  E:/AI/bg3d/docs/QUEST_GRAND_MERCHANT.md. 3 different merchants talked to -> ambush area SQAMBU revealed (map by
  LoRA, modelled on BG4100's caravan); trap scene, merchant kills a bandit, truth through dialogue only; outcomes
  unmasked (hand over / kill / blackmail) / believed (joins camp, betrays later) / killed (younger brother replaces him).
  Scripts, dialogues, creatures, worldmap link: lead. Old notes below kept for history.
- Any merchant (store owner) has a rumour line about him. After the 3rd DIFFERENT merchant, he comes to talk to the party, then asks the party to get back his cart stolen by bandits (Camp v2 mini-quest), then sets up at camp. Works in BG1, SoD, BG2.

## Deckard (scholar)
- BG1 first meeting (chapter 1): petrified next to Branwen at the Nashkel Carnival. The same Stone to Flesh scroll frees both (statues stuck together). He whines about her.
- BG1 later: caged with Dynaheir (Gnoll Stronghold). He finds her unbearable as a cellmate and begs to be freed BEFORE she is (small comic dialogue choice).
- BG2: in the cage next to Minsc in Irenicus's dungeon (AR0602), complains about Minsc and Boo like he did about Dynaheir. Exact cage chosen on site (visit planned in BG2 (test) 2.7.3 with haste + permanent invisibility).
  - Cage picked by John 2026-10-25: **cage B, AR0602 ~(3745,2795)** = the player's cage (small hanging cage, left twin of the one at ~(3802,2765)). Minsc stands at (4029,2759), Jaheira at (3898,2676). Map with candidates A-E: `deckard_cage_ar0602.png` (rendered from AR0602 WED/TIS, world coords in yellow). Coordinates are estimated from the render: check the exact spot in game before building.
  - Freed or not, he shows up again later in the dungeon at Yoshimo's side (Yoshimo's recruitment scene, upper dungeon level, likely AR0603: to check). If left caged, he explains that "a certain necromancer" came by after the party and freed him (ties in with the necromancer tracking the party from the start).
  - Deckard lines: he also complains about how uncomfortable the cage is, slipped into the opening Imoen / PC dialogues.
- Running gag, BG1 + SoD + BG2: at EVERY joinable NPC recruitment scene, even after being met, he pops up physically next to the NPC, slips 1-2 lines into the dialogue, then fades back to camp.
- He can NEVER be silenced.
- **Scope for now (John 2026-11-02)**: only Branwen, Dynaheir, the BG2 opening with the PCs (Imoen...), the
  protagonist's start, and Yoshimo. The other recruitment scenes later.
- Tone: pretentious scholar (corrects the NPC, quotes his books, judges their class) + whining about his cellmates (Dynaheir, Minsc/Boo).

## Priestess (redesigned by John 2026-11-02, supersedes the 30% HP trigger)
- Why she joins the camp: she senses the Bhaal blood and wants to watch over this child of Bhaal (to guide or stop
  them). RP tension.
- Two encounters; whichever happens FIRST is her introduction (the other never fires).
- Keep it simple: a script takes over the scene, 3-4 lines of dialogue at most, no big dialogue tree.

### A. The protagonist dies
- The protagonist never really dies (game over screen must not fire): a hidden min-HP 1 effect on Player1; when he
  reaches 1 HP he falls (unconscious / dead-looking) and the script takes over.
- **Full script (cutscene mode)**: the game controls the party; companions finish the fight in a few seconds with
  maximum damage rolls and critical hits on every hit.
- Companions react with their OWN voice lines (soundset react-to-death slots): nothing to write or translate.
- Fight over: the priestess walks in, raises the protagonist AND every companion who died in this fight, heals all,
  and tells the protagonist it is not his time yet. Then she leaves for the camp.

### B. The child of Bhaal kills an innocent (reputation loss)
- Trigger: reputation drops because the party killed an innocent.
- After the fight: she comes to tell him this is not the path a child of Bhaal should take.
- She raises EVERY creature that died in the area during this incident (innocents, guards, enemies too).
  - Each raised creature gets back the gear that lay on the ground from it (items dropped at death return to it).
  - Every raised creature is pacified (neutral). Attacked again -> it turns hostile again; killing it again costs
    reputation as usual.
  - Guards / townsfolk who turned hostile because of the murder are made neutral again.
- She gives back the reputation lost in this incident.

- Deaths in scene A do NOT count as the necromancer's trigger: he waits for a later companion death (John 2026-11-02).

## Necromancer
- Trigger: first death of a party member. Comes coldly, offers to reanimate any monster the party has defeated as a replacement; asks to meet him at camp later.
- Lore: he has been tracking the party from the start and collects an "imprint" of every creature killed = the existing bestiary (creatures seen dying).
- Comes even if the priestess raises the dead. If both meet: icy exchange, then a rivalry at camp.

## Faceless (Sans-Visage), replaces Withers (respec + recruit), decided 2026-10-31
- Doppelganger who fled the Iron Throne; polite, unsettling, changes voice. Details in SadoQoL/docs/CAMP_V2.md.
- RP: Deckard's old acquaintance, the only one who can stand him.
- Tone: mysterious and calm; speaks little, in riddles, about souls and destinies that can be rewritten.

### Introduction: the nightmare (John's quiz 2026-11-02, supersedes "at camp from the start")
- New games: Faceless is ABSENT from the camp (no respec, no recruit) until the nightmare happened.
  Existing saves where he is already at camp: he stays.
- Condition: Deckard met + at least 2 of the 3 others (priestess, merchant, necromancer).
- Trigger: once the condition is met, each rest at the camp has a 1-in-3 chance to be interrupted by a dream.
  It happens ONCE per playthrough; never again after.
- The dream: every camp NPC the party has already met (Deckard + the 2-3 others) turns hostile and attacks the
  whole party with powerful instant AoE spells. They take damage but are immortal. At half HP each turns into a
  greater doppelganger.
- The party is meant to die: real death screen, the player reloads his last save.
- The dream is remembered OUTSIDE the save (per-playthrough file), so it survives the reload.
- Next visit to the camp after the dream: Deckard tells the protagonist he looks a bit pale, and introduces Faceless
  (free staging). Faceless explains he did it to find out whether someone is brave enough to receive his help.
  From then on Faceless is at the camp with his jobs.

## Build push (John 2026-11-02)
- All 5 introductions go in: merchant (cart), priestess, necromancer, Deckard (limited scope), Faceless (nightmare).
- Order: priestess first (simplest; proves the "absent until met" system), then the others.

## Open
- Exact merchant list / rumour texts, Deckard lines per NPC (big text volume), SoD replacement scenes.

## README section "Camp companions" (John's quiz 2026-11-02)
- Added in ONE go, when all 5 introductions are built (not quest by quest).
- Same section in 3 places: GitHub README (`<details>`), Nexus page (BBCode `[spoiler]`), the HTML readme in the zip.
- Per NPC, two spoiler blocks: 1) **Hint** = an RP riddle, one sentence, in-world tone;
  2) **Solution** = the steps + the exact condition (thresholds: 30% HP, 3 different merchants, 2 of 3 + Deckard,
  1-in-3 per camp rest...) + the reward (what the NPC brings to the camp).
