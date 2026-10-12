# Provenance

The native VM, ISA macros, Pong bytecode source, and original artwork were
created by Ruben Boonen for the VM Pong project. This standalone packaging
preserves the compiled identities of those components:

| Component | Bytes | SHA-256 |
|---|---:|---|
| Native VM image | 2,304 | `5586a6103a6fb02199a225518c66726638efed27c5996a2fa11901871f609648` |
| Pong bytecode | 499 | `cc0a04e7ac6795fb4bb1ae32d6114c07c26ff591d0eaf7b012ee893a2dabc894` |
| Unpacked tiles | 1,488 | `1fae9744aa0301145c6f4b4cf6bf4eb9bb5c5c4f8376bbc20dc9112f216cbe78` |
| Packed tiles | 1,094 | `135912cb4dfd257ecba00a4a083ee939ba6711a51eac22ccc9260508d898dad2` |
| Loading map | 224 | `e67563d8017800ea033d0c6e0326fd80f0ae4fb0bf08116f61701859b65358e4` |

The `VM LOADING` composition, `0xb33f` signature, court, paddles, ball, and
score tiles are original project artwork. The standalone bootstrap and build
script were added to package the native runtime and bytecode as an independent
cartridge. No source, graphics, audio, or other data from a commercial game is
included.

RGBDS writes the standard 48-byte Nintendo logo field required by Game Boy
boot validation. That platform header field is distinct from this project's
artwork. Nintendo names and platform marks belong to their owners. RGBDS and
PyBoy retain their own licenses.

The project source and original artwork are available under the MIT License;
see `LICENSE.md`.
