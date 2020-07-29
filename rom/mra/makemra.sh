#!/bin/bash

(cd $JTFRAME/cc && make)

COMMON="-rbf jtbubl -frac gfx1 2 \
    -ignore plds \
    -start subcpu   0x28000 \
    -start audiocpu 0x30000 \
    -start mcu      0x38000 \
    -start gfx1     0x40000 \
    -start proms    0xC0000 \
    -swapbytes audiocpu \
    -swapbytes subcpu \
    -swapbytes mcu \
    -swapbytes maincpu"

mkdir -p _alt/{_Tokio,"_Bubble Bobble"}

mame2dip bublbobl.xml $COMMON -buttons shoot jump -altfolder "_alt/_Bubble Bobble"
mame2dip tokio.xml $COMMON -buttons shoot formation -altfolder "_alt/_Tokio"

# For now, the bootleg for Tokio is the main one
# as the MCU is not implemented yet
mv 'Tokio - Scramble Formation (newer).mra' _alt/_Tokio
mv _alt/_Tokio/'Tokio - Scramble Formation (bootleg).mra' .
