#!/bin/bash
mame2dip bublbobl.xml -rbf jtbubl -frac gfx1 2 \
    -ignore plds \
    -start subcpu   0x28000 \
    -start audiocpu 0x30000 \
    -start gfx1     0x40000 \
    -start proms    0xC0000 \
    -swapbytes audiocpu \
    -swapbytes subcpu \
    -swapbytes mcu \
    -swapbytes maincpu