#!/bin/bash

OTHER=
SCENE=

while [ $# -gt 0 ]; do
    case $1 in
        -s)
            shift
            if [ ! -d scene${1} ]; then
                echo "Cannot find scene #" $1
                exit 1
            fi
            SCENE=$1
            cp scene${1}/* .;;
        *) OTHER="$OTHER $1";;
    esac
    shift
done

# Palette
# Note than in AWK FNR starts from 1
byte2hex < pal.bin > pal.hex
gawk "{if (FNR%2==0) print $1}" pal.hex > pal_odd.hex
gawk "{if (FNR%2==1) print $1}" pal.hex > pal_even.hex
rm pal.hex

# VRAM contents
byte2hex < vram.bin > vram.hex
gawk "{if (FNR%2==0) print $1}" vram.hex > vram_odd.hex
gawk "{if (FNR%2==1) print $1}" vram.hex > vram_even.hex
head vram_even.hex -n  2048 > vram0.hex
head vram_odd.hex  -n  2048 > vram1.hex
tail vram_even.hex -n  2048 > vram2.hex
tail vram_odd.hex  -n  2048 > vram3.hex

go.sh -d GFX_ONLY -d NOSOUND -d VIDEO_START=1 -video 2 -w \
    -d SIMULATION_VTIMER \
    $OTHER 
#-d GRAY

if [ ! -z "$SCENE" ]; then
    cp video-0.jpg $SCENE.jpg
fi
