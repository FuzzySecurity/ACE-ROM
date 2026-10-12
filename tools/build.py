"""Standalone RGBDS build; only Python's standard library is required."""
from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / "build"
EXPECTED = {
    "boot-tiles.bin": "1fae9744aa0301145c6f4b4cf6bf4eb9bb5c5c4f8376bbc20dc9112f216cbe78",
    "boot-tiles.packbits.bin": "135912cb4dfd257ecba00a4a083ee939ba6711a51eac22ccc9260508d898dad2",
    "boot-map.bin": "e67563d8017800ea033d0c6e0326fd80f0ae4fb0bf08116f61701859b65358e4",
    "resident-vm.bin": "5586a6103a6fb02199a225518c66726638efed27c5996a2fa11901871f609648",
    "pong-cartridge.bin": "cc0a04e7ac6795fb4bb1ae32d6114c07c26ff591d0eaf7b012ee893a2dabc894",
}


def identity(path: Path) -> dict:
    data = path.read_bytes()
    return {"bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()}


def run(tool: str, *args: str) -> None:
    subprocess.run([os.environ.get(tool.upper(), tool), *args], cwd=ROOT, check=True)


def symbols(path: Path) -> dict[str, int]:
    return {
        name: int(address, 16)
        for address, name in re.findall(
            r"^00:([0-9a-fA-F]{4})\s+(\S+)$", path.read_text(), re.MULTILINE
        )
    }


def verify_identity(path: Path, name: str) -> None:
    if identity(path)["sha256"] != EXPECTED[name]:
        raise SystemExit(f"{name} differs from the preserved original; build refused")


def main() -> None:
    BUILD.mkdir(exist_ok=True)
    versions = {}
    for tool in ("rgbasm", "rgblink", "rgbfix"):
        executable = os.environ.get(tool.upper(), tool)
        try:
            result = subprocess.run(
                [executable, "--version"], capture_output=True, text=True, check=True
            )
        except FileNotFoundError:
            raise SystemExit(f"Install RGBDS and put {executable} on PATH") from None
        versions[tool] = result.stdout.strip()
    for name in ("boot-tiles.bin", "boot-tiles.packbits.bin", "boot-map.bin"):
        verify_identity(ROOT / "assets" / name, name)
    include = ("-I", "build/", "-I", "assets/", "-I", "src/")
    for source, output in (
        ("resident-vm", "resident-vm"), ("pong", "pong-cartridge")
    ):
        run("rgbasm", *include, "-o", f"build/{output}.o", f"src/{source}.asm")
        run("rgblink", "-x", "-o", f"build/{output}.bin", "-n",
            f"build/{output}.sym", f"build/{output}.o")
        verify_identity(BUILD / f"{output}.bin", f"{output}.bin")
    vm = symbols(BUILD / "resident-vm.sym")
    addresses = {
        "VM_START": vm["vmStart"], "VM_WAIT_PACKET": vm["waitPacket"],
        "VM_WAIT_FRAME": vm["waitFrame"], "VM_DISPATCH": vm["dispatch"],
    }
    (BUILD / "resident-addresses.inc").write_text(
        "; Generated from this build's original resident symbols.\n" +
        "".join(f"DEF {name} EQU ${address:04x}\n" for name, address in addresses.items())
    )
    run("rgbasm", *include, "-o", "build/rom.o", "src/rom.asm")
    run("rgblink", "-p", "0xff", "-o", "build/vm-pong-demo.gb", "-n",
        "build/vm-pong-demo.sym", "-m", "build/vm-pong-demo.map", "build/rom.o")
    run("rgbfix", "-v", "-C", "-p", "0xff", "-m", "0", "-r", "0",
        "-t", "VM PONG DEMO", "build/vm-pong-demo.gb")
    rom = (BUILD / "vm-pong-demo.gb").read_bytes()
    header_sum = 0
    for byte in rom[0x134:0x14d]:
        header_sum = (header_sum - byte - 1) & 0xff
    global_sum = (sum(rom) - sum(rom[0x14e:0x150])) & 0xffff
    logo_sha256 = hashlib.sha256(rom[0x104:0x134]).hexdigest()
    if not (len(rom) == 32768 and rom[0x143] == 0xc0 and
            rom[0x147:0x14a] == b"\x00\x00\x00" and
            logo_sha256 == "daf4cabdc852baa0291849203f0b41fd0b4ecd58e0d7aff4a509f5de4d7f9a2e" and
            rom[0x14d] == header_sum and
            int.from_bytes(rom[0x14e:0x150], "big") == global_sum):
        raise SystemExit("Generated ROM header/checksum validation failed")
    manifest = {
        "schema_version": 1, "tool_versions": versions,
        "seed": 37, "native_reveal_vblanks": 169,
        "standalone_completed_mark_hold_vblanks": 90,
        "runtime_receiver_redirect": {
            "address": addresses["VM_WAIT_PACKET"], "bytes": 3,
            "purpose": "JP standaloneInstallCartridge after native reveal",
        },
        "header": {
            "title": "VM PONG DEMO", "cgb_only": True,
            "mapper": "ROM ONLY", "rom_bytes": 32768, "cartridge_ram_bytes": 0,
            "header_checksum": header_sum, "global_checksum": global_sum,
            "platform_logo": "standard hardware header supplied by rgbfix -v",
            "platform_logo_sha256": logo_sha256,
        },
        "inputs": {
            str(path.relative_to(ROOT)): identity(path)
            for path in sorted([
                ROOT / "Makefile", ROOT / "tools/build.py",
                *ROOT.joinpath("src").glob("*"),
                *ROOT.joinpath("assets").glob("*.bin"),
            ])
        },
        "preserved_assets": {
            name: identity(ROOT / "assets" / name)
            for name in ("boot-tiles.bin", "boot-tiles.packbits.bin", "boot-map.bin")
        },
        "artifacts": {
            name: identity(BUILD / name)
            for name in (
                "resident-vm.bin", "pong-cartridge.bin", "vm-pong-demo.gb",
                "resident-vm.sym", "pong-cartridge.sym", "resident-addresses.inc",
                "vm-pong-demo.sym", "vm-pong-demo.map",
            )
        },
    }
    (BUILD / "manifest.json").write_text(
        json.dumps(manifest, indent=2, sort_keys=True) + "\n"
    )
    result = manifest["artifacts"]["vm-pong-demo.gb"]
    print(f"build/vm-pong-demo.gb: {result['bytes']} bytes; SHA-256 {result['sha256']}")


if __name__ == "__main__":
    main()
