#!/bin/bash

OTHER=

while [ $# -gt 0 ]; do
    case $1 in
        -s)
            shift
            if [ ! -d scene${1} ]; then
                echo "Cannot find scene #" $1
                exit 1
            fi
            cp scene${1}/* .;;
        *) OTHER="$OTHER $1";;
    esac
    shift
done

# Palette
byte2hex < pal.bin > pal.hex
gawk "{if (FNR%2==0) print $1}" pal.hex > pal_even.hex
gawk "{if (FNR%2==1) print $1}" pal.hex > pal_odd.hex
rm pal.hex

go.sh -d GFX_ONLY -d NOSOUND -video 2 -deep -d VIDEO_START=1 $OTHER