#!/bin/bash

MIST=-mist
VIDEO=0
for k in $*; do
    if [ "$k" = -mister ]; then
        echo "MiSTer setup chosen."
        MIST=$k
    fi
    if [ "$k" = -video ]; then
        VIDEO=1
    fi
done

# Mare SDRAM file
if [ ! -s sdram.hex ]; then
    bin2hex < ../../rom/bublbobl.rom > sdram.hex
fi

# Find PROM file
if [ ! -e a71-25.41 ]; then
    zipfile=$(locate bublbobl.zip | head -n 1)
    if [ -z "$zipfile" ]; then
        echo "ERROR: cannot locate bublbobl.zip. Needed to extract a71-25.41."
        exit 1
    fi
    unzip -o $zipfile a71-25.41 || exit $?
fi

export GAME_ROM_PATH=../../rom/bublbobl.rom
export MEM_CHECK_TIME=310_000_000
# 280ms to load the ROM ~17 frames
#export CONVERT_OPTIONS="-resize 300%x300%"
GAME_ROM_LEN=$(stat -c%s $GAME_ROM_PATH)
export YM2203=1

if [ ! -e $GAME_ROM_PATH ]; then
    echo Missing file $GAME_ROM_PATH
    exit 1
fi

# Generic simulation script from JTFRAME
echo "Game ROM length: " $GAME_ROM_LEN
$JTFRAME/bin/sim.sh $MIST -d GAME_ROM_LEN=$GAME_ROM_LEN \
    -sysname tora -d SCANDOUBLER_DISABLE=1 \
    -def ../../hdl/jtbubl.def \
    -d FAST_LOAD \
    -d SIMULATION_VTIMER \
    $*
