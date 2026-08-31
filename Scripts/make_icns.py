#!/usr/bin/env python3
"""Pack the standard PNG iconset files into a modern ICNS container."""

from pathlib import Path
import struct
import sys


def chunk(kind: str, payload: bytes) -> bytes:
    return kind.encode("ascii") + struct.pack(">I", len(payload) + 8) + payload


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit("usage: make_icns.py ICONSET_DIR OUTPUT.icns")

    iconset = Path(sys.argv[1])
    output = Path(sys.argv[2])
    entries = [
        ("icp4", "icon_16x16.png"),
        ("icp5", "icon_32x32.png"),
        ("icp6", "icon_32x32@2x.png"),
        ("ic07", "icon_128x128.png"),
        ("ic08", "icon_256x256.png"),
        ("ic09", "icon_512x512.png"),
        ("ic10", "icon_512x512@2x.png"),
        ("ic11", "icon_16x16@2x.png"),
        ("ic12", "icon_32x32@2x.png"),
        ("ic13", "icon_128x128@2x.png"),
        ("ic14", "icon_256x256@2x.png"),
    ]

    payload = b"".join(
        chunk(kind, (iconset / filename).read_bytes())
        for kind, filename in entries
    )
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_bytes(b"icns" + struct.pack(">I", len(payload) + 8) + payload)


if __name__ == "__main__":
    main()
