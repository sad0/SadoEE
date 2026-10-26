"""Builds PSXQ.menu: the quest chronicle page (M_PSXQ.lua), Decard's quest page (John 2026-10-24).

    python build_q_menu.py            -> PSXQ.menu

Same notice board and geometry as the camp merchant page (build_gm_menu.py: 864 x 710, centered). Left: games and
kinds, the status filters. Middle: search, the quest list, the selected quest's journal / hints / full solution.
Right: the selected quest (title, game, chapter, place, status), the Journal / Hints / Full solution tickets, Close.
"""
import os

from build_gm_menu import W, H, GX, RX, RW, label, button, pbutton

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, 'PSXQ.menu')
P, PN = 'label_parchment', 'normal_parchment'
MW = 432           # the big notice's width
LY, LH = 100, 208  # quest list: 8 rows of 26
DY = LY + LH + 10  # detail block


def page():
    items = []
    items.append(label((0, 0, W, H), extra='\t\trectangle 0\n\t\trectangle opacity 255'))
    items.append(label((0, 0, W, H), enabled='PSXQ_Skin() == 1', extra='\t\tmosaic PSXGMBA'))
    items.append(label((0, 0, W, H), enabled='PSXQ_Skin() == 2', extra='\t\tmosaic PSXGMBB'))
    items.append(button((0, 0, W, H), extra='\t\taction ""'))  # eats the clicks meant for the world underneath
    # the title in charcoal (art/build_gm_board.py title): PSXQT = "Quests" in the installed language
    items.append(label((GX + 46, 14, 340, 42), extra='\t\tbam PSXQT'))
    # games and kinds (the tall notice on the left), the chosen one circled in pencil (PSXGMCIR frame 1)
    items.append('''\tlist
\t{
\t\tcolumn
\t\t{
\t\t\twidth 100
\t\t\tlabel
\t\t\t{
\t\t\t\tarea 0 0 180 26
\t\t\t\tbam PSXGMCIR
\t\t\t\tframe lua "PSXQ_TreeSelected(rowNumber) and 1 or 0"
\t\t\t}
\t\t\tlabel
\t\t\t{
\t\t\t\tarea 10 0 -1 -1
\t\t\t\ttext lua "PSXQ_TreeText(rowNumber)"
\t\t\t\ttext style "%s"
\t\t\t\ttext align left center
\t\t\t}
\t\t}
\t\tarea 26 68 184 338
\t\trowheight 26
\t\ttable "qTreeList"
\t\tvar qTreeRow
\t\thidehighlight
\t\taction "PSXQ_TreeClick()"
\t}''' % PN)
    # status filters: the game's round toggle (ROUNDBUT, frame 0 off / 2 on), lower part of the left notice
    for i, which in enumerate(('active', 'none', 'done')):
        y = 440 + i * 36
        items.append(label((32, y + 4, 24, 24), extra='\n'.join([
            '\t\tbam ROUNDBUT', '\t\tscaleToClip', f'\t\tframe lua "PSXQ_ShowFrame(\'{which}\')"'])))
        items.append(button((30, y, 176, 32), extra='\n'.join([
            f'\t\ttext lua "PSXQ_ShowText(\'{which}\')"', f'\t\ttext style "{P}"', '\t\ttext align left center',
            '\t\tpad 32 0 0 0', f'\t\taction "PSXQ_ToggleShow(\'{which}\')"'])))
    # search (top of the big notice): the "Search..." hint UNDER the edit field (on top it takes the clicks)
    items.append(label((GX + 6, 60, MW - 12, 32), "PSXQ_T('q_search') .. '...'", enabled="qFindText == ''"))
    items.append('''\tedit
\t{
\t\tarea %d 60 %d 32
\t\tvar qFindText
\t\ttext style "edit"
\t\tmaxlines 1
\t\tfill 40 25 10 110
\t\taction "return PSXQ_SearchEdit()"
\t}''' % (GX, MW))
    # the quest list: title, status
    items.append('''\tlist
\t{
\t\tcolumn
\t\t{
\t\t\twidth 74
\t\t\tlabel
\t\t\t{
\t\t\t\tenabled "PSXQ_ListSelected(rowNumber)"
\t\t\t\tarea 0 0 -1 -1
\t\t\t\tfill 90 60 20 70
\t\t\t}
\t\t\tlabel
\t\t\t{
\t\t\t\tarea 6 0 -1 -1
\t\t\t\ttext lua "PSXQ_ListText(rowNumber)"
\t\t\t\ttext style "%s"
\t\t\t\ttext align left center
\t\t\t}
\t\t}
\t\tcolumn
\t\t{
\t\t\twidth 26
\t\t\tlabel
\t\t\t{
\t\t\t\tenabled "PSXQ_ListSelected(rowNumber)"
\t\t\t\tarea 0 0 -1 -1
\t\t\t\tfill 90 60 20 70
\t\t\t}
\t\t\tlabel
\t\t\t{
\t\t\t\tarea 0 0 -1 -1
\t\t\t\ttext lua "PSXQ_ListStatus(rowNumber)"
\t\t\t\ttext style "%s"
\t\t\t\ttext align right center
\t\t\t}
\t\t}
\t\tarea %d %d %d %d
\t\trowheight 26
\t\ttable "qListRows"
\t\tvar qListRow
\t\thidehighlight
\t\tscrollbar 'GUISCRP'
\t\taction "PSXQ_ListClick()"
\t}''' % (PN, PN, GX, LY, MW, LH))
    # a pencil line between the list and the selected quest (John 2026-10-24)
    items.append(label((GX + 6, DY - 5, MW - 12, 2), extra='\t\tfill 60 40 20 170'))
    # the selected quest: which view, then its text (scrolls)
    items.append(label((GX + 6, DY, MW - 12, 26), 'PSXQ_DetailTitle()', style=P, align='left center'))
    items.append('''\ttext
\t{
\t\tarea %d %d %d %d
\t\ttext lua "PSXQ_DetailText()"
\t\ttext style "%s"
\t\ttext align left top
\t\tscrollbar 'GUISCRP'
\t}''' % (GX + 6, DY + 28, MW - 12, 488 - DY - 28, PN))
    # the torn strip under the big notice: how many quests are listed
    items.append(label((GX + 10, 536, 410, 48), 'PSXQ_CountText()', style=PN, align='left center'))
    # the selected quest (top right poster)
    items.append(label((RX + 6, 62, RW - 12, 96), 'PSXQ_SelTitle()', style=P, align='center center'))
    items.append(label((RX + 6, 160, RW - 12, 110), 'PSXQ_SelInfo()', style=PN, align='center top'))
    # the three views
    items.append(pbutton((RX + 8, 292, 144, 32), "PSXQ_ViewText('journal')", "PSXQ_SetView('journal')", 'PSXGMBN2',
                         clickable='PSXQ_HasSel()'))
    items.append(pbutton((RX + 8, 364, 144, 32), "PSXQ_ViewText('hints')", "PSXQ_SetView('hints')", 'PSXGMBN2',
                         clickable='PSXQ_HasSel()'))
    items.append(pbutton((RX + 8, 404, 144, 32), "PSXQ_ViewText('solution')", "PSXQ_SetView('solution')",
                         'PSXGMBN2', clickable='PSXQ_HasSel()'))
    # close ticket (Esc too)
    items.append(pbutton((RX + 8, 584, 144, 32), "PSXQ_T('q_close')", 'PSXQ_Close()', 'PSXGMBN2')
                 .replace('\t\taction ', '\t\ton esc\n\t\taction ', 1))
    # board swap (bottom left, a paper tag on the wood): the camp merchant's setting
    items.append(pbutton((20, 674, 196, 28), 'PSXQ_SkinText()', 'PSXQ_NextSkin()', 'PSXGMBN4',
                         enabled='PSXQ_CanSkin()'))
    return '''menu
{
\tname "PSXQ_PAGE"
\talign center center
\tsize %d %d
\tignoreesc
\tonOpen "PSXQ_OnOpen()"
%s
}
''' % (W, H, '\n'.join(items))


def main():
    with open(OUT, 'w', newline='\n') as f:
        f.write('-- Generated by build_q_menu.py: edit that instead.\n')
        f.write(page())
    print('written', OUT)


if __name__ == '__main__':
    main()
