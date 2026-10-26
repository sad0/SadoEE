"""The quest chronicle's title in charcoal (Decard's quest page, John 2026-10-24), like the camp merchant's.

    python build_q_title.py      -> ../PSXQTEN.BAM, ../PSXQTFR.BAM (the install copies its language's as PSXQT.BAM)

Lettering: Windows' Ink Free font, black on white (gm/title_quests_<lang>.png), then build_gm_board.charcoal().
"""
import os
import sys

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import build_gm_board  # noqa: E402

TITLES = {'en': ('Quests', 'PSXQTEN'), 'fr': ('Quêtes', 'PSXQTFR')}


def main():
    sys.argv = sys.argv[:1]
    import build_art
    font = ImageFont.truetype(r'C:\Windows\Fonts\Inkfree.ttf', 150)
    for key, (text, bam) in TITLES.items():
        src = os.path.join(build_gm_board.GM, 'title_quests_%s.png' % key)
        im = Image.new('L', (900, 240), 255)
        ImageDraw.Draw(im).text((30, 20), text, font=font, fill=0)
        im.save(src)
        img = build_gm_board.charcoal(src, (340, 42))
        img.save(os.path.join(build_gm_board.GM, 'title_quests_%s_charcoal.png' % key))
        # BAM V1 is 1-bit transparent: keep the solid strokes, drop the faint smudge
        img.putalpha(img.getchannel('A').point(lambda a: 255 if a > 100 else 0))
        build_art.write_bam(img, os.path.join(HERE, '..', bam + '.BAM'))
        print('written', bam + '.BAM')


if __name__ == '__main__':
    main()
