# Validation

The release ROM was rebuilt and checked on 2026-10-12 with RGBDS 1.0.1 and
PyBoy 2.7.0 in CGB mode. Both tools are pinned by the build instructions and
`requirements-validation.txt`.

```sh
make clean
make
python3 tools/validate.py
```

Expected checkpoints from a fresh power-on are:

| Emulated frame | Check |
|---:|---|
| 239 | Completed native `VM LOADING` / `0xb33f` screen; status `$56,$01` |
| 424 | Pong bytecode installed exactly; status `$56,$02`; court and sprites live |
| 456 | Down has moved the left paddle from y=72 to y=120 |
| 472 | Up has moved the paddle back to y=96 |
| 492 | A has served; the ball has moved from `(86,89)` to `(106,79)` |

The validator performs no host memory writes and supplies no save state. It
checks the full installed bytecode, input behavior, frame identity, ROM header,
checksums, and SHA-256.

```text
ROM bytes: 32768
ROM SHA-256: ddecb5ed7927fb6eb07cea62a34e0a8207989ddb7f0cf00bf71c1c8a29da353d
Completed loading RGBA SHA-256: ac3ad2fd2948dd4ca7b977a52a25abb9ee2d10e33223f4aef39865c6c7f1d4a1
```

The run passed in PyBoy. Physical hardware and other emulators have not been
checked.
