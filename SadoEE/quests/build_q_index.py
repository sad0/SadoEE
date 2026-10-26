"""Quest chronicle (Decard's quest page, John 2026-10-24): the index of every quest of the game, for the hint writers.

    python build_q_index.py            -> quests/index.json

Reads the game's own quest table (override/BGEE.LUA buildQuestsTable: createQuest(title) + createEntry(title, -1,
entry, {}, subgroup)), the English and French dialog.tlk, and which dialogs (DLG transitions with a journal entry) and
scripts (BCS AddJournalEntry) write each entry, to guess the game each quest belongs to (BG1 / SoD / BG2 / ToB).
The guess is checked by hand in quests/text/*.json ("game" there wins).
"""
import json
import os
import re
import struct
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.abspath(os.path.join(HERE, '..', '..'))
OUT = os.path.join(HERE, 'index.json')
sys.path.insert(0, r"E:\SteamLibrary\steamapps\common\Baldur's Gate Enhanced Edition\BGBot\bot\data")
import build_items  # noqa: E402

build_items.TYP['DLG'] = 0x3F3
build_items.TYP['BCS'] = 0x3EF
build_items.TYP['IDS'] = 0x3F0


def quest_table():
    src = open(os.path.join(GAME, 'override', 'BGEE.LUA'), encoding='latin-1').read()
    body = src[src.index('function buildQuestsTable'):]
    body = body[:body.index('\nend')]
    qs, by = [], {}
    for line in body.splitlines():
        line = line.strip()
        m = re.match(r'createQuest\s*\(\s*(-?\d+)\s*\)', line)
        if m:
            q = {'idx': len(qs) + 1, 'title': int(m.group(1)), 'entries': [], 'subgroups': {}}
            qs.append(q)
            by[q['title']] = q
            continue
        m = re.match(r'createEntry\s*\(\s*(-?\d+)\s*,\s*-?\d+\s*,\s*(-?\d+)\s*,\s*\{[^}]*\}\s*,\s*(\w+)\s*\)', line)
        if m:
            q = by[int(m.group(1))]
            e = int(m.group(2))
            q['entries'].append(e)
            if m.group(3) != 'nil':
                q['subgroups'][e] = int(m.group(3))
    return qs


def sources(g):
    """entry strref -> set of 'DLG:NAME' / 'BCS:NAME' that write it."""
    out = {}
    for name in g.names('DLG'):
        d = g.get(name, 'DLG')
        if not d or d[:8] != b'DLG V1.0':
            continue
        nt, ot = struct.unpack_from('<II', d, 0x10)
        for i in range(nt):
            o = ot + i * 32
            if o + 32 > len(d):
                break
            fl, _txt, jr = struct.unpack_from('<III', d, o)
            if fl & 0x10 and 0 < jr < 0x7fffffff:
                out.setdefault(jr, set()).add('DLG:' + name)
    ids = {}
    for line in (g.text('ACTION', 'IDS') or '').splitlines():
        m = re.match(r'\s*(\d+)\s+AddJournalEntry\b', line)
        if m:
            ids[int(m.group(1))] = 1
    pat = re.compile(r'AC\n(%s)OB.*?ob\nOB.*?ob\nOB.*?ob\n(-?\d+) ' % '|'.join(str(k) for k in ids), re.S)
    for name in g.names('BCS'):
        t = g.text(name, 'BCS')
        if not t or 'AC\n' not in t:
            continue
        for m in pat.finditer(t):
            out.setdefault(int(m.group(2)), set()).add('BCS:' + name)
    return out


def guess(q, src):
    names = sorted({s.split(':')[1] for e in q['entries'] for s in src.get(e, ())})
    if q['title'] >= 200000:   # EET: BG1 + SoD strings come after BG2's
        bd = [n for n in names if n.startswith('BD')]
        return ('sod' if bd and len(bd) * 2 >= len(names) else 'bg1'), names
    tob = [n for n in names if re.match(r'(AR[3456]\d\d\d|25|BAZ|SARADU|SENDAI|AMEL|BALTH|YAGA|ABAZ|GROMN|ILLASERA|FATESP|SOLAR|CELOGAN|AMELYS|MARLOWE|SARVOLO|HEXXAT|BHAAL)', n)]
    return ('tob' if tob and len(tob) * 2 >= len(names) else 'bg2'), names


def main():
    g = build_items.Game(GAME)
    en = build_items.TLK(os.path.join(GAME, 'lang', 'en_US', 'dialog.tlk'))
    fr2 = build_items.TLK(os.path.join(GAME, 'lang', 'fr_FR', 'dialog.tlk'))
    # EET's BG1 + SoD strings = the BGEE dialog.tlk's, 200000 further (EET is installed in English here)
    fr1 = build_items.TLK(os.path.join(GAME, '..', 'EET 2.7.3 source BGEE', 'lang', 'fr_FR', 'dialog.tlk'))

    def fr(r):
        return fr1(r - 200000) if r >= 200000 else fr2(r)
    src = sources(g)
    out = []
    for q in quest_table():
        game, names = guess(q, src)
        out.append({'idx': q['idx'], 'title': q['title'], 'game': game, 'en': en(q['title']), 'fr': fr(q['title']),
                    'sources': names,
                    'entries': [{'id': e, 'en': en(e), 'fr': fr(e)} for e in q['entries']]})
    with open(OUT, 'w', encoding='utf-8', newline='\n') as f:
        json.dump(out, f, ensure_ascii=False, indent=1)
    counts = {}
    for q in out:
        counts[q['game']] = counts.get(q['game'], 0) + 1
    print('written', OUT, len(out), counts)


if __name__ == '__main__':
    main()
