#!/usr/bin/env python3
"""Check that a PE executable targets arm64 (machine 0xAA64)."""

import struct
import sys

PE_MACHINE_ARM64 = 0xAA64


def pe_machine(path):
    with open(path, "rb") as f:
        dos = f.read(64)
        if dos[:2] != b"MZ":
            raise ValueError("not a DOS/PE file")
        f.seek(struct.unpack("<I", dos[0x3C:0x40])[0])
        if f.read(4) != b"PE\x00\x00":
            raise ValueError("invalid PE signature")
        return struct.unpack("<H", f.read(2))[0]


def main():
    machine = pe_machine(sys.argv[1])
    print(f"Machine type: 0x{machine:04X}")
    if machine != PE_MACHINE_ARM64:
        print("[FAIL] expected arm64 (0xAA64)")
        return 1
    print("[OK] arm64")
    return 0


if __name__ == "__main__":
    sys.exit(main())
