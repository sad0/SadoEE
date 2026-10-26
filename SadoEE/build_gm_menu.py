"""Builds PSXGM.menu: the camp merchant page (M_PSXGM.lua), its tick menu and the "back" button.

    python build_gm_menu.py            -> PSXGM.menu

Geometry: 864 x 710 like the game's STORE_BUYSELL (centered), drawn over it while the camp store is open. Not modal: the portraits
stay clickable (the buyer is the selected character); a full-size empty button stops clicks reaching the vanilla panel.
Left: category tree. Middle: search + filters, the 8 x 7 icon grid (54 px pitch, like the stash), pages.
Right: the selected item, quantity, Buy, party gold, "vanilla view" (to sell) and Done.
"""
import os

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, 'PSXGM.menu')

W, H = 864, 710
GX, GY, PITCH, CELL, COLS, ROWS = 236, 104, 54, 52, 8, 7
RX, RW = 684, 160  # right panel


def label(area, text=None, style='normal', align='left center', enabled=None, extra=''):
    out = ['\tlabel', '\t{']
    if enabled:
        out.append(f'\t\tenabled "{enabled}"')
    out.append('\t\tarea %d %d %d %d' % area)
    if text:
        out.append(f'\t\ttext lua "{text}"')
        out.append(f'\t\ttext style "{style}"')
        out.append(f'\t\ttext align {align}')
    if extra:
        out.append(extra)
    out.append('\t}')
    return '\n'.join(out)


def button(area, text=None, action=None, style='button', enabled=None, clickable=None, extra=''):
    out = ['\tbutton', '\t{']
    if enabled:
        out.append(f'\t\tenabled "{enabled}"')
    out.append('\t\tarea %d %d %d %d' % area)
    if text:
        out.append(f'\t\ttext lua "{text}"')
        out.append(f'\t\ttext style "{style}"')
        out.append('\t\ttext align center center')
    if clickable:
        out.append(f'\t\tclickable lua "{clickable}"')
    if action:
        out.append(f'\t\taction "{action}"')
    if extra:
        out.append(extra)
    out.append('\t}')
    return '\n'.join(out)


def pbutton(area, text, action, bam, clickable=None, enabled=None):
    """A paper ticket button (art/build_gm_board.py buttons: frames 0 up, 1 pressed, 3 disabled), dark text."""
    return button(area, text, action, style='label_parchment', clickable=clickable, enabled=enabled,
                  extra=f'\t\tbam {bam}\n\t\tsequence 0')


def frame(area, opacity=120):
    return label(area, extra=f'\t\trectangle 1\n\t\trectangle opacity {opacity}')


def page():
    # Background: a notice board (art/build_gm_board.py), two versions swapped by a button: PSXGMBA = assembled
    # (board + papers), PSXGMBB = the same redrawn by SwarmUI. Each notice sits under one part of the page, so the
    # texts on paper use the game's dark parchment styles (BG1 and BG2 both have label_ / normal_parchment).
    P, PN = 'label_parchment', 'normal_parchment'
    items = []
    items.append(label((0, 0, W, H), extra='\t\trectangle 0\n\t\trectangle opacity 255'))
    items.append(label((0, 0, W, H), enabled='PSXGM_Skin() == 1', extra='\t\tmosaic PSXGMBA'))
    items.append(label((0, 0, W, H), enabled='PSXGM_Skin() == 2', extra='\t\tmosaic PSXGMBB'))
    items.append(button((0, 0, W, H), extra='\t\taction ""'))  # eats the clicks meant for STORE_BUYSELL underneath
    items.append(label((0, 0, 0, 0), enabled='PSXGM_Tick()'))  # the tick also runs from the page itself
    # the title in charcoal (art/build_gm_board.py title): PSXGMTT.BAM = the camp merchant in the installed language,
    # PSXGMTC.BAM = "Codex" (Decard's page, the chest mode: the same word in every language)
    items.append(label((GX + 46, 14, 340, 42), enabled="PSXGM_Mode() == 'camp'", extra='\t\tbam PSXGMTT'))
    items.append(label((GX + 46, 14, 340, 42), enabled="PSXGM_Mode() == 'chest'", extra='\t\tbam PSXGMTC'))
    # category tree (the tall notice on the left): the chosen category circled in pencil (PSXGMCIR frame 1)
    items.append('''\tlist
\t{
\t\tcolumn
\t\t{
\t\t\twidth 100
\t\t\tlabel
\t\t\t{
\t\t\t\tarea 0 0 180 26
\t\t\t\tbam PSXGMCIR
\t\t\t\tframe lua "PSXGM_TreeSelected(rowNumber) and 1 or 0"
\t\t\t}
\t\t\tlabel
\t\t\t{
\t\t\t\tarea 10 0 -1 -1
\t\t\t\ttext lua "PSXGM_TreeText(rowNumber)"
\t\t\t\ttext style "%s"
\t\t\t\ttext align left center
\t\t\t}
\t\t}
\t\tarea 26 68 184 580
\t\trowheight 26
\t\ttable "gmTreeList"
\t\tvar gmTreeRow
\t\thidehighlight
\t\taction "PSXGM_TreeClick()"
\t}''' % PN)
    # search + filters (top of the big notice). The "Search..." hint sits UNDER the edit field (drawn first): on top
    # of it, it took the clicks and the field could not get the focus (John 2026-10-23).
    items.append(label((GX + 6, 60, 190, 32), "PSXGM_T('gm_search') .. '...'", enabled="gmFindText == ''"))
    items.append('''\tedit
\t{
\t\tarea %d 60 196 32
\t\tvar gmFindText
\t\ttext style "edit"
\t\tmaxlines 1
\t\tfill 40 25 10 110
\t\taction "return PSXGM_SearchEdit()"
\t}''' % GX)
    # filters: the game's round toggle (ROUNDBUT, frame 0 off / 2 on, as in its options screens; BG1 and BG2)
    for fx, fw, which, act in ((GX + 202, 112, 'usable', 'PSXGM_ToggleUsable()'),
                               (GX + 318, 114, 'afford', 'PSXGM_ToggleAfford()')):
        items.append(label((fx + 2, 64, 24, 24), extra='\n'.join([
            '\t\tbam ROUNDBUT', '\t\tscaleToClip', f'\t\tframe lua "PSXGM_FilterFrame(\'{which}\')"'])))
        items.append(button((fx, 60, fw, 32), extra='\n'.join([
            f'\t\ttext lua "PSXGM_FilterText(\'{which}\')"', f'\t\ttext style "{P}"', '\t\ttext align right center',
            f'\t\taction "{act}"'])))
    # grid
    items.append(label((GX, GY, COLS * PITCH, ROWS * PITCH), extra='\t\tactionScroll "PSXGM_Wheel()"'))
    for i in range(COLS * ROWS):
        x, y = GX + (i % COLS) * PITCH, GY + (i // COLS) * PITCH
        items.append(button((x, y, CELL, CELL), extra='\n'.join([
            '\t\tbam PSSLOT',
            f'\t\ticon lua "PSXGM_CellIcon({i})"',
            f'\t\ttint lua "PSXGM_CellTint({i})"',
            f'\t\tgreyscale lua "PSXGM_CellGrey({i})"',
            f'\t\tcount lua "PSXGM_CellCount({i})"',
            f'\t\ttooltip lua "PSXGM_CellTip({i})"',
            f'\t\taction "PSXGM_CellClick({i})"',
            f'\t\tactionAlt "PSXGM_CellDesc({i})"',
            '\t\tactionScroll "PSXGM_Wheel()"'])))
        items.append(label((x + 36, y + 1, 16, 18), "'*'", style='title', align='center center',
                           enabled=f'PSXGM_CellWished({i})'))
    py = GY + ROWS * PITCH + 6
    items.append(pbutton((GX + 4, py, 30, 30), "'<'", 'PSXGM_Page(-1)', 'PSXGMBN3', clickable='PSXGM_CanPage(-1)'))
    items.append(label((GX + 40, py, 100, 30), 'PSXGM_PageText()', style=P, align='center center'))
    items.append(pbutton((GX + 146, py, 30, 30), "'>'", 'PSXGM_Page(1)', 'PSXGMBN3', clickable='PSXGM_CanPage(1)'))
    items.append(pbutton((GX + 182, py - 1, 144, 32), 'PSXGM_SortText()', 'PSXGM_NextSort()', 'PSXGMBN2'))
    items.append(label((GX + 330, py, 102, 30), 'PSXGM_CountText()', style=PN, align='right center'))
    # messages: the torn strip under the big notice; on its right, Party Stash's "sell marked" (the stash items
    # marked for sale, sold to the camp store: PStash_SellMarked), shown when there is something to sell
    items.append(label((GX + 10, 536, 270, 48), 'PSXGM_MsgText()', style=PN, align='left center'))
    items.append(pbutton((GX + 284, 543, 144, 32), 'PSXGM_SellMarkedText()', 'PSXGM_SellMarked()', 'PSXGMBN2',
                         clickable='PSXGM_CanSellMarked()', enabled="PSXGM_Mode() == 'camp'"))
    # the selected item (wanted poster, top right)
    items.append(button((RX + (RW - CELL) // 2, GY, CELL, CELL), extra='\n'.join([
        '\t\tbam PSSLOT', '\t\ticon lua "PSXGM_SelIcon()"', '\t\tactionAlt "PSXGM_SelDesc()"'])))
    items.append(label((RX + 6, GY + 56, RW - 12, 50), 'PSXGM_SelName()', style=PN, align='center top'))
    items.append(label((RX + 6, GY + 106, RW - 12, 72), 'PSXGM_SelInfo()', style=PN, align='center top'))
    # quantity ticket
    qy = GY + 184
    items.append(pbutton((RX + 16, qy, 30, 30), "'-'", 'PSXGM_Qty(-1)', 'PSXGMBN3'))
    items.append(label((RX + 48, qy, RW - 96, 30), 'PSXGM_QtyText()', style=P, align='center center'))
    items.append(pbutton((RX + RW - 46, qy, 30, 30), "'+'", 'PSXGM_Qty(1)', 'PSXGMBN3'))
    items.append(label((RX + 8, qy + 32, RW - 16, 30), 'PSXGM_TotalText()', style=PN, align='center center'))
    # Buy ticket: the button, the buyer (the selected portrait), the party gold
    items.append(pbutton((RX + 22, 360, 116, 32), 'PSXGM_BuyText()', 'PSXGM_BuySelected()', 'PSXGMBN1',
                         clickable='PSXGM_CanBuy()'))
    items.append(label((RX + 22, 394, RW - 44, 22), 'Infinity_GetSelectedCharacterName()', style=PN,
                       align='center center'))
    items.append(label((RX + 22, 416, RW - 44, 26), 'PSXGM_GoldText()', style=P, align='center center'))
    # done ticket (no vanilla view: John 2026-10-24; selling = the Sell marked ticket)
    items.append(pbutton((RX + 8, 584, 144, 32), "PSXGM_T('gm_done')", 'PSXGM_Done()', 'PSXGMBN2'))
    # campaign filters (John 2026-10-24, the small pinned paper under the grid): an item shows when one of its origins
    # is in a ticked campaign (BG, SoD, BG2, ToB, Black Pits 1 / 2, other), and "Carried" keeps the party's items only;
    # the board swap button is gone (the painted board stays). John's layout: BG SoD BP / BG2 ToB BP2 / Other Carried.
    # and on the small paper on the left (John 2026-10-24): Found (seen in this save) / Not found
    for k, cx, cy, w in ((1, 456, 598, 56), (2, 512, 598, 56), (5, 568, 598, 56),
                         (3, 456, 624, 56), (4, 512, 624, 56), (6, 568, 624, 56),
                         (7, 456, 650, 66), (8, 524, 650, 90),
                         (9, 228, 612, 80), (10, 228, 640, 80)):
        items.append(label((cx, cy + 4, 16, 16), extra='\n'.join([
            '\t\tbam ROUNDBUT', '\t\tscaleToClip', f'\t\tframe lua "PSXGM_CampFrame({k})"'])))
        items.append(label((cx + 18, cy, w - 18, 24), f'PSXGM_CampText({k})', style=P, align='left center'))
        items.append(button((cx, cy, w, 24), extra=f'\t\taction "PSXGM_ToggleCamp({k})"'))
    return '''menu
{
\tname "PSXGM_PAGE"
\talign center center
\tsize %d %d
\tignoreesc
\tonOpen "PSXGM_OnOpen()"
%s
}
''' % (W, H, '\n'.join(items))


def main():
    tick = '''menu
{
\tname "PSXGM_TICK"
\tignoreesc
\t-- Camp merchant: its enabled check runs every frame (throttled in PSXGM_Tick): store discovery, the page.
\tlabel
\t{
\t\tarea 0 0 0 0
\t\tenabled "PSXGM_Tick()"
\t}
}
'''
    back = '''menu
{
\tname "PSXGM_BACK"
\talign center center
\tsize %d %d
\tignoreesc
%s
%s
}
''' % (W, H, frame((664, 14, 184, 32)), button((664, 14, 184, 32), "PSXGM_T('gm_back')", 'PSXGM_Back()'))
    with open(OUT, 'w', newline='\n') as f:
        f.write('-- Generated by build_gm_menu.py: edit that instead.\n')
        f.write(tick + '\n' + back + '\n' + page())
    print('written', OUT)


if __name__ == '__main__':
    main()
