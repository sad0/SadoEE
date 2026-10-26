"""Builds the camp stores (empty; M_PSXGM.lua fills them in game).

    python build_gm_store.py           -> PSXCAMP.STO, PSXCHEST.STO, PSXSEEN.STO

PSXCHEST: the camp chest (John 2026-10-23): the stash, what the known stores sell, every item of the game; a store
the player only buys from (flag 1). PSXSEEN: a hidden bag (type 5) never opened, the save's log of the items seen
(one entry per item: M_PSXGM.lua packs how / where into its usage counts, flags and stock).


STO V1.0: type 0 (store), flags = buy | sell, sell markup 300 % (M_PSXGM.lua switches it to each item's
best markup seen while buying through the page; the vanilla view, used to sell, must not be a cheaper way to buy), buy markup 50 %, the item types it buys from the party (everything but quest
categories: keys, gold, books, notes...). Name strref -1: the installer sets it (SAY NAME), the page has its own title.
"""
import os
import struct

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, 'PSXCAMP.STO')

BUYS = [1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31,
        32, 34, 35, 41, 44, 47, 49, 53, 57, 60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 72, 73]
HEADER = 0x9C


def build(name_strref=-1, typ=0, flags=0x1 | 0x2, buy_types=BUYS):
    buys = b''.join(struct.pack('<I', t) for t in buy_types)
    h = bytearray(HEADER)
    h[0:8] = b'STORV1.0'
    struct.pack_into('<IiI', h, 0x08, typ, name_strref, flags)
    struct.pack_into('<III', h, 0x14, 300, 50, 0)       # sell markup, buy markup, depreciation
    struct.pack_into('<HH', h, 0x20, 0, 0)              # steal failure, capacity (0 = no limit)
    struct.pack_into('<II', h, 0x2C, HEADER, len(buy_types))  # purchased types
    struct.pack_into('<II', h, 0x34, HEADER + len(buys), 0)  # items
    struct.pack_into('<II', h, 0x3C, 0, 0)              # lore, identify price
    struct.pack_into('<II', h, 0x4C, HEADER + len(buys), 0)  # drinks
    struct.pack_into('<II', h, 0x70, HEADER + len(buys), 0)  # cures
    return bytes(h) + buys


if __name__ == '__main__':
    for name, data in (('PSXCAMP', build()), ('PSXCHEST', build(flags=0x1, buy_types=[])),
                       ('PSXSEEN', build(typ=5, flags=0, buy_types=[]))):
        with open(os.path.join(HERE, name + '.STO'), 'wb') as f:
            f.write(data)
        print('written', name + '.STO')
