#!/usr/bin/env python3
"""Remove Windows CRLF from shell scripts in current directory."""
from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parent

def main() -> None:
    fixed = 0
    for path in sorted(ROOT.glob("*.sh")):
        raw = path.read_bytes()
        if b"\r" not in raw:
            continue
        path.write_bytes(raw.replace(b"\r\n", b"\n").replace(b"\r", b"\n"))
        print(f"fixed: {path.name}")
        fixed += 1
    if fixed:
        print(f"done, {fixed} file(s)")
    else:
        print("no CRLF found in *.sh")

if __name__ == "__main__":
    main()
