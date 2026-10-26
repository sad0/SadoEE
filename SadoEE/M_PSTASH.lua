-- Party Stash (requires EEex, BGEE or BG2EE v2.7.3.0 or v2.6.6.0): one stash shared by the whole party, Pillars of Eternity style.
-- One source for both games: the generated tables below are BGEE's; PartyStash.tp2 rewrites them at install on
-- the other games (BG2EE, EET) from that game's own files (same format).
-- The stash is the PSTASH bag store, read and written straight through the engine (no bag screen). It is shown
-- next to the inventory screen as a scrollable grid with category tabs. Rules:
--   * everything the party carries + the stash counts against the SUM of the members' weight allowances;
--     over that, the whole party is slowed down;
--   * a member with a full backpack gets one item moved to the stash, so loot never falls on the floor;
--   * a collected bag (gem bag, scroll case...) is emptied into the stash; the items it holds weigh nothing.

PStash = PStash or {}
local P = PStash
P.RES = 'PSTASH'
if P.CARRY == nil then P.CARRY = true end -- John: quests see the stash through the carried bag (tested in game)
P.COLS, P.ROWS = 8, 7
P.tab = P.tab or 1
P.top = P.top or 0
P.view = P.view or {}
P.msg = P.msg or ''

-- UI strings (localization): PStash_Strings comes from M_PSTXT.lua, written by the installer from
-- tra/<language>/ui.tra (lib/strings.tpa); P.EN is the English fallback (a live reload without it, a missing key).
P.EN = {
	tab_all = 'All', tab_weap = 'Weap.', tab_armor = 'Armor', tab_gear = 'Gear', tab_ammo = 'Ammo', tab_gems = 'Gems',
	tab_scroll = 'Scroll', tab_potion = 'Potion', tab_quest = 'Quest', tab_notes = 'Notes', tab_misc = 'Misc', tab_bags = 'Bags',
	sort_prefix = 'Sort: ', sort_auto = 'Auto', sort_dps = 'DPS', sort_level = 'Level', sort_date = 'Date', sort_quality = 'Quality', sort_type = 'Type',
	sort_price = 'Price', sort_gplb = 'Gp/lb',
	store_all = 'Store all', sell_marked = 'Sell Marked', sell_text = 'Sell marked (%d gp)',
	cmp_cursed = 'Cursed', cmp_empty_slot = 'Empty slot', cmp_ac = 'AC ', cmp_saves = 'Saves ',
	cmp_no_skill = 'No weapon skill', cmp_no_weapon = 'No weapon of this kind', cmp_hit = 'To hit ',
	cmp_damage = 'Damage ', cmp_skill = 'Skill: %d',
	weight_tip = "Party + stash weight / sum of the members' weight allowances. Above it, everyone is slowed down. "
		.. 'Stash items held by a collected bag (Bags tab) weigh nothing.',
	helm_hide = 'Hide the helmet', helm_show = 'Show the helmet', ab_level = 'Level %d', msg_cannot_equip = 'This item cannot go there', msg_comp_full = "The companion's backpack is full",
	msg_bag_hint = 'Bag: Shift + double-click or Store all', msg_quest_bags = 'Quest items and bags stay in the backpack',
	msg_quest = 'Quest items stay in the backpack', msg_hand = 'Could not empty the hand',
	msg_bags_kept = 'Bags stay in the collection', msg_bag_contents = 'Bag contents: ',
	msg_restore = 'Stash restore: make room in a backpack',
	bags_warning = 'Warning: your bags will be emptied into the stash, and the matching items will weigh 0.',
	bags_ok = 'OK',
	slot_neck = 'Neck', slot_torso = 'Torso AC', slot_belt = 'Belt', slot_boots = 'Boots', slot_cloak = 'Cloak',
	slot_gloves = 'Gloves', slot_helmet = 'Helmet', slot_ring = 'Ring', slot_shield = 'Shield', slot_ammo = 'Ammo',
	slot_weapon = 'Weapon', slot_offhand = 'Off-hand', slot_bow = 'Bow', slot_xbow = 'Crossbow', slot_sling = 'Sling',
	hp_class = 'Class: %s', hp_con = '%s: %s',
	st_ac = 'AC ', st_hp = 'HP ', st_thac0 = 'THAC0 ', st_damage = 'Damage ',
	ab_ac = 'AC', ab_ac_mods = 'AC mods', ab_missile = 'Missile', ab_prof = 'Prof.', ab_base_thac0 = 'Base THAC0',
	ab_main_hand = 'Main', ab_off_hand = 'Off', ab_two_weapon = '2 weapons',
	stash_slot_tip = 'Your party\'s stash: the game counts its items as carried (quests).',
	dps_line = '%s dmg/round, THAC0 %d', st_apr = 'Attacks/round: %s',
	msg_valuable_ground = 'A valuable item cannot be dropped on the ground',
	dump_armed = 'Open the container that should receive the items (Esc cancels)',
	dump_confirm = 'Put into this container: the backpack (%d items) or this stash page (%d items)?',
	dump_done = '%d items put in the container', dump_none = 'Nothing to put away', dump_cancel = 'Put away cancelled',
	dump_backpack = 'Backpack', dump_stashpage = 'Stash page',
	container_tip = 'Put the backpack or the last stash page shown into this container (not the valuable or quest items)',
	help_stash_title = 'This is your stash',
	help_stash = 'Click: take an item (double-click: take and equip)\nCtrl + click: mark it for sale (Sell Marked at a merchant)\nAlt + click: valuable (golden, never sold)\n'
		.. 'Right-click: description. Mouse wheel: scroll\n*Tabs: filter the stash by category (wheel or arrows to see them all)\n'
		.. '*Weapons: damage per round in the tooltip',
	help_pack_title = "This is your character's inventory (the 2 top rows)",
	help_pack = 'Shift + double-click, or drag onto the stash: store an item\nSpace or Store all: store the whole backpack\n'
		.. '*The chest in the last slot: your stash; the game counts its items as carried (quests).\n'
		.. 'Ctrl + click: mark for sale (it goes to the stash)\nAlt + click: valuable (golden, never sold)',
	help_storeall = 'Space: store the whole backpack.\nQuest items stay in the backpack; bags ask first.',
	help_sort = 'Click: change the sort\nRight-click: reverse it\n*Auto: each tab its own order (weapons by damage '
		.. 'per round for the shown character, armor by AC, scrolls by class and level...).\n*Also: Date, Quality, Type, Price, '
		.. 'Value/weight.', sort_rev = ' (rev.)',
	help_bags = 'Store a bag (Shift + double-click or Store all): it is emptied into the stash and kept here.\n'
		.. 'Stash items it can hold weigh nothing.',
	help_sell = '%d marked items will be sold for %d gp.\n%d marked items are skipped (no value, quest item, or not '
		.. 'bought here).',
	empty_confirm = 'Empty the stash? Your collected bags come back filled with the items they can hold; '
		.. 'everything else drops on the ground. Do this before uninstalling Party Stash.',
	bag_tip = 'Ctrl + left click: empty the stash into your bags and onto the ground (before uninstalling)\nRight click: '
		.. 'put the backpack or this stash page (not the valuable or quest items) into the next container you open\n'
		.. '*Container panel: the red button at the bottom right does the same',
	help_btn_tip = 'Help: what Party Stash adds to this page', bubble_weight_t = 'Weight bag', bubble_tabs_t = 'Tabs',
	bubble_tabs = 'Filter the stash by category\nWheel or arrows: see all the tabs\n*Bags: your collected bags; the stash '
		.. 'items they can hold weigh nothing',
	bubble_sort_t = 'Sort', bubble_ground_t = 'Ground',
	bubble_ground = 'Items on the ground around the party\nDrag: put items down or pick them up\nValuable items cannot be '
		.. 'dropped here',
	bubble_close = 'Click anywhere to close',
}
-- A line starting with '*' is a label, not a keybind ("*Tabs: ..."): greenKeys colours it gold instead of green
-- (John: green is for keybinds only). TRaw keeps the marks for greenKeys; T drops them.
local function TRaw(k)
	local s = (PStash_Strings and PStash_Strings[k]) or P.EN[k] or k
	return (string.gsub(s, '\\n', '\n')) -- tra texts write a line break as \n
end
function PStash_T(k, ...)
	local s = string.gsub(string.gsub(TRaw(k), '^%*', ''), '\n%*', '\n')
	if select('#', ...) > 0 then return string.format(s, ...) end
	return s
end
local T = PStash_T

-- class line of the inventory page, without the {K=..,C=..} tags that SCS / Tweaks Anthology add to class names
function PStash_ClassText()
	local s = characters and characters[id] and characters[id].class
	if type(s) ~= 'string' then return s end
	return (string.gsub(s, '{[^}]*}', ''))
end

-- Quest items NPCs look for in the backpack: never moved to the stash automatically.
-- KEEP:BEGIN (generated by build_keep.py: BGBot KEEP_OUT_OF_BAGS + data/quest_items_keep.json)
P.KEEP = {
	AMUL11 = true, AMUL13CO = true, BOOK03 = true, BOOK04 = true, BOOK05 = true, BOOK06 = true, BOOK07 = true,
	BOOK08 = true, BOOK16 = true, BOOK40 = true, BOOT02ZH = true, BOOT06 = true, CLCK22 = true, DAGG06 = true,
	DAGG07 = true, DAGG10 = true, MISC1A = true, MISC1H = true, MISC1J = true, MISC2A = true, MISC2B = true,
	MISC2C = true, MISC2D = true, MISC2E = true, MISC2F = true, MISC2G = true, MISC2H = true, MISC2I = true,
	MISC2J = true, MISC2K = true, MISC2L = true, MISC2M = true, MISC2N = true, MISC2O = true, MISC43 = true,
	MISC50 = true, MISC53 = true, MISC54 = true, MISC60 = true, MISC61 = true, MISC62 = true, MISC67 = true,
	MISC85 = true, MISC86 = true, MISC91 = true, MISC92 = true, MISC93 = true, MISC94 = true, MISC95 = true,
	RING19MA = true, RINGJOIA = true, RINGJOS = true, SCRL3C = true, SCRL3I = true, SCRLPET = true, SW1H17 = true,
	ULBOOK54 = true,
}
-- KEEP:END

-- QUEST:BEGIN (generated by build_quest.py: items a BG1 / SoD / BG2 dialog or script checks or takes)
P.QUEST = {
	BAZPLO01 = true, BAZPLO02 = true, BAZPLO05 = true, BAZPLO06 = true, BAZPLO08 = true, BDBCASE = true,
	BDBELLAD = true, BDBODY01 = true, BDBODY02 = true, BDBODY03 = true, BDBODY04 = true, BDBONE01 = true,
	BDBOOKNJ = true, BDBRD03 = true, BDBWOOSH = true, BDCHICKN = true, BDEGG01 = true, BDFEATH = true, BDJUICE = true,
	BDKEY02 = true, BDKEY03 = true, BDKEY04 = true, BDKEY05 = true, BDKEY06 = true, BDKEY10 = true, BDKEY11 = true,
	BDKEY12 = true, BDKEY14 = true, BDLIQUOR = true, BDMIRR01 = true, BDMISC04 = true, BDMISC06 = true, BDMISC08 = true,
	BDMISC11 = true, BDMISC12 = true, BDMISC13 = true, BDMISC14 = true, BDMISC15 = true, BDMISC16 = true,
	BDMISC18 = true, BDMISC19 = true, BDMISC20 = true, BDMISC21 = true, BDMISC22 = true, BDMISC23 = true,
	BDMISC24 = true, BDMISC25 = true, BDMISC26 = true, BDMISC27 = true, BDMISC28 = true, BDMISC29 = true,
	BDMISC31 = true, BDMISC33 = true, BDMISC34 = true, BDMISC40 = true, BDMISC41 = true, BDMISC44 = true,
	BDMISC48 = true, BDMISC50 = true, BDMISC51 = true, BDMISC52 = true, BDMISC55 = true, BDMISC56 = true,
	BDMISC57 = true, BDMISC59 = true, BDMISC60 = true, BDMISC66 = true, BDNEO1 = true, BDNEO2 = true, BDNEO3 = true,
	BDPOTN07 = true, BDSCALEG = true, BDSCRL01 = true, BDSCRL3A = true, BDSCRL3B = true, BDSHACKL = true,
	BDSHBHR = true, BDSHPAM1 = true, BDSHPAM2 = true, BDSHSARE = true, BDSHSTF2 = true, BDSILK01 = true,
	BDSPECTQ = true, BDSPIDER = true, BDSTAKE = true, BDSUPPLY = true, BDTINDER = true, BDTORCB = true, BDTORCP = true,
	BDTORCR = true, BDTORCY = true, BDYMORI = true, BLUN14A = true, BLUN14B = true, BLUN14C = true, BLUN30A = true,
	BLUN30B = true, BOOK16 = true, BOOK36 = true, BOOK40 = true, BOOK55 = true, BOOK59 = true, BOOK68 = true,
	BOOK70 = true, BOOK87 = true, BOOK89 = true, BOOK92 = true, BOOK94 = true, BOOK98 = true, BOW19A = true,
	BOW19B = true, C6LANTHO = true, C6LENS = true, COMPON01 = true, COMPON02 = true, COMPON03 = true, COMPON04 = true,
	COMPON06 = true, COMPON07 = true, COMPON08 = true, COMPON10 = true, COMPON12 = true, COMPON13 = true,
	COMPON14 = true, COMPON15 = true, COMPON18 = true, COMPON19 = true, DECK = true, DNNOTE = true, DWDUST = true,
	EDWINKEY = true, GBERRY = true, GLOBBLU1 = true, GLOBBLU2 = true, GLOBBLU3 = true, GLOBBLU4 = true, GLOBGRE1 = true,
	GLOBGRE2 = true, GLOBGRE3 = true, GLOBGRE4 = true, GLOBPUR1 = true, GLOBPUR2 = true, GLOBPUR3 = true,
	GLOBPUR4 = true, GLOBRED1 = true, GLOBRED2 = true, GLOBRED3 = true, GLOBRED4 = true, GOLIRO = true, HALB09A = true,
	HALB09B = true, HGHEART = true, HGHEART2 = true, HGWARD01 = true, HGWARD02 = true, HGWARD03 = true, HGWARD04 = true,
	KEY03 = true, KEY04 = true, KEY05 = true, KEY06 = true, KEY09 = true, KEY10 = true, KEY11 = true, KEY14 = true,
	KEY15 = true, KEY16 = true, KEY17 = true, KEY18 = true, KEY19 = true, KEY24 = true, KEY25 = true, KEY26 = true,
	KEY28 = true, MISC01 = true, MISC04 = true, MISC13 = true, MISC1A = true, MISC1C = true, MISC1E = true,
	MISC1F = true, MISC1G = true, MISC1H = true, MISC1I = true, MISC1J = true, MISC2O = true, MISC3I = true,
	MISC3J = true, MISC47 = true, MISC48 = true, MISC49 = true, MISC4A = true, MISC4B = true, MISC4C = true,
	MISC4D = true, MISC4E = true, MISC4G = true, MISC4H = true, MISC4I = true, MISC4J = true, MISC4K = true,
	MISC4L = true, MISC4M = true, MISC4N = true, MISC4R = true, MISC4S = true, MISC4T = true, MISC4V = true,
	MISC4W = true, MISC4X = true, MISC4Z = true, MISC50 = true, MISC51 = true, MISC52 = true, MISC53 = true,
	MISC54 = true, MISC55 = true, MISC5A = true, MISC5B = true, MISC5D = true, MISC5F = true, MISC5G = true,
	MISC5H = true, MISC5I = true, MISC5J = true, MISC5K = true, MISC5L = true, MISC5M = true, MISC5N = true,
	MISC5O = true, MISC5P = true, MISC5Q = true, MISC5S = true, MISC5U = true, MISC5V = true, MISC5Z = true,
	MISC60 = true, MISC62 = true, MISC63 = true, MISC64 = true, MISC65 = true, MISC67 = true, MISC68 = true,
	MISC69 = true, MISC6A = true, MISC6B = true, MISC6C = true, MISC6D = true, MISC6E = true, MISC6H = true,
	MISC6I = true, MISC6J = true, MISC6K = true, MISC6M = true, MISC6P = true, MISC6Q = true, MISC6S = true,
	MISC6V = true, MISC6W = true, MISC6X = true, MISC6Y = true, MISC70 = true, MISC71 = true, MISC73 = true,
	MISC78 = true, MISC79 = true, MISC7D = true, MISC7F = true, MISC7L = true, MISC7M = true, MISC7Q = true,
	MISC7S = true, MISC7U = true, MISC7V = true, MISC7X = true, MISC7Z = true, MISC80 = true, MISC81 = true,
	MISC82 = true, MISC83 = true, MISC85 = true, MISC86 = true, MISC8F = true, MISC8H = true, MISC8K = true,
	MISC8N = true, MISC8P = true, MISC8Q = true, MISC8R = true, MISC8S = true, MISC8T = true, MISC8U = true,
	MISC8V = true, MISC8W = true, MISC8X = true, MISC8Y = true, MISC8Z = true, MISC90 = true, MISC91 = true,
	MISC92 = true, MISC94 = true, MISC95 = true, MISC96 = true, MISC97 = true, MISC9A = true, MISC9D = true,
	MISC9E = true, MISC9F = true, MISC9G = true, MISC9H = true, MISC9L = true, MISC9M = true, MISC9R = true,
	MISC9T = true, MISC9U = true, MISC9V = true, MISC9Z = true, MISCA2 = true, MISCA3 = true, MISCA4 = true,
	MISCA7 = true, MISCA8 = true, MISCAB = true, MISCAC = true, MISCAF = true, MISCAG = true, MISCAH = true,
	MISCAJ = true, MISCAL = true, MISCAS = true, MISCAU = true, MISCAW = true, MISCAY = true, MISCAZ = true,
	MISCB2 = true, MISCB3 = true, MISCB4 = true, MISCB5 = true, MISCB6 = true, MISCB7 = true, MISCB8 = true,
	MISCB9 = true, MISCBE = true, MISCBF = true, MISCBG = true, MISCBI = true, MISCBJ = true, MISCBK = true,
	MISCBL = true, MISCBM = true, MISCBN = true, MISCBO = true, MISCBP = true, MISCBR = true, MISCBS = true,
	MISCBT = true, MISCBU = true, MISCBV = true, MISCCB = true, OHBBOOK2 = true, OHBBOOK6 = true, OHBCOM01 = true,
	OHBCOM02 = true, OHBCOM03 = true, OHBCOM04 = true, OHBCOM05 = true, OHBCOM06 = true, OHBCOM07 = true,
	OHBCOM08 = true, OHBCOM09 = true, OHBCOM10 = true, OHBCOM12 = true, OHBGOL01 = true, OHBKEY01 = true,
	OHBKEY02 = true, OHBKEY03 = true, OHBPTN02 = true, OHDACORN = true, OHDAPPLE = true, OHDINK = true, OHDSCALE = true,
	OHDSUMS1 = true, OHDSUMS2 = true, OHDSUMS3 = true, OHHBOOK = true, OHHCASK2 = true, OHHCASQ = true, OHHCLAW = true,
	OHHKEY = true, OHHOIL = true, OHHONKEY = true, OHHPRISN = true, OHHROD = true, OHHSHROU = true, OHHSILK = true,
	OHHSTAT1 = true, OHHSTATU = true, OHNCASK = true, OHNCAT = true, OHNDINGS = true, OHNFOOD = true, OHNHAIRB = true,
	OHNHTUNI = true, OHNKEY02 = true, OHNMBIRD = true, OHNNOTE1 = true, OHNNOTE4 = true, OHRGROG = true,
	OHRKEY02 = true, OHRNOT01 = true, OHRNOT02 = true, OHRNOT03 = true, OHRROPE1 = true, OHRSALT = true,
	OHRWHEEL = true, PLOT01B = true, PLOT01F = true, PLOT01G = true, PLOT01H = true, PLOT01J = true, PLOT01K = true,
	PLOT01L = true, PLOT02I = true, PLOT02J = true, PLOT03E = true, PLOT04A = true, PLOT04B = true, PLOT04C = true,
	PLOT04D = true, PLOT04F = true, PLOT04G = true, PLOT04H = true, PLOT05A = true, PLOT05B = true, PLOT05C = true,
	PLOT05D = true, PLOT17A = true, PLOT18A = true, PLOT18B = true, POTN53 = true, RSNOTE1 = true, RSNOTE2 = true,
	RSNOTE3 = true, SARBONE = true, SARSKUL = true, SCALEB = true, SCALER = true, SCRL2J = true, SCRL2K = true,
	SCRL2O = true, SCRL2P = true, SCRL2Q = true, SCRL2V = true, SCRL2W = true, SCRL2X = true, SCRL2Z = true,
	SCRL3A = true, SCRL3C = true, SCRL3F = true, SCRL3I = true, SCRLAG = true, SCRLJALA = true, SCRLMZ = true,
	SW1H54A = true, SW1H54B = true, SW2H15A = true, TOME01 = true, TOME02 = true, TOME02A = true, TOME03 = true,
	TOME03A = true, TOME04A = true, TTKEY01 = true, ULBOOK54 = true,
}
-- QUEST:END

-- BAGS:BEGIN (generated by build_bags.py: every bag item of the game)
P.BAG_RES = {
	'BAG02', 'BAG02G', 'BAG02H', 'BAG02I', 'BAG03', 'BAG03G', 'BAG03H', 'BAG03I', 'BAG03J', 'BAG05', 'BAG06',
	'BAG06B', 'BAG06C', 'BAG06D', 'BAG19', 'BAG19A', 'BAG19B', 'BAG19C', 'BAG19D', 'BAG19E', 'BAG20', 'BAG21',
	'BAG22', 'BAG23', 'BAG24', 'BAG25', 'BAG26', 'BAG27', 'BAG28', 'BAG29', 'BAG30', 'BAG31', 'BDKEYR',
}
-- BAGS:END

-- STORES:BEGIN (generated by build_stores.py)
P.STORE_TYPES = {
	{ [0] = true, [1] = true, [2] = true, [3] = true, [4] = true, [5] = true, [6] = true, [7] = true, [8] = true, [9] = true, [10] = true, [11] = true, [12] = true, [13] = true, [14] = true, [15] = true, [16] = true, [17] = true, [18] = true, [19] = true, [20] = true, [21] = true, [22] = true, [23] = true, [24] = true, [25] = true, [26] = true, [27] = true, [28] = true, [29] = true, [30] = true, [31] = true, [32] = true, [33] = true, [34] = true, [35] = true, [36] = true, [37] = true, [39] = true, [47] = true, [50] = true, [53] = true, [54] = true, [55] = true, [56] = true, [58] = true, [72] = true },
	{ [0] = true, [1] = true, [2] = true, [3] = true, [4] = true, [5] = true, [6] = true, [7] = true, [8] = true, [9] = true, [10] = true, [11] = true, [12] = true, [13] = true, [14] = true, [15] = true, [16] = true, [17] = true, [18] = true, [19] = true, [20] = true, [21] = true, [22] = true, [23] = true, [24] = true, [25] = true, [26] = true, [27] = true, [28] = true, [29] = true, [30] = true, [31] = true, [32] = true, [33] = true, [34] = true, [35] = true, [36] = true, [37] = true, [39] = true, [50] = true, [54] = true, [55] = true, [56] = true, [58] = true, [72] = true },
	{ [0] = true, [1] = true, [2] = true, [3] = true, [4] = true, [5] = true, [6] = true, [7] = true, [8] = true, [9] = true, [10] = true, [11] = true, [12] = true, [13] = true, [14] = true, [15] = true, [16] = true, [17] = true, [18] = true, [19] = true, [20] = true, [21] = true, [22] = true, [23] = true, [24] = true, [25] = true, [26] = true, [27] = true, [28] = true, [29] = true, [30] = true, [31] = true, [32] = true, [33] = true, [34] = true, [35] = true, [36] = true, [37] = true, [72] = true },
	{ [0] = true, [1] = true, [2] = true, [3] = true, [4] = true, [5] = true, [6] = true, [7] = true, [8] = true, [9] = true, [10] = true, [11] = true, [12] = true, [13] = true, [14] = true, [15] = true, [16] = true, [17] = true, [18] = true, [19] = true, [20] = true, [21] = true, [22] = true, [23] = true, [24] = true, [25] = true, [26] = true, [27] = true, [28] = true, [29] = true, [30] = true, [31] = true, [32] = true, [33] = true, [34] = true, [35] = true, [37] = true, [38] = true, [39] = true, [40] = true, [41] = true, [42] = true, [43] = true, [44] = true, [45] = true, [46] = true, [47] = true, [48] = true, [49] = true, [50] = true, [51] = true, [52] = true, [53] = true, [54] = true, [55] = true, [56] = true, [57] = true, [58] = true, [59] = true, [60] = true, [61] = true, [62] = true, [63] = true, [64] = true, [65] = true, [66] = true, [67] = true, [68] = true, [69] = true, [70] = true, [71] = true, [72] = true, [73] = true },
	{ [0] = true, [39] = true },
	{ [1] = true, [10] = true, [34] = true },
	{ [5] = true, [14] = true, [24] = true, [31] = true },
	{ [8] = true },
	{ [9] = true },
	{ [11] = true, [37] = true },
}
P.STORES = { -- [name strref] = { buy %, P.STORE_TYPES index }
	[9432] = { 50, 2 }, [10235] = { 50, 2 }, [11669] = { 50, 2 }, [11676] = { 50, 2 }, [11680] = { 50, 2 },
	[11684] = { 50, 2 }, [11685] = { 50, 2 }, [11687] = { 50, 1 }, [11688] = { 50, 1 }, [11691] = { 50, 1 },
	[11782] = { 50, 1 }, [11818] = { 50, 1 }, [11837] = { 100, 5 }, [12706] = { 50, 1 }, [13700] = { 50, 1 },
	[20639] = { 50, 1 }, [23501] = { 50, 2 }, [24096] = { 50, 1 }, [25502] = { 0, 6 }, [25505] = { 0, 10 },
	[25508] = { 0, 9 }, [29087] = { 30, 2 }, [29088] = { 30, 2 }, [29089] = { 30, 2 }, [29090] = { 30, 2 },
	[29091] = { 30, 2 }, [29092] = { 30, 2 }, [29093] = { 30, 2 }, [29094] = { 30, 2 }, [29136] = { 30, 2 },
	[29137] = { 30, 2 }, [31234] = { 0, 7 }, [32727] = { 0, 3 }, [45188] = { 30, 2 }, [45474] = { 55, 2 },
	[49454] = { 50, 2 }, [55813] = { 30, 2 }, [56711] = { 30, 2 }, [60299] = { 30, 3 }, [62499] = { 80, 2 },
	[62637] = { 50, 2 }, [65747] = { 50, 2 }, [69343] = { 50, 2 }, [69413] = { 0, 8 }, [70071] = { 50, 2 },
	[71099] = { 55, 2 }, [71100] = { 60, 2 }, [71727] = { 0, 4 },
}
-- STORES:END

-- The bot pushes its own list at start (and whenever it grows): PStash_AddKeep({'RES', ...}); PStash_SetKeep replaces it.
-- The bot's own keep list (ammo for the quivers, tomes...): only the bot's storing (PStash_StoreAllParty,
-- PStash_AutoStoreAll) honours it. P.KEEP above stays the quest list (Quest tab, never stored by hand).
P.BOT_KEEP = P.BOT_KEEP or {}
function PStash_SetKeep(list)
	P.BOT_KEEP = {}
	for _, r in ipairs(list or {}) do P.BOT_KEEP[string.upper(r)] = true end
	return true
end
function PStash_AddKeep(list)
	for _, r in ipairs(list or {}) do P.BOT_KEEP[string.upper(r)] = true end
	return true
end
local function botKeep(res) return P.KEEP[res] or P.BOT_KEEP[res] end

-- Collected bags (John): a bag put in the stash is consumed: emptied into it and kept as a count (global
-- PSTB_<res>), shown in the Bags tab, never taken back. Stash items of a type a collected bag holds weigh nothing; the others weigh again.
local function bagCount(res) return EEex_GameState_GetGlobalInt('PSTB_' .. res) end
local function setBagCount(res, n)
	EEex_GameState_SetGlobalInt('PSTB_' .. res, math.max(0, n))
	P.covered = nil
end

-- Bags the install-time list (P.BAG_RES) does not know: a mod installed after this one added them (issue #2: Tweaks
-- Anthology bags, an NPC mod's gem bag). Collecting one records it in the save, string globals PSTBX_1..PSTBX_<n>
-- (count PSTBX_N), and bagList() merges them in, so they stay in the Bags tab after a reload too.
-- Each one is also kept as two integer globals PSTBX_<n>A / PSTBX_<n>B (4 letters each): integer globals are always
-- saved, the string ones were not checked in a save yet. Same globals as Party Stash v1.2.2: its saves move here.
local function packRes(res, from)
	local v = 0
	for k = from + 3, from, -1 do v = v * 256 + (string.byte(res, k) or 0) end
	return v
end
local function unpackRes(v)
	local out = {}
	for _ = 1, 4 do
		local c = v % 256
		if c > 0 then out[#out + 1] = string.char(c) end
		v = math.floor(v / 256)
	end
	return table.concat(out)
end
local function knownBag(res)
	for _, r in ipairs(P.BAG_RES or {}) do if r == res then return true end end
	return false
end
local function bagList()
	P.BAG_RES = P.BAG_RES or {}
	for i = 1, EEex_GameState_GetGlobalInt('PSTBX_N') do
		local r = string.upper(EEex_GameState_GetGlobalString('PSTBX_' .. i) or '')
		if r == '' then
			r = unpackRes(EEex_GameState_GetGlobalInt('PSTBX_' .. i .. 'A')) .. unpackRes(EEex_GameState_GetGlobalInt('PSTBX_' .. i .. 'B'))
		end
		if r ~= '' and not knownBag(r) then P.BAG_RES[#P.BAG_RES + 1] = r end
	end
	return P.BAG_RES
end
local function recordBag(res)
	bagList()
	if knownBag(res) then return end
	local n = EEex_GameState_GetGlobalInt('PSTBX_N') + 1
	EEex_GameState_SetGlobalString('PSTBX_' .. n, res)
	EEex_GameState_SetGlobalInt('PSTBX_' .. n .. 'A', packRes(res, 1))
	EEex_GameState_SetGlobalInt('PSTBX_' .. n .. 'B', packRes(res, 5))
	EEex_GameState_SetGlobalInt('PSTBX_N', n)
	P.BAG_RES[#P.BAG_RES + 1] = res
end

-- Item types a bag holds: its store's purchase list (STO 0x2C/0x30); a bag of holding (30+ types) holds all.
P.bagTypesCache = P.bagTypesCache or {}
local function bagTypes(res)
	local c = P.bagTypesCache[res]
	if c then return c end
	c = {}
	pcall(function()
		local h = EEex_Resource_Demand(res, 'STO')
		if not h then return end
		-- the resource points past the 8-byte "STORV1.0" signature: file offsets are base + offset
		local base = EEex_UDToPtr(h) - 8
		local off, n = EEex_ReadU32(base + 0x2C), EEex_ReadU32(base + 0x30)
		if n >= 30 then c.all = true return end
		for i = 0, n - 1 do c[EEex_ReadU32(base + off + i * 4)] = true end
	end)
	P.bagTypesCache[res] = c
	return c
end

-- Union of the types held by the collected bags. Not cached: the counts are game globals, a loaded save changes
-- them behind our back (a cache kept the reduction after loading a save without the bags).
local function coveredTypes()
	local cov = {}
	for _, res in ipairs(bagList()) do
		if bagCount(res) > 0 then
			for t in pairs(bagTypes(res)) do cov[t] = true end
		end
	end
	P.covered = cov
	return cov
end

-- Tabs: item type codes (ITM 0x1C). Every tab is always open (John 2026-10-19: no bag needed for Gems/Scroll/Potion).
local function set(...) local s = {} for _, v in ipairs({ ... }) do s[v] = true end return s end
P.TABS = {
	{ label = 'All', key = 'tab_all' },
	{ label = 'Weap.', key = 'tab_weap', types = set(15, 16, 17, 18, 19, 20, 21, 22, 23, 25, 26, 27, 28, 29, 30, 44, 57, 69) },
	-- John: body armor + shields / the rest of the worn gear (+ magical rings and amulets, see tabOf)
	{ label = 'Armor', key = 'tab_armor', types = set(2, 12, 41, 47, 49, 53, 60, 61, 62, 63, 64, 65, 66, 67) },
	{ label = 'Gear', key = 'tab_gear', types = set(3, 4, 6, 7, 32, 72, 73) },
	{ label = 'Ammo', key = 'tab_ammo', types = set(5, 14, 24, 31) },
	{ label = 'Gems', key = 'tab_gems', types = set(1, 10, 34) },
	{ label = 'Scroll', key = 'tab_scroll', types = set(11) },
	{ label = 'Potion', key = 'tab_potion', types = set(9) },
	{ label = 'Quest', key = 'tab_quest', quest = true }, -- quest items: critical, the keep list, P.QUEST
	{ label = 'Notes', key = 'tab_notes' },              -- what a scroll case takes but cannot be cast (John 2026-10-22)
	{ label = 'Misc', key = 'tab_misc' },                -- everything no other tab takes (letters, cursed scrolls...)
	{ label = 'Bags', key = 'tab_bags', bags = true },   -- the collected bags (not stash entries)
}
P.TAB_VIS = 7 -- John: 7 tabs spread over the grid (the offset to the columns looks better)
P.tabTop = P.tabTop or 0

-- Only a bag with its own store can be collected (BG2's TBAG01 wolf pelt is a type-36 item without one).
P.bagStore = P.bagStore or {}
local function hasStore(res)
	if P.bagStore[res] == nil then
		local ok, h = pcall(EEex_Resource_Demand, res, 'STO')
		P.bagStore[res] = ok and h ~= nil
	end
	return P.bagStore[res]
end

-----------------------
-- Engine functions  --
-----------------------

-- The engine's own bag functions (CInfGame::AddItemToStore and friends), called through fixed-target stubs.
-- Each stub is a tiny lua_CFunction wired to ONE whitelisted function of a known build (prologue bytes checked
-- first; on any other build the mod switches itself off). Integer/pointer args only (Win64 ABI). BGEE and BG2EE
-- share the same code on each build (2.7.3.0: .text differs by 32 bytes, checked 2026-10-19): same addresses.
-- Addresses from EEex's loader/<build>/<game>/function_names.db (2026-10-21: same prologues on both builds).
-- SwapItemPersonal is CInfGame::SwapItemPersonalInventory.
local PROLOGUE = {
	AddItemToStore = { { 0x40, 0x55, 0x53, 0x56, 0x57, 0x41, 0x54 }, 4 },
	SwapItemPersonal = { { 0x40, 0x55, 0x53, 0x56, 0x57, 0x41, 0x54 }, 9 },
	AddDisposableItem = { { 0x48, 0x85, 0xD2, 0x74, 0x0C }, 2 },
	DemandServerStore = { { 0x48, 0x89, 0x5C, 0x24, 0x10 }, 3 },
	GetServerStore = { { 0x32, 0xC0 }, 2 },
	ReleaseServerStore = { { 0x48, 0x83, 0xEC, 0x28 }, 2 },
	TakeItemFromStore = { { 0x48, 0x89, 0x5C, 0x24, 0x20, 0x55, 0x56, 0x57 }, 4 },
}
-- probe: CInfGame::AddPartyGold, whose rip-relative load (bytes 13-19) tells the builds apart.
P.BUILDS = {
	['2.7.3.0'] = {
		probe = { 0x14026DAC0, { 0x85, 0xD2, 0x0F, 0x84, 0x88, 0x00, 0x00, 0x00, 0x53, 0x48, 0x83, 0xEC, 0x20, 0x48, 0x8B, 0x05, 0x8C, 0x9A, 0x3F, 0x00 } },
		AddItemToStore = 0x14026D680, SwapItemPersonal = 0x1402913C0, AddDisposableItem = 0x14026D660,
		DemandServerStore = 0x1402728F0, GetServerStore = 0x140278F00, ReleaseServerStore = 0x140285C60,
		TakeItemFromStore = 0x140292B00 },
	['2.6.6.0'] = {
		probe = { 0x14026D860, { 0x85, 0xD2, 0x0F, 0x84, 0x88, 0x00, 0x00, 0x00, 0x53, 0x48, 0x83, 0xEC, 0x20, 0x48, 0x8B, 0x05, 0x24, 0x78, 0x3F, 0x00 } },
		AddItemToStore = 0x14026D420, SwapItemPersonal = 0x140290E00, AddDisposableItem = 0x14026D400,
		DemandServerStore = 0x140272680, GetServerStore = 0x140278A70, ReleaseServerStore = 0x140285760,
		TakeItemFromStore = 0x140292480 },
}

local function bytesAt(addr, bytes)
	for i, b in ipairs(bytes) do
		if EEex_ReadU8(addr + i - 1) ~= b then return false end
	end
	return true
end

-- The running build's functions as { name = { address, prologue, nargs } }, or nil on an unknown build.
local function engineFuncs()
	for build, t in pairs(P.BUILDS) do
		if bytesAt(t.probe[1], t.probe[2]) then
			local out = {}
			for name, pro in pairs(PROLOGUE) do
				if not bytesAt(t[name], pro[1]) then return nil end
				out[name] = { t[name], pro[1], pro[2] }
			end
			P.build = build
			return out
		end
	end
end

local function bytesLE(v, n)
	local out = {}
	for i = 1, n do out[i] = v % 256 v = math.floor(v / 256) end
	return table.unpack(out)
end

local function buildStub(name, target, nargs)
	local toint, pushint = EEex_Label('Hardcoded_lua_tointegerx'), EEex_Label('Hardcoded_lua_pushinteger')
	local code = {}
	local function emit(...) for _, b in ipairs({ ... }) do code[#code + 1] = b end end
	local function slot(i) return 0x50 + 8 * (i - 1) end
	emit(0x53, 0x56, 0x57)
	emit(0x48, 0x81, 0xEC, bytesLE(0xA0, 4))
	emit(0x48, 0x89, 0xCB)
	for i = 1, nargs do
		emit(0x48, 0x89, 0xD9)
		emit(0xBA, bytesLE(i, 4))
		emit(0x45, 0x31, 0xC0)
		emit(0x48, 0xB8, bytesLE(toint, 8))
		emit(0xFF, 0xD0)
		emit(0x48, 0x89, 0x84, 0x24, bytesLE(slot(i), 4))
	end
	for k = 0, nargs - 5 do
		emit(0x48, 0x8B, 0x84, 0x24, bytesLE(slot(5 + k), 4))
		emit(0x48, 0x89, 0x44, 0x24, 0x20 + 8 * k)
	end
	local regs = { { 0x48, 0x8B, 0x8C }, { 0x48, 0x8B, 0x94 }, { 0x4C, 0x8B, 0x84 }, { 0x4C, 0x8B, 0x8C } }
	for i = 1, math.min(nargs, 4) do
		emit(regs[i][1], regs[i][2], regs[i][3], 0x24, bytesLE(slot(i), 4))
	end
	emit(0x48, 0xB8, bytesLE(target, 8))
	emit(0xFF, 0xD0)
	emit(0x48, 0x89, 0xD9)
	emit(0x48, 0x89, 0xC2)
	emit(0x48, 0xB8, bytesLE(pushint, 8))
	emit(0xFF, 0xD0)
	emit(0xB8, 1, 0, 0, 0)
	emit(0x48, 0x81, 0xC4, bytesLE(0xA0, 4))
	emit(0x5F, 0x5E, 0x5B, 0xC3)
	local addr = EEex_AllocNear(#code)
	EEex_DisableCodeProtection()
	for i, b in ipairs(code) do EEex_WriteU8(addr + i - 1, b) end
	EEex_EnableCodeProtection()
	EEex_ExposeToLua(addr, 'PStash_Eng_' .. name)
end
P.buildStub = buildStub

-- The engine build the stash runs on ('2.7.3.0', '2.6.6.0'), nil before PStash_Ready() or on an unknown build.
function PStash_Build() PStash_Ready() return P.build end

function PStash_Ready()
	if P.ready ~= nil and (P.ready == false or _G.PStash_Eng_TakeItemFromStore) then return P.ready end
	P.FUNCS = engineFuncs()
	if not P.FUNCS then P.ready = false return false end
	for name, f in pairs(P.FUNCS) do
		if not _G['PStash_Eng_' .. name] then buildStub(name, f[1], f[3]) end
	end
	P.scratch = P.scratch or EEex_Malloc(64) -- [0] bag resref, [16] CItem*, [24] int err, [32] item resref
	P.ready = true
	return true
end

local function resRef(res, offset)
	local buf = P.scratch + (offset or 0)
	res = string.upper(res)
	for i = 0, 7 do EEex_WriteU8(buf + i, i < #res and string.byte(res, i + 1) or 0) end
	return buf
end

local function gamePtr() return EEex_UDToPtr(EEex_EngineGlobal_CBaldurChitin.m_pObjectGame) end

-----------------
-- Item data   --
-----------------

local function readRes(addr)
	local out = {}
	for i = 0, 7 do
		local b = EEex_ReadU8(addr + i)
		if b == 0 then break end
		out[#out + 1] = string.char(b)
	end
	return string.upper(table.concat(out))
end

-- The spell a scroll teaches: resource of its first opcode-147 ("learn spell") ability effect.
local function scrollSpell(p)
	local absOff, absCount, effOff = EEex_ReadU32(p + 0x64), EEex_ReadU16(p + 0x68), EEex_ReadU32(p + 0x6A)
	for a = 0, absCount - 1 do
		local ab = p + absOff + a * 0x38
		local count, first = EEex_ReadU16(ab + 0x1E), EEex_ReadU16(ab + 0x20)
		for e = first, first + count - 1 do
			local ef = p + effOff + e * 0x30
			if EEex_ReadU16(ef) == 147 then return readRes(ef + 0x14) end
		end
	end
end

-- First ability: attack type (1 melee, 2 ranged, 4 launcher), to-hit, damage dice and bonus.
local function firstAbility(p)
	if EEex_ReadU16(p + 0x68) == 0 then return nil end
	local ab = p + EEex_ReadU32(p + 0x64)
	local toHit = EEex_ReadU16(ab + 0x14)
	if toHit >= 0x8000 then toHit = toHit - 0x10000 end
	local bonus = EEex_ReadU16(ab + 0x1A)
	if bonus >= 0x8000 then bonus = bonus - 0x10000 end
	return { kind = EEex_ReadU8(ab), toHit = toHit, sides = EEex_ReadU8(ab + 0x16), dice = EEex_ReadU8(ab + 0x18),
		bonus = bonus, charges = EEex_ReadU16(ab + 0x22), launcher = EEex_ReadU8(ab + 0x10), strHit = EEex_BAnd(EEex_ReadU32(ab + 0x26), 0x9) ~= 0, strDmg = EEex_BAnd(EEex_ReadU32(ab + 0x26), 0x5) ~= 0 }
end

-- Equipping effects that matter for the comparison: AC (opcode 0), saving throws (33-37), attacks per round
-- (opcode 1 in increment mode: bows' extra shot, Kondar...).
local function equipEffects(p)
	local out = { ac = 0, base = nil, saves = 0, apr = 0 }
	local off, first, count = EEex_ReadU32(p + 0x6A), EEex_ReadU16(p + 0x6E), EEex_ReadU16(p + 0x70)
	for e = first, first + count - 1 do
		local ef = p + off + e * 0x30
		local op, p1, p2 = EEex_ReadU16(ef), EEex_ReadU32(ef + 4), EEex_ReadU32(ef + 8)
		if p1 >= 0x80000000 then p1 = p1 - 0x100000000 end
		if op == 0 and p2 == 16 then out.base = p1             -- armor: sets base AC
		elseif op == 0 and p2 == 0 then out.ac = out.ac + p1   -- generic AC bonus
		elseif op >= 33 and op <= 37 then out.saves = out.saves + p1
		elseif op == 1 and p2 == 0 then out.apr = out.apr + p1 end
	end
	return out
end

-- Raw ITM header fields (EEex hands out the file header as loaded in memory).
-- itmV: bumped when the fields change, so a reloaded file does not use older cached entries.
if P.itmV ~= 5 then P.itm, P.itmV = {}, 5 end
P.itm = P.itm or {}
function PStash_ItemInfo(res)
	res = string.upper(res)
	local c = P.itm[res]
	if c then return c end
	local h = EEex_Resource_Demand(res, 'ITM')
	if not h then return nil end
	local p = EEex_UDToPtr(h)
	local icon = {}
	for i = 0, 7 do
		local b = EEex_ReadU8(p + 0x3A + i)
		if b == 0 then break end
		icon[#icon + 1] = string.char(b)
	end
	c = {
		critical = EEex_BAnd(EEex_ReadU32(p + 0x18), 1) ~= 0,
		type = EEex_ReadU16(p + 0x1C),
		unidName = EEex_ReadU32(p + 0x08), idName = EEex_ReadU32(p + 0x0C),
		stack = math.max(1, EEex_ReadU16(p + 0x38)),
		icon = table.concat(icon), weight = EEex_ReadU32(p + 0x4C), price = EEex_ReadU32(p + 0x34), enchant = EEex_ReadU32(p + 0x60),
		magical = EEex_BAnd(EEex_ReadU32(p + 0x18), 0x40) ~= 0, cursed = EEex_BAnd(EEex_ReadU32(p + 0x18), 0x10) ~= 0,
		twoHanded = EEex_BAnd(EEex_ReadU32(p + 0x18), 0x2) ~= 0,
		unusable = EEex_ReadU32(p + 0x1E), prof = EEex_ReadU8(p + 0x31),
		minStr = EEex_ReadU16(p + 0x26), minStrEx = EEex_ReadU8(p + 0x28), minInt = EEex_ReadU8(p + 0x2A),
		minDex = EEex_ReadU8(p + 0x2C), minWis = EEex_ReadU8(p + 0x2E), minCon = EEex_ReadU8(p + 0x30),
		minCha = EEex_ReadU16(p + 0x32),
		unidDesc = EEex_ReadU32(p + 0x50), idDesc = EEex_ReadU32(p + 0x54), descPic = readRes(p + 0x58),
		spell = scrollSpell(p),
		kit = { EEex_ReadU8(p + 0x29), EEex_ReadU8(p + 0x2B), EEex_ReadU8(p + 0x2D), EEex_ReadU8(p + 0x2F) },
		ability = firstAbility(p), equip = equipEffects(p),
	}
	P.itm[res] = c
	return c
end

-----------------
-- Store I/O   --
-----------------

-- Contents of a bag store: { {res, count, uses, identified, weight}, ... } in store order.
function PStash_List(bagRes)
	if not PStash_Ready() then return {} end
	bagRes = bagRes or P.RES
	local game, out = gamePtr(), {}
	PStash_Eng_DemandServerStore(game, resRef(bagRes), 0)
	pcall(function()
		local storePtr = PStash_Eng_GetServerStore(game, resRef(bagRes))
		if storePtr == 0 then return end
		EEex_Utility_IterateCPtrList(EEex_PtrToUD(storePtr, 'CStore').m_lInventory, function(data)
			local fi = type(data) == 'number' and EEex_PtrToUD(data, 'CStoreFileItem') or data
			local ptr = type(data) == 'number' and data or EEex_UDToPtr(data)
			-- Raw STO item entry: flags u32 at +0x10, bit 0 = identified.
			out[#out + 1] = { res = string.upper(fi.m_itemId:get()), count = fi.m_nInStock,
				uses = fi.m_usageCount:get(0), identified = EEex_BAnd(EEex_ReadU32(ptr + 0x10), 1) ~= 0 }
		end)
	end)
	PStash_Eng_ReleaseServerStore(game, resRef(bagRes))
	return out
end

-- Moves the item in inventory slot `slot` of `portrait` into bag `bagRes` (default: the stash).
function PStash_Add(portrait, slot, bagRes)
	if not PStash_Ready() then return false, 'engine build not supported' end
	local ok, res, why = pcall(function()
		local sp = EEex_Sprite_GetInPortrait(portrait)
		if not sp then return false, 'no such portrait' end
		local item = sp.m_equipment.m_items:get(slot)
		if not item then return false, 'empty slot' end
		local itemPtr, game, buf = EEex_UDToPtr(item), gamePtr(), P.scratch
		EEex_Write32(buf + 24, -1)
		if PStash_Eng_AddItemToStore(game, resRef(bagRes or P.RES), itemPtr, buf + 24) % 256 == 0 then
			return false, string.format('refused (0x%x)', EEex_ReadU32(buf + 24))
		end
		EEex_Write64(buf + 16, 0)
		PStash_Eng_SwapItemPersonal(game, portrait, buf + 16, slot, buf + 24, 0xFFFF, 0, 1, 0)
		local out = EEex_ReadU64(buf + 16)
		if out ~= itemPtr then return false, 'in the stash but the slot kept it (duplicate!)' end
		PStash_Eng_AddDisposableItem(game, out)
		return true
	end)
	P.dirty = true
	if not ok then return false, tostring(res) end
	return res, why
end

-- The last backpack slot (33) is the "-> stash" drop slot on the inventory page: never filled by us.
P.DROP_SLOT = 33
local function freeSlot(sp)
	for i = 18, P.DROP_SLOT - 1 do if not sp.m_equipment.m_items:get(i) then return i end end
end

-- Takes `itemRes` out of bag `bagRes` (default: the stash) into `portrait`'s backpack: a whole pile for stackable
-- items (the store keeps stacks unit by unit: 530 arrows = 530 x 1), up to the item's max stack; one piece for the
-- others (charges kept). Refuses when the backpack is full (the engine would drop it on the floor).
-- Returns the slot it landed in, or nil + reason.
function PStash_Take(portrait, itemRes, bagRes)
	if not PStash_Ready() then return nil, 'engine build not supported' end
	local sp = EEex_Sprite_GetInPortrait(portrait)
	if not sp then return nil, 'no such portrait' end
	if not freeSlot(sp) then return nil, 'backpack full' end
	itemRes, bagRes = string.upper(itemRes), bagRes or P.RES
	local entry
	for _, e in ipairs(PStash_List(bagRes)) do
		if e.res == itemRes then entry = e break end
	end
	if not entry then return nil, 'not in the stash' end
	local before = {}
	for i = 18, 33 do before[i] = sp.m_equipment.m_items:get(i) ~= nil end
	local info = PStash_ItemInfo(itemRes)
	local stackable = info and info.stack > 1
	local want = stackable and math.min(math.max(1, entry.count), info.stack) or 1
	local game = gamePtr()
	local taken = PStash_Eng_TakeItemFromStore(game, resRef(bagRes), resRef(itemRes, 32), want) % 65536
	if taken == 0 then return nil, 'the stash kept it' end
	EEex_Action_ExecuteResponseStringOnAIBaseInstantly(
		string.format('CreateItem("%s",%d,0,0)', itemRes, stackable and taken * math.max(1, entry.uses) or entry.uses), sp)
	local landed
	for i = 18, 33 do
		local it = sp.m_equipment.m_items:get(i)
		if it and not before[i] and string.upper(it.pRes.resref:get()) == itemRes then
			landed = i
			if entry.identified then it.m_flags = EEex_BOr(it.m_flags, 1) end
			break
		end
	end
	if not landed then -- merged into a stack already in the backpack
		for i = 18, 33 do
			local it = sp.m_equipment.m_items:get(i)
			if it and string.upper(it.pRes.resref:get()) == itemRes then landed = i break end
		end
	end
	P.dirty = true
	return landed
end

-----------------
-- Weight      --
-----------------

-- Weight allowance of a creature (STRMOD / STRMODEX WEIGHT_ALLOWANCE, live STR incl. buffs).
local function allowance(sp)
	P.strmod = P.strmod or EEex_Resource_Load2DA('STRMOD')
	P.strmodex = P.strmodex or EEex_Resource_Load2DA('STRMODEX')
	local str, ex = EEex_Sprite_GetStat(sp, 36), EEex_Sprite_GetStat(sp, 37)
	local w = tonumber(EEex_Resource_GetAt2DALabels(P.strmod, 'WEIGHT_ALLOWANCE', tostring(str))) or 0
	if str == 18 and ex > 0 then
		w = w + (tonumber(EEex_Resource_GetAt2DALabels(P.strmodex, 'WEIGHT_ALLOWANCE', tostring(ex))) or 0)
	end
	return w
end

-- Companions outside the 6 portraits (issue #1, John 2026-10-23): mods that add party members as familiars (EA 3,
-- AddFamiliar: they follow the party between areas). Joining Party travelers (LOCALS JO_JOIN_IS_TRAVELER), NPC
-- Generator followers (LOCALS A7CHR-FOLLOWER, script name A7CHR-...) and any familiar that is a real character
-- (player class and race); not the mage familiars (animals), the golems (A7!G...) or Afaaq (no inventory).
-- Familiars always travel with the party, so the current area holds them all. Refreshed every 2 s.
local function isCompanion(c)
	if not c or c.m_typeAI.m_EnemyAlly ~= 3 or EEex_Sprite_GetPortraitIndex(c) >= 0 then return false end
	local name = string.upper(c.m_scriptName:get() or '')
	if string.sub(name, 1, 3) == 'A7!' or name == 'A7AFAAQ' then return false end
	if EEex_Sprite_GetLocalInt(c, 'JO_JOIN_IS_TRAVELER') ~= 0 or EEex_Sprite_GetLocalInt(c, 'A7CHR-FOLLOWER') ~= 0
		or string.sub(name, 1, 6) == 'A7CHR-' then return true end
	local cls, race = c.m_typeAI.m_Class, c.m_typeAI.m_Race
	return cls >= 1 and cls <= 21 and race >= 1 and race <= 7
end
function PStash_Companions()
	local now = Infinity_GetClockTicks()
	if P.companions and P.companionsAt and now - P.companionsAt < 2000 then return P.companions end
	local out = {}
	pcall(function()
		local lead = EEex_Sprite_GetInPortrait(0)
		if not lead or not lead.m_pArea then return end
		local all = EEex_Area_GetAllOfTypeStringInRange(lead.m_pArea, lead.m_pos.x, lead.m_pos.y, '[FAMILIAR]', 32767, false)
		for _, c in ipairs(all or {}) do if isCompanion(c) then out[#out + 1] = c end end
	end)
	P.companions, P.companionsAt = out, now
	return out
end

local function itemWeight(res, units)
	local info = PStash_ItemInfo(res)
	return info and info.weight * math.max(1, units) or 0
end

-- (party + stash weight, sum of allowances)
-- Install options (optional WeiDU components; each one writes an override M_PSOPT*.lua setting PStash_Opt.<name>):
-- weightless = the stash never weighs anything; keepgold = the party gold survives the campaign moves (BG1 -> SoD,
-- EET SoD -> BG2); losestash = the stash is emptied by those moves, like everything else the party carries.
local function opt(name) return type(PStash_Opt) == 'table' and PStash_Opt[name] == true end

-- A quest item: the game's critical flag, an item NPCs look for on a party member (P.KEEP), or one any dialog or
-- script of the three campaigns checks or takes (P.QUEST, build_quest.py: "Provisions" BDSUPPLY, John 2026-10-22).
local function questItem(info, res)
	return info.critical or ((P.KEEP[res] or (P.QUEST and P.QUEST[res])) and not (P.NOT_QUEST and P.NOT_QUEST[res]))
end

-- The 6 portraits, then the companions (they carry their share of the stash too, issue #1).
-- Last portrait index of the party: 5, or more with the Party Stash >6 members prototype (M_PSXP7.lua, John
-- 2026-10-23). Every party loop below uses it.
local function lastPortrait() return PSXP7_LastPortrait and PSXP7_LastPortrait() or 5 end

local function carriers()
	local out = {}
	for p = 0, lastPortrait() do
		local sp = EEex_Sprite_GetInPortrait(p)
		if sp then out[#out + 1] = sp end
	end
	for _, c in ipairs(PStash_Companions()) do out[#out + 1] = c end
	return out
end

function PStash_Weight()
	local load, cap = 0, 0
	for _, sp in ipairs(carriers()) do
		cap = cap + allowance(sp)
		for i = 0, 38 do
			local it = sp.m_equipment.m_items:get(i)
			if it then load = load + itemWeight(it.pRes.resref:get(), it.m_useCount1) end
		end
	end
	-- The stash: items a collected bag holds weigh nothing (John), the rest counts.
	local cov = coveredTypes()
	if not cov.all and not opt('weightless') then
		for _, e in ipairs(P.list or {}) do
			local info = PStash_ItemInfo(e.res)
			-- quest items weigh nothing (John 2026-10-22; the install also sets their ITM weight to 0)
			if info and not cov[info.type] and not questItem(info, e.res) then
				local units = info.stack > 1 and math.max(1, e.uses) or 1
				load = load + itemWeight(e.res, units) * math.max(1, e.count)
			end
		end
	end
	return load, cap
end

-- Over the shared allowance: everyone moves at half speed (one tagged effect, replaced every refresh).
local function applySlow(on)
	for _, sp in ipairs(carriers()) do
		EEex_GameObject_ApplyEffect(sp, { effectID = 321, res = 'PSTASHW', durationType = 1,
			sourceID = sp.m_id, sourceTarget = sp.m_id })
		if on then
			EEex_GameObject_ApplyEffect(sp, { effectID = 176, effectAmount = 50, dwFlags = 5, durationType = 0,
				duration = 3, m_sourceRes = 'PSTASHW', sourceID = sp.m_id, sourceTarget = sp.m_id })
		end
	end
end

-----------------
-- Grid view   --
-----------------

function PStash_TabUnlocked(i) return P.TABS[i] ~= nil end

-- In the keep list but not quest items: things the bot keeps for its own plans (Imoen's Shadow Armor, the Ankheg
-- shell for Taerom). They stay out of auto-store but show in their normal tab, not Quest.
-- + the stat manuals and tomes (BOOK03-08): usable items a script checks, not quest items (John 2026-10-22)
P.NOT_QUEST = { LEAT08 = true, MISC12 = true, BOOK03 = true, BOOK04 = true, BOOK05 = true, BOOK06 = true, BOOK07 = true,
	BOOK08 = true }

local function tabIndex(label)
	for i, t in ipairs(P.TABS) do if t.label == label then return i end end
end

-- A scroll that teaches or casts nothing (a letter, a note) or a cursed one belongs to Misc (John).
local function realScroll(info)
	if info.type ~= 11 or info.ability == nil or info.cursed then return false end
	-- cursed scrolls carry their curse as an effect, not the cursed flag: their name says it
	local name = string.lower(Infinity_FetchString(info.idName) or '')
	return not (string.find(name, 'maudit', 1, true) or string.find(name, 'cursed', 1, true))
end

-- Known cursed items (flag 0x10 or "maudit/cursed" in the name) go to Misc (John); unidentified ones keep their tab
-- so the stash does not spoil the curse.
local function cursedItem(info)
	if info.cursed then return true end
	local name = string.lower(Infinity_FetchString(info.idName) or '')
	return string.find(name, 'maudit', 1, true) ~= nil or string.find(name, 'cursed', 1, true) ~= nil
end

-- Books and letters the game types as misc (BG1 BOOK10.., SoD BDBOOK04 "The Nine Hells"...): the resref tells, and
-- they do nothing when used (the stat manuals BOOK03-08 have an ability: they stay in Misc).
local BOOK_RES = { 'BOOK', 'NOTE', 'LETT', 'LETR', 'JOUR', 'DIAR', 'TOME' }  -- JOUR: BG2's OHHJOUR, OHDJOUR (John)
local function bookLike(info, res)
	if info.type ~= 0 or info.ability ~= nil then return false end
	for _, w in ipairs(BOOK_RES) do if string.find(res, w, 1, true) then return true end end
	return false
end

local function tabOf(info, res, identified)
	local misc = tabIndex('Misc')
	local cursed = identified and cursedItem(info)
	-- Notes: everything a scroll case takes (scrolls 11, books 37) but the castable scrolls, quest ones included
	-- (they keep being weightless and kept in a backpack when an NPC looks for them); known cursed scrolls stay in
	-- Misc (John 2026-10-22)
	if (info.type == 37 or (info.type == 11 and not realScroll(info)) or bookLike(info, res)) and not cursed then
		return tabIndex('Notes')
	end
	if questItem(info, res) then return tabIndex('Quest') end
	if cursed then return misc end
	-- magical rings and amulets go with the gear, mundane ones stay with the gems (John)
	if (info.type == 1 or info.type == 10) and (info.magical or info.enchant > 0) then return tabIndex('Gear') end
	if info.type == 11 and not realScroll(info) then return misc end
	for i = 2, misc - 1 do
		if P.TABS[i].types and P.TABS[i].types[info.type] then return i end
	end
	return misc
end

-- Portrait of the character shown in the inventory screen.
local function shownPortrait()
	for p = 0, lastPortrait() do
		local sp = EEex_Sprite_GetInPortrait(p)
		if sp and sp.m_id == id then return p end
	end
	return 0
end

-- ITM 0x1E "unusable by" bits for a class / race / alignment (sorcerer = mage bit, shaman = druid bit).
local CLASS_BIT = { [1] = 0x40000, [2] = 0x800, [3] = 0x80, [4] = 0x400000, [5] = 0x40, [6] = 0x100000,
	[7] = 0x2000, [8] = 0x4000, [9] = 0x20000, [10] = 0x10000, [11] = 0x40000000, [12] = 0x200000, [13] = 0x80000,
	[14] = 0x100, [15] = 0x200, [16] = 0x1000, [17] = 0x8000, [18] = 0x400, [19] = 0x40000, [20] = 0x20000000,
	[21] = 0x40000000 }
local RACE_BIT = { [1] = 0x8000000, [2] = 0x800000, [3] = 0x2000000, [4] = 0x1000000, [5] = 0x4000000,
	[6] = 0x10000000, [7] = 0x80000000 }

-- KITLIST UNUSABLE of a kit id (KIT stat, 0x4000 + row), split into the 4 ITM kit bytes (0x29, 0x2B, 0x2D, 0x2F).
P.kits = P.kits or {}
local function kitUnusable(kitId)
	if not kitId or kitId < 0x4000 then return nil end
	if P.kits[kitId] == nil then
		P.kits[kitId] = false
		pcall(function()
			local t = EEex_Resource_Load2DA('KITLIST')
			local u = tonumber(EEex_Resource_GetAt2DALabels(t, 'UNUSABLE', tostring(kitId - 0x4000)))
			if u then
				P.kits[kitId] = { math.floor(u / 0x1000000) % 256, math.floor(u / 0x10000) % 256,
					math.floor(u / 0x100) % 256, u % 256 }
			end
		end)
	end
	return P.kits[kitId] or nil
end

-- Can portrait `p` use this item at all (class, kit, race, alignment, minimum stats)?
local function usableSprite(sp, info)
	if not sp then return true end
	local ai, f = sp.m_typeAI, info.unusable
	local function has(bit) return bit ~= nil and EEex_BAnd(f, bit) ~= 0 end
	if has(CLASS_BIT[ai.m_Class]) or has(RACE_BIT[ai.m_Race]) then return false end
	local law, moral = math.floor(ai.m_Alignment / 16), ai.m_Alignment % 16
	if (law == 3 and has(0x1)) or (moral == 3 and has(0x2)) or (moral == 1 and has(0x4)) or (moral == 2 and has(0x8))
		or (law == 1 and has(0x10)) or (law == 2 and has(0x20)) then
		return false
	end
	local kit = kitUnusable(EEex_Sprite_GetStat(sp, 152))
	if kit and (EEex_BAnd(info.kit[1], kit[1]) ~= 0 or EEex_BAnd(info.kit[2], kit[2]) ~= 0
		or EEex_BAnd(info.kit[3], kit[3]) ~= 0 or EEex_BAnd(info.kit[4], kit[4]) ~= 0) then
		return false
	end
	local function st(n) return EEex_Sprite_GetStat(sp, n) end
	if st(36) < info.minStr or (st(36) == 18 and info.minStr == 18 and st(37) < info.minStrEx) then return false end
	return st(38) >= info.minInt and st(40) >= info.minDex and st(39) >= info.minWis and st(41) >= info.minCon
		and st(42) >= info.minCha
end
local function usable(p, info) return usableSprite(EEex_Sprite_GetInPortrait(p), info) end

-- Equipment slot of each item type (rings: either hand).
local SLOTS = { [2] = { 1 }, [60] = { 1 }, [61] = { 1 }, [62] = { 1 }, [63] = { 1 }, [64] = { 1 }, [65] = { 1 },
	[66] = { 1 }, [67] = { 1 }, [7] = { 6 }, [72] = { 6 }, [12] = { 9 }, [41] = { 9 }, [47] = { 9 }, [49] = { 9 },
	[53] = { 9 }, [1] = { 0 }, [10] = { 7, 8 }, [32] = { 4 }, [4] = { 3 }, [3] = { 2 }, [6] = { 5 }, [73] = { 5 } }
local MAIN_HAND = 35

-- AC an item gives (higher = better): armor sets the base AC (10 - base), others add a bonus.
local function acOf(info)
	local e = info and info.equip
	if not e then return 0, 0 end
	return (e.base and 10 - e.base or 0) + e.ac, e.saves
end

-- WSPECIAL.2DA (BG-style weapon skills): to-hit and damage bonus per skill pip.
local function skillBonus(pips)
	P.wspecial = P.wspecial or EEex_Resource_Load2DA('WSPECIAL')
	local row = tostring(math.min(pips, 5))
	return tonumber(EEex_Resource_GetAt2DALabels(P.wspecial, 'HIT', row)) or 0,
		tonumber(EEex_Resource_GetAt2DALabels(P.wspecial, 'DAMAGE', row)) or 0
end

-- To-hit and average damage of a weapon for this character (item bonuses + weapon skill).
local function weaponScore(sp, info)
	local ab = info and info.ability
	if not ab then return nil end
	local pips = info.prof > 0 and EEex_Sprite_GetStat(sp, info.prof) or 0
	local hit, dmg = skillBonus(pips)
	return ab.toHit + hit, ab.dice * (ab.sides + 1) / 2 + ab.bonus + dmg, pips
end

-- Weapon DPS for the shown character (John 2026-10-21): damage per round (6 s) and THAC0 with this weapon, from the
-- game's own tables. Damage = average dice + item bonus + strength (abilities flagged "add strength bonus") + skill;
-- x attacks per round. Launchers shoot their base ammo (AROW01 / BOLT01 / BULL01). Sort score = damage/round x
-- (1 + 5% per point of to-hit bonus): no reference AC (1 THAC0 = 5% to hit).
local WARRIOR = { [2] = true, [6] = true, [7] = true, [8] = true, [9] = true, [10] = true, [12] = true, [16] = true,
	[17] = true, [18] = true }
local BASE_AMMO = { [15] = 'AROW01', [27] = 'BOLT01', [18] = 'BULL01' }

local function table2DA(name)
	P.t2da = P.t2da or {}
	if not P.t2da[name] then P.t2da[name] = EEex_Resource_Load2DA(name) end
	return P.t2da[name]
end
local function at2DA(name, col, row) return tonumber(EEex_Resource_GetAt2DALabels(table2DA(name), col, tostring(row))) or 0 end

-- Strength to-hit and damage (STRMOD, plus STRMODEX for 18/xx).
local function strBonus(sp)
	local str, ex = EEex_Sprite_GetStat(sp, 36), EEex_Sprite_GetStat(sp, 37)
	local hit, dmg = at2DA('STRMOD', 'TO_HIT', str), at2DA('STRMOD', 'DAMAGE', str)
	if str == 18 and ex > 0 then
		hit, dmg = hit + at2DA('STRMODEX', 'TO_HIT', ex), dmg + at2DA('STRMODEX', 'DAMAGE', ex)
	end
	return hit, dmg
end

-- Engine attacks-per-round code (NUMBEROFATTACKS): 1-5 attacks, 6 = 1/2, 7 = 3/2, 8 = 5/2, 9 = 7/2, 10 = 9/2
-- (checked in game: a specialized level 1 fighter = 7 = 1.5, WSPATCK's figure).
local function aprCode(v) if v >= 6 then return v - 5.5 end return v end

-- No skill in a weapon: the class's to-hit penalty (the best of a multiclass): warriors -2, priests and rogues -3,
-- mages -5 (the engine's "Prof.: +2" line for an untrained fighter).
local NONPROF = { [1] = -5, [19] = -5, [3] = -3, [4] = -3, [5] = -3, [11] = -3, [13] = -3, [14] = -3, [15] = -3,
	[20] = -3, [21] = -3 }
local function nonProficient(sp)
	local cls = sp.m_typeAI.m_Class
	if WARRIOR[cls] then return -2 end
	return NONPROF[cls] or -2
end

-- Attacks per round with a weapon of `pips` skill: warriors from WSPATCK (skill x level; 0 = 1, 1 = 2, 2 = 3,
-- -1 = 1.5, -2 = 2.5), monks as the engine counts them, others 1; plus the weapon's own extra attacks.
local function attacksPerRound(sp, info, pips)
	local cls, apr = sp.m_typeAI.m_Class, 1
	if WARRIOR[cls] then
		local lvl = math.max(1, math.min(40, math.max(EEex_Sprite_GetStat(sp, 34), EEex_Sprite_GetStat(sp, 68))))
		local v = at2DA('WSPATCK', lvl == 1 and 'LEVEL1' or tostring(lvl), math.min(pips, 5))
		apr = v >= 0 and 1 + v or 0.5 - v
	elseif cls == 20 then
		apr = aprCode(EEex_Sprite_GetStat(sp, 8))
	end
	-- bows shoot twice as often as the other weapons (the engine's own rule, not an item effect)
	if info.type == 15 then apr = apr + 1 end
	return apr + (info.equip and info.equip.apr or 0)
end

-- Damage per hit, to-hit bonus and attacks per round of a weapon from its own data and the character's tables.
local function weaponCore(sp, info)
	local ab = info.ability
	local pips = EEex_Sprite_GetStat(sp, info.prof)
	local sHit, sDmg = skillBonus(pips)
	if pips == 0 and info.type ~= 28 then sHit = sHit + nonProficient(sp) end -- not the fist (hand-to-hand, type 28)
	local hit, dmg = ab.toHit + sHit, ab.bonus + sDmg
	local dice, sides = ab.dice, ab.sides
	if ab.kind == 4 then
		local ammo = BASE_AMMO[info.type] and PStash_ItemInfo(BASE_AMMO[info.type])
		local aa = ammo and ammo.ability
		if not aa then return nil end
		dice, sides, hit, dmg = aa.dice, aa.sides, hit + aa.toHit, dmg + aa.bonus
	end
	-- strength: melee always; ranged when flagged (bit 0 both, EE bit 2 damage, bit 3 to-hit: slings, thrown...)
	if ab.kind == 1 or ab.strHit or ab.strDmg then
		local h, d = strBonus(sp)
		if ab.kind == 1 or ab.strHit then hit = hit + h end
		if ab.kind == 1 or ab.strDmg then dmg = dmg + d end
	end
	return dice * (sides + 1) / 2 + dmg, hit, attacksPerRound(sp, info, pips)
end

local function isWeapon(info)
	local ab = info and info.ability
	return ab ~= nil and info.prof > 0 and (ab.kind == 1 or ab.kind == 2 or ab.kind == 4)
end

-- What the engine says about the weapon in use (inventory numbers: damage min-max, THAC0, attacks per round), minus
-- what weaponCore finds for it: the character's own bonuses (gloves, kit, ammo in the quiver, effects...). Added to
-- the weapons of the same group (launchers / the others), so the weapon in hand shows the game's exact figures
-- (John 2026-10-21). Computed once per page rebuild; rebuild() keeps one per character and group (P.anchors).
local AMMO_LAUNCHER = { [1] = 15, [2] = 27, [3] = 18 } -- ammo "launcher required" -> launcher item type
local function weaponAnchor(p)
	local sp, c = EEex_Sprite_GetInPortrait(p), characters and characters[id]
	if not sp or not c or not c.damage or not c.THAC0 then return nil end
	local items = sp.m_equipment.m_items
	local sel = sp.m_equipment.m_selectedWeapon
	local it = sel and items:get(sel)
	local info = it and PStash_ItemInfo(it.pRes.resref:get())
	if info and info.ability and info.ability.kind == 2 and sel >= 11 and sel <= 13 then
		-- ammo selected: the launcher it needs, among the weapon slots
		local want = AMMO_LAUNCHER[info.ability.launcher or 0]
		info = nil
		for slot = MAIN_HAND, MAIN_HAND + 3 do
			local w = items:get(slot)
			local wi = w and PStash_ItemInfo(w.pRes.resref:get())
			if wi and wi.type == want then info = wi break end
		end
	end
	if not isWeapon(info) then return nil end
	local function first(v) return tonumber(string.match(tostring(v or ''), '%-?%d+')) end
	local lo, hi, thac0 = first(c.damage.min), first(c.damage.max), first(c.THAC0.current)
	if not lo or not hi or not thac0 then return nil end
	local perHit, hit, apr = weaponCore(sp, info)
	if not perHit then return nil end
	local engApr = aprCode(EEex_Sprite_GetStat(sp, 8))
	local off = items:get(9)
	local oi = off and PStash_ItemInfo(off.pRes.resref:get())
	if oi and oi.ability and oi.ability.kind == 1 then engApr = engApr - 1 end -- the off-hand's own attack
	return { launcher = info.ability.kind == 4, dmg = (lo + hi) / 2 - perHit,
		hit = (EEex_Sprite_GetStat(sp, 7) - thac0) - hit, apr = engApr - apr }
end

-- { round = damage per round, hit = to-hit bonus, thac0 = THAC0 with it, score } of a weapon for this character, or
-- nil (not a weapon, or unusable by him).
local function weaponDps(p, info)
	local sp = EEex_Sprite_GetInPortrait(p)
	if not sp or not isWeapon(info) or not usable(p, info) then return nil end
	if info.ability.kind == 4 and not BASE_AMMO[info.type] then return nil end
	local perHit, hit, apr = weaponCore(sp, info)
	if not perHit then return nil end
	local a = P.anchor and P.anchor[info.ability.kind == 4]
	if a then perHit, hit, apr = perHit + a.dmg, hit + a.hit, apr + a.apr end
	local round = math.max(1, perHit) * math.max(1, apr)
	return { round = round, hit = hit, thac0 = EEex_Sprite_GetStat(sp, 7) - hit, score = round * (1 + 0.05 * hit) }
end
PStash_WeaponDps = weaponDps -- (portrait, PStash_ItemInfo) -> { round, hit, thac0, score } or nil: the camp merchant's Auto sort

-- Game language, read from a string the game translates: "Arc" (8733, the Bow skill) in French.
local function lang()
	if P.lang == nil then P.lang = Infinity_FetchString(8733) == 'Arc' and 'fr' or 'en' end
	return P.lang
end

-- Gains and losses of `info` for portrait `p` against what he wears in that slot.
-- Returns the gain (> 0 = upgrade) and the tooltip lines.
local function compare(p, info)
	local sp = EEex_Sprite_GetInPortrait(p)
	if not sp or not info or not usable(p, info) then return 0, {} end
	if info.cursed then return -1, { T('cmp_cursed') } end
	local items = sp.m_equipment.m_items
	local lines = {}
	local function sign(v) return (v > 0 and '+' or '') .. (math.floor(v * 10 + 0.5) / 10) end
	local slots = SLOTS[info.type]
	if slots then
		-- Weakest worn piece among the possible slots (an empty ring hand counts as nothing).
		-- John: compare with what is WORN (the weakest worn piece for rings); a bare slot gives no "+".
		local worstAc, worstSaves
		for _, slot in ipairs(slots) do
			local cur = items:get(slot)
			if cur then
				local ac, saves = acOf(PStash_ItemInfo(cur.pRes.resref:get()))
				if worstAc == nil or ac + saves < worstAc + worstSaves then worstAc, worstSaves = ac, saves end
			end
		end
		if worstAc == nil then return 0, { T('cmp_empty_slot') } end
		local ac, saves = acOf(info)
		local dAc, dSaves = ac - worstAc, saves - worstSaves
		if dAc ~= 0 then lines[#lines + 1] = T('cmp_ac') .. sign(dAc) end
		if dSaves ~= 0 then lines[#lines + 1] = T('cmp_saves') .. sign(dSaves) end
		return dAc + dSaves / 2, lines
	end
	if info.ability and info.prof > 0 then
		-- John 2026-10-22: by damage per round (the tooltip's figure). Melee: against the best melee weapon among the
		-- quick weapon slots, or the fist when there is none; dual wielding: against the weaker hand (one-handed
		-- weapons only). Ranged: against the best ranged weapon there; none -> every ranged weapon is an upgrade.
		-- John 2026-10-24: only weapons the character has at least one proficiency point in
		if (EEex_Sprite_GetStat(sp, info.prof) or 0) < 1 then return 0, lines end
		local mine = weaponDps(p, info)
		if not mine then return 0, lines end
		local function ranged(i) return i.ability.kind == 4 or i.ability.kind == 2 end
		local isRanged = ranged(info)
		local best
		for slot = MAIN_HAND, MAIN_HAND + 3 do
			local it = items:get(slot)
			local ci = it and PStash_ItemInfo(it.pRes.resref:get())
			if ci and ci.ability and ranged(ci) == isRanged then
				local d = weaponDps(p, ci)
				if d and (not best or d.round > best) then best = d.round end
			end
		end
		if not isRanged then
			if not best then -- the fist: 1d2 + strength damage, the character's own attacks per round
				local _, d = strBonus(sp)
				best = math.max(1, 1.5 + d) * math.max(1, aprCode(EEex_Sprite_GetStat(sp, 8)))
			end
			local off = items:get(9)
			local oi = off and PStash_ItemInfo(off.pRes.resref:get())
			if oi and oi.ability and oi.ability.kind == 1 and not info.twoHanded then
				local d = weaponDps(p, oi)
				if d then best = math.min(best, d.round) end
			end
		end
		return mine.round - (best or 0), lines
	end
	return 0, lines
end

local function upgrade(p, info) return (compare(p, info)) > 0 end

-- The engine's own slot tints are overlay BAMs (read in game from item.tint): red = unusable, blue = unidentified.
P.tintOk, P.tintBad, P.tintUnid = '', 'STORTINT', 'STORTIN2'

-- Arcane casters who copy scrolls (sorcerers cannot): mage, bard, F/M, F/M/T, M/T, C/M, F/M/C.
local SCRIBES = { [1] = true, [5] = true, [7] = true, [10] = true, [13] = true, [14] = true, [17] = true }

-- Spells known by EVERY scribe of the party (a scroll is green while one of them still lacks it).
local function knownByAll()
	local all, any = nil, false
	for p = 0, lastPortrait() do
		local sp = EEex_Sprite_GetInPortrait(p)
		if sp and SCRIBES[sp.m_typeAI.m_Class] then
			any = true
			local mine = {}
			for _, _, res in EEex_Sprite_GetKnownMageSpellsIterator(sp) do mine[string.upper(res)] = true end
			if all == nil then all = mine
			else for k in pairs(all) do if not mine[k] then all[k] = nil end end end
		end
	end
	return any and all or nil
end


-- Auto (default, John): each category has its own order (see autoLess); the others apply to every tab.
P.SORTS = { 'Auto', 'Date', 'Quality', 'Type', 'Price', 'Gp/lb' }
if P.sortsV ~= 2 then P.sort, P.sortsV = 1, 2 end
P.sort = P.sort or 1

-- Within a tab: body armor by AC (best first); scrolls mage (by level) > priest (by level) > other spells >
-- protection scrolls (no spell taught), last.
local BODY = { [2] = true, [60] = true, [61] = true, [62] = true, [63] = true, [64] = true, [65] = true, [66] = true,
	[67] = true }
local function subRank(info)
	if BODY[info.type] then return -(acOf(info)) end
	if info.type == 11 then
		local sp = info.spell or ''
		local lvl = tonumber(string.sub(sp, 5, 5)) or 9
		if string.sub(sp, 1, 4) == 'SPWI' then return lvl end
		if string.sub(sp, 1, 4) == 'SPPR' then return 10 + lvl end
		if sp ~= '' then return 30 end
		return 40
	end
	return 0
end

local function validRef(r) return r and r > 0 and r < 0x7FFFFFFF and r or nil end

-- Sort keys. Gear in body order (John): helmet/hat, cloak, amulet, ring, bracers/gauntlets, belt, boots.
local BODY_ORDER = { [7] = 1, [72] = 1, [32] = 2, [1] = 3, [10] = 4, [6] = 5, [73] = 5, [3] = 6, [4] = 7 }
local TAB = {}
local function tabs()
	if not TAB.weap then
		TAB.weap, TAB.armor, TAB.gear, TAB.ammo = tabIndex('Weap.'), tabIndex('Armor'), tabIndex('Gear'), tabIndex('Ammo')
		TAB.gems, TAB.scroll, TAB.potion = tabIndex('Gems'), tabIndex('Scroll'), tabIndex('Potion')
		TAB.quest, TAB.notes, TAB.misc = tabIndex('Quest'), tabIndex('Notes'), tabIndex('Misc')
	end
	return TAB
end

-- +5, +4... then magical without +N, then mundane; armor then by AC; then by value.
local function qualityLess(a, b)
	if a.enchant ~= b.enchant then return a.enchant > b.enchant end
	if a.magic ~= b.magic then return a.magic end
	if a.tabIdx ~= TAB.weap and a.ac ~= b.ac then return a.ac > b.ac end
	if a.price ~= b.price then return a.price > b.price end
	return a.order < b.order
end

-- The former "Type" sort: magical first, sub rank (body armor by AC, scrolls by class/level), item type.
local function typeLess(a, b)
	if a.magic ~= b.magic then return a.magic end
	if a.sub ~= b.sub then return a.sub < b.sub end
	if a.type ~= b.type then return a.type < b.type end
	return a.order < b.order
end

local function priceLess(a, b)
	if a.price ~= b.price then return a.price > b.price end
	return a.order < b.order
end

-- Auto (John): grouped by category; weapons/armor by quality; gear by body order then price; ammo by type then
-- price; gems and potions by price; scrolls by class (mage, priest, other, protection) then level then price;
-- quest by type; misc by type then price.
local function autoLess(a, b)
	local T = tabs()
	if a.tabIdx ~= b.tabIdx then return a.tabIdx < b.tabIdx end
	local t = a.tabIdx
	if t == T.weap then
		-- DPS for the shown character, best first; weapons he cannot use last (John 2026-10-21)
		if (a.dps ~= nil) ~= (b.dps ~= nil) then return a.dps ~= nil end
		if a.dps and a.dps.score ~= b.dps.score then return a.dps.score > b.dps.score end
		return qualityLess(a, b)
	end
	if t == T.armor then -- best AC first, then quality (John 2026-10-22)
		if a.ac ~= b.ac then return a.ac > b.ac end
		return qualityLess(a, b)
	end
	if t == T.gear then
		local ra, rb = BODY_ORDER[a.type] or 9, BODY_ORDER[b.type] or 9
		if ra ~= rb then return ra < rb end
		return priceLess(a, b)
	end
	if t == T.scroll then
		if a.sub ~= b.sub then return a.sub < b.sub end -- class then level (subRank)
		return priceLess(a, b)
	end
	if t == T.gems or t == T.potion then return priceLess(a, b) end
	if t == T.notes then return a.order < b.order end -- in the order they were found (John 2026-10-22)
	if t == T.quest then return a.order < b.order end -- by date (John 2026-10-22)
	-- misc: known cursed items (scrolls included) last (John)
	if t == T.misc and a.cursed ~= b.cursed then return b.cursed end
	-- ammo, misc: type then price
	if a.type ~= b.type then return a.type < b.type end
	return priceLess(a, b)
end

local function rebuild()
	P.list = PStash_List(P.RES)
	P.view = {}
	local p = shownPortrait()
	local known = knownByAll()
	if P.TABS[P.tab] and P.TABS[P.tab].bags then
		for order, res in ipairs(bagList()) do
			local n, info = bagCount(res), PStash_ItemInfo(res)
			if n > 0 and info then
				P.view[#P.view + 1] = { res = res, bag = true, icon = info.icon, units = n, order = order,
					name = Infinity_FetchString(info.idName), tint = P.tintOk, plus = false,
					desc = validRef(info.idDesc) or validRef(info.unidDesc) or -1, descPic = info.descPic,
					type = 36, price = 0, tabIdx = P.tab, magic = false, enchant = 0, ac = 0, sub = 0, ratio = 0,
					cursed = false }
			end
		end
		P.top = 0
		P.load, P.cap = PStash_Weight()
		P.dirty = false
		P.shownId = id
		return
	end
	local gearTab = tabIndex('Gear')
	-- the anchor of the weapon in hand, remembered per character and per group: an archer stays an archer when he
	-- puts his bow away (John 2026-10-21); lasts for the game session
	local okA, anchor = pcall(weaponAnchor, p)
	local who = EEex_Sprite_GetInPortrait(p)
	P.anchors = P.anchors or {}
	local mine = who and P.anchors[who.m_id] or {}
	if who then P.anchors[who.m_id] = mine end
	if okA and anchor then mine[anchor.launcher] = anchor end
	P.anchor = mine
	for order, e in ipairs(P.list) do
		local info = PStash_ItemInfo(e.res)
		if info and (P.tab == 1 or tabOf(info, e.res, e.identified) == P.tab) then
			local units = info.stack > 1 and math.max(1, e.uses) or 1
			local ok = usable(p, info)
			local itemTab = tabOf(info, e.res, e.identified)
			-- charged items (wands, rods...): the charges left, like the backpack shows them (John 2026-10-21)
			-- (both: charges bottom left, the number of copies bottom right, John 2026-10-22)
			local charged = info.stack == 1 and info.ability and info.ability.charges > 0
			P.view[#P.view + 1] = { res = e.res, icon = info.icon, units = units * math.max(1, e.count),
				name = Infinity_FetchString(e.identified and info.idName or info.unidName),
				order = order, type = info.type, price = info.price,
				-- value per weight unit (John): weightless items first
				ratio = info.weight > 0 and info.price / info.weight or math.huge, tabIdx = tabOf(info, e.res, e.identified),
				magic = info.magical or info.enchant > 0, enchant = info.enchant, ac = (acOf(info)), sub = subRank(info),
				cursed = e.identified and cursedItem(info) or false, charged = charged or nil, charges = charged and e.uses or nil,
				dps = itemTab == tabs().weap and weaponDps(p, info) or nil,
				tint = (not e.identified and P.tintUnid) or (not ok and P.tintBad) or P.tintOk,
				desc = validRef(e.identified and info.idDesc or info.unidDesc) or validRef(info.idDesc)
					or validRef(info.unidDesc) or -1, descPic = info.descPic,
				-- "+": an upgrade for the shown character (not for Gear items: helmets, boots, rings... John), or a
				-- mage scroll a party scribe can still learn.
				plus = e.identified and ((tabOf(info, e.res, e.identified) ~= gearTab and upgrade(p, info))
					or (known ~= nil and info.spell ~= nil
					and string.sub(info.spell, 1, 4) == 'SPWI' and not known[info.spell])) }
		end
	end
	local mode = P.SORTS[P.sort]
	tabs()
	if mode == 'Auto' then
		table.sort(P.view, autoLess)
	elseif mode == 'Quality' then
		table.sort(P.view, function(a, b)
			if a.tabIdx ~= b.tabIdx then return a.tabIdx < b.tabIdx end
			if a.tabIdx == TAB.weap or a.tabIdx == TAB.armor or a.tabIdx == TAB.gear then return qualityLess(a, b) end
			return typeLess(a, b)
		end)
	elseif mode == 'Type' then
		table.sort(P.view, function(a, b)
			if a.tabIdx ~= b.tabIdx then return a.tabIdx < b.tabIdx end
			return typeLess(a, b)
		end)
	elseif mode == 'Price' then
		table.sort(P.view, function(a, b)
			if a.price ~= b.price then return a.price > b.price end
			return a.order < b.order
		end)
	elseif mode == 'Gp/lb' then
		table.sort(P.view, function(a, b)
			if a.ratio ~= b.ratio then return a.ratio > b.ratio end
			if a.price ~= b.price then return a.price > b.price end
			return a.order < b.order
		end)
	end
	if P.reverse then
		-- Date / Price / Gp/lb mix the tabs: the whole list turns over; the others turn over within each tab,
		-- weapons the shown character cannot use staying last
		local function flip(i, j) while i < j do P.view[i], P.view[j] = P.view[j], P.view[i] i, j = i + 1, j - 1 end end
		if mode == 'Date' or mode == 'Price' or mode == 'Gp/lb' then
			flip(1, #P.view)
		else
			local i = 1
			while i <= #P.view do
				local j = i
				while j < #P.view and P.view[j + 1].tabIdx == P.view[i].tabIdx do j = j + 1 end
				local last = j
				if P.view[i].tabIdx == TAB.weap then while last >= i and not P.view[last].dps do last = last - 1 end end
				flip(i, last)
				i = j + 1
			end
		end
	end
	local maxTop = math.max(0, math.ceil(#P.view / P.COLS) - P.ROWS)
	P.top = math.min(P.top, maxTop)
	P.load, P.cap = PStash_Weight()
	P.dirty = false
	P.shownId = id
end

-- Rows shown so far: the page opens with an empty stash grid and reveals one row per frame (the item icons load
-- then, after the page is up, instead of all before the first frame).
P.reveal = P.reveal or P.ROWS
local function cell(i)
	if math.floor(i / P.COLS) >= P.reveal then return nil end
	if P.dirty or not P.list or P.shownId ~= id then rebuild() end
	return P.view[P.top * P.COLS + i + 1]
end

function PStash_CellIcon(i) local c = cell(i) return c and c.icon or nil end
function PStash_CellCount(i) local c = cell(i) return c and c.units > 1 and c.units or nil end
-- Charges of a charged item, bottom left of its cell like the game's inventory (John 2026-10-21). Drawn in the
-- "label" style: a custom style with the BAM font NUMBER crashed the game (0xC0000005, 2026-10-21).
function PStash_CellCharged(i) local c = cell(i) return c ~= nil and c.charged == true end
-- Digit k (0 = first) of a charged item's charges, or nil.
function PStash_ChargeDigit(i, k)
	local c = cell(i)
	if not c or not c.charged then return nil end
	return tonumber(string.sub(tostring(math.min(c.charges or 0, 999)), k + 1, k + 1))
end
-- Name; weapons add their damage per round and THAC0 for the shown character (John 2026-10-21).
function PStash_CellName(i)
	local c = cell(i)
	if not c then return '' end
	if c.dps then
		return c.name .. '\n' .. T('dps_line', string.format('%.1f', c.dps.round), c.dps.thac0)
	end
	return c.name
end
function PStash_CellDesc(i)
	local c = cell(i)
	if not c then return end
	showItemDescription({ name = c.name, description = Infinity_FetchString(c.desc), descPicture = c.descPic,
		icon = c.icon }, 2)
end
function PStash_CellSell(i) local c = cell(i) return c ~= nil and PStash_IsMarked(c.res) end
function PStash_CellValuable(i) local c = cell(i) return c ~= nil and PStash_IsValuable(c.res) end
-- Valuable items: old gold over the cell (15 %); to sell: the cell darkened (45 %) and the icon in greyscale
-- (John 2026-10-22).
local TINT_VALUABLE, TINT_SELL = 'PSTASHOR', 'PSTASHDK'
function PStash_CellTint(i)
	local c = cell(i)
	if not c then return nil end
	if not c.bag and PStash_IsValuable(c.res) then return TINT_VALUABLE end
	if not c.bag and PStash_IsMarked(c.res) then return TINT_SELL end
	return c.tint
end
function PStash_CellGrey(i) local c = cell(i) return c ~= nil and not c.bag and PStash_IsMarked(c.res) end
function PStash_CellPlus(i) local c = cell(i) return c ~= nil and c.plus == true end

local SORT_KEY = { Auto = 'sort_auto', Date = 'sort_date', Quality = 'sort_quality', Type = 'sort_type',
	Price = 'sort_price', ['Gp/lb'] = 'sort_gplb' }
-- Auto says what it sorts by on the shown tab (John 2026-10-22): "Auto (DPS)".
local AUTO_BY = { weap = 'sort_dps', armor = 'ab_ac', gear = 'sort_type', ammo = 'sort_type', gems = 'sort_price',
	scroll = 'sort_level', potion = 'sort_price', quest = 'sort_date', notes = 'sort_date', misc = 'sort_type' }
function PStash_SortText()
	local mode = P.SORTS[P.sort]
	local by = ''
	if mode == 'Auto' then
		for k, idx in pairs(tabs()) do
			if idx == P.tab and AUTO_BY[k] then by = ' (' .. T(AUTO_BY[k]) .. ')' end
		end
	end
	return T('sort_prefix') .. T(SORT_KEY[mode] or mode) .. by .. (P.reverse and T('sort_rev') or '')
end
-- Right click on the sort button: the same sort, reversed (John 2026-10-22).
function PStash_ReverseSort()
	P.reverse = not P.reverse
	P.help = nil
	rebuild()
end
-- A click on the sort button closes its help panel (John 2026-10-22: the player wants to see the grid); the panel
-- comes back when the mouse leaves the button and enters it again (actionEnter).
function PStash_CycleSort()
	P.sort = P.sort % #P.SORTS + 1
	P.help = nil
	rebuild()
end

-- Stats popup: toggled by the [Stats] button, shown by itself while comparing an item (tempStats).
P.showStats = P.showStats or false
function PStash_ToggleStats() P.showStats = not P.showStats end
function PStash_StatsShown() return P.showStats end
function PStash_Comparing() return not P.showStats and tempStats ~= nil and tempStats[id] ~= nil end

function PStash_Scroll()
	local rows = math.ceil(#P.view / P.COLS)
	if scrollDirection > 0 then P.top = math.max(0, P.top - 1)
	elseif scrollDirection < 0 then P.top = math.min(math.max(0, rows - P.ROWS), P.top + 1) end
end

function PStash_TabScroll(d)
	P.tabTop = math.max(0, math.min(#P.TABS - P.TAB_VIS, P.tabTop + d))
end
-- Mouse wheel over the tab bar (John): up = left, down = right.
function PStash_TabWheel()
	if scrollDirection > 0 then PStash_TabScroll(-1) elseif scrollDirection < 0 then PStash_TabScroll(1) end
end
function PStash_TabCanScroll(d)
	local t = P.tabTop + d
	return t >= 0 and t <= #P.TABS - P.TAB_VIS
end

function PStash_SetTab(i)
	i = i + P.tabTop
	if not PStash_TabUnlocked(i) then return end
	P.tab, P.top, P.msg = i, 0, ''
	rebuild()
end

function PStash_TabText(i)
	i = i + P.tabTop
	local t = P.TABS[i]
	if not t then return '' end
	return (P.tab == i and '^G' or '') .. T(t.key or t.label)
end

-- Party weight next to the bag: carried / sum of allowances (a message replaces it for a moment).
function PStash_WeightText()
	if P.reveal < P.ROWS then P.reveal = P.reveal + 1 end
	if P.refreshPending then
		P.refreshPending = false
		pcall(Infinity_ActivateInventory)
	end
	if P.dirty or not P.list or P.shownId ~= id then rebuild() end
	if P.msg ~= '' then return P.msg end
	return string.format('%d / %d lb', P.load or 0, P.cap or 0)
end
-- John: the bag keeps its leather colour; being overloaded shows in the weight text, in red.
function PStash_BagFrame() return 0 end
function PStash_Overloaded() return (P.load or 0) > (P.cap or 0) end
function PStash_NotOverloaded() return not PStash_Overloaded() end
-- A red for menu texts ("text color P"): an entry of the game's font colour table (AABBGGRR).
if fontcolors then fontcolors['P'] = 'FF3C3CE6' end
-- Tooltips do not wrap: long texts are cut into lines of about `width` characters, at spaces (UTF-8 aware; a text
-- without spaces, Chinese / Japanese, is cut anywhere).
local function wrap(text, width)
	local out, line, n = {}, {}, 0
	local function flush() if #line > 0 then out[#out + 1] = table.concat(line) end line, n = {}, 0 end
	for word, space in string.gmatch(text, '([^ ]+)( ?)') do
		local len = 0
		for _ in string.gmatch(word, '[%z\1-\127\194-\244][\128-\191]*') do len = len + 1 end
		if n > 0 and n + len > width then flush() end
		if len > width then
			for ch in string.gmatch(word, '[%z\1-\127\194-\244][\128-\191]*') do
				if n >= width then flush() end
				line[#line + 1], n = ch, n + 1
			end
		else
			line[#line + 1], n = word, n + len
		end
		if space ~= '' and n > 0 then line[#line + 1], n = ' ', n + 1 end
	end
	flush()
	for i, l in ipairs(out) do out[i] = string.gsub(l, ' +$', '') end
	return table.concat(out, '\n')
end

function PStash_WeightTooltip()
	return wrap(T('weight_tip'), 55) .. '\n' .. wrap(T('bag_tip'), 55)
end
-- Hover help panels (PSTASH.menu, John): P.help = the hovered element ('bag', 'storeall', 'sort', 'bags', 'sell').
P.help = nil
function PStash_Help(k) P.help = k end
function PStash_HelpIs(k)
	if P.help ~= k then return false end
	local inv = EEex_EngineGlobal_CBaldurChitin.m_pEngineInventory
	return not (inv and inv.m_pTempItem)
end
function PStash_TabHover(i)
	local t = P.TABS[i + P.tabTop]
	P.help = t and t.bags and 'bags' or nil
end
-- Help overlay (John 2026-10-22): the "?" button shows bubbles with arrows over the whole page, one per zone; a
-- click anywhere (or the button again) closes it. Bubble texts: a gold title, then one bullet per line, keys in green.
P.helpAll = false
function PStash_ToggleHelp() P.helpAll = not P.helpAll P.help = nil end
function PStash_HelpAll() return P.helpAll == true end
local BUBBLE = {
	weight = { 'bubble_weight_t', function()
		return T('weight_tip') .. '\n' .. TRaw('bag_tip')
	end },
	pack = { 'help_pack_title', function() return TRaw('help_pack') end },
	stash = { 'help_stash_title', function() return TRaw('help_stash') end },
	tabs = { 'bubble_tabs_t', function() return TRaw('bubble_tabs') end },
	sort = { 'bubble_sort_t', function() return TRaw('help_sort') end },
	ground = { 'bubble_ground_t', function() return TRaw('bubble_ground') end },
}
function PStash_BubbleTitle(k) return BUBBLE[k] and (PStash_Gold .. T(BUBBLE[k][1]) .. '^-') or '' end
function PStash_BubbleText(k)
	if not BUBBLE[k] then return '' end
	local out = {}
	for line in string.gmatch(PStash_GreenKeys(BUBBLE[k][2]()) .. '\n', '(.-)\n') do
		if string.find(line, '%S') then out[#out + 1] = '• ' .. line end
	end
	return table.concat(out, '\n')
end

-- older menus (a hot reload over an older page)
function PStash_BagHover(on) P.help = on and 'bag' or nil end
function PStash_BagHovering() return PStash_HelpIs('bag') end
-- Keybinds in green (John): in each sentence, what comes before its colon ("Ctrl + click: ..."), or only the
-- part in brackets when there is one ("Store a bag (Shift + double-click or Store all): ..."). ^G...^- is the
-- game's colour markup (it renders in button texts: the help panels are buttons).
local GOLD = '^0xff5cc3e6' -- labels ('*' lines) and the help bubbles' titles; the engine reads 0xAABBGGRR
local function greenKeys(text)
	local out = {}
	for line in string.gmatch(text .. '\n', '(.-)\n') do
		local colour = '^G'
		if string.sub(line, 1, 1) == '*' then colour, line = GOLD, string.sub(line, 2) end
		local parts = {}
		for raw, sep in string.gmatch(line .. '. ', '(.-)(%. )') do
			local sentence = raw
			local cut = string.find(sentence, ':', 1, true) or string.find(sentence, '\239\188\154', 1, true)
			if cut then
				local key, rest = string.sub(sentence, 1, cut - 1), string.sub(sentence, cut)
				local o, c = string.find(key, '%b()')
				if o then
					key = string.sub(key, 1, o) .. colour .. string.sub(key, o + 1, c - 1) .. '^-' .. string.sub(key, c)
				else
					local lead, body = string.match(key, '^(%s*)(.-)%s*$')
					local tail = string.sub(key, #lead + #body + 1)
					key = lead .. colour .. body .. '^-' .. tail
				end
				sentence = key .. rest
			end
			parts[#parts + 1] = sentence .. sep
		end
		local l = table.concat(parts)
		out[#out + 1] = string.sub(l, 1, #l - 2) -- the '. ' added above
	end
	return table.concat(out, '\n')
end
PStash_GreenKeys = greenKeys -- the help overlay's bubbles, defined above
PStash_Gold = GOLD

function PStash_HelpText(k)
	-- no manual wrap here: the panel's text wraps by itself (wrap() cut the "Key: text" lines, John)
	if k == 'weight' then
		return T('weight_tip') .. '\n' .. greenKeys(TRaw('bag_tip'))
	end
	if k == 'pack' then return T('help_pack_title') .. '\n' .. greenKeys(TRaw('help_pack')) end
	if k == 'stash' then return T('help_stash_title') .. '\n' .. greenKeys(TRaw('help_stash')) end
	if k == 'storeall' or k == 'bags' then return greenKeys(TRaw('help_' .. k)) end
	if k == 'sell' and PStash_SellHelp then return PStash_SellHelp() end
	return T('help_' .. k)
end

-- The inventory page reads the engine's item tables: rebuild them after we move items behind its back.
-- Page closed: nothing to do, the engine rebuilds them when it opens (a pending refresh would cost a second full
-- rebuild at the next opening, 0.5-1 s).
local function refreshInventory()
	if not Infinity_IsMenuOnStack('INVENTORY') then return end
	pcall(Infinity_ActivateInventory)
	P.refreshPending = true -- done again from the page's next frame (a call from the tick is not always applied)
end

-- The item in the player's hand (inventory screen), or nil.
local function heldItem()
	local inv = EEex_EngineGlobal_CBaldurChitin.m_pEngineInventory
	return inv and inv.m_pTempItem or nil
end

-- A bag in hand: the game will not drop it on the stash (no bag in a bag); say how to add it.
function bagInHandHint()
	local held = heldItem()
	local res = held and string.upper(held.pRes.resref:get())
	local info = res and PStash_ItemInfo(res)
	if info and info.type == 36 and res ~= P.RES then
		P.msg = T('msg_bag_hint')
	end
end

-- Click on the stash grid with an item in hand: the item goes into the stash and the hand is emptied.
function PStash_StoreHeld()
	local inv = EEex_EngineGlobal_CBaldurChitin.m_pEngineInventory
	local item = inv and inv.m_pTempItem
	if not item or not PStash_Ready() then return false end
	local res = string.upper(item.pRes.resref:get())
	local info = PStash_ItemInfo(res)
	if P.KEEP[res] or (info and (info.critical or info.type == 36)) then
		P.msg = T('msg_quest_bags')
		return true
	end
	local itemPtr, game, buf = EEex_UDToPtr(item), gamePtr(), P.scratch
	EEex_Write32(buf + 24, -1)
	if PStash_Eng_AddItemToStore(game, resRef(P.RES), itemPtr, buf + 24) % 256 == 0 then
		P.msg = string.format('refused (0x%x)', EEex_ReadU32(buf + 24))
		return true
	end
	pcall(function() inv.m_pTempItem = nil end)
	if inv.m_pTempItem then
		-- The hand kept it: undo the copy in the stash (no duplicate, no freed item still in use).
		PStash_Eng_TakeItemFromStore(game, resRef(P.RES), resRef(res, 32), 1)
		P.msg = T('msg_hand')
		return true
	end
	PStash_Eng_AddDisposableItem(game, itemPtr)
	-- The item icon stays on the mouse until the cursor is redrawn: force the normal cursor now.
	pcall(function()
		local c = EEex_EngineGlobal_CBaldurChitin.m_pObjectCursor
		c:SetCursor(2, true, -1) -- a different cursor first, so the switch back really redraws it
		c:SetCursor(0, true, -1)
	end)
	P.dirty = true
	rebuild()
	refreshInventory()
	return true
end

-- Dropping on the stash: menu buttons get no clicks while an item is in hand, so while the player holds one a
-- REAL slot widget bound to the drop slot (backpack slot 16) covers the whole stash grid (PSTASH.menu). The game
-- drops the item there itself (cursor and all) and drainDropSlot moves it into the stash. No mouse maths.
function PStash_Holding()
	local holding = heldItem() ~= nil
	local now = Infinity_GetClockTicks()
	-- The hand just emptied (maybe a native drop into the Stash bag): rebuild now and once more a bit later,
	-- the engine may store the item a frame after.
	if P.wasHolding and not holding then
		P.dirty = true
		P.recheckAt = now + 300
	elseif P.recheckAt and now >= P.recheckAt then
		P.recheckAt = nil
		P.dirty = true
	end
	P.wasHolding = holding
	if holding and Infinity_IsMenuOnStack('INVENTORY') then pcall(bagInHandHint) end
	return holding
end

-- What the overlay slot shows: the last slot's data marked empty (no chest icon drawn over the grid); the engine
-- still drops on the real slot (it goes by the widget name, slot_inv_45).
-- The last backpack slot (the stash item): the game's slot data, with a tooltip saying what the item is for.
-- One table, refilled in place: a new table every frame made the engine reopen the tooltip in a loop (the scroll
-- sound over and over, John).
P.stashSlot = P.stashSlot or {}
function PStash_StashSlot()
	local real = characters and characters[id] and characters[id].equipment.group15
	if not (real and real.item and string.upper(real.item.res or '') == P.RES) then return real end
	local t = P.stashSlot
	for k in pairs(t) do if real[k] == nil then t[k] = nil end end
	for k, v in pairs(real) do t[k] = v end
	t.tooltip = T('stash_slot_tip')
	return t
end

function PStash_OverlaySlot()
	local real = characters and characters[id] and characters[id].equipment.group15
	local t = {}
	for k, v in pairs(real or {}) do t[k] = v end
	t.empty, t.tooltip, t.highlight = 1, '', 0
	t.item = { count = 0, usages = 0, icon = '', tint = '', name = '', identified = 1 }
	return t
end

-- Backpack and equipped items behave like stash items (John 2026-10-22): marks (Ctrl + click), gold coin / gold rim,
-- and weapons' damage per round in their tooltip. Slot names (UI.MENU slotinfo) -> m_items index.
local SLOT_INDEX = { amulet = 0, armor = 1, belt = 2, boots = 3, cloak = 4, gauntlets = 5, helmet = 6, ringleft = 7,
	ringright = 8, shield = 9, quiver0 = 11, quiver1 = 12, quiver2 = 13, personal0 = 15, personal1 = 16, personal2 = 17,
	weapon0 = 35, weapon1 = 36, weapon2 = 37, weapon3 = 38 }
for k = 0, 15 do SLOT_INDEX['group' .. k] = 18 + k end

-- Item type in a slot of the shown character, or nil.
function PStash_SlotRes(name)
	local sp = EEex_Sprite_GetInPortrait(shownPortrait())
	local idx = SLOT_INDEX[name]
	local it = sp and idx and sp.m_equipment.m_items:get(idx)
	return it and string.upper(it.pRes.resref:get()) or nil
end
function PStash_SlotMark(name)
	local res = PStash_SlotRes(name)
	return res and ((PStash_IsValuable(res) and 2) or (PStash_IsMarked(res) and 1)) or 0
end
function PStash_CtrlDown()
	return EEex_Key_IsDown(EEex_Key_GetFromName('Left Ctrl')) or EEex_Key_IsDown(EEex_Key_GetFromName('Right Ctrl'))
end
function PStash_AltDown()
	return EEex_Key_IsDown(EEex_Key_GetFromName('Left Alt')) or EEex_Key_IsDown(EEex_Key_GetFromName('Right Alt'))
end
-- Ctrl or Alt down: a click marks instead of taking (Ctrl = to sell, Alt = valuable).
function PStash_MarkKeyDown() return PStash_CtrlDown() or PStash_AltDown() end
-- Ctrl / Alt + click on a backpack / equipment slot (a button over it, enabled only while one is down).
-- A backpack item just marked to sell goes straight to the stash, where Sell Marked sells it (John 2026-10-22): an
-- item taken out of a backpack slot while a store is open crashed the game, so not at a store.
function PStash_SlotToggle(name)
	local res = PStash_SlotRes(name)
	if not res then return end
	PStash_ToggleMark(res)
	P.saleCache, P.dirty = {}, true
	local idx = SLOT_INDEX[name]
	if PStash_IsMarked(res) and idx >= 18 and idx <= 33 and e:GetActiveEngine() ~= storeScreen then
		if PStash_Add(shownPortrait(), idx) then P.list = nil rebuild() refreshInventory() end
	end
end

-- An item in hand that is valuable: the ground column refuses it (John 2026-10-22: never dropped on the floor).
function PStash_HoldingValuable()
	local it = heldItem()
	return it ~= nil and PStash_IsValuable(string.upper(it.pRes.resref:get()))
end
function PStash_RefuseGround() P.msg = T('msg_valuable_ground') end

-- Weapons' tooltips in the backpack and weapon slots: the engine's text + "x dmg/round, THAC0 y" for the shown
-- character. The engine's own tables are edited in place (a new slotinfo table every frame made tooltips loop),
-- from a label's "enabled" check evaluated every frame before the slots draw; the figures are cached 1 s.
local TIP_SLOTS = { 'weapon0', 'weapon1', 'weapon2', 'weapon3', 'shield' }
for k = 0, 15 do TIP_SLOTS[#TIP_SLOTS + 1] = 'group' .. k end
P.tipLine = P.tipLine or {}
function PStash_DecorateTooltips()
	local eq = characters and characters[id] and characters[id].equipment
	if not eq then return false end
	local now, p = Infinity_GetClockTicks(), shownPortrait()
	if not P.tipAt or now - P.tipAt > 1000 or P.tipFor ~= id then P.tipLine, P.tipAt, P.tipFor = {}, now, id end
	-- marked items: their tint on the slot too (the engine's slot table edited in place, its own tint kept)
	P.slotTint = P.slotTint or {}
	for name in pairs(SLOT_INDEX) do
		local s = eq[name]
		local item = s and s.item
		if item then
			local res = PStash_SlotRes(name)
			local want = res and ((PStash_IsValuable(res) and 'PSTASHOR') or (PStash_IsMarked(res) and 'PSTASHDK')) or nil
			local ours = item.tint == 'PSTASHOR' or item.tint == 'PSTASHDK'
			if want then
				if item.tint ~= want then
					if not ours then P.slotTint[name] = item.tint end
					item.tint = want
				end
			elseif ours then
				item.tint = P.slotTint[name] or ''
			end
		end
	end
	for _, name in ipairs(TIP_SLOTS) do
		local s = eq[name]
		local res = s and s.tooltip and s.tooltip ~= '' and PStash_SlotRes(name)
		if res then
			local line = P.tipLine[res]
			if line == nil then
				local d = weaponDps(p, PStash_ItemInfo(res))
				line = d and T('dps_line', string.format('%.1f', d.round), d.thac0) or false
				P.tipLine[res] = line
			end
			-- the engine keeps its slot table: the line added before goes first when the figure changed (John: two DPS
			-- lines once the off hand was filled)
			P.tipAdded = P.tipAdded or {}
			local old = P.tipAdded[name]
			if old and old ~= line then
				local cut = '\n' .. old
				if string.sub(s.tooltip, -#cut) == cut then s.tooltip = string.sub(s.tooltip, 1, #s.tooltip - #cut) end
				P.tipAdded[name] = nil
			end
			if line and not string.find(s.tooltip, line, 1, true) then
				s.tooltip = s.tooltip .. '\n' .. line
				P.tipAdded[name] = line
			end
		end
	end
	return false
end

-- The old raw-SDL drop (mouse coordinates were unreliable: their origin depends on the open menus) is retired;
-- a hook left over from a hot reload calls this and gets "not handled".
function PStash_MouseEvent() return false end

-- Click: one unit to the shown character's backpack. Double-click: same, then equip it.
function PStash_CellClick(i, equip)
	if heldItem() then PStash_StoreHeld() return end
	-- a companion shown (companion bar): the item goes to its backpack
	if PStash_CompShown and PStash_CompShown() then
		local c = cell(i)
		if c and not c.bag and P.compTake then P.compTake(c.res) end
		return
	end
	local c = cell(i)
	if not c then return end
	if c.bag then P.msg = T('msg_bags_kept') return end
	-- Ctrl + click: mark / unmark the item for sale; Alt + click: valuable (John 2026-10-24), instead of taking it.
	if PStash_MarkKeyDown() then
		PStash_ToggleMark(c.res)
		return
	end
	local p = shownPortrait()
	local slot, why = PStash_Take(p, c.res)
	if not slot then P.msg = why return end
	if equip then
		EEex_Action_ExecuteResponseStringOnAIBaseInstantly(
			string.format('XEquipItem("%s",Myself,%d,EQUIP)', c.res, slot), EEex_Sprite_GetInPortrait(p))
	end
	rebuild()
	refreshInventory()
	if not equip then
		-- Put it in the player's hand, like picking it from a slot: the engine's split-stack call takes a whole
		-- backpack slot onto the cursor (UI slot widget slot_inv_<30 + n> is backpack slot 18 + n).
		local ui = 30 + slot - 18
		local s = characters[id] and characters[id].equipment['group' .. (slot - 18)]
		local count = s and s.item and s.item.count or 0
		pcall(Infinity_SplitItemStack, ui, math.max(1, count), 'slot_inv_' .. ui)
	end
end

-- Shift + double-click on a backpack slot (UI.MENU slotDoubleClick hook): send it to the stash.
function PStash_SlotDoubleClick(slotName)
	local n = tonumber(string.match(slotName or '', '^group(%d+)$'))
	if not n or not (EEex_Key_IsDown(EEex_Key_GetFromName('Left Shift'))
		or EEex_Key_IsDown(EEex_Key_GetFromName('Right Shift'))) then
		return false
	end
	local p = shownPortrait()
	local sp = EEex_Sprite_GetInPortrait(p)
	local it = sp and sp.m_equipment.m_items:get(18 + n)
	local info = it and PStash_ItemInfo(string.upper(it.pRes.resref:get()))
	if info and info.type == 36 then
		local res = string.upper(it.pRes.resref:get())
		if res ~= P.RES and hasStore(res) then P.requestBags({ it }) end
		return true
	end
	local ok, why = PStash_Add(p, 18 + n)
	P.msg = ok and '' or why
	rebuild()
	refreshInventory()
	return true
end

-----------------
-- Bags        --
-----------------

-- Pours the contents of bag store `res` into the stash through `p`'s backpack (one free slot is enough).
-- Returns true when the bag is empty; what is left is retried by the tick (P.pour).
local function pourBag(p, res)
	for _ = 1, 500 do
		local list = PStash_List(res)
		if #list == 0 then P.pour[res] = nil return true end
		local slot, why = PStash_Take(p, list[1].res, res)
		if not slot then P.pour[res] = true P.msg = T('msg_bag_contents') .. tostring(why) return false end
		PStash_Add(p, slot)
	end
	P.pour[res] = true
	return false
end
P.pour = P.pour or {}

-- Collects the bag in backpack slot `slot` of portrait `p`: the item goes, its contents go to the stash, the count
-- grows. Public for the bot (no confirmation). Returns true or nil + reason.
function PStash_CollectBag(p, slot)
	local sp = EEex_Sprite_GetInPortrait(p)
	local it = sp and sp.m_equipment.m_items:get(slot)
	if not it then return nil, 'empty slot' end
	local res = string.upper(it.pRes.resref:get())
	local info = PStash_ItemInfo(res)
	if not info or info.type ~= 36 or res == P.RES then return nil, 'not a bag' end
	if not hasStore(res) then return nil, 'not a container bag' end
	sp.m_equipment.m_items:set(slot, nil)
	PStash_Eng_AddDisposableItem(gamePtr(), EEex_UDToPtr(it))
	recordBag(res)
	setBagCount(res, bagCount(res) + 1)
	pourBag(p, res)
	P.list, P.dirty = nil, true
	return true
end

-- Bags waiting for the player's OK (by item pointer: they may move between slots meanwhile).
P.pendingBags = P.pendingBags or {}
local function collectPending()
	for p = 0, lastPortrait() do
		local sp = EEex_Sprite_GetInPortrait(p)
		if sp then
			for i = 18, 33 do
				local it = sp.m_equipment.m_items:get(i)
				if it and P.pendingBags[EEex_UDToPtr(it)] then PStash_CollectBag(p, i) end
			end
		end
	end
	P.pendingBags = {}
	P.dirty = true
	rebuild()
	refreshInventory()
end

-- Asks once (the game's two-button popup) before collecting the given bag items. The bot collects without asking.
local function requestBags(items)
	if #items == 0 then return end
	if BGBot and BGBot.enabled then
		for _, it in ipairs(items) do P.pendingBags[EEex_UDToPtr(it)] = true end
		collectPending()
		return
	end
	for _, it in ipairs(items) do P.pendingBags[EEex_UDToPtr(it)] = true end
	if Infinity_IsMenuOnStack('POPUP_TWOBUTTON') then return end
	Popup2Button = {
		info = T('bags_warning'),
		okText = T('bags_ok'),
		okFunc = function() pcall(collectPending) end,
		cancelFunc = function() P.pendingBags = {} end,
	}
	Infinity_PushMenu('POPUP_TWOBUTTON')
end
P.requestBags = requestBags

-- Contents left in a collected bag (backpack was full): poured as soon as there is room.
local function pourLeftovers()
	for res in pairs(P.pour) do
		if bagCount(res) > 0 then
			for p = 0, lastPortrait() do
				local sp = EEex_Sprite_GetInPortrait(p)
				if sp and freeSlot(sp) then pourBag(p, res) break end
			end
		else
			P.pour[res] = nil
		end
	end
end

-- "Store all" rule: every backpack item except the stash itself, bags and quest items. Returns how many moved.
local function storeAllFor(p, forBot, bags)
	local sp = EEex_Sprite_GetInPortrait(p)
	if not sp then return 0 end
	local n = 0
	for i = 18, 33 do
		local it = sp.m_equipment.m_items:get(i)
		if it then
			local res = string.upper(it.pRes.resref:get())
			local info = PStash_ItemInfo(res)
			-- valuable items stay where the player put them (John 2026-10-22)
			local kept = (forBot and botKeep(res) or P.KEEP[res]) or PStash_IsValuable(res)
			if info and info.type == 36 and res ~= P.RES and not kept and hasStore(res) then
				-- a bag: collected (bot) or listed for the player's confirmation
				if forBot then if PStash_CollectBag(p, i) then n = n + 1 end
				elseif bags then bags[#bags + 1] = it end
			elseif res ~= P.RES and not kept and info and not info.critical and info.type ~= 36 then
				if PStash_Add(p, i) then n = n + 1 end
			end
		end
	end
	return n
end

-- "Store all" button: the shown character.
function PStash_StoreAll()
	local bags = {}
	storeAllFor(shownPortrait(), false, bags)
	rebuild()
	refreshInventory()
	requestBags(bags)
end

-- "Store all" for the whole party, for the bot (John: the addon itself never stores on its own). Returns the count.
-- Public API: BGBot_AutoStash (M_BGBOT.lua) calls it, keep the name and contract.
function PStash_StoreAllParty()
	local n = 0
	for p = 0, lastPortrait() do n = n + storeAllFor(p, true) end
	if n > 0 then P.list, P.dirty = nil, true end
	refreshInventory()
	return n
end

-----------------
-- Auto store  --
-----------------

-- John: looted items go straight to the stash, except bags, quest items, unidentified items, ammo (quivers are
-- refilled from the backpack) and rare items: magical/enchanted, named (unique), worth more than RARE_PRICE,
-- or an upgrade for someone in the party.
P.RARE_PRICE = 500
local AMMO = { [5] = true, [14] = true, [31] = true }

local function named(info)
	if info.idName == info.unidName or info.idName <= 0 or info.unidName <= 0 then return false end
	return Infinity_FetchString(info.idName) ~= Infinity_FetchString(info.unidName)
end

-- Consumables and valuables (potions 9, scrolls 11, gems 34, misc 0, books 37...) are never "rare": they always
-- went to the bags. Rarity only matters for gear that can be worn or wielded.
local CONSUMABLE = { [0] = true, [9] = true, [11] = true, [34] = true, [37] = true, [35] = true }

function PStash_IsRare(res)
	local info = PStash_ItemInfo(res)
	if not info then return true end
	if CONSUMABLE[info.type] then return false end
	-- Plain jewelry ("Anneau d'or") has a specific name too: only its magic or an upgrade makes it rare.
	local jewel = info.type == 1 or info.type == 10
	if info.magical or info.enchant > 0 or (not jewel and (info.price > P.RARE_PRICE or named(info))) then return true end
	for p = 0, lastPortrait() do
		if EEex_Sprite_GetInPortrait(p) then
			local ok, gain = pcall(compare, p, info)
			if ok and gain and gain > 0 then return true end
		end
	end
	return false
end

-- Backpack item `it` may go to the stash on its own.
local function autoStorable(it)
	local res = string.upper(it.pRes.resref:get())
	local info = PStash_ItemInfo(res)
	if not info or EEex_BAnd(it.m_flags, 1) == 0 then return false end -- unidentified
	if botKeep(res) or info.critical or info.type == 36 or AMMO[info.type] or res == P.RES then return false end
	return not PStash_IsRare(res)
end

-- Stores every auto-storable backpack item of the party (the bot calls this after its loots). Returns the resrefs.
function PStash_AutoStoreAll()
	local done = {}
	if not PStash_Ready() then return done end
	for p = 0, lastPortrait() do
		local sp = EEex_Sprite_GetInPortrait(p)
		if sp then
			for i = 18, P.DROP_SLOT - 1 do
				local it = sp.m_equipment.m_items:get(i)
				if it and autoStorable(it) then
					local res = string.upper(it.pRes.resref:get())
					if PStash_Add(p, i) then done[#done + 1] = res end
				end
			end
		end
	end
	return done
end

-- Hand play (bot OFF): whatever newly lands in a backpack is checked once and stored if allowed (the first look
-- after a load checks everything). Not while the inventory or a store is open (the player sorts by hand there).
P.seen = P.seen or {}
local function autoStoreNew()
	local busy = (BGBot and BGBot.enabled) or Infinity_IsMenuOnStack('INVENTORY')
		or e:GetActiveEngine() == storeScreen
	for p = 0, lastPortrait() do
		local sp = EEex_Sprite_GetInPortrait(p)
		if sp then
			local now, old = {}, P.seen[sp.m_id]
			for i = 18, P.DROP_SLOT do
				local it = sp.m_equipment.m_items:get(i)
				if it then
					local ptr = EEex_UDToPtr(it)
					now[ptr] = true
					if not (old and old[ptr]) and not busy and i < P.DROP_SLOT and autoStorable(it) then
						if PStash_Add(p, i) then now[ptr] = nil end
					end
				end
			end
			P.seen[sp.m_id] = now
		end
	end
end

-----------------
-- Stats 2x2   --
-----------------

-- John: shorter terms in the stats blocks (the engine's French and English labels).
P.SHORT = {
	{ 'TACO main principale', 'Main princ.' }, { 'TAC0 main principale', 'Main princ.' },
	{ 'TACO main secondaire', 'Main sec.' }, { 'TAC0 main secondaire', 'Main sec.' },
	{ 'TACO deuxième main', 'Main sec.' }, { 'TAC0 deuxième main', 'Main sec.' }, { 'Deux armes', '2 armes' },
	{ 'main principale', 'main princ.' }, { 'main secondaire', 'main sec.' }, { 'Force', 'For' },
	{ 'Main Hand THAC0', 'Main' }, { 'Off Hand THAC0', 'Off' }, { 'Off%-hand THAC0', 'Off' }, { 'Strength', 'Str' },
	{ "Modificateurs de classe d'armure", 'Modif. CA' }, { "Classe d'[Aa]rmure", 'CA' },
	{ 'Modification de la dextérité', 'Dex' }, { 'Dextérité', 'Dex' },
	{ 'Modification de la force', 'For' }, { 'Ajustement projectiles', 'Proj.' },
	{ 'Classe Points de vie/Niveau', 'PV/niv' }, { 'Bonus Points de vie/Niveau', 'Bonus PV/niv' },
	{ 'Points de vie', 'PV' }, { 'Compétences', 'Comp.' }, { 'TAC0 de base', 'TAC0 base' },
	{ 'TACO de base', 'TAC0 base' }, { 'Modificateurs', 'Modif.' },
	{ 'Armor Class', 'AC' }, { 'Dexterity', 'Dex' }, { 'Missile Adjustment', 'Missile' },
	{ 'Hit Points', 'HP' }, { 'Proficiency', 'Prof.' }, { 'Base THAC0', 'THAC0 base' },
}

-- Slot names in the AC details (John 2026-10-19: the body part, "Torse CA", "Cou", "Anneau").
local function slotLabels()
	return { [0] = T('slot_neck'), [1] = T('slot_torso'), [2] = T('slot_belt'), [3] = T('slot_boots'),
		[4] = T('slot_cloak'), [5] = T('slot_gloves'), [6] = T('slot_helmet'), [7] = T('slot_ring'),
		[8] = T('slot_ring'), [9] = T('slot_shield'), ammo = T('slot_ammo'), weapon = T('slot_weapon'),
		offhand = T('slot_offhand'), bow = T('slot_bow'), xbow = T('slot_xbow'), sling = T('slot_sling') }
end

-- Names of the shown character's equipped items, mapped to their slot label (longest names first).
local function equippedNames()
	local sp = EEex_Sprite_GetInPortrait(shownPortrait())
	local out, L = {}, slotLabels()
	if not sp then return out end
	local function add(slot, label)
		local it = sp.m_equipment.m_items:get(slot)
		local info = it and PStash_ItemInfo(it.pRes.resref:get())
		if info and info.idName > 0 then out[#out + 1] = { Infinity_FetchString(info.idName), label } end
		return info
	end
	for slot = 0, 8 do add(slot, L[slot]) end
	local off = sp.m_equipment.m_items:get(9)
	local offInfo = off and PStash_ItemInfo(off.pRes.resref:get())
	add(9, offInfo and offInfo.ability and offInfo.type ~= 12 and offInfo.type ~= 41 and offInfo.type ~= 47
		and offInfo.type ~= 49 and offInfo.type ~= 53 and L.offhand or L[9])
	for slot = 11, 13 do add(slot, L.ammo) end
	for slot = 35, 38 do
		local it = sp.m_equipment.m_items:get(slot)
		local info = it and PStash_ItemInfo(it.pRes.resref:get())
		if info then
			add(slot, info.type == 15 and L.bow or info.type == 27 and L.xbow or info.type == 18 and L.sling or L.weapon)
		end
	end
	table.sort(out, function(a, b) return #a[1] > #b[1] end)
	return out
end

local function replacePlain(text, old, new)
	if old == '' then return text end
	local i, out = 1, {}
	while true do
		local a, b = string.find(text, old, i, true)
		if not a then break end
		out[#out + 1] = string.sub(text, i, a - 1) .. new
		i = b + 1
	end
	out[#out + 1] = string.sub(text, i)
	return table.concat(out)
end

-- First `n` letters (UTF-8 characters, not bytes).
local function firstLetters(str, n)
	local out, k = {}, 0
	for ch in string.gmatch(str or '', '[%z\1-\127\194-\244][\128-\191]*') do
		k = k + 1
		if k > n then break end
		out[k] = ch
	end
	return table.concat(out)
end
local function escapePattern(str) return (string.gsub(str, '[%^%$%(%)%%%.%[%]%*%+%-%?]', '%%%0')) end

-- The 6 attributes (strrefs 1145 STR, 1151 DEX, 1178 CON, 1179 INT, 1180 WIS, 1181 CHA): first 3 letters
-- of the game's own name (John: Str/Dex/Con, For/Dex/Con in French).
local ATTR_REF = { str = 1145, dex = 1151, con = 1178, int = 1179, wis = 1180, cha = 1181 }
local function attr(k) return firstLetters(Infinity_FetchString(ATTR_REF[k]), 3) end

-- Engine labels of the stats details, by strref, and their short form (tra).
local LABEL_REF = {
	{ 24182, 'ab_main_hand' }, { 24181, 'ab_off_hand' }, { 25023, 'ab_two_weapon' }, { 11766, 'ab_ac_mods' },
	{ 14024, 'dex' }, { 14042, 'str' }, { 10340, 'ab_missile' }, { 8442, 'ab_prof' }, { 24180, 'ab_base_thac0' },
	{ 10339, 'ab_ac' },
}
local function shortRules()
	if P.shortRules then return P.shortRules end
	local rules = {}
	for _, r in ipairs(LABEL_REF) do
		local full = Infinity_FetchString(r[1])
		if full and full ~= '' then
			local abbr = ATTR_REF[r[2]] and attr(r[2]) or T(r[2])
			rules[#rules + 1] = { escapePattern(full), (string.gsub(abbr, '%%', '%%%%')) }
		end
	end
	for k, ref in pairs(ATTR_REF) do
		local full = Infinity_FetchString(ref)
		if full and full ~= '' then rules[#rules + 1] = { escapePattern(full), (string.gsub(attr(k), '%%', '%%%%')) } end
	end
	-- longest first, so "Dexterity Modification" goes before "Dexterity"
	table.sort(rules, function(a, b) return #a[1] > #b[1] end)
	P.shortRules = rules
	return rules
end

local function short(text)
	text = tostring(text or '')
	for _, n in ipairs(equippedNames()) do text = replacePlain(text, n[1], n[2]) end
	for _, r in ipairs(shortRules()) do text = string.gsub(text, r[1], r[2]) end
	for _, r in ipairs(P.SHORT) do text = string.gsub(text, r[1], r[2]) end
	-- the armour's name line followed by its "AC" line: one line, "Torse CA : 5"
	local torso, ac = escapePattern(T('slot_torso')), escapePattern(T('ab_ac'))
	text = string.gsub(text, '(' .. torso .. ')%s*\n%s*' .. ac .. '%s*', '%1 ')
	return text
end

-- Hit die per level of the shown character (John: "Classe : 1d6", a die roll, not the rolled value): HPCLASS.2DA
-- gives the HP table of the kit or class, its row for the next level gives ROLLS d SIDES (+ MODIFIER past the
-- dice levels).
local CLASS_NAME = { 'MAGE', 'FIGHTER', 'CLERIC', 'THIEF', 'BARD', 'PALADIN', 'FIGHTER_MAGE', 'FIGHTER_CLERIC',
	'FIGHTER_THIEF', 'FIGHTER_MAGE_THIEF', 'DRUID', 'RANGER', 'MAGE_THIEF', 'CLERIC_MAGE', 'CLERIC_THIEF',
	'FIGHTER_DRUID', 'FIGHTER_MAGE_CLERIC', 'CLERIC_RANGER', 'SORCERER', 'MONK', 'SHAMAN' }
local function hitDie(sp)
	local ok, out = pcall(function()
		P.hpclass = P.hpclass or EEex_Resource_Load2DA('HPCLASS')
		local kit, name = EEex_Sprite_GetStat(sp, 152), nil
		if kit and kit > 0x4000 then
			P.kitlist = P.kitlist or EEex_Resource_Load2DA('KITLIST')
			name = EEex_Resource_GetAt2DALabels(P.kitlist, 'ROWNAME', tostring(kit - 0x4000))
		end
		local tableRes = name and EEex_Resource_GetAt2DALabels(P.hpclass, 'TABLE', name)
		if not tableRes or tableRes == '*' or tableRes == '' then
			tableRes = EEex_Resource_GetAt2DALabels(P.hpclass, 'TABLE', CLASS_NAME[sp.m_typeAI.m_Class] or 'FIGHTER')
		end
		local t = EEex_Resource_Load2DA(tableRes)
		local row = tostring(math.max(1, EEex_Sprite_GetStat(sp, 34)) + 1)
		local sides = tonumber(EEex_Resource_GetAt2DALabels(t, 'SIDES', row)) or 0
		local rolls = tonumber(EEex_Resource_GetAt2DALabels(t, 'ROLLS', row)) or 0
		local mod = tonumber(EEex_Resource_GetAt2DALabels(t, 'MODIFIER', row)) or 0
		if rolls > 0 then return rolls .. 'd' .. sides .. (mod ~= 0 and string.format('%+d', mod) or '') end
		return string.format('%+d', mod)
	end)
	return ok and out or nil
end

-- HP details (John): "Classe : 1d6" and "Constit : +2" (the engine's bonus line, its number kept).
local function hpDetails(c)
	local lines = {}
	local die = hitDie(EEex_Sprite_GetInPortrait(shownPortrait()))
	if die then lines[#lines + 1] = T('hp_class', die) end
	for line in string.gmatch(tostring(c.HP.details or ''), '[^\n]+') do
		local low = string.lower(line)
		if string.find(low, 'bonus', 1, true) or string.find(low, 'constit', 1, true) then
			local n = string.match(line, '([%+%-]%d+)%s*$')
			if n then lines[#lines + 1] = T('hp_con', attr('con'), n) end
		end
	end
	if #lines == 0 then return short(c.HP.details) end
	return table.concat(lines, '\n')
end

-- LeUI installed (buildInventoryStats exists only in its UI.MENU): on BGEE it brings BG2's label font, so the
-- page uses BG2's offset for the stats values.
function PStash_LeUI() return type(buildInventoryStats) == 'function' end

-- Dual wielding: the engine gives two values ("4\n8"); the menu shows them in a smaller font.
function PStash_StatSingle(k) return not string.find(PStash_StatValue(k), '\n', 1, true) end
function PStash_StatDouble(k) return not PStash_StatSingle(k) end

local function ch() return characters and characters[id] end
local function comparing() return tempStats ~= nil and tempStats[id] ~= nil end

-- The game's inventory message (TEXT_inventoryError), shown in the title band; "Mode pause" is hidden (John:
-- the inventory always pauses the game).
function PStash_InvMessage()
	local t = tostring(TEXT_inventoryError or '')
	if string.find(string.lower(t), 'pause', 1, true) then return '' end
	return t
end

-- Value shown in each block's icon (0 AC, 1 HP, 2 THAC0, 3 damage), like the original page.
function PStash_StatValue(k)
	if PStash_CompShown and PStash_CompShown() then return (PStash_CompStat(k)) end
	local c = ch()
	if not c then return '' end
	if k == 0 then return tostring(c.AC.current) end
	if k == 1 then return c.HP.current .. '/' .. c.HP.max end
	-- read from characters[id] (Infinity UI++ rewrites getInventoryTHAC0 / getInventoryDamage on its own rgInvId)
	if k == 2 then return tostring(c.THAC0.current) .. (c.THAC0.offhand and ('\n' .. c.THAC0.offhand) or '') end
	local d = c.damage
	local s = d.min .. ' - ' .. d.max
	if d.minOffhand and d.maxOffhand then s = s .. '\n' .. d.minOffhand .. ' - ' .. d.maxOffhand end
	return s
end

-- Two weapons (John 2026-10-21): the lines both hands share once, then what differs, "Main: ..." / "Off: ...".
-- Lines are compared once shortened, the off-hand's "Weapon 2:" counting as "Weapon:"; a per-hand line loses its
-- "THAC0 main hand -" style prefix (the hand is said in front).
local function splitLines(s)
	local out = {}
	for l in string.gmatch(s, '[^\n]+') do if string.find(l, '%S') then out[#out + 1] = l end end
	return out
end
local function bothHands(main, off)
	-- each line: no "THAC0 main hand -" prefix, the off hand's "Weapon 2:" read as "Weapon:"
	local function clean(l) return (string.gsub(string.gsub(l, '^[^:]-%-%s*', ''), '^([^:]-) 2%s*:', '%1:')) end
	local m, o = splitLines(short(main)), splitLines(short(off))
	for i, l in ipairs(m) do m[i] = clean(l) end
	for i, l in ipairs(o) do o[i] = clean(l) end
	local function parts(l) return string.match(l, '^([^:]-)%s*:%s*([%+%-]?%d+)%s*$') end
	-- The engine folds the off hand's strength into its weapon line (THAC0: main "Str: -3" + "Weapon: -3", off
	-- "Weapon: -6"): with no strength line of its own, the off hand's weapon line gives it back (John 2026-10-21).
	local strLabel, str, offStr = attr('str'), nil, false
	for _, l in ipairs(m) do local a, v = parts(l) if a == strLabel then str = tonumber(v) end end
	for _, l in ipairs(o) do if parts(l) == strLabel then offStr = true end end
	if str and str ~= 0 and not offStr then
		local mainLabels = {}
		for _, l in ipairs(m) do local a = parts(l) if a then mainLabels[a] = true end end
		for i, l in ipairs(o) do
			local a, v = parts(l)
			if a and a ~= strLabel and mainLabels[a] and string.find(a, escapePattern(T('slot_weapon'))) then
				local n = tonumber(v) - str
				o[i] = a .. ': ' .. (n > 0 and '+' or '') .. n
				o[#o + 1] = strLabel .. ': ' .. (str > 0 and '+' or '') .. str
				break
			end
		end
	end
	local left = {}
	for _, l in ipairs(o) do left[l] = (left[l] or 0) + 1 end
	local common, onlyMain = {}, {}
	for _, l in ipairs(m) do
		if (left[l] or 0) > 0 then left[l] = left[l] - 1 common[#common + 1] = l
		else onlyMain[#onlyMain + 1] = l end
	end
	local out = common
	for _, l in ipairs(onlyMain) do out[#out + 1] = T('ab_main_hand') .. ': ' .. l end
	for _, l in ipairs(o) do
		if (left[l] or 0) > 0 then left[l] = left[l] - 1 out[#out + 1] = T('ab_off_hand') .. ': ' .. l end
	end
	return table.concat(out, '\n')
end

-- The UI.MENU helper when it exists, else the same text built here (LeUI's UI.MENU has no
-- getInventoryTHAC0Details / getInventoryDamageDetails); two weapons: factorized (bothHands).
local function statDetails(c, key, helper)
	local s = c[key]
	if s and s.detailsOffhand ~= nil and s.detailsOffhand ~= '' then return bothHands(tostring(s.details), s.detailsOffhand) end
	if type(helper) == 'function' then return helper() end
	return s and s.details or ''
end

-- Compared value as the vanilla getTempStat: "-" when unchanged, red when worse, green when better.
-- Built here because LeUI's UI.MENU lacks part of the vanilla compare helpers (getStat, getTempHP...).
local function tempStat(old, key, coeff)
	local new = tempStats[id] and tempStats[id][key]
	if new == nil then return '-' end
	local score = coeff * (new - old)
	if score == 0 then return '-' end
	return (score < 0 and '^R' or '^G') .. new .. '^-'
end

local function tempHP(c)
	local maxHP = tempStat(c.HP.max, 'maxHP', 1)
	local curHP = tempStat(c.HP.current, 'currentHP', 1)
	if maxHP == '-' and curHP == '-' then return '-' end
	if maxHP == '-' then maxHP = c.HP.max end
	if curHP == '-' then curHP = c.HP.current end
	return curHP .. '/' .. maxHP
end

-- Shortened details, or "current > new" while an item is being compared (dragged / hovered).
function PStash_StatText(k)
	if PStash_CompShown and PStash_CompShown() then local _, text = PStash_CompStat(k) return text end
	local c = ch()
	if not c then return '' end
	if comparing() then
		local title = k == 0 and (tostring(tempStats[id].tempItem or '') .. '\n') or ''
		if k == 0 then return title .. T('st_ac') .. c.AC.current .. ' > ' .. tempStat(c.AC.current, 'AC', -1) end
		if k == 1 then return T('st_hp') .. c.HP.current .. '/' .. c.HP.max .. ' > ' .. tempHP(c) end
		if k == 2 then
			return T('st_thac0') .. c.THAC0.current .. ' > ' .. tempStat(c.THAC0.current, 'THAC0', -1)
		end
		return T('st_damage') .. c.damage.min .. '-' .. c.damage.max .. ' > ' .. tostring(getTempDamage())
	end
	if k == 0 then return short(c.AC.details) end
	if k == 1 then return hpDetails(c) end
	if k == 2 then return short(statDetails(c, 'THAC0', getInventoryTHAC0Details)) end
	-- damage block: the engine's attacks per round with what is equipped, last line (John 2026-10-21)
	local text = short(statDetails(c, 'damage', getInventoryDamageDetails))
	local sp = EEex_Sprite_GetInPortrait(shownPortrait())
	if sp then
		local apr = aprCode(EEex_Sprite_GetStat(sp, 8))
		local shown = string.format('%g', apr) -- 1, 1.5, 2... (John: decimals, not 3/2)
		text = text .. '\n' .. T('st_apr', shown)
	end
	return text
end

-----------------
-- Tick        --
-----------------

-- A storable backpack item: identified, not a quest item, not a bag.
local function storable(it)
	local res = string.upper(it.pRes.resref:get())
	local info = PStash_ItemInfo(res)
	-- valuable items stay where the player put them (John 2026-10-22: not moved by Store all or any other system)
	return info and EEex_BAnd(it.m_flags, 1) ~= 0 and not botKeep(res) and not info.critical and info.type ~= 36
		and not PStash_IsValuable(res)
end

-- An item dropped on the stash grid: hand it to the shown character like a drop on his portrait
-- (Infinity_SwapWithPortrait), then move whatever newly appeared in his backpack into the stash.
function PStash_DropOnStash()
	local p = shownPortrait()
	local sp = EEex_Sprite_GetInPortrait(p)
	if not sp then return end
	local before = {}
	for i = 18, P.DROP_SLOT do
		local it = sp.m_equipment.m_items:get(i)
		before[i] = it and EEex_UDToPtr(it) or 0
	end
	pcall(Infinity_SwapWithPortrait, p)
	for i = 18, P.DROP_SLOT do
		local it = sp.m_equipment.m_items:get(i)
		if it and EEex_UDToPtr(it) ~= before[i] then
			local res = string.upper(it.pRes.resref:get())
			local info = PStash_ItemInfo(res)
			if P.KEEP[res] or (info and (info.critical or info.type == 36)) then
				P.msg = T('msg_quest_bags')
			else
				local ok, why = PStash_Add(p, i)
				P.msg = ok and '' or why
			end
			break
		end
	end
	rebuild()
	refreshInventory()
end

-- Whatever lands in the drop slot while the inventory page is open goes straight to the stash.
local function drainDropSlot()
	if not Infinity_IsMenuOnStack('INVENTORY') or not PStash_Ready() then return end
	local p = shownPortrait()
	local sp = EEex_Sprite_GetInPortrait(p)
	local it = sp and sp.m_equipment.m_items:get(P.DROP_SLOT)
	if not it then return end
	local res = string.upper(it.pRes.resref:get())
	if res == P.RES then return end
	local info = PStash_ItemInfo(res)
	if info and info.type == 36 then
		if not hasStore(res) then P.msg = T('msg_quest_bags') return end
		if not P.pendingBags[EEex_UDToPtr(it)] then requestBags({ it }) end
		return
	end
	if P.KEEP[res] or (info and info.critical) then
		P.msg = T('msg_quest')
		return
	end
	local ok, why = PStash_Add(p, P.DROP_SLOT)
	P.msg = ok and '' or why
	rebuild()
	refreshInventory()
end

-- John: every member carries the Stash item (the stash bag) in his LAST backpack slot. The engine treats it like
-- any carried bag: quests see and take the stash's items, and an item dropped on it (or on the stash grid, whose
-- overlay slot is that last slot) goes into the stash natively.
-- One stash item per character: extra copies (a stash item dragged in hand looked missing, so a new one was made,
-- then the dragged one was dropped back) are destroyed, the one in the last slot is kept.
local function dropExtraStashItems(sp)
	local items, keep, moved = sp.m_equipment.m_items, nil, false
	local last = items:get(P.DROP_SLOT)
	if last and string.upper(last.pRes.resref:get()) == P.RES then keep = P.DROP_SLOT end
	for i = 0, 38 do
		local it = items:get(i)
		if it and string.upper(it.pRes.resref:get()) == P.RES then
			if not keep then keep = i
			elseif i ~= keep then
				items:set(i, nil)
				PStash_Eng_AddDisposableItem(gamePtr(), EEex_UDToPtr(it))
				moved = true
			end
		end
	end
	return moved
end

-- A creature still being built (character creation, a joining NPC) has no area yet: no CreateItem on it (BG2 session).
local function inArea(sp)
	local ok, area = pcall(function() return sp.m_pArea end)
	return ok and area ~= nil
end

local function placeStashItems()
	-- John picked the stash item up (it is in his hand, not in a slot): wait for the drop.
	if heldItem() then return end
	local moved = false
	for p = 0, lastPortrait() do
		local sp = EEex_Sprite_GetInPortrait(p)
		if sp then
			if dropExtraStashItems(sp) then moved = true end
			local items = sp.m_equipment.m_items
			local last = items:get(P.DROP_SLOT)
			if not (last and string.upper(last.pRes.resref:get()) == P.RES) then
				local at
				for i = 18, P.DROP_SLOT - 1 do
					local it = items:get(i)
					if it and string.upper(it.pRes.resref:get()) == P.RES then at = i break end
				end
				if at then
					-- swap the stash item into the last slot (whatever sat there takes its place)
					local stash = items:get(at)
					items:set(at, last)
					items:set(P.DROP_SLOT, stash)
					moved = true
				elseif last and freeSlot(sp) then
					-- the last slot holds something else: move it to a free slot, the stash item comes next tick
					local free = freeSlot(sp)
					items:set(free, last)
					items:set(P.DROP_SLOT, nil)
					moved = true
				elseif not last and inArea(sp) then
					-- the engine puts a new item in the first free slot: it is moved to the last slot next tick
					EEex_Action_ExecuteResponseStringOnAIBaseInstantly('CreateItem("' .. P.RES .. '",0,0,0)', sp)
				end
			end
		end
	end
	if moved and Infinity_IsMenuOnStack('INVENTORY') then refreshInventory() end
end

-----------------
-- Sale marks  --
-----------------

-- John: Ctrl + click on a stash item marks it "to sell" (all of that kind); a merchant's "Sell marked" button sells
-- them, and the bot sells them at Nashkel. Saved in the game (a global per item).
-- Marks, per item type (global PSTS_<RES>, kept in the save): 1 = to sell, 2 = valuable (never sold, John 2026-10-22).
local function markKey(res) return 'PSTS_' .. string.upper(res) end
local function markOf(res) return EEex_GameState_GetGlobalInt(markKey(res)) end
function PStash_IsMarked(res) return markOf(res) == 1 end
function PStash_IsValuable(res) return res ~= nil and markOf(res) == 2 end
local function setMarked(res, on) EEex_GameState_SetGlobalInt(markKey(res), on and 1 or 0) end

P.hoverCell = P.hoverCell or -1
P.gtop = P.gtop or 0
function PStash_Hover(i) P.hoverCell = i end

-- John 2026-10-24: Ctrl + click toggles "to sell", Alt + click toggles "valuable" (was one Ctrl cycle of both).
function PStash_ToggleMark(res)
	local want = PStash_AltDown() and 2 or 1
	EEex_GameState_SetGlobalInt(markKey(res), markOf(res) == want and 0 or want)
end

-- Space in the inventory (John 2026-10-19): "Store all", wherever the mouse is (marking is Ctrl + click now).
function PStash_OnKey(key)
	if P.dump and not P.dump.target and key == EEex_Key_GetFromName('Escape') then
		P.dumpCancel(true)
		return false
	end
	if key ~= EEex_Key_GetFromName('Space') or not Infinity_IsMenuOnStack('INVENTORY') then return false end
	if heldItem() then return true end
	PStash_StoreAll()
	return true -- consumed: Space does not pause/unpause here
end
-- The listener calls the global so a reloaded file takes over (keyHooked2: the first listener called a local).
if not P.keyHooked2 then
	P.keyHooked2 = true
	EEex_Key_AddPressedListener(function(key) local ok, used = pcall(PStash_OnKey, key) return ok and used end)
end

function PStash_MarkedCount()
	local n = 0
	for _, e in ipairs(P.list or {}) do if PStash_IsMarked(e.res) then n = n + 1 end end
	return n
end

local function inStoreSellPanel()
	return e:GetActiveEngine() == storeScreen and Infinity_IsMenuOnStack('STORE_BUYSELL')
		and not storeScreen:IsContainer()
end

-- The "Sell marked" button lives in a small menu shown over a merchant's buy/sell panel.
local function storeMenu()
	local want = inStoreSellPanel()
	if not want then P.storeName = nil
	elseif not P.storeName then
		P.storeName = storeScreen:GetStoreName()
		-- a fresh stash list for this visit: the one in memory may predate a save load (John: "Sell marked" only
		-- showed once the inventory had been opened since the reload)
		P.list, P.saleCache = PStash_List(P.RES), {}
	end
	local shown = Infinity_IsMenuOnStack('PSTASH_STORE')
	if want and not shown then Infinity_PushMenu('PSTASH_STORE') elseif shown and not want then Infinity_PopMenu('PSTASH_STORE') end
end

-- The merchant on screen: buy % and the item types he buys (P.STORES, keyed by his name). Unknown store: 50 %, all.
-- The name is read once per visit by the tick (GetStoreName crashes once the store is closed, while the menu still draws).
local function storeRules()
	local r = P.storeName and P.STORES[P.storeName]
	-- r[2]: an index into P.STORE_TYPES (build_stores.py) or the type set itself (PartyStash.tp2, other games)
	if r then return r[1], type(r[2]) == 'table' and r[2] or P.STORE_TYPES[r[2]] end
	return 50, nil
end

-- Marked stash items this merchant buys: { {res, count, gold}, ... } and the total gold.
local computeSaleList

-- The store menu's labels ask for it many times per frame: computed at most every 250 ms (or when the stash
-- list or the store changes). A fresh one for the sale itself.
P.saleCache = P.saleCache or {}
local function saleList(fresh)
	local c, now = P.saleCache, Infinity_GetClockTicks()
	if fresh or c.list ~= P.list or c.store ~= P.storeName or not c.at or now - c.at >= 250 then
		c.out, c.total = computeSaleList()
		c.list, c.store, c.at = P.list, P.storeName, now
	end
	return c.out, c.total
end

function computeSaleList()
	local pct, types = storeRules()
	local out, total = {}, 0
	for _, e in ipairs(P.list or {}) do
		local info = PStash_ItemInfo(e.res)
		if PStash_IsMarked(e.res) and info and info.price > 0 and not info.critical and info.type ~= 36
			and not P.KEEP[e.res] and (not types or types[info.type]) then
			local gold = math.floor(info.price * pct / 100) * math.max(1, e.count)
			out[#out + 1] = { res = e.res, count = math.max(1, e.count), gold = gold }
			total = total + gold
		end
	end
	return out, total
end

function PStash_SellText()
	if not P.storeName then return '' end
	local _, total = saleList()
	return T('sell_text', total)
end

-- The store button's amount and its length (the menu has one label set per length, 1-7 digits); 0 = nothing shown.
-- The Sell Marked help (store menu): how many marked kinds sell, for how much, how many are skipped.
function PStash_SellHelp()
	if not P.storeName then return '' end
	local list, total = saleList()
	return T('help_sell', #list, total, math.max(0, PStash_MarkedCount() - #list))
end

function PStash_SellAmount()
	if not P.storeName then return '' end
	local _, total = saleList()
	return tostring(total)
end
function PStash_SellDigits()
	if not P.storeName or not Infinity_IsMenuOnStack('PSTASH_STORE') or not PStash_CanSellMarked() then return 0 end
	return math.min(7, #PStash_SellAmount())
end

-- The button is always there at a merchant's buy/sell panel (John 2026-10-24), greyed when he buys none of the
-- marked items; its help says why.
function PStash_SellShown()
	return P.storeName ~= nil and Infinity_IsMenuOnStack('PSTASH_STORE') and true or false
end
function PStash_SellIdle()
	return '^0xff808080' .. T('sell_marked') .. '^-'
end

function PStash_CanSellMarked()
	if not P.storeName then return false end
	local list = saleList()
	return #list > 0
end

-- Party gold (CInfGame +0x7988 on v2.7.3.0 and v2.6.6.0, checked against GetPartyGold / AddPartyGold). Script actions run instantly while the
-- store screen is live crash the game: if the field does not match, the gold waits for the store to close.
local GOLD_OFF = 0x7988
local function addGold(n)
	local p = EEex_UDToPtr(EEex_EngineGlobal_CBaldurChitin.m_pObjectGame)
	local cur = game:GetPartyGold()
	if EEex_ReadU32(p + GOLD_OFF) == cur then
		EEex_Write32(p + GOLD_OFF, cur + n)
		if game:GetPartyGold() == cur + n then return end
		EEex_Write32(p + GOLD_OFF, cur)
	end
	P.goldDue = (P.goldDue or 0) + n
end

local function payGoldDue()
	if not P.goldDue or P.goldDue <= 0 or e:GetActiveEngine() == storeScreen then return end
	local sp = EEex_Sprite_GetInPortrait(0)
	if not sp then return end
	EEex_Action_ExecuteResponseStringOnAIBaseInstantly(string.format('GiveGoldForce(%d)', P.goldDue), sp)
	P.goldDue = 0
end

-- Sold straight from the stash (John's choice): the marked items leave the stash, the party gets the merchant's price.
function PStash_SellMarked()
	if not P.storeName or not inStoreSellPanel() then return end
	P.list = PStash_List(P.RES)
	local list = saleList(true)
	local game, gold = gamePtr(), 0
	for _, it in ipairs(list) do
		local taken = PStash_Eng_TakeItemFromStore(game, resRef(P.RES), resRef(it.res, 32), it.count) % 65536
		if taken > 0 then
			gold = gold + math.floor(it.gold * taken / it.count)
			if taken >= it.count then setMarked(it.res, false) end
		end
	end
	if gold > 0 then
		addGold(gold)
		-- the game's own gold pickup sound (CBaldurEngine::RESREF_SOUND_EQUIP_TAKE_GOLD), John 2026-10-21
		pcall(Infinity_PlaySound, 'GAM_37A')
	end
	P.list = PStash_List(P.RES)
	P.saleCache = {} -- the button's total drops at once
	P.dirty = true
	pcall(function() storeScreen:UpdateBuySellPanel() end)
end

-----------------
-- Campaigns   --
-----------------

-- BG1 -> SoD (BDSODTRN: SetGlobal SOD_fromimport 1, movies, MoveToCampaign("SoD")): the new campaign starts with a
-- fresh, empty stash store and no PSTB_ bag counts. The game process (and this Lua state) lives on through the
-- move, so a snapshot of the stash taken until SOD_fromimport is set is put back once in the new campaign.
P.snapshot = P.snapshot or nil
local function takeSnapshot()
	if EEex_GameState_GetGlobalInt('SOD_fromimport') == 1 then return end -- frozen during the transition
	local snap = { items = {}, bags = {}, gold = game:GetPartyGold() }
	for _, e in ipairs(PStash_List(P.RES)) do
		snap.items[#snap.items + 1] = { res = e.res, count = e.count, uses = e.uses, identified = e.identified }
	end
	for _, res in ipairs(bagList()) do
		local n = bagCount(res)
		if n > 0 then snap.bags[res] = n end
	end
	P.snapshot = snap
end

-- Puts the snapshot back, a few items per tick, through a backpack (CreateItem then PStash_Add).
local function restoreStep()
	local r = P.restore
	if not r then return end
	local p, sp
	for q = 0, lastPortrait() do
		local s2 = EEex_Sprite_GetInPortrait(q)
		if s2 and freeSlot(s2) then p, sp = q, s2 break end
	end
	if not sp then P.msg = T('msg_restore') return end
	for _ = 1, 10 do
		local e = table.remove(r, 1)
		if not e then P.restore = nil P.list, P.dirty = nil, true return end
		local info = PStash_ItemInfo(e.res)
		local stack = info and info.stack or 1
		local units = stack > 1 and math.max(1, e.count) * math.max(1, e.uses) or math.max(0, e.uses)
		for _ = 1, (stack > 1 and 1 or math.max(1, e.count)) do
			local slot = freeSlot(sp)
			if not slot then table.insert(r, 1, e) return end
			EEex_Action_ExecuteResponseStringOnAIBaseInstantly(
				string.format('CreateItem("%s",%d,0,0)', e.res, units), sp)
			local it = sp.m_equipment.m_items:get(slot)
			if it then
				if e.identified then it.m_flags = EEex_BOr(it.m_flags, 1) end
				PStash_Add(p, slot)
			end
		end
	end
end

local function campaignWatch()
	if EEex_GameState_GetGlobalInt('SOD_fromimport') == 1 and EEex_GameState_GetGlobalInt('PSTASH_SODDONE') == 0
		and P.snapshot and #PStash_List(P.RES) == 0 then
		EEex_GameState_SetGlobalInt('PSTASH_SODDONE', 1)
		if opt('keepgold') and P.snapshot.gold and game:GetPartyGold() < P.snapshot.gold then
			addGold(P.snapshot.gold - game:GetPartyGold())
		end
		if not opt('losestash') then
			for res, n in pairs(P.snapshot.bags) do recordBag(res); setBagCount(res, n) end
			P.restore = P.snapshot.items
		end
		P.snapshot = nil
	end
	-- EET, SoD -> BG2 (chapter 12 -> 13: Irenicus takes everything): the stash store lives on in the save; the options
	-- give the gold back (the most the party had in the last minute: the move takes it before the chapter changes)
	-- or empty the stash too.
	local chapter = EEex_GameState_GetGlobalInt('CHAPTER')
	if P.lastChapter and P.lastChapter >= 7 and P.lastChapter <= 12 and chapter >= 13 then
		if opt('keepgold') then
			local best = 0
			for _, v in ipairs(P.goldHistory or {}) do best = math.max(best, v) end
			if best > game:GetPartyGold() then addGold(best - game:GetPartyGold()) end
		end
		if opt('losestash') then
			local g = gamePtr()
			for _, e in ipairs(PStash_List(P.RES)) do
				PStash_Eng_TakeItemFromStore(g, resRef(P.RES), resRef(e.res, 32), math.max(1, e.count))
			end
			for _, res in ipairs(bagList()) do setBagCount(res, 0) end
			P.list, P.dirty = nil, true
		end
	end
	P.lastChapter = chapter
	if P.restore then restoreStep() return end
	local now = Infinity_GetClockTicks()
	if not P.snapNext or now >= P.snapNext then
		P.snapNext = now + 5000
		takeSnapshot()
		if chapter <= 12 then -- the last minute of party gold, for the EET move (see above)
			P.goldHistory = P.goldHistory or {}
			table.insert(P.goldHistory, game:GetPartyGold())
			if #P.goldHistory > 12 then table.remove(P.goldHistory, 1) end
		end
	end
end

-- Before uninstalling (John): everything comes out. The stash items and the collected bags are created on the
-- shown character; what his backpack cannot hold falls on the ground at his feet (the game does that itself).
local function carries(sp, res)
	for i = 0, 38 do
		local it = sp.m_equipment.m_items:get(i)
		if it and string.upper(it.pRes.resref:get()) == res then return true end
	end
	return false
end

-- One item out of the stash: created on `sp`, then dropped at his feet (John: "tout au sol"); an item he already
-- carries stays in his backpack (DropItem takes the first of that name, it could be his own one).
local function createToGround(sp, res, units)
	local own = carries(sp, res)
	EEex_Action_ExecuteResponseStringOnAIBaseInstantly(string.format('CreateItem("%s",%d,0,0)', res, units), sp)
	if not own then EEex_Action_ExecuteResponseStringOnAIBaseInstantly(string.format('DropItem("%s",[-1.-1])', res), sp) end
end

-- One stash entry straight to the ground (out of the store, created, dropped).
local function entryToGround(sp, e2)
	local info = PStash_ItemInfo(e2.res)
	local stack = info and info.stack or 1
	local want = stack > 1 and math.max(1, e2.count) or 1
	local taken = PStash_Eng_TakeItemFromStore(gamePtr(), resRef(P.RES), resRef(e2.res, 32), want) % 65536
	if taken == 0 then return false end
	local units = stack > 1 and taken * math.max(1, e2.uses) or math.max(0, e2.uses)
	for _ = 1, (stack > 1 and 1 or taken) do createToGround(sp, e2.res, units) end
	return true
end

-- Ctrl + click on the weight bag (John, before uninstalling): the collected bags come back, each filled with the
-- stash items it can hold (specific bags first, bags of holding last); everything else drops on the ground at the
-- shown character's feet. Returns how many stash entries were handled.
function PStash_EmptyAll()
	if e:GetActiveEngine() == storeScreen then return 0 end
	local p = shownPortrait()
	local sp = EEex_Sprite_GetInPortrait(p) or EEex_Sprite_GetInPortrait(0)
	if not sp then return 0 end
	local bags = {}
	for _, res in ipairs(bagList()) do
		if bagCount(res) > 0 then bags[#bags + 1] = { res = res, types = bagTypes(res), n = bagCount(res) } end
	end
	table.sort(bags, function(a, b) return (a.types.all and 1 or 0) < (b.types.all and 1 or 0) end)
	local n = 0
	for _ = 1, 3000 do
		local e2 = PStash_List(P.RES)[1]
		if not e2 then break end
		local info = PStash_ItemInfo(e2.res)
		local bag
		for _, b in ipairs(bags) do
			if info and (b.types.all or b.types[info.type]) then bag = b break end
		end
		local done = false
		if bag and freeSlot(sp) then
			-- through the backpack into the bag's own store (a full bag refuses it: the item stays in the backpack)
			local slot = PStash_Take(p, e2.res)
			if slot then
				PStash_Add(p, slot, bag.res)
				done = true
			end
		end
		if not done and not entryToGround(sp, e2) then break end
		n = n + 1
	end
	-- the bags themselves (their contents live in their store, by name): into the backpack, or the ground if full
	for _, b in ipairs(bags) do
		for _ = 1, b.n do
			EEex_Action_ExecuteResponseStringOnAIBaseInstantly('CreateItem("' .. b.res .. '",0,0,0)', sp)
		end
		setBagCount(b.res, 0)
	end
	P.list, P.dirty = nil, true
	pcall(Infinity_ActivateInventory)
	return n
end

-- The weight bag (John): Ctrl + left click empties the stash (bags back, filled; the rest on the ground), after a
-- confirmation (to do before uninstalling the mod; the installer tells the keybind).
function PStash_BagClick()
	if not (EEex_Key_IsDown(EEex_Key_GetFromName('Left Ctrl')) or EEex_Key_IsDown(EEex_Key_GetFromName('Right Ctrl'))) then
		return
	end
	if Infinity_IsMenuOnStack('POPUP_TWOBUTTON') then return end
	Popup2Button = {
		info = T('empty_confirm'),
		okText = T('bags_ok'),
		okFunc = function() pcall(PStash_EmptyAll) end,
		cancelFunc = function() end,
	}
	Infinity_PushMenu('POPUP_TWOBUTTON')
end

-----------------
-- Companions  --
-----------------

-- Companions' inventories (issue #1, John 2026-10-23): a familiar companion (PStash_Companions) has no inventory
-- screen of its own, so the page draws its slots over the shown character's (same places, same look, PSTASH.menu)
-- when its portrait is picked in the companion bar. Items move by pointer between slots (no effects in a backpack);
-- an item entering an equipment slot gets its "while equipped" effects in the companion's equipped list (EEex
-- effectList 2, what the engine itself uses for items: they survive a save/load), and loses them when it leaves
-- (opcode 321, remove effects by resource; another copy still worn gets its own back).
P.comp = nil      -- the shown companion's object id; nil = the party
P.compFor = nil   -- the party member the page showed when the companion was picked
P.compDrag = nil  -- slot name being dragged from

local function compSprite()
	if not P.comp then return nil end
	local ok, c = pcall(EEex_GameObject_Get, P.comp)
	if ok and c and isCompanion(c) then return c end
	P.comp = nil
	return nil
end
local function isEquipSlot(idx) return idx ~= nil and (idx < 18 or idx > 33) end
local function itemRes(it) return it and string.upper(it.pRes.resref:get()) or nil end


local WEAPON_TYPES = P.TABS[2].types
local AMMO_TYPES = { [5] = true, [14] = true, [31] = true }
local function slotAccepts(idx, info)
	if not isEquipSlot(idx) then return true end
	if idx >= 35 and idx <= 38 then return WEAPON_TYPES[info.type] == true end
	if idx >= 11 and idx <= 13 then return AMMO_TYPES[info.type] == true end
	if idx >= 15 and idx <= 17 then return info.ability ~= nil and not WEAPON_TYPES[info.type] and not SLOTS[info.type] end
	for _, s in ipairs(SLOTS[info.type] or {}) do if s == idx then return true end end
	return false
end

-- The "while equipped" effects of an item (ITM global feature blocks with timing 2) onto creature c, slot idx.
local function equipEffects(c, res, idx)
	if idx >= 35 and idx <= 38 and idx ~= c.m_equipment.m_selectedWeapon then return end -- only the weapon in hand
	local h = EEex_Resource_Demand(res, 'ITM')
	if not h then return end
	local p = EEex_UDToPtr(h)
	local fo, fi, fc = EEex_ReadU32(p + 0x6A), EEex_ReadU16(p + 0x6E), EEex_ReadU16(p + 0x70)
	for k = 0, fc - 1 do
		local b = p + fo + (fi + k) * 0x30
		if EEex_ReadU8(b + 0x0C) == 2 then
			EEex_GameObject_ApplyEffect(c, {
				effectID = EEex_ReadU16(b), targetType = EEex_ReadU8(b + 2), spellLevel = EEex_ReadU8(b + 3),
				effectAmount = EEex_Read32(b + 4), dwFlags = EEex_ReadU32(b + 8), durationType = 2,
				duration = EEex_ReadU32(b + 0x0E), probabilityUpper = EEex_ReadU8(b + 0x12),
				probabilityLower = EEex_ReadU8(b + 0x13), res = EEex_ReadLString(b + 0x14, 8),
				numDice = EEex_ReadU32(b + 0x1C), diceSize = EEex_ReadU32(b + 0x20),
				savingThrow = EEex_ReadU32(b + 0x24), saveMod = EEex_Read32(b + 0x28), special = EEex_ReadU32(b + 0x2C),
				effectList = 2, m_sourceRes = res, m_sourceType = 2, m_slotNum = idx,
				sourceID = c.m_id, sourceTarget = c.m_id,
			})
		end
	end
end
-- The game is paused on the inventory page: a creature's stats only follow its effect lists at the next AI tick.
-- CGameSprite::ProcessEffectList (what SwapItemPersonal calls after a swap) refreshes them now. Found from an EEex
-- label inside it (every build EEex knows), back to the function's start (int3 padding before it).
local function processEffects(c)
	if not _G.PStash_Eng_ProcessEffectList then
		if P.noPEL then return end
		local ok, a = pcall(EEex_Label, 'Hook-CGameSprite::ProcessEffectList()-FirstRandCall')
		if not ok or type(a) ~= 'number' then P.noPEL = true return end
		local st = a
		while not (EEex_ReadU8(st - 1) == 0xCC and EEex_ReadU8(st - 2) == 0xCC) and a - st < 0x4000 do st = st - 1 end
		if a - st >= 0x4000 then P.noPEL = true return end
		P.buildStub('ProcessEffectList', st, 1)
	end
	pcall(PStash_Eng_ProcessEffectList, EEex_UDToPtr(c))
end

-- An item's equipped effects follow where its copies are: all removed (they share the resource), then given back to
-- each copy still worn.
local function refreshEffects(c, res)
	EEex_GameObject_ApplyEffect(c, { effectID = 321, res = res, durationType = 1, sourceID = c.m_id, sourceTarget = c.m_id })
	for idx = 0, 38 do
		if isEquipSlot(idx) and idx ~= 10 and idx ~= 14 and idx ~= 34 and itemRes(c.m_equipment.m_items:get(idx)) == res then
			equipEffects(c, res, idx)
		end
	end
	processEffects(c)
end

-- Moves the item of slot `from` to slot `to` on companion c (swapping with what is there). Returns ok, reason.
local function compMove(c, from, to)
	if from == to then return false end
	local items = c.m_equipment.m_items
	local a, b = items:get(from), items:get(to)
	if not a then return false end
	local ia, ib = PStash_ItemInfo(itemRes(a)), b and PStash_ItemInfo(itemRes(b))
	if not ia then return false end
	if isEquipSlot(to) and (not slotAccepts(to, ia) or not usableSprite(c, ia)) then return false, T('msg_cannot_equip') end
	if b and isEquipSlot(from) and (not ib or not slotAccepts(from, ib) or not usableSprite(c, ib)) then return false, T('msg_cannot_equip') end
	-- two hands: a two-handed weapon in hand and a shield exclude each other
	local function twoHandedIn(slot) local it = items:get(slot) local i = it and PStash_ItemInfo(itemRes(it)) return i and i.twoHanded end
	if to == 9 and twoHandedIn(c.m_equipment.m_selectedWeapon) then return false, T('msg_cannot_equip') end
	if to == c.m_equipment.m_selectedWeapon and ia.twoHanded and items:get(9) then return false, T('msg_cannot_equip') end
	items:set(to, a)
	items:set(from, b)
	if isEquipSlot(from) or isEquipSlot(to) then
		refreshEffects(c, itemRes(a))
		if b then refreshEffects(c, itemRes(b)) end
	end
	P.dirty = true
	return true
end

local function compFree(c)
	for i = 18, 33 do if not c.m_equipment.m_items:get(i) then return i end end
end
-- Stash -> companion backpack: through the shown party member's backpack (PStash_Take), then the pointer moves.
local function compTake(res)
	local c = compSprite()
	if not c then return false end
	local to = compFree(c)
	if not to then P.msg = T('msg_comp_full') return false end
	local p = shownPortrait()
	local slot, why = PStash_Take(p, res)
	if not slot then P.msg = tostring(why) return false end
	local sp = EEex_Sprite_GetInPortrait(p)
	c.m_equipment.m_items:set(to, sp.m_equipment.m_items:get(slot))
	sp.m_equipment.m_items:set(slot, nil)
	P.dirty = true
	return true
end
-- Companion slot -> stash: the pointer goes to a free slot of the shown party member, then PStash_Add.
local function compStore(idx)
	local c = compSprite()
	if not c then return false end
	local it = c.m_equipment.m_items:get(idx)
	if not it then return false end
	local p = shownPortrait()
	local sp = EEex_Sprite_GetInPortrait(p)
	local slot = sp and freeSlot(sp)
	if not slot then P.msg = T('msg_hand') return false end
	local res = itemRes(it)
	sp.m_equipment.m_items:set(slot, it)
	c.m_equipment.m_items:set(idx, nil)
	if isEquipSlot(idx) then refreshEffects(c, res) end
	if not PStash_Add(p, slot) then -- back where it was
		c.m_equipment.m_items:set(idx, sp.m_equipment.m_items:get(slot))
		sp.m_equipment.m_items:set(slot, nil)
		if isEquipSlot(idx) then refreshEffects(c, res) end
		return false
	end
	P.dirty = true
	return true
end

-- Companion bar (PSTASH_COMPBAR, left of the game's portraits) and the page's companion mode.
function PStash_CompCount() return #PStash_Companions() end
-- The >6 members bar (PSXP7_BAR, 54 wide) takes the place next to the game's portraits: ours goes left of it.
function PStash_CompBarShift() return type(PSXP7_BarWidth) == 'function' and (PSXP7_BarWidth() or 0) or 0 end -- 0, 54, 108, 162
function PStash_CompPortrait(i)
	local c = PStash_Companions()[i + 1]
	return c and c.m_baseStats.m_portraitSmall:get() or ''
end
function PStash_CompTooltip(i)
	local c = PStash_Companions()[i + 1]
	if not c then return '' end
	return string.format('%s (%d/%d)', EEex_Sprite_GetName(c), c.m_baseStats.m_hitPoints, EEex_Sprite_GetStat(c, 1))
end
function PStash_CompSelected(i)
	local c = PStash_Companions()[i + 1]
	return c ~= nil and P.comp == c.m_id and Infinity_IsMenuOnStack('INVENTORY')
end
function PStash_CompSelect(i)
	local c = PStash_Companions()[i + 1]
	if not c then return end
	P.comp, P.compFor, P.compDrag = c.m_id, nil, nil
	if not Infinity_IsMenuOnStack('INVENTORY') then pcall(function() e:GetActiveEngine():OnLeftPanelButtonClick(3) end) end
	P.dirty = true
end
function PStash_CompShown()
	if not Infinity_IsMenuOnStack('INVENTORY') then return false end
	local c = compSprite()
	if not c then return false end
	-- a party portrait picked meanwhile: back to the party
	if P.compFor == nil then P.compFor = id elseif id ~= P.compFor then P.comp = nil return false end
	return true
end
function PStash_CompName()
	local c = compSprite()
	return c and EEex_Sprite_GetName(c) or ''
end
function PStash_CompBigPortrait()
	local c = compSprite()
	return c and c.m_baseStats.m_portraitLarge:get() or ''
end
function PStash_CompStatText()
	local c = compSprite()
	if not c then return '' end
	return string.format('%s %d\n%s %d/%d', T('ab_ac'), EEex_Sprite_GetStat(c, 2), 'HP', c.m_baseStats.m_hitPoints,
		EEex_Sprite_GetStat(c, 1))
end
function PStash_CompIcon(name)
	local c = compSprite()
	local it = c and SLOT_INDEX[name] and c.m_equipment.m_items:get(SLOT_INDEX[name])
	local info = it and PStash_ItemInfo(itemRes(it))
	return info and info.icon or nil
end
function PStash_CompCount_(name)
	local c = compSprite()
	local it = c and SLOT_INDEX[name] and c.m_equipment.m_items:get(SLOT_INDEX[name])
	return it and it.m_useCount1 > 1 and it.m_useCount1 or nil
end
function PStash_CompTip(name)
	local c = compSprite()
	local it = c and SLOT_INDEX[name] and c.m_equipment.m_items:get(SLOT_INDEX[name])
	local info = it and PStash_ItemInfo(itemRes(it))
	return info and Infinity_FetchString(info.idName) or ''
end
-- The same hand as the party's (John 2026-10-23): a click or a drag on a companion slot puts its item in the inventory
-- screen's hand (the engine draws it at the cursor, and any slot of the page takes it: a party member's, the stash's,
-- the companion's); a click or a drop on a companion slot with an item in hand puts it there (what was there comes
-- into the hand).
local function canWear(c, idx, info)
	if not isEquipSlot(idx) then return true end
	if not info or not slotAccepts(idx, info) or not usableSprite(c, info) then return false end
	local items = c.m_equipment.m_items
	local sel = c.m_equipment.m_selectedWeapon
	local w = items:get(sel)
	local wi = w and PStash_ItemInfo(itemRes(w))
	if idx == 9 and wi and wi.twoHanded then return false end
	if idx == sel and info.twoHanded and items:get(9) then return false end
	return true
end
function PStash_CompClick(name)
	local c, idx = compSprite(), SLOT_INDEX[name]
	local inv = EEex_EngineGlobal_CBaldurChitin.m_pEngineInventory
	if not c or not idx or not inv then return end
	local items = c.m_equipment.m_items
	local held, cur = heldItem(), items:get(idx)
	if held then
		local info = PStash_ItemInfo(itemRes(held))
		if not canWear(c, idx, info) then P.msg = T('msg_cannot_equip') return end
		items:set(idx, held)
		inv.m_pTempItem = cur
		if isEquipSlot(idx) then
			refreshEffects(c, itemRes(held))
			if cur then refreshEffects(c, itemRes(cur)) end
		end
	elseif cur then
		items:set(idx, nil)
		inv.m_pTempItem = cur
		if isEquipSlot(idx) then refreshEffects(c, itemRes(cur)) end
	end
	P.dirty = true
end
-- An item in hand dropped on the stash grid: stored, like a click on the grid with an item in hand.
function PStash_CompDropStash()
	if heldItem() then PStash_StoreHeld() end
end
function PStash_CompDblClick(name)
	local idx = SLOT_INDEX[name]
	local c = compSprite()
	if not c or not idx then return end
	local shift = EEex_Key_IsDown(EEex_Key_GetFromName('Left Shift')) or EEex_Key_IsDown(EEex_Key_GetFromName('Right Shift'))
	if shift then compStore(idx) return end
	-- double-click a backpack item: wear it in the first slot that takes it; a worn item: back to the backpack
	if isEquipSlot(idx) then
		local to = compFree(c)
		if to then compMove(c, idx, to) end
		return
	end
	local it = c.m_equipment.m_items:get(idx)
	local info = it and PStash_ItemInfo(itemRes(it))
	if not info then return end
	local order = {}
	for _, s in ipairs(SLOTS[info.type] or {}) do order[#order + 1] = s end
	if WEAPON_TYPES[info.type] then order = { c.m_equipment.m_selectedWeapon, 35, 36, 37, 38 } end
	if AMMO_TYPES[info.type] then order = { 11, 12, 13 } end
	for _, s in ipairs(order) do
		if not c.m_equipment.m_items:get(s) then
			local ok, why = compMove(c, idx, s)
			if not ok and why then P.msg = why end
			return
		end
	end
	if order[1] then local ok, why = compMove(c, idx, order[1]) if not ok and why then P.msg = why end end
end
P.compTake = compTake

-- The 2x2 stats of a companion (value, details), from its stats and the weapon in hand (the engine's characters[]
-- tables only cover the party): 0 AC (worn pieces), 1 HP, 2 THAC0 (base, strength, skill, weapon), 3 damage.
function PStash_CompStat(k)
	local c = compSprite()
	if not c then return '', '' end
	local function sgn(v) return (v >= 0 and '+' or '') .. v end
	local items = c.m_equipment.m_items
	if k == 0 then
		local lines = { T('ab_ac') .. ': ' .. c.m_baseStats.m_armorClass }
		for idx = 0, 9 do
			local it = items:get(idx)
			local info = it and PStash_ItemInfo(itemRes(it))
			local ac = info and acOf(info) or 0
			if ac ~= 0 then lines[#lines + 1] = Infinity_FetchString(info.idName) .. ': ' .. sgn(-ac) end
		end
		return tostring(EEex_Sprite_GetStat(c, 2)), table.concat(lines, '\n')
	end
	if k == 1 then
		return c.m_baseStats.m_hitPoints .. '/' .. EEex_Sprite_GetStat(c, 1),
			EEex_Sprite_GetName(c) .. '\n' .. T('ab_level', EEex_Sprite_GetStat(c, 34))
	end
	local sel = c.m_equipment.m_selectedWeapon
	local w = items:get(sel) or items:get(10)
	local info = w and PStash_ItemInfo(itemRes(w))
	local ok, perHit, hit, apr = false
	if info and info.ability then ok, perHit, hit, apr = pcall(weaponCore, c, info) end
	if not ok or not perHit then return '', '' end
	local name = Infinity_FetchString(info.idName)
	local pips = EEex_Sprite_GetStat(c, info.prof)
	local sh, sd = skillBonus(pips)
	if pips == 0 and info.type ~= 28 then sh = sh + nonProficient(c) end
	local h, d = strBonus(c)
	if k == 2 then
		local lines = { T('ab_base_thac0') .. ': ' .. EEex_Sprite_GetStat(c, 7), 'Str: ' .. sgn(-h), T('ab_prof') .. ': ' .. sgn(-sh) }
		if info.ability.toHit ~= 0 then lines[#lines + 1] = name .. ': ' .. sgn(-info.ability.toHit) end
		return tostring(EEex_Sprite_GetStat(c, 7) - hit), table.concat(lines, '\n')
	end
	local ab = info.ability
	local bonus = perHit - ab.dice * (ab.sides + 1) / 2
	local lo, hi = math.floor(ab.dice + bonus + 0.5), math.floor(ab.dice * ab.sides + bonus + 0.5)
	local lines = { string.format('%s: %dd%d%s', name, ab.dice, ab.sides, ab.bonus ~= 0 and (' ' .. sgn(ab.bonus)) or ''),
		T('ab_prof') .. ': ' .. sgn(sd), 'Str: ' .. sgn(d), T('st_apr', string.format('%g', apr)) }
	return lo .. ' - ' .. hi, table.concat(lines, '\n')
end

-----------------
-- Dump        --
-----------------

-- Right click on the weight bag (John 2026-10-22): put things away into a container. The inventory closes and the
-- game waits for the party to open a container (WORLD_CONTAINER; the open one is m_pObjectGame.m_iContainer); a
-- three-button popup then asks what goes in: the shown character's backpack, or the stash page shown when the bag
-- was clicked (its tab), or nothing. Never moved: the stash item, valuable items, quest items (and bags from the
-- stash). Items move a few per tick: a backpack item off its slot (SwapItemPersonal); a stash item first out of the
-- stash into a backpack (PStash_Take); then onto the container's item list (m_lstItems:AddTail). Esc cancels.
P.dump = nil
local function dumpable(it)
	local res = string.upper(it.pRes.resref:get())
	local info = PStash_ItemInfo(res)
	return res ~= P.RES and info ~= nil and not info.critical and not PStash_IsValuable(res)
end
local function dumpSlots(p)
	local sp, out = EEex_Sprite_GetInPortrait(p), {}
	if not sp then return out end
	for i = 18, 32 do
		local it = sp.m_equipment.m_items:get(i)
		if it and dumpable(it) then out[#out + 1] = i end
	end
	return out
end
local function dumpPrepare(p)
	local page = {}
	for _, c in ipairs(P.view or {}) do
		local info = not c.bag and PStash_ItemInfo(c.res)
		if info and not info.critical and not PStash_IsValuable(c.res) then page[#page + 1] = c.res end
	end
	if #page == 0 and #dumpSlots(p) == 0 then return false end
	P.dump = { portrait = p, page = page }
	return true
end
function PStash_DumpArm()
	if not dumpPrepare(shownPortrait()) then P.msg = T('dump_none') return end
	pcall(function() e:SelectEngine(worldScreen) end)
	Infinity_DisplayString(T('dump_armed'))
end
-- The container panel's button (lib/main.tpa): the container is already open, the popup comes at the next tick.
-- Backpack of the character who opened it; stash page = the last one shown in the inventory (rebuilt first).
function PStash_DumpHere()
	if P.dump then return end
	local p = shownPortrait()
	local opener = EEex_EngineGlobal_CBaldurChitin.m_pObjectGame.m_iContainerSprite
	for q = 0, lastPortrait() do
		local sp = EEex_Sprite_GetInPortrait(q)
		if sp and sp.m_id == opener then p = q end
	end
	P.dirty = true
	pcall(PStash_Holding)
	if not dumpPrepare(p) then Infinity_DisplayString(T('dump_none')) end
end

local function dumpCancel(say)
	P.dump = nil
	if say then Infinity_DisplayString(T('dump_cancel')) end
end
P.dumpCancel = dumpCancel

-- An item in backpack `slot` of portrait `p` -> the container. Returns true when it moved.
local function slotToContainer(p, slot, container)
	local buf = P.scratch
	EEex_Write64(buf + 16, 0)
	EEex_Write32(buf + 24, -1)
	PStash_Eng_SwapItemPersonal(gamePtr(), p, buf + 16, slot, buf + 24, 0xFFFF, 0, 1, 0)
	local ptr = EEex_ReadU64(buf + 16)
	if ptr == 0 then return false end
	container.m_lstItems:AddTail(EEex_PtrToUD(ptr, 'CItem'))
	return true
end

-- One stash stack -> a backpack with room -> the container. Returns true when something moved.
local function stashToContainer(res, container)
	for p = 0, lastPortrait() do
		local sp = EEex_Sprite_GetInPortrait(p)
		if sp and freeSlot(sp) then
			local slot = PStash_Take(p, res)
			return slot ~= nil and slotToContainer(p, slot, container)
		end
	end
	return false
end

local function inStash(res)
	for _, e in ipairs(PStash_List(P.RES)) do if e.res == res then return true end end
	return false
end

-- Called by the tick: waits for a container, asks, then moves up to 6 items per tick.
local function dumpStep()
	local d = P.dump
	if not d or not PStash_Ready() then return end
	local g = EEex_EngineGlobal_CBaldurChitin.m_pObjectGame
	if not d.target then
		if d.asking or not Infinity_IsMenuOnStack('WORLD_CONTAINER') or Infinity_IsMenuOnStack('POPUP_THREEBUTTON') then return end
		local id = g.m_iContainer
		if not id or id <= 0 then return end
		d.asking = true
		Popup3Button = {
			info = T('dump_confirm', #dumpSlots(d.portrait), #d.page),
			leftText = 'CANCEL_BUTTON',
			leftFunc = function() dumpCancel(false) end,
			midText = T('dump_backpack'),
			midFunc = function() d.asking, d.target, d.source, d.moved = false, id, 'backpack', 0 end,
			rightText = T('dump_stashpage'),
			rightFunc = function() d.asking, d.target, d.source, d.moved = false, id, 'stash', 0 end,
		}
		Infinity_PushMenu('POPUP_THREEBUTTON')
		return
	end
	local ob = EEex_GameObject_Get(d.target)
	if not ob then dumpCancel(true) return end
	local c = EEex_GameObject_CastUserType(ob)
	local steps, finished = 0, false
	if d.source == 'backpack' then
		local slots = dumpSlots(d.portrait)
		for _, slot in ipairs(slots) do
			if steps >= 6 then break end
			if slotToContainer(d.portrait, slot, c) then d.moved, steps = d.moved + 1, steps + 1 end
		end
		finished = steps == 0 or #slots <= steps
	else
		while #d.page > 0 and steps < 6 do
			local res = d.page[1]
			if inStash(res) and stashToContainer(res, c) then
				d.moved, steps = d.moved + 1, steps + 1
			else
				table.remove(d.page, 1) -- all of it moved, or no room in any backpack: next one
			end
		end
		finished = #d.page == 0
	end
	if finished then
		Infinity_DisplayString(T('dump_done', d.moved))
		P.dump, P.list, P.dirty = nil, nil, true
	end
end
P.dumpStep = dumpStep

-----------------
-- Helmet      --
-----------------
-- John 2026-10-24: a toggle at the top right of the paperdoll hides the character's helmet (on the map and on the
-- paperdoll), its bonuses stay. Per character, kept in the save (sprite local PSHIDEHELM). The engine has no such
-- option: CGameAnimationTypeCharacter's m_renderHelmet (0x2414, the map) and m_bEquipHelmet (0x2418, the paperdoll)
-- are written 0 every frame (the engine sets them back on its own). Character animations only (0x5000-0x6FFF), and
-- only when both fields read 0 or 1 (another engine build or another layout: left alone).
local HELM_RENDER, HELM_EQUIP = 0x2414, 0x2418
local function helmAnim(sp)
	local a = sp and sp.m_animation and sp.m_animation.m_animation
	if not a then return nil end
	local aid = a.m_animationID
	if aid < 0x5000 or aid >= 0x7000 then return nil end
	local ptr = EEex_UDToPtr(a)
	if EEex_ReadU32(ptr + HELM_RENDER) > 1 or EEex_ReadU32(ptr + HELM_EQUIP) > 1 then return nil end
	return ptr
end
local function helmHidden(sp) return sp ~= nil and EEex_Sprite_GetLocalInt(sp, 'PSHIDEHELM') == 1 end
local function hideHelmets()
	for p = 0, lastPortrait() do
		local sp = EEex_Sprite_GetInPortrait(p)
		if helmHidden(sp) then
			local ptr = helmAnim(sp)
			if ptr then
				EEex_Write32(ptr + HELM_RENDER, 0)
				EEex_Write32(ptr + HELM_EQUIP, 0)
			end
		end
	end
end
-- The paperdoll button: shown while the character wears a helmet (or hides one).
function PStash_HelmCan()
	local sp = EEex_Sprite_GetInPortrait(shownPortrait())
	return sp ~= nil and helmAnim(sp) ~= nil and (sp.m_equipment.m_items:get(6) ~= nil or helmHidden(sp))
end
function PStash_HelmFrame() return helmHidden(EEex_Sprite_GetInPortrait(shownPortrait())) and 1 or 0 end
function PStash_HelmTip() return T(PStash_HelmFrame() == 1 and 'helm_show' or 'helm_hide') end
function PStash_ToggleHelm()
	local sp = EEex_Sprite_GetInPortrait(shownPortrait())
	if not sp then return end
	local hide = not helmHidden(sp)
	EEex_Sprite_SetLocalInt(sp, 'PSHIDEHELM', hide and 1 or 0)
	local ptr = helmAnim(sp)
	if ptr and not hide then
		EEex_Write32(ptr + HELM_RENDER, 1)
		EEex_Write32(ptr + HELM_EQUIP, 1)
	end
	if hide then hideHelmets() end
end

function PStash_Tick()
	pcall(hideHelmets)
	-- The game's Lua heap is not collected on its own between screens (it grew to 4 GB at a store and the game ran
	-- out of memory): a small collection step every frame keeps it flat.
	collectgarbage('step', 200)
	-- the companion bar, left of the game's portraits, while there are companions and the portraits are up
	local wantBar = Infinity_IsMenuOnStack('RIGHT_SIDEBAR') and #PStash_Companions() > 0
	if wantBar ~= (Infinity_IsMenuOnStack('PSTASH_COMPBAR') == true) then
		pcall(function() if wantBar then Infinity_PushMenu('PSTASH_COMPBAR') else Infinity_PopMenu('PSTASH_COMPBAR') end end)
	end
	-- Infinity UI++ reads characters[rgInvId], set by its own inventory page: follow the shown character
	if rgInvId ~= nil and id ~= nil and rgInvId ~= id then rgInvId = id end
	local atStore = e:GetActiveEngine() == storeScreen
	-- Character creation: the sprite being built is in portrait 0, leave it alone (no CreateItem on it).
	if createCharScreen and e:GetActiveEngine() == createCharScreen then return false end
	local now = Infinity_GetClockTicks()
	if P.next and now < P.next then return false end
	P.next = now + 500
	if not PStash_Ready() or not EEex_Sprite_GetInPortrait(0) then return false end
	-- John: nothing goes to the stash on its own (the player decides; the bot calls PStash_AutoStoreAll itself).
	-- Not at a store: a script action run there crashes the game (the stash item is never missing there anyway).
	-- Only on the world and inventory screens (never in chargen, level-up or other screens).
	local eng = e:GetActiveEngine()
	if P.CARRY and (eng == worldScreen or eng == inventoryScreen) then pcall(placeStashItems) end
	pcall(storeMenu)
	pcall(payGoldDue)
	if P.dump and eng == worldScreen then
		local ok, err = pcall(dumpStep)
		if not ok then print('PStash dump: ' .. tostring(err)) P.dump = nil end
	end
	if not atStore then pcall(campaignWatch) end
	if next(P.pour) and e:GetActiveEngine() ~= storeScreen then pcall(pourLeftovers) end
	-- Shared weight: refreshed every 2 s.
	if not P.wnext or now >= P.wnext then
		P.wnext = now + 2000
		if not P.list then P.list = PStash_List(P.RES) end
		P.load, P.cap = PStash_Weight()
		-- Over the shared allowance: the whole party is slowed (John).
		local over = P.load > P.cap
		if over or P.slowed then applySlow(over) end
		P.slowed = over
	end
	return false
end

-----------------
-- Menus       --
-----------------

-- The tick menu is pushed only on the world screen: pushed on a sprite load during character creation, a tick
-- menu crashed BG2 at the Appearance step (createCharScreen:GetCurrentPortrait 0xC0000005, found by the BG2 session
-- with GameLog, 2026-10-19). Any later menu push on the world screen brings it back (after a load or chargen).
local function pushTick()
	if Infinity_IsMenuOnStack('PSTASH_TICK') then return end
	if worldScreen == nil or e:GetActiveEngine() ~= worldScreen then return end
	Infinity_PushMenu('PSTASH_TICK')
end

-- Chained wrapper over whatever Infinity_PushMenu is now (other mods may wrap it too), installed once.
if not P.pushWrapped then
	P.pushWrapped = true
	local push = Infinity_PushMenu
	Infinity_PushMenu = function(...)
		local m = ...
		local r = table.pack(push(...)) -- forward the args as they came (pop() is not pop(nil))
		if m ~= 'PSTASH_TICK' then pcall(pushTick) end
		return table.unpack(r, 1, r.n)
	end
end

EEex_Menu_AddMainFileLoadedListener(function() EEex_Menu_LoadFile('PSTASH') end)

EEex_Sprite_AddLoadedListener(function() pcall(pushTick) end)
EEex_GameState_AddInitializedListener(pushTick)
-- A loaded save has its own stash: forget the previous game's list.
EEex_GameState_AddInitializedListener(function()
	P.list, P.saleCache, P.pour, P.pendingBags, P.dirty = nil, {}, {}, {}, true
end)
EEex_Menu_AddAfterMainFileReloadedListener(pushTick)

-- Called from the INVENTORY menu's onOpen.
function PStash_OnInventoryOpen()
	P.dirty, P.msg, P.gtop = true, '', 0
	if fontcolors and not fontcolors['P'] then fontcolors['P'] = 'FF3C3CE6' end -- the overloaded weight's red
	P.refreshPending, P.reveal = false, -1
	-- The quick-loot list (loot.groundItems) is only filled while the world screen's ground items run, for the
	-- selected characters: the shown one gets selected alone (groundFor), the player's selection comes back on close.
	local ok, sel = pcall(EEex_Sprite_GetAllSelectedIDs)
	P.selSaved = ok and sel or nil
	P.groundFor = nil
	-- Its bar (WORLD_QUICKLOOT) would draw over the page: moved off screen (popping it empties the list).
	PStash_HideQuickLoot()
end

-- The quick-loot bar (WORLD_QUICKLOOT) would draw over the page: moved off screen while it is open (popping it empties
-- the list). Its own position is kept for the way back.
function PStash_HideQuickLoot()
	if not P.qlSaved then
		local ok, x, y = pcall(Infinity_GetOffset, 'WORLD_QUICKLOOT')
		if ok and type(x) == 'number' and type(y) == 'number' and y < 4000 then P.qlSaved = { x, y } end
	end
	pcall(Infinity_SetOffset, 'WORLD_QUICKLOOT', 0, 5000)
end

-- The quick-loot bar stays as the player left it (its toggle in the action bar).
function PStash_OnInventoryClose()
	P.helpAll = false
	P.comp, P.compFor, P.compDrag = nil, nil, nil
	if P.selSaved and P.groundFor then
		pcall(function()
			local g = EEex_EngineGlobal_CBaldurChitin.m_pObjectGame
			g:UnselectAll()
			for _, sid in ipairs(P.selSaved) do g:SelectCharacter(sid, false) end
		end)
	end
	P.selSaved, P.groundFor = nil, nil
	if groundItemsButtonToggle ~= 1 then pcall(function() worldScreen:StopGroundItems() end) end
	-- back where it was: a UI mod's own quick-loot window (EEUITweaks' Better Quick Loot opens at the mouse) keeps its
	-- place; the vanilla bar's spot only when its position could not be read (John 2026-10-25: it landed on the chat)
	local q = P.qlSaved
	P.qlSaved = nil
	if q then pcall(Infinity_SetOffset, 'WORLD_QUICKLOOT', q[1], q[2])
	else pcall(Infinity_SetOffset, 'WORLD_QUICKLOOT', 0, -(toolbarTop or 0)) end
end

--------------------
-- Ground column  --
--------------------

-- loot.groundItems: { [0..n-1] = { item = {res, name, icon, count, usages, tint...}, slotId, containerId } }.
local function groundCount()
	local n = 0
	while loot and loot.groundItems and loot.groundItems[n] do n = n + 1 end
	return n
end

-- The ground column follows the shown character (John): selected alone, quick-loot list rebuilt.
local function groundFollow()
	if P.groundFor == id or e:GetActiveEngine() ~= inventoryScreen then return end
	P.groundFor, P.gtop = id, 0
	pcall(function()
		local g = EEex_EngineGlobal_CBaldurChitin.m_pObjectGame
		g:UnselectAll()
		g:SelectCharacter(id, false)
		worldScreen:StopGroundItems()
		worldScreen:StartGroundItems()
	end)
	PStash_HideQuickLoot()
end

local function groundEntry(i)
	groundFollow()
	local n = groundCount()
	if P.gtop > math.max(0, n - 8) then P.gtop = math.max(0, n - 8) end
	return loot and loot.groundItems and loot.groundItems[i + P.gtop]
end

function PStash_GroundProp(i, prop)
	local g = groundEntry(i)
	return g and g.item and g.item[prop] or nil
end

function PStash_GroundClick(i)
	local g = groundEntry(i)
	if g and g.item then
		worldScreen:OnGroundButtonClick(g.slotId, g.containerId, g.item.res)
		P.dirty = true
	end
end

function PStash_GroundDesc(i)
	local g = groundEntry(i)
	if g and g.item then
		Infinity_GetGroundItemDescription(i + P.gtop, g.slotId, g.containerId)
		showItemDescription(g.item, 2)
	end
end

-- For the bot: picks quick-loot entry `i` (loot.groundItems[i], 0-based, raw index) and stores it in the stash.
-- The engine's pickup puts it in a selected character's backpack (needs a free slot), then PStash_Add moves it.
-- Returns true, or nil + reason ('no such entry', 'not picked up', 'picked up but kept: <why>').
function PStash_LootToStash(i)
	local g = loot and loot.groundItems and loot.groundItems[i]
	if not g or not g.item then return nil, 'no such entry' end
	local res = string.upper(g.item.res or '')
	local before = {}
	for p = 0, lastPortrait() do
		local sp = EEex_Sprite_GetInPortrait(p)
		before[p] = {}
		if sp then for k = 18, 33 do before[p][k] = sp.m_equipment.m_items:get(k) ~= nil end end
	end
	worldScreen:OnGroundButtonClick(g.slotId, g.containerId, g.item.res)
	for p = 0, lastPortrait() do
		local sp = EEex_Sprite_GetInPortrait(p)
		if sp then
			for k = 18, 33 do
				local it = sp.m_equipment.m_items:get(k)
				if it and not before[p][k] and string.upper(it.pRes.resref:get()) == res then
					local ok, why = PStash_Add(p, k)
					if ok then return true end
					return nil, 'picked up but kept: ' .. tostring(why)
				end
			end
		end
	end
	return nil, 'not picked up'
end

function PStash_GroundScroll(d)
	P.gtop = math.max(0, math.min((P.gtop or 0) + d * 8, math.max(0, groundCount() - 8)))
end

function PStash_GroundWheel()
	local n = groundCount()
	if scrollDirection > 0 then P.gtop = math.max(0, (P.gtop or 0) - 1)
	elseif scrollDirection < 0 then P.gtop = math.min((P.gtop or 0) + 1, math.max(0, n - 8)) end
end

function PStash_GroundPage()
	local n = groundCount()
	return string.format('%d/%d', math.floor((P.gtop or 0) / 8) + 1, math.max(1, math.ceil(n / 8)))
end

