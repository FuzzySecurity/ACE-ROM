# Native artwork assets

`boot-tiles.bin` is the authoritative 93-tile asset: sixteen bytes
per 8×8 tile in Game Boy two-bit planar order, alternating low/high bytes for
each row. Tiles 0–14 are the Pong blank, rail, paddle, ball, score
digits, and net. Tiles 15–92 complete the `VM LOADING` composition, including
the filled block mark and circuit socket. `boot-tiles.packbits.bin` is the exact
1,094-byte stream expanded by the resident into the same 1,488 tile bytes.

`boot-map.bin` holds the occupied 16×14 rectangle's tile indices in column
order: fourteen row indices for the first column, then fourteen for the next.
This 128×112 pixel rectangle begins at `(16,16)` on the 160×144 screen. The
resident reveals one whole column every six VBlanks. VRAM map rows have a
32-tile stride; the resident maps this compact asset to that hardware layout.

The resident palette uses CGB RGB5 values `(2,2,2)`, `(18,9,8)`, `(11,11,10)`,
and `(27,27,25)`: charcoal, faded red, warm stone, and off-white. The native
160×144 PNGs in `docs/` show the emulator output, including this palette.

These binary assets are complete source inputs. The standalone build includes
them directly and checks their hashes. To create a changed version,
edit these with your own Game Boy tile tooling and update the explicit expected
identities in `tools/build.py` after reviewing the result.
