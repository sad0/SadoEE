"""Builds the SadoEE mod folder from the Party Stash and SadoQoL dev folders (John 2026-10-23: one mod, every feature
an optional component; plan: side-session-notes merge_plan_partystash_sadoqol.md).

    python build_sadoee.py            -> <BGEE>\\SadoEE\\ + <BGEE>\\setup-SadoEE.exe (installable)
    python build_sadoee.py --check    -> same, then WeiDU lists the components (parse check)

The sources stay where they are edited (PartyStash\\ and SadoQoL\\ of the EET dev game); this script copies them, moves
paths, renumbers components and strings, and writes SadoEE.tp2. Never edit <BGEE>\\SadoEE by hand: it is rebuilt.
Hand-written SadoEE files: src/ (tra/<lang>/sadoee.tra: groups, guards, merged component names).

Components: Party Stash keeps its numbers (#0-#7); camp block #10 camp, #11 grand merchant (was Party Stash #8, now
needs the camp), #12 old scholar, #13 waiting at the camp, #16 quest chronicle (was Party Stash #9); quality of life #20-#31 (SadoQoL #0-#14 minus its sorted
loot, the same as Party Stash #1). ex-SadoQoL strings: @N -> @(1000 + N) in tra/<lang>/qol.tra.
Every resref, Lua global and game variable keeps its name: saves made with Party Stash / SadoQoL keep working.
"""
import os
import re
import shutil
import subprocess
import sys

GAME = r"E:\Enhanced Edition\Environnement de test\EET 2.7.3 (dev)"  # the dev folders live in the EET dev game since 2026-10-23 (was the Steam BGEE)
PS = os.path.join(GAME, 'PartyStash')
SQ = os.path.join(GAME, 'SadoQoL')
OUT = os.path.join(GAME, 'SadoEE')
HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, 'src')
SQ_OFFSET = 1000

sys.path.insert(0, os.path.dirname(HERE))
import sync_partystash  # noqa: E402  (its file list = what the Party Stash installer uses)

# SadoQoL component -> SadoEE component, label. Missing = dropped (#3 sorted loot = Party Stash #1, #4 deprecated).
SQ_MAP = {0: (20, 'SADOEE-QOL-PASSIVE-TRAPS'), 1: (21, 'SADOEE-QOL-VALUABLE-CONTAINERS'),
          2: (22, 'SADOEE-QOL-AUTO-DISARM'), 5: (23, 'SADOEE-QOL-FPS-COUNTER'), 6: (24, 'SADOEE-QOL-ENDLESS-AMMO'),
          7: (25, 'SADOEE-QOL-FOOTPRINT-ONE'), 8: (26, 'SADOEE-QOL-FOOTPRINT-NONE'), 9: (27, 'SADOEE-QOL-LASTING-MODES'),
          10: (10, 'SADOEE-CAMP'), 11: (28, 'SADOEE-QOL-ATTACK-MOVE'), 12: (29, 'SADOEE-QOL-MOUSE-BUTTONS'),
          13: (30, 'SADOEE-QOL-KEEP-GEAR'), 14: (31, 'SADOEE-QOL-CHESTS-IN-GROUND-BAR'), 15: (12, 'SADOEE-CAMP-SCHOLAR'),
          16: (13, 'SADOEE-CAMP-WAITING'), 17: (14, 'SADOEE-CAMP-WITHERS'),
          18: (32, 'SADOEE-QOL-AUTO-ROLLER'), 19: (15, 'SADOEE-CAMP-WITHERS-RECRUIT'),
          20: (17, 'SADOEE-CAMP-NECROMANCER'),
          # camp priestess prices (John 2026-10-25): one SUBCOMPONENT group, camp block
          21: (50, 'SADOEE-CAMP-PRIEST-PRICES-75'), 22: (51, 'SADOEE-CAMP-PRIEST-PRICES-50'),
          23: (52, 'SADOEE-CAMP-PRIEST-PRICES-25'), 24: (53, 'SADOEE-CAMP-PRIEST-PRICES-0')}
SQ_DROPPED = {3, 4}   # sorted loot (= Party Stash #1), deprecated half personal space
CAMP_FILES = {'M_SQCAMP.lua', 'SQCAMP.menu', 'M_SQCAIN.lua', 'M_SQPRST.lua', 'M_SQWAIT.lua', 'SQWAIT.menu', 'M_SQRESP.lua', 'SQRESP.menu',
             'M_SQRECR.lua', 'SQRECR.menu', 'M_SQNECR.lua', 'SQNECR.menu'}
GROUP_STASH, GROUP_CAMP, GROUP_QOL, GROUP_ENGINE = '@2000', '@2001', '@2002', '@2003'
CAMP_PRED = 'REQUIRE_PREDICATE MOD_IS_INSTALLED ~SadoEE.tp2~ (ID_OF_LABEL ~SadoEE.tp2~ ~SADOEE-CAMP~) @2011'
MERCHANT_LINE = "{ 'SQMERCH', 723, 301, 2 },"   # M_SQCAMP.lua's spawn list (old saves): off without the merchant


def read(p):
    with open(p, encoding='utf-8') as f:
        return f.read()


def write(p, s):
    os.makedirs(os.path.dirname(p), exist_ok=True)
    with open(p, 'w', encoding='utf-8', newline='') as f:
        f.write(s)


def blocks(tp2):
    """Splits a tp2 into (preamble, [component text]); the comment lines right above a BEGIN go with it."""
    lines = tp2.splitlines(keepends=True)
    starts = []
    for i, line in enumerate(lines):
        if line.startswith('BEGIN '):
            while i > 0 and lines[i - 1].startswith('//'):
                i -= 1
            starts.append(i)
    cuts = starts + [len(lines)]
    return ''.join(lines[:starts[0]]), [''.join(lines[a:b]) for a, b in zip(cuts, cuts[1:])]


def designated(block):
    return int(re.search(r'DESIGNATED (\d+)', block).group(1))


def add_group(block, group):
    return re.sub(r'(?m)^(BEGIN [^\n]*\n)', r'\1GROUP %s\n' % group, block, count=1)


def offset_refs(text):
    return re.sub(r'@(\d+)', lambda m: '@%d' % (int(m.group(1)) + SQ_OFFSET), text)


def must_sub(pattern, repl, text, flags=0):
    new, n = re.subn(pattern, repl, text, flags=flags)
    assert n, 'not found: ' + pattern
    return new


def parse_tra(text):
    """@N = ~...~ entries (multi-line allowed) -> {N: raw entry text}."""
    return {int(m.group(1)): m.group(0) for m in re.finditer(r'(?ms)^@(\d+)\s*=\s*~.*?~', text)}


def build_tra(langs):
    sq_en = parse_tra(read(os.path.join(SQ, 'tra', 'english', 'setup.tra')))
    own_en = parse_tra(read(os.path.join(SRC, 'tra', 'english', 'sadoee.tra')))
    for lang in langs:
        # qol.tra: ex-SadoQoL strings, English where the language has none yet
        sq = dict(sq_en)
        p = os.path.join(SQ, 'tra', lang, 'setup.tra')
        if os.path.exists(p):
            sq.update(parse_tra(read(p)))
        lines = ['// ex-SadoQoL strings (GENERATED by build_sadoee.py from SadoQoL/tra; @N there = @%d + N here)'
                 % SQ_OFFSET]
        sq = {n + SQ_OFFSET: offset_refs(t.replace('SadoQoL', 'SadoEE')) for n, t in sq.items()}
        # translations made for SadoEE (src/tra/<lang>/qol.tra, SadoEE numbers) win over English
        p = os.path.join(SRC, 'tra', lang, 'qol.tra')
        if os.path.exists(p):
            sq.update(parse_tra(read(p)))
        for n in sorted(sq):
            lines.append(sq[n])
        write(os.path.join(OUT, 'tra', lang, 'qol.tra'), '\n'.join(lines) + '\n')
        own = dict(own_en)
        p = os.path.join(SRC, 'tra', lang, 'sadoee.tra')
        if os.path.exists(p):
            own.update(parse_tra(read(p)))
        write(os.path.join(OUT, 'tra', lang, 'sadoee.tra'),
              '// SadoEE strings (GENERATED from SadoEE/src/tra)\n' + '\n'.join(own[n] for n in sorted(own)) + '\n')
        # the merchant's old name said "for SadoQoL's camp": the component uses @2012 now; nothing else to patch


def copy_party_stash():
    for rel in sync_partystash.wanted():
        name = rel.replace('\\', '/')
        if not name.startswith('PartyStash/') or name in ('PartyStash/PartyStash.tp2', 'PartyStash/README.md'):
            continue
        dst = os.path.join(OUT, name[len('PartyStash/'):])
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        if name.endswith('.tpa'):
            write(dst, read(os.path.join(GAME, rel)).replace('PartyStash/', 'SadoEE/')
                  .replace('PartyStash.tp2', 'SadoEE.tp2'))
        else:
            shutil.copy2(os.path.join(GAME, rel), dst)


def copy_sadoqol():
    paths = {}
    for f in os.listdir(SQ):
        if not re.match(r'(M_SQ\w+\.lua|SQ\w+\.menu)$', f) or f in ('M_SQSORT.lua', 'SQSORT.menu'):
            continue
        sub = 'camp' if f in CAMP_FILES else 'qol'
        shutil.copy2(os.path.join(SQ, f), os.path.join(OUT, sub, f))
        paths[f] = 'SadoEE/%s/%s' % (sub, f)
    shutil.copytree(os.path.join(SQ, 'camp'), os.path.join(OUT, 'camp', 'area'))
    shutil.copytree(os.path.join(SQ, 'camp_bg2'), os.path.join(OUT, 'camp', 'area_bg2'))  # BG2EE's camp (OH5300)
    shutil.copytree(os.path.join(SQ, 'withers'), os.path.join(OUT, 'camp', 'withers'))
    shutil.copytree(os.path.join(SQ, 'necro'), os.path.join(OUT, 'camp', 'necro'))  # necromancer: dolls, portraits
    shutil.copytree(os.path.join(SQ, 'quiver'), os.path.join(OUT, 'qol', 'quiver'))  # endless ammo's quiver icons
    for f in os.listdir(os.path.join(SQ, 'dlg')):
        write(os.path.join(OUT, 'camp', 'dlg', f), offset_refs(read(os.path.join(SQ, 'dlg', f))))
    assert MERCHANT_LINE in read(os.path.join(SQ, 'M_SQCAMP.lua')), 'M_SQCAMP.lua spawn line changed'
    return paths


def ps_components():
    tp2 = read(os.path.join(PS, 'PartyStash.tp2'))
    _pre, comps = blocks(tp2)
    out = {}
    for b in comps:
        n = designated(b)
        b = b.replace('~PartyStash/', '~SadoEE/').replace('PartyStash.tp2', 'SadoEE.tp2') \
             .replace('.../PartyStash-inlined/', '.../SadoEE-inlined/').replace('~PARTYSTASH-', '~SADOEE-')
        b = b.replace('(PartyStash.tp2 #', '(SadoEE.tp2 #')
        out[n] = b
    return out


def sq_components(paths):
    tp2 = read(os.path.join(SQ, 'SadoQoL.tp2'))
    _pre, comps = blocks(tp2)
    out = {}
    for b in comps:
        n = designated(b)
        if n in SQ_DROPPED:
            continue
        assert n in SQ_MAP, 'SadoQoL #%d is new: give it a SadoEE number in SQ_MAP' % n
        new_n, label = SQ_MAP[n]
        b = offset_refs(b)
        b = re.sub(r'DESIGNATED \d+', 'DESIGNATED %d' % new_n, b, count=1)
        b = re.sub(r'LABEL ~[^~]+~', 'LABEL ~%s~' % label, b, count=1)
        b = b.replace('~SadoQoL.tp2~', '~SadoEE.tp2~').replace('~SADOQOL-REST-CAMP~) @%d' % (2 + SQ_OFFSET),
                                                                 '~SADOEE-CAMP~) @2011')
        if new_n == 10:   # BGEE / EET: the BD5000 crop; BG2EE: OH5300 (camp_bg2, 2026-10-25)
            b = must_sub(r'(LABEL ~SADOEE-CAMP~\n)', r'\1REQUIRE_PREDICATE GAME_IS ~bgee eet bg2ee~ @2014\n', b)
        b = b.replace('.../sadoqol-inlined/', '.../sadoee-inlined/')
        b = b.replace('~SadoQoL/camp_bg2~', '~SadoEE/camp/area_bg2~')
        b = b.replace('~SadoQoL/camp~', '~SadoEE/camp/area~').replace('~SadoQoL/withers~', '~SadoEE/camp/withers~')
        b = b.replace('~SadoQoL/quiver~', '~SadoEE/qol/quiver~')
        b = b.replace('~SadoQoL/necro~', '~SadoEE/camp/necro~')
        b = re.sub(r'~SadoQoL/dlg/', '~SadoEE/camp/dlg/', b)
        b = b.replace('USING ~SadoQoL/tra/%LANGUAGE%/setup.tra~', 'USING ~SadoEE/tra/%LANGUAGE%/qol.tra~')
        b = re.sub(r'~SadoQoL/([^~/]+)~', lambda m: '~%s~' % paths[m.group(1)], b)
        b = re.sub(r'^// #\d+(?: / #\d+)? ', '// ', b)
        code = '\n'.join(line.split('//')[0] for line in b.splitlines())
        assert 'SadoQoL/' not in code, 'unmapped path in SadoQoL #%d' % n
        out[new_n] = b
    return out


def split_camp(camp):
    """SadoQoL #10 carries the camp merchant's creature: it moves to the merchant component (#11)."""
    i = camp.index('// the camp merchant:')
    camp_only, merchant = camp[:i], camp[i:]
    merchant = must_sub(r'ACTION_IF FILE_EXISTS_IN_GAME ~psxcamp.sto~ BEGIN\s*(COMPILE [^\n]*SQMERCH\.d[^\n]*)\s*END ELSE BEGIN'
                        r'\s*COMPILE [^\n]*SQMERCH0\.d[^\n]*\s*END', r'\1', merchant)
    merchant = re.sub(r'(?m)^// Without PSXCAMP[^\n]*\n', '', merchant)
    merchant = re.sub(r'(?m)^// the camp merchant:[^\n]*', '// the camp merchant himself (was in SadoQoL #10), from'
                      ' Belegarm\'s creature (SoD\'s quartermaster)', merchant, count=1)
    # without the merchant: no actor in the area, no respawn in old saves, and a creature already in an old save
    # says his wagons have not arrived (SQMERCH0.d compiles to SQMERCH.dlg; the merchant component replaces it)
    camp_only = must_sub(r'(COPY ~SadoEE/camp/M_SQCAMP\.lua~ ~override~\n)',
                         r'\1\tREPLACE_TEXTUALLY EXACT_MATCH ~%s~ ~-- SADOEE-MERCHANT %s~\n'
                         % (re.escape(MERCHANT_LINE).replace('\\', ''), MERCHANT_LINE), camp_only)
    camp_only = camp_only.rstrip('\n') + '''
// the camp merchant is component #11: until then his spot by the fire stays empty (actor schedule 0 = never there)
COPY_EXISTING ~SQCAMP.ARE~ ~override~
	READ_LONG 0x54 off
	READ_SHORT 0x58 cnt
	FOR (i = 0; i < cnt; ++i) BEGIN
		READ_ASCII (off + i * 0x110 + 0x80) cre (8) NULL
		PATCH_IF ~%cre%~ STRING_EQUAL_CASE ~SQMERCH~ BEGIN WRITE_LONG (off + i * 0x110 + 0x40) 0 END
	END
COMPILE ~SadoEE/camp/dlg/SQMERCH0.d~ USING ~SadoEE/tra/%LANGUAGE%/qol.tra~

'''
    merchant_add = merchant.rstrip('\n') + '''
// back by the fire: the area's actor (schedule: every hour) and the respawn line of old saves
COPY_EXISTING ~SQCAMP.ARE~ ~override~
	READ_LONG 0x54 off
	READ_SHORT 0x58 cnt
	FOR (i = 0; i < cnt; ++i) BEGIN
		READ_ASCII (off + i * 0x110 + 0x80) cre (8) NULL
		PATCH_IF ~%cre%~ STRING_EQUAL_CASE ~SQMERCH~ BEGIN WRITE_LONG (off + i * 0x110 + 0x40) 0xFFFFFFFF END
	END
COPY ~override/M_SQCAMP.lua~ ~override~
	REPLACE_TEXTUALLY EXACT_MATCH ~-- SADOEE-MERCHANT ~ ~~
'''
    return camp_only, merchant_add


def languages():
    langs = []
    for line in read(os.path.join(PS, 'PartyStash.tp2')).splitlines():
        m = re.match(r'LANGUAGE (~[^~]+~) ~([^~]+)~', line)
        if m:
            langs.append((m.group(1), m.group(2)))
    return langs


def tp2(ps, sq, langs):
    ps_nums = sorted(designated(b) for b in blocks(read(os.path.join(PS, 'PartyStash.tp2')))[1])
    sq_nums = sorted(n for n in (designated(b) for b in blocks(read(os.path.join(SQ, 'SadoQoL.tp2')))[1]) if n != 4)
    guard = '\n'.join('\tACTION_IF MOD_IS_INSTALLED ~%s~ ~%d~ BEGIN FAIL @2010 END' % (t, n)
                      for t, nums in (('PartyStash.tp2', ps_nums), ('SadoQoL.tp2', sq_nums)) for n in nums)
    lang_lines = '\n'.join('LANGUAGE %s ~%s~ ~SadoEE/tra/%s/setup.tra~ ~SadoEE/tra/%s/qol.tra~ ~SadoEE/tra/%s/sadoee.tra~'
                           % (title, d, d, d, d) for title, d in langs)
    head = '''// SadoEE: Party Stash + SadoQoL in one mod, every feature an optional component (John 2026-10-23).
// GENERATED by build_sadoee.py from the PartyStash and SadoQoL dev folders: edit those (and SadoEE/src), not this file.
BACKUP ~weidu_external/backup/SadoEE~
AUTHOR ~sad0~
VERSION ~v1.0.1~
README ~SadoEE/readme/readme-%%LANGUAGE%%.html~ ~SadoEE/readme/readme-english.html~

// SadoEE replaces Party Stash and SadoQoL: same override files, so never both (uninstall theirs first).
ALWAYS
%s
END

%s

////////// Party Stash (#0-#7) //////////
''' % (guard, lang_lines)
    parts = [head]
    merchant = chronicle = None
    for n in sorted(ps):
        b = ps[n]
        if n == 8:
            merchant = b
            continue
        if n == 9:   # quest chronicle: Decard's page, in the camp block (#16)
            chronicle = b
            continue
        if n >= 40:   # engine extension (#40 big party): its own group, after quality of life
            continue
        parts.append(add_group(b, GROUP_STASH))
    camp, merchant_add = split_camp(sq[10])
    parts.append('\n////////// Rest camp (#10-#15) //////////\n')
    parts.append(add_group(camp, GROUP_CAMP))
    # Party Stash #8 -> #11: needs the camp now (John), still the stash (its engine stubs live in M_PSTASH.lua)
    merchant = must_sub(r'BEGIN @18 DESIGNATED 8', 'BEGIN @2012 DESIGNATED 11', merchant)
    merchant = must_sub(r'(LABEL ~SADOEE-CAMP-MERCHANT~\n)', r'\1%s\n' % CAMP_PRED, merchant)
    merchant = merchant.replace(') @17\n', ') @2013\n')
    merchant = re.sub(r'^// #8 Camp merchant', '// #11 Camp merchant', merchant, flags=re.M)
    parts.append(add_group(merchant.rstrip('\n') + '\n\n' + merchant_add, GROUP_CAMP) + '\n')
    for n in (12, 13, 14, 15):
        parts.append(add_group(sq[n], GROUP_CAMP))
    # Party Stash #9 -> #16: Decard's quest chronicle (John 2026-10-24), needs the old scholar (#12)
    if chronicle:
        chronicle = must_sub(r'BEGIN @20 DESIGNATED 9', 'BEGIN @20 DESIGNATED 16', chronicle)
        chronicle = must_sub(r'(LABEL ~SADOEE-QUEST-CHRONICLE~\n)',
                             r'\1REQUIRE_PREDICATE MOD_IS_INSTALLED ~SadoEE.tp2~ (ID_OF_LABEL ~SadoEE.tp2~ '
                             r'~SADOEE-CAMP-SCHOLAR~) @21\n', chronicle)
        chronicle = re.sub(r'^// #9 Quest chronicle', '// #16 Quest chronicle', chronicle, flags=re.M)
        parts.append(add_group(chronicle, GROUP_CAMP))
    if 17 in sq:   # SadoQoL #20: the camp necromancer (target dummies, John 2026-10-24)
        parts.append(add_group(sq[17], GROUP_CAMP))
    for n in (50, 51, 52, 53):   # SadoQoL #21-#24: camp priestess prices (one SUBCOMPONENT group)
        if n in sq:
            parts.append(add_group(sq[n], GROUP_CAMP))
    parts.append('\n////////// Quality of life (#20-#31) //////////\n')
    for n in sorted(k for k in sq if 20 <= k < 40):
        parts.append(add_group(sq[n], GROUP_QOL))
    parts.append('\n////////// Engine extension (#40+) //////////\n')
    for n in sorted(k for k in ps if k >= 40):
        parts.append(add_group(ps[n], GROUP_ENGINE))
    return ''.join(parts)


README_CSS = ('body{font-family:Segoe UI,Arial,sans-serif;max-width:900px;margin:2em auto;padding:0 1em;background:#1b1712;'
              'color:#e8dcc4;line-height:1.5}h1,h2,h3{color:#e6c35c}a{color:#e6c35c}table{border-collapse:collapse;'
              'width:100%;margin:.5em 0}td,th{border:1px solid #5a4a32;padding:.4em .6em;text-align:left;vertical-align:top}'
              'th{background:#2a2219}img{max-width:100%;border:1px solid #5a4a32;margin:.5em 0}.v{color:#a89878}'
              '.n{white-space:nowrap;color:#a89878}')


def tra_text(lang):
    """Every @N of the installed language (setup, qol, sadoee) -> plain text."""
    out = {}
    for name in ('setup.tra', 'qol.tra', 'sadoee.tra'):
        p = os.path.join(OUT, 'tra', lang, name)
        if os.path.exists(p):
            for m in re.finditer(r'(?ms)^@(\d+)\s*=\s*~(.*?)~', read(p)):
                out[int(m.group(1))] = m.group(2)
    return out


def build_readme(langs):
    """readme/readme-<language>.html: prose from src/readme_text.py, the component list from SadoEE.tp2 + the .tra."""
    import html
    sys.path.insert(0, SRC)
    from readme_text import TEXT
    tp2_text = read(os.path.join(OUT, 'SadoEE.tp2'))
    _pre, comps = blocks(tp2_text)
    version = re.search(r'VERSION ~([^~]+)~', tp2_text).group(1)
    for lang in langs:
        t = dict(TEXT['english'])
        t.update(TEXT.get(lang, {}))
        s = tra_text(lang)
        e = html.escape
        rows, group = [], None
        for b in comps:
            if 'DEPRECATED' in b.split('\n', 1)[0] or 'DEPRECATED' in re.search(r'(?m)^BEGIN [^\n]*', b).group(0):
                continue
            n = designated(b)
            name = s.get(int(re.search(r'(?m)^BEGIN @(\d+)', b).group(1)), '')
            sub = re.search(r'SUBCOMPONENT @(\d+)', b)
            if sub:
                name = '%s → %s' % (s.get(int(sub.group(1)), ''), name)
            g = re.search(r'(?m)^GROUP @(\d+)', b)
            g = s.get(int(g.group(1)), '') if g else ''
            if g != group:
                rows.append('<tr><th colspan="2">%s</th></tr>' % e(g))
                group = g
            extra = ' <span class="v">(%s)</span>' % e(t['experimental']) if n >= 40 else ''
            rows.append('<tr><td class="n">#%d</td><td>%s%s</td></tr>' % (n, e(name), extra))
        compat = ['<tr>%s</tr>' % ''.join('<th>%s</th>' % e(h) for h in t['compat_head'])]
        compat += ['<tr>%s</tr>' % ''.join('<td>%s</td>' % e(c) for c in row) for row in t['compat']]
        page = ['<!DOCTYPE html>', '<html lang="%s"><head><meta charset="utf-8">' % t['lang'],
                '<title>SadoEE %s</title><style>%s</style></head><body>' % (e(version), README_CSS),
                '<h1>SadoEE <span class="v">%s</span></h1>' % e(version), '<p>%s</p>' % e(t['intro']),
                '<p><img src="inventory_bg1.png" alt="Party Stash"></p>',
                '<h2>%s</h2><table>%s</table>' % (e(t['h_components']), ''.join(rows)),
                '<h2>%s</h2><table>%s</table><p>%s</p>' % (e(t['h_compat']), ''.join(compat), e(t['compat_note'])),
                '<h2>%s</h2><ol>%s</ol>' % (e(t['h_install']), ''.join('<li>%s</li>' % e(i) for i in t['install'])),
                '<h2>%s</h2><p>%s</p>' % (e(t['h_upgrade']), e(t['upgrade'])),
                '<h2>%s</h2><p>%s</p>' % (e(t['h_help']), e(t['help'])),
                '<h2>%s</h2><p>%s</p>' % (e(t['h_uninstall']), e(t['uninstall'])),
                '<h2>%s</h2><p>%s</p>' % (e(t['h_license']), e(t['license'])), '</body></html>']
        write(os.path.join(OUT, 'readme', 'readme-%s.html' % lang), '\n'.join(page) + '\n')


def main():
    # the rebuild wipes SadoEE\: never while a WeiDU install reads it (a rebuild broke an EET install, 2026-10-23)
    # Only an install run from GAME reads OUT: one in another game folder (install_test.ps1 copies SadoEE there, e.g.
    # a Compat test left hanging) does not block the rebuild (2026-10-26).
    paths = subprocess.run(['powershell', '-NoProfile', '-Command',
                            '(Get-Process setup-SadoEE -ErrorAction SilentlyContinue).Path'],
                           capture_output=True, text=True, errors='replace').stdout.splitlines()
    here = [p for p in paths if p.strip() and os.path.normcase(os.path.abspath(p.strip())).startswith(
        os.path.normcase(os.path.abspath(GAME)) + os.sep)]
    if here:
        sys.exit('setup-SadoEE.exe is running in %s (a WeiDU install): rebuild later.' % GAME)
    if os.path.exists(OUT):
        shutil.rmtree(OUT)
    os.makedirs(os.path.join(OUT, 'qol'))
    os.makedirs(os.path.join(OUT, 'camp'))
    copy_party_stash()
    paths = copy_sadoqol()
    langs = languages()
    build_tra([d for _t, d in langs])
    write(os.path.join(OUT, 'SadoEE.tp2'), tp2(ps_components(), sq_components(paths), langs))
    build_readme([d for _t, d in langs])
    shutil.copy2(os.path.join(GAME, 'setup-PartyStash.exe'), os.path.join(GAME, 'setup-SadoEE.exe'))
    n = sum(len(fs) for _r, _d, fs in os.walk(OUT))
    print('SadoEE built:', n, 'files in', OUT)
    if '--check' in sys.argv:
        r = subprocess.run([os.path.join(GAME, 'setup-SadoEE.exe'), '--game', GAME, '--list-components',
                            'SadoEE/SadoEE.tp2', '0', '--no-exit-pause'], cwd=GAME, capture_output=True, text=True,
                           encoding='utf-8', errors='replace')
        print(r.stdout[-6000:], r.stderr[-3000:])


if __name__ == '__main__':
    main()
