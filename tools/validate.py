"""Headless validation for the standalone VM Pong ROM."""
from __future__ import annotations

import hashlib
import io
from importlib.metadata import version
from pathlib import Path

from pyboy import PyBoy

ROOT = Path(__file__).resolve().parents[1]
ROM = ROOT / "build" / "vm-pong-demo.gb"
PONG = ROOT / "build" / "pong-cartridge.bin"
EXPECTED_ROM_SHA256 = "ddecb5ed7927fb6eb07cea62a34e0a8207989ddb7f0cf00bf71c1c8a29da353d"
EXPECTED_LOADING_RGBA_SHA256 = (
    "ac3ad2fd2948dd4ca7b977a52a25abb9ee2d10e33223f4aef39865c6c7f1d4a1"
)


def require(condition: bool, message: str) -> None:
    if not condition:
        raise RuntimeError(message)


def memory_bytes(pyboy: PyBoy, start: int, length: int) -> bytes:
    return bytes(pyboy.memory[address] for address in range(start, start + length))


def main() -> None:
    require(version("pyboy") == "2.7.0", "validation requires PyBoy 2.7.0")
    rom = ROM.read_bytes()
    require(len(rom) == 32768, "ROM is not 32 KiB")
    require(hashlib.sha256(rom).hexdigest() == EXPECTED_ROM_SHA256, "ROM hash differs")
    require(rom[0x143] == 0xC0, "ROM is not marked CGB-only")
    require(rom[0x147:0x14A] == b"\x00\x00\x00", "unexpected mapper/RAM fields")

    header_sum = 0
    for byte in rom[0x134:0x14D]:
        header_sum = (header_sum - byte - 1) & 0xFF
    global_sum = (sum(rom) - sum(rom[0x14E:0x150])) & 0xFFFF
    require(rom[0x14D] == header_sum, "header checksum differs")
    require(int.from_bytes(rom[0x14E:0x150], "big") == global_sum, "global checksum differs")

    pyboy = PyBoy(
        io.BytesIO(rom),
        ram_file=None,
        rtc_file=None,
        window="null",
        bootrom=None,
        cgb=True,
        sound_emulated=False,
        log_level="ERROR",
        randomize=False,
    )
    pyboy.set_emulation_speed(0)
    try:
        require(pyboy.tick(239, render=True, sound=False), "emulator stopped during loading")
        loading_hash = hashlib.sha256(pyboy.screen.ndarray.tobytes()).hexdigest()
        require(loading_hash == EXPECTED_LOADING_RGBA_SHA256, "loading frame differs")
        require(memory_bytes(pyboy, 0xD220, 2) == b"\x56\x01", "loading status differs")

        require(pyboy.tick(185, render=True, sound=False), "emulator stopped before Pong")
        require(memory_bytes(pyboy, 0xD220, 2) == b"\x56\x02", "Pong status differs")
        pong = PONG.read_bytes()
        require(memory_bytes(pyboy, 0xD000, len(pong)) == pong, "installed Pong differs")
        require(memory_bytes(pyboy, 0xD204, 2) == bytes((72, 73)), "initial paddles differ")
        ball_before = tuple(memory_bytes(pyboy, 0xD200, 2))

        pyboy.button_press("down")
        require(pyboy.tick(32, render=False, sound=False), "emulator stopped on Down")
        pyboy.button_release("down")
        require(pyboy.memory[0xD204] == 120, "Down did not move the left paddle")

        pyboy.button_press("up")
        require(pyboy.tick(16, render=False, sound=False), "emulator stopped on Up")
        pyboy.button_release("up")
        require(pyboy.memory[0xD204] == 96, "Up did not move the left paddle")

        pyboy.button_press("a")
        require(pyboy.tick(1, render=False, sound=False), "emulator stopped on A")
        pyboy.button_release("a")
        require(pyboy.tick(19, render=True, sound=False), "emulator stopped after serve")
        ball_after = tuple(memory_bytes(pyboy, 0xD200, 2))
        require(ball_before == (86, 89), f"unexpected ball before serve: {ball_before}")
        require(ball_after == (106, 79), f"ball did not enter live play: {ball_after}")
    finally:
        pyboy.stop(save=False)

    print(f"PASS PyBoy {version('pyboy')}: loading, cartridge, controls, and live Pong")
    print(f"ROM SHA-256 {EXPECTED_ROM_SHA256}")


if __name__ == "__main__":
    main()
