#!/bin/sh
set -eu

OUT=build/font_glyphs.bin
CANDIDATES="
/usr/share/consolefonts/default8x16.psfu.gz
/usr/share/consolefonts/default8x16.psf
/usr/share/kbd/consolefonts/default8x16.psfu.gz
/usr/share/kbd/consolefonts/drdos8x16.psfu.gz
/usr/share/kbd/consolefonts/cp850-8x16.psfu.gz
/usr/share/kbd/consolefonts/UniCyr_8x16.psf.gz
"

mkdir -p build
mkdir -p /tmp/opencode

try() {
    src=$1
    tmp=$2
    if [ -f "$src" ]; then
        if [ "${src##*.}" = "gz" ]; then
            gunzip -c "$src" > "$tmp"
        else
            cp "$src" "$tmp"
        fi
        magic4=$(od -An -tx1 -N4 "$tmp" | tr -d ' \n')
        if [ "$magic4" = "72b54a86" ]; then
            hs=$(od -An -tu4 -j8 -N4 "$tmp" | tr -d ' ')
            cs=$(od -An -tu4 -j20 -N4 "$tmp" | tr -d ' ')
            height=$(od -An -tu4 -j24 -N4 "$tmp" | tr -d ' ')
            width=$(od -An -tu4 -j28 -N4 "$tmp" | tr -d ' ')
            if [ "$cs" = "16" ] && [ "$height" = "16" ] && [ "$width" = "8" ]; then
                dd if="$tmp" of="$OUT" bs=1 skip="$hs" count=4096 status=none
                if [ "$(wc -c < "$OUT")" -eq 4096 ]; then
                    echo "FONT 4096 bytes"
                    return 0
                fi
            fi
        fi
        magic2=$(od -An -tx1 -N2 "$tmp" | tr -d ' \n')
        if [ "$magic2" = "3604" ]; then
            cs=$(od -An -tu1 -j3 -N1 "$tmp" | tr -d ' ')
            if [ "$cs" = "16" ]; then
                dd if="$tmp" of="$OUT" bs=1 skip=4 count=4096 status=none
                if [ "$(wc -c < "$OUT")" -eq 4096 ]; then
                    echo "FONT 4096 bytes"
                    return 0
                fi
            fi
        fi
    fi
    return 1
}

tmp=/tmp/opencode/font_candidate.bin
for src in $CANDIDATES; do
    rm -f "$tmp"
    if try "$src" "$tmp"; then
        rm -f "$tmp"
        exit 0
    fi
done
rm -f "$tmp"
echo "font: no usable 8x16 console font found" >&2
exit 1