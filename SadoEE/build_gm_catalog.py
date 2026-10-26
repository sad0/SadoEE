"""The Codex encyclopedia (Decard's page): every item the player can come across, and the area names -> M_PSXCAT.lua
(dev build).

    python build_gm_catalog.py          (reads the game this folder sits in: chitin.key, override, the installed language's TLK)

PSXGM_ALL = { 'AMUL01', ... }  items with an icon and a name (gold left out) that obtainable() finds, sorted.
PSXGM_AREAS = { AR2300 = 'Auberge de Brasamical', ... }  WORLDMAP.WMP area captions; an inner area (AR2301) takes
its outer area's name (AR2300) in M_PSXGM.lua. A release builds the same file at install time from the player's own
game and language (TODO in the installer).
"""
import os
import re
import struct
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.dirname(HERE)
sys.path.insert(0, os.path.join(GAME, 'BGBot', 'bot', 'data'))
# fallback: a game without BGBot (e.g. the EET dev game) uses the Steam BGBot reader
sys.path.append(r"E:\SteamLibrary\steamapps\common\Baldur's Gate Enhanced Edition\BGBot\bot\data")
import build_items  # noqa: E402  (KEY/BIF reader)

build_items.TYP.update({'WMP': 0x3f7, 'BAM': 0x3e8, 'ARE': 0x3f2, 'STO': 0x3f6, 'CRE': 0x3f1, 'INI': 0x802, 'DLG': 0x3f3})


def res8(b):
    return b.split(b'\0')[0].decode('latin-1').upper()


MAX_FROM = 12  # origins kept per item
PER_KIND = 4   # and per kind (stores would fill the list of a common item)

STORE_AT = {}  # store -> the area its merchant stands in (places())

# Outer areas the world map leaves without a caption (EET), (English, French).
UNNAMED = {
    'BG0100': ("Baldur's Gate, North-West", 'Porte de Baldur, nord-ouest'),
    'BG0200': ("Baldur's Gate, North", 'Porte de Baldur, nord'),
    'BG0300': ("Baldur's Gate, North-East", 'Porte de Baldur, nord-est'),
    'BG0600': ("Baldur's Gate, West", 'Porte de Baldur, ouest'),
    'BG0700': ("Baldur's Gate, Center", 'Porte de Baldur, centre'),
    'BG0800': ("Baldur's Gate, East", 'Porte de Baldur, est'),
    'BG1100': ("Baldur's Gate, South-West", 'Porte de Baldur, sud-ouest'),
    'BG1200': ("Baldur's Gate, South", 'Porte de Baldur, sud'),
    'BG1300': ("Baldur's Gate, South-East", 'Porte de Baldur, sud-est'),
    'BG2600': ('Candlekeep', 'Château-Suif'),
    # BG2 areas no world map names (John 2026-10-24: never show a code)
    'AR0601': ("Irenicus' Dungeon", "Donjon d'Irenicus"),
    'AR0602': ("Irenicus' Dungeon", "Donjon d'Irenicus"),
    'AR0603': ("Irenicus' Dungeon", "Donjon d'Irenicus"),
    'AR2900': ('Hell', 'Enfer'),
    'AR2901': ('Hell', 'Enfer'),
    'AR2902': ('Hell', 'Enfer'),
    'AR2903': ('Hell', 'Enfer'),
    'AR2904': ('Hell', 'Enfer'),
    'AR2905': ('Hell', 'Enfer'),
    'AR4500': ('Pocket Plane', 'Plan de poche'),
}


def store_info(g, tlk):
    """{ STORE: (type, name) }: a few stores point at a dialogue line, not a name (then the resref)."""
    out = {}
    for n in g.names('STO'):
        d = g.get(n, 'STO')
        if not d or d[:4] != b'STOR' or len(d) < 0x9C:
            continue
        typ, name = struct.unpack_from('<Ii', d, 0x08)
        nm = tlk(name)
        if not nm or len(nm) > 40:
            nm = n
        out[n.upper()] = (typ, nm)
    return out


START_RE = re.compile(rb'StartStore\s*\(\s*"([^"]+)"', re.I)


def places(g, tlk, wmp):
    """Readable places (John 2026-10-24): { AREA: 'Outer area name' or 'Outer area name - building' } and
    STORE_AT { STORE: AREA }.
    - A merchant's area: the dialogues that run StartStore("X") -> the creatures with that dialogue (CRE +0x2CC, or
      the ARE actor's own dialogue +0x48) -> the areas they stand in.
    - An area without a world map caption (an inner area, BG0102...) takes the nearest captioned area through the
      travel regions (ARE region type 2, destination +0x38), and the name of an inn / tavern / temple standing in it
      as the building."""
    store_dlg = {}
    for n in g.names('DLG'):
        d = g.get(n, 'DLG')
        if d:
            for m in START_RE.finditer(d):
                store_dlg.setdefault(n.upper(), set()).add(m.group(1).decode('latin-1').upper())
    cre_dlg = {}

    def dlg_of(cre):
        if cre not in cre_dlg:
            d = g.get(cre, 'CRE')
            cre_dlg[cre] = res8(d[0x2CC:0x2D4]) if d and d[:8] == b'CRE V1.0' and len(d) > 0x2D4 else ''
        return cre_dlg[cre]

    adj = {}
    for n in g.names('ARE'):
        d = g.get(n, 'ARE')
        if not d or d[:8] != b'AREAV1.0' or len(d) < 0x11C:
            continue
        area = n.upper()
        rcnt, roff = struct.unpack_from('<HI', d, 0x5A)
        for r in range(rcnt):
            e = roff + r * 0xC4
            if e + 0xC4 > len(d):
                break
            if struct.unpack_from('<H', d, e + 0x20)[0] == 2:
                dest = res8(d[e + 0x38:e + 0x40])
                if dest and dest != area:
                    adj.setdefault(area, set()).add(dest)
                    adj.setdefault(dest, set()).add(area)
        aoff, acnt = struct.unpack_from('<IH', d, 0x54)
        for a in range(acnt):
            e = aoff + a * 0x110
            if e + 0x110 > len(d):
                break
            dlg = res8(d[e + 0x48:e + 0x50]) or dlg_of(res8(d[e + 0x80:e + 0x88]))
            for s in store_dlg.get(dlg, ()):
                STORE_AT.setdefault(s, area)

    def outer(area):
        seen, todo = {area}, [area]
        for _ in range(6):
            nxt = []
            for a in todo:
                if a in wmp:
                    return wmp[a]
                for b in sorted(adj.get(a, ())):
                    if b not in seen:
                        seen.add(b)
                        nxt.append(b)
            todo = nxt
        return None

    info = store_info(g, tlk)
    building = {}
    for s, area in STORE_AT.items():
        if s in info and info[s][0] in (1, 2, 3) and area not in wmp:  # tavern, inn, temple
            building.setdefault(area, info[s][1])
    out = {}
    for area in set(adj) | set(STORE_AT.values()) | set(wmp):
        if area in wmp:
            out[area] = wmp[area]
            continue
        o, b = outer(area), building.get(area)
        if o and b:
            out[area] = '%s - %s' % (o, b)
        elif o or b:
            out[area] = o or b
    return out


def origins(g, tlk):
    """{ RES: ['S~store name~', 'G~~AR2600', 'C~~AR2600', 'K~creature name~AR2600', ...] } from the game files:
    the stores that sell it (STO, store / tavern / inn / temple), the areas' ground piles and containers (ARE),
    the creatures placed in the areas (ARE actors -> CRE inventory, undroppable items left out)."""
    out = {}

    def add(res, entry):
        res = res.upper()
        note_camp(res, entry)
        lst = out.setdefault(res, [])
        same = sum(1 for x in lst if x[0] == entry[0])
        if entry not in lst and same < PER_KIND and len(lst) < MAX_FROM:
            lst.append(entry)

    for n, (typ, nm) in store_info(g, tlk).items():
        if typ > 3:
            continue
        d = g.get(n, 'STO')
        ioff, icnt = struct.unpack_from('<II', d, 0x34)
        for i in range(icnt):
            e = ioff + i * 0x1C
            if e + 0x1C > len(d):
                break
            stock, inf = struct.unpack_from('<II', d, e + 0x14)
            if stock > 0 or inf & 1:
                add(res8(d[e:e + 8]), 'S~%s~%s' % (nm, STORE_AT.get(n) or camp_of(g, n, 'STO')))
    cre_items = {}

    def cre(n):
        if n in cre_items:
            return cre_items[n]
        d = g.get(n, 'CRE')
        r = (None, [])
        if d and d[:8] == b'CRE V1.0' and len(d) > 0x2C4:
            name = tlk(struct.unpack_from('<i', d, 0x08)[0]) or tlk(struct.unpack_from('<i', d, 0x0C)[0])
            ioff, icnt = struct.unpack_from('<II', d, 0x2BC)
            its = []
            for i in range(icnt):
                e = ioff + i * 0x14
                if e + 0x14 > len(d):
                    break
                if not struct.unpack_from('<I', d, e + 0x10)[0] & 0x8:  # undroppable
                    its.append(res8(d[e:e + 8]))
            r = (name, its)
        cre_items[n] = r
        return r

    for n in g.names('ARE'):
        d = g.get(n, 'ARE')
        if not d or d[:8] != b'AREAV1.0' or len(d) < 0x11C:
            continue
        aoff, acnt = struct.unpack_from('<IH', d, 0x54)
        coff, ccnt, icnt, ioff = struct.unpack_from('<IHHI', d, 0x70)
        for c in range(ccnt):
            e = coff + c * 0xC0
            if e + 0xC0 > len(d):
                break
            ctype = struct.unpack_from('<H', d, e + 0x24)[0]
            first, cnt = struct.unpack_from('<II', d, e + 0x40)
            kind = 'G' if ctype == 4 else 'C'
            for i in range(first, first + cnt):
                ie = ioff + i * 0x14
                if ie + 0x14 > len(d):
                    break
                # a container keeps its type (chest, barrel...: the page names it)
                add(res8(d[ie:ie + 8]), '%s~%s~%s' % (kind, ctype if kind == 'C' else '', n))
        for a in range(acnt):
            e = aoff + a * 0x110
            if e + 0x110 > len(d):
                break
            name, its = cre(res8(d[e + 0x80:e + 0x88]))
            for r in its:
                add(r, 'K~%s~%s' % (name or '?', n))
    return out


# script actions (ACTION.IDS) that hand an item to the party / create a creature (its first CRE string)
ITEM_ACTIONS = {82, 140, 256, 363}  # CreateItem, GiveItemCreate, CreateItemGlobal, AddStoreItem
CRE_ACTIONS = {7, 227, 228, 231, 232, 233, 238, 246, 250, 252, 295, 323}  # CreateCreature* (all variants)
ITEM_RE = re.compile(rb'(?:GiveItemCreate|CreateItem|CreateItemGlobal|AddStoreItem)\s*\(([^)]*)\)', re.I)
CRE_RE = re.compile(rb'CreateCreature\w*\s*\(([^)]*)\)', re.I)
# 2DA tables of random treasure and starting gear (items), random spawns and NPC level versions (creatures)
ITEM_TABLES = ('RNDTRES', 'RNDTREAS', 'RNDSCROL', 'RNDEQUIP', 'RNDWEP', 'RNDMAGIC', '25STWEAP', 'MPSTWEAP', 'BDSTWEAP')
CRE_TABLES = ('SPAWNGRP', 'NPCLVLDS')
TOKEN_RE = re.compile(rb'[A-Za-z0-9_#!$-]{1,8}')


GAME_KIND = ''  # 'eet', 'bgee', 'bg2ee' (main())


def camp_of(g, n, ext):
    """An origin without an area gets its campaign from its file (John 2026-10-24: no "Other" when it can be traced):
    '#1' BG, '#2' SoD, '#3' SoA, '#4' ToB, '#5' the Black Pits, '#6' the Black Pits II, '' unknown. SoD files start
    with BD, the Black Pits' with BP, the Black Pits II's with OH; in a BIF, ToB's are in 25*.bif, the Black Pits II's
    in BlackPits.bif; EET keeps BG1 (and SoD) in its override, BG2 in the BIFs."""
    n = n.upper()
    if n[:2] == 'BD':
        c = 2
    elif n[:2] == 'BP':  # BGEE's Black Pits
        c = 5
    elif n[:2] == 'OH':  # BG2EE's Black Pits II
        c = 6
    else:
        loc = g.res.get((n, build_items.TYP[ext]))
        b = os.path.basename(g.bifs[loc >> 20]).upper() if loc is not None else ''
        if GAME_KIND == 'bgee':
            c = 1
        elif b.startswith('25'):
            c = 4
        elif b.startswith('BLACKP'):
            c = 6
        elif b and not b.startswith('EET'):
            c = 3
        else:  # EET: only in the override (or EET's own BIFs) = BG1; BG2EE: a mod's file
            c = 1 if GAME_KIND == 'eet' else 0
    return '#%d' % c if c else ''


CAMPS = {}  # item -> bitmask of the campaigns of ALL its origins (the list shown is cut at MAX_FROM: John 2026-10-24,
# BG1 items hidden by the BG filter because their BG1 lines were cut)


def area_camp(a):
    """An origin's campaign (M_PSXGM.lua campaign(), the same): 1 BG, 2 SoD, 3 SoA, 4 ToB, 5 the Black Pits,
    6 the Black Pits II, 7 elsewhere."""
    if a[:1] == '#' and a[1:].isdigit():
        return int(a[1:])
    m = re.match(r'^([A-Za-z]{2})(\d{4})', a)
    if not m:
        return 7
    p, n = m.group(1).upper(), int(m.group(2))
    if p == 'BG':
        return 1
    if p == 'BD':
        return 2
    if p == 'BP':
        return 5
    if p == 'OH':
        return 5 if n < 4000 or 9300 <= n < 9400 else 6
    if p == 'AR':
        return 1 if GAME_KIND == 'bgee' else (4 if n >= 4000 else 3)
    return 7


def note_camp(res, entry):
    CAMPS[res] = CAMPS.get(res, 0) | (1 << area_camp(entry.rsplit('~', 1)[-1]))


def owners(g, tlk):
    """Who runs a dialogue or a script, for the given / spawned origins: { DLG: (creature name, area) } and
    { BCS: (creature name or '', area) }; an area's own script -> ('', area); a dialogue or a script many creatures
    share (generic) -> ('', '')."""
    dlg, bcs = {}, {}

    def put(table, key, val):
        if not key:
            return
        table.setdefault(key, set()).add(val)

    def name_of(d):
        return tlk(struct.unpack_from('<i', d, 0x08)[0]) or tlk(struct.unpack_from('<i', d, 0x0C)[0]) or ''

    cres = {}
    for n in g.names('CRE'):
        d = g.get(n, 'CRE')
        if d and d[:8] == b'CRE V1.0' and len(d) > 0x2D4:
            cres[n.upper()] = (name_of(d), res8(d[0x2CC:0x2D4]), [res8(d[o:o + 8]) for o in range(0x248, 0x270, 8)])
    placed = set()
    for n in g.names('ARE'):
        d = g.get(n, 'ARE')
        if not d or d[:8] != b'AREAV1.0' or len(d) < 0x11C:
            continue
        area = n.upper()
        put(bcs, res8(d[0x94:0x9C]), ('', area))
        aoff, acnt = struct.unpack_from('<IH', d, 0x54)
        for k in range(acnt):
            e = aoff + k * 0x110
            if e + 0x110 > len(d):
                break
            c = res8(d[e + 0x80:e + 0x88])
            nm, cd, cs = cres.get(c, ('', '', []))
            placed.add(c)
            put(dlg, res8(d[e + 0x48:e + 0x50]) or cd, (nm, area))
            for sc in [res8(d[o:o + 8]) for o in range(e + 0x50, e + 0x80, 8)] + cs:
                put(bcs, sc, (nm, area))
    for c, (nm, cd, cs) in cres.items():  # joinable NPCs, created creatures: no area
        if c not in placed:
            if cd not in dlg:
                put(dlg, cd, (nm, ''))
            for sc in cs:
                if sc not in bcs:
                    put(bcs, sc, (nm, ''))

    def one(vals):
        return sorted(vals)[0] if len(vals) <= 2 else ('', '')

    return {k: one(v) for k, v in dlg.items()}, {k: one(v) for k, v in bcs.items()}


def obtainable(g, frm, tlk):
    """The items the player can come across in play (John 2026-10-24: the Codex lists only these): an origin of
    origins() (store, ground, container, placed creature), an item a script or a dialogue gives / creates / adds to a
    store, a random treasure or starting gear table, or a droppable item of a creature that a script, a dialogue, a
    spawn point, a rest encounter, a spawn INI or a spawn table creates.
    It also adds those origins to frm (John 2026-10-24: every item says where it comes from): D~giver~area (given by
    a dialogue or a script), P~creature~area (carried by a creature that appears), T~~ (random treasure)."""
    items = set(n.upper() for n in g.names('ITM'))
    cres = set(n.upper() for n in g.names('CRE'))
    got = {}  # item -> how: 'found' (store, ground, container), 'carried' (placed creature), 'give' (script /
    # dialogue), 'table' (random treasure, starting gear), 'spawn' (a created creature carries it)
    spawned = {}  # creature -> the areas it appears in ('' unknown)
    more = []  # (item, origin entry), added to frm at the end
    dlg_own, bcs_own = owners(g, tlk)

    def mark(res_set, how):
        for r in res_set:
            got.setdefault(r, set()).add(how)

    def spawn(c, area):
        spawned.setdefault(c, []).append(area)

    for r, lst in frm.items():
        mark({r}, 'found' if any(e[0] in 'SGC' for e in lst) else 'carried')

    def strings(b):
        return set(s.decode('latin-1').upper() for s in re.findall(rb'"([^"]{1,8})"', b))

    for n in g.names('BCS'):
        d = g.get(n, 'BCS') or b''
        who, area = bcs_own.get(n.upper(), ('', ''))
        area = area or camp_of(g, n, 'BCS')
        for m in re.finditer(rb'AC\n(\d+)(.*?)AC\n', d, re.S):
            aid = int(m.group(1))
            if aid in ITEM_ACTIONS or aid in CRE_ACTIONS:
                s = strings(m.group(2).split(b'OB\n')[-1])  # the action's own strings come after its objects
                if aid in ITEM_ACTIONS:
                    mark(s & items, 'give')
                    more += [(r, 'D~%s~%s' % (who, area)) for r in s & items]
                else:
                    for c in s & cres:
                        spawn(c, area)
    for n in g.names('DLG'):
        d = g.get(n, 'DLG') or b''
        who, area = dlg_own.get(n.upper(), ('', ''))
        area = area or camp_of(g, n, 'DLG')
        for m in ITEM_RE.finditer(d):
            s = strings(m.group(1)) & items
            mark(s, 'give')
            more += [(r, 'D~%s~%s' % (who, area)) for r in s]
        for m in CRE_RE.finditer(d):
            for c in strings(m.group(1)) & cres:
                spawn(c, area)
    for n in g.names('2DA'):
        if n.upper() in ITEM_TABLES or n.upper() in CRE_TABLES:
            toks = set(t.decode('latin-1').upper() for t in TOKEN_RE.findall(g.get(n, '2DA') or b''))
            mark(toks & items, 'table')
            more += [(r, 'T~~%s' % camp_of(g, n, '2DA')) for r in toks & items]
            for c in toks & cres:
                spawn(c, '')
    for n in g.names('INI'):
        toks = set(t.decode('latin-1').upper() for t in TOKEN_RE.findall(g.get(n, 'INI') or b''))
        area = n.upper() if g.get(n, 'ARE') is not None else ''  # an area's spawn INI has its name
        for c in toks & cres:
            spawn(c, area)
    for n in g.names('ARE'):
        d = g.get(n, 'ARE')
        if not d or d[:8] != b'AREAV1.0' or len(d) < 0x11C:
            continue
        soff, scnt = struct.unpack_from('<IH', d, 0x60)
        for s in range(scnt):
            e = soff + s * 0xC8
            if e + 0xC8 > len(d):
                break
            cnt = struct.unpack_from('<H', d, e + 0x74)[0]
            for k in range(min(cnt, 10)):
                spawn(res8(d[e + 0x24 + k * 8:e + 0x2C + k * 8]), n.upper())
        roff = struct.unpack_from('<I', d, 0xC0)[0]
        if roff and roff + 0xE4 <= len(d):
            for k in range(10):
                spawn(res8(d[roff + 0x48 + k * 8:roff + 0x50 + k * 8]), n.upper())
    for n in sorted(set(spawned) & cres):
        d = g.get(n, 'CRE')
        if d and d[:8] == b'CRE V1.0' and len(d) > 0x2C4:
            name = tlk(struct.unpack_from('<i', d, 0x08)[0]) or tlk(struct.unpack_from('<i', d, 0x0C)[0]) or '?'
            ioff, icnt = struct.unpack_from('<II', d, 0x2BC)
            for i in range(icnt):
                e = ioff + i * 0x14
                if e + 0x14 > len(d):
                    break
                if not struct.unpack_from('<I', d, e + 0x10)[0] & 0x8:  # undroppable
                    r = res8(d[e:e + 8])
                    mark({r}, 'spawn')
                    more += [(r, 'P~%s~%s' % (name, a or camp_of(g, n, 'CRE'))) for a in sorted(set(spawned[n]) - {''} or {''})]
    # a creature that appears somewhere known: its line without a place goes (several CRE share a name)
    known_by = set((r, e.rsplit('~', 1)[0]) for r, e in more if e[0] == 'P' and not e.endswith('~'))
    for r, entry in more:
        note_camp(r, entry)
        lst = frm.setdefault(r, [])
        if entry[0] == 'P' and entry.endswith('~') and (r, entry[:-1]) in known_by:
            continue
        same = sum(1 for x in lst if x[0] == entry[0])
        if entry not in lst and same < PER_KIND and len(lst) < MAX_FROM:
            lst.append(entry)
    return got


def main():
    g = build_items.Game(GAME)
    global GAME_KIND
    GAME_KIND = 'eet' if g.get('BG0100', 'ARE') is not None else ('bg2ee' if g.get('AR6200', 'ARE') is not None else 'bgee')
    lang = 'en_US'  # the installed language (weidu.conf lang_dir), like the installer's own build
    conf = os.path.join(GAME, 'weidu.conf')
    if os.path.exists(conf):
        m = re.search(r'lang_dir\s*=\s*(\w+)', open(conf, encoding='latin-1').read())
        lang = m.group(1) if m else lang
    tlk = build_items.TLK(os.path.join(GAME, 'lang', lang, 'dialog.tlk'))
    items = []
    droppable = {}  # ITM flag 0x4: a creature drops it, the party can drop it
    for n in g.names('ITM'):
        d = g.get(n, 'ITM')
        if not d or d[:4] != b'ITM ' or len(d) < 0x72:
            continue
        typ = struct.unpack_from('<H', d, 0x1C)[0]
        icon = res8(d[0x3A:0x42])
        idn, unid = struct.unpack_from('<ii', d, 0x0C)[0], struct.unpack_from('<i', d, 0x08)[0]
        name = tlk(idn) or tlk(unid)
        if typ == 33 or not icon or not name or g.get(icon, 'BAM') is None:
            continue
        items.append(n)
        droppable[n.upper()] = struct.unpack_from('<I', d, 0x18)[0] & 0x4
    areas = {}
    for wname in ['WORLDMAP'] + [w for w in g.names('WMP') if w.upper() != 'WORLDMAP']:  # EET / SoD: several maps
        d = g.get(wname, 'WMP')
        if not d or d[:4] != b'WMAP':
            continue
        nmaps, moff = struct.unpack_from('<II', d, 8)
        for m in range(nmaps):
            mo = moff + m * 0xB8
            na, ao = struct.unpack_from('<II', d, mo + 0x20)
            for a in range(na):
                e = ao + a * 0xF0
                if e + 0xF0 > len(d):
                    break
                area = res8(d[e:e + 8])
                cap = struct.unpack_from('<i', d, e + 0x40)[0]
                nm = tlk(cap) or tlk(struct.unpack_from('<i', d, e + 0x44)[0])
                if area and nm and area not in areas:
                    areas[area] = nm
    # EET's world map has no caption for the Baldur's Gate districts and Candlekeep (BG1's AR0100... renamed BG0100...)
    for k, names in UNNAMED.items():
        if k not in areas and g.get(k, 'ARE') is not None:
            areas[k] = names[1] if lang.startswith('fr') else names[0]
    plc = places(g, tlk, areas)
    frm = origins(g, tlk)
    got = obtainable(g, frm, tlk)
    # an item only a creature carries must be droppable (ITM flag 0x4: no monster weapons, creature immunity rings...)
    keep = lambda n: n in got and (droppable[n] or bool(got[n] & {'found', 'give', 'table'}))
    left = [n for n in items if not keep(n.upper())]
    items = [n for n in items if keep(n.upper())]
    print(len(left), 'items left out (not obtainable), e.g.', ', '.join(sorted(left)[:40]))
    q = lambda s: "'" + s.replace('\\', '\\\\').replace("'", "\\'").replace('\n', ' ') + "'"
    lines = ['-- Generated by build_gm_catalog.py: the camp chest encyclopedia (every item) and the area names.',
             'PSXGM_ALL = {']
    for i in range(0, len(items), 10):
        lines.append('\t' + ', '.join(q(x) for x in items[i:i + 10]) + ',')
    lines.append('}')
    lines.append('PSXGM_AREAS = {')
    for k in sorted(areas):
        lines.append('\t["%s"] = %s,' % (k, q(areas[k])))  # keys quoted: a resref may start with a digit
    lines.append('}')
    lines.append('-- Readable places: the outer area name, and the building (an inn / tavern / temple there) for an inner one.')
    lines.append('PSXGM_PLACES = {')
    for k in sorted(plc):
        lines.append('\t["%s"] = %s,' % (k, q(plc[k])))
    lines.append('}')
    # the game: on BGEE the AR areas are BG1's, on BG2EE and EET BG2's (the origins' campaigns)
    lines.append('PSXGM_GAME = %s' % q(GAME_KIND))
    lines.append('-- The campaigns of all the origins of each item (bit 1 BG ... 7 elsewhere), for the Codex filters.')
    lines.append('PSXGM_CAMPS = {')
    for k in sorted(CAMPS):
        if k in set(n.upper() for n in items):
            lines.append('	["%s"] = %d,' % (k, CAMPS[k]))
    lines.append('}')
    lines.append('-- The area each store\'s merchant stands in.')
    lines.append('PSXGM_STOREAT = {')
    for k in sorted(STORE_AT):
        lines.append('\t["%s"] = %s,' % (k, q(STORE_AT[k])))
    lines.append('}')
    lines.append('-- Where each item comes from at the start of the game: kind~name~area entries joined by "|"')
    lines.append('-- (S a store that sells it (name~its area), G on the ground, C in a container (name = its ARE type),')
    lines.append('-- K a creature that carries it).')
    lines.append('PSXGM_FROM = {')
    for k in sorted(frm):
        lines.append('\t["%s"] = %s,' % (k, q('|'.join(frm[k]))))
    lines.append('}')
    out = os.path.join(HERE, 'M_PSXCAT.lua')
    open(out, 'w', encoding='utf-8', newline='\n').write('\n'.join(lines) + '\n')
    print(len(items), 'items,', len(areas), 'areas ->', out)


if __name__ == '__main__':
    main()
