#!/usr/bin/env python3
"""Reject literal backslash-n pasted between GDScript statements.

A previous edit placed '\\n' in executable GDScript, making main.gd
unparseable and preventing Android export. Run from project root.
"""
from pathlib import Path
import re
import sys

root = Path(__file__).resolve().parents[1]
failures = []
for path in sorted(root.rglob("*.gd")):
    if ".godot" in path.parts:
        continue
    for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        # Literal escaped line breaks in comments or between statements are
        # almost always a pasted patch, not a valid GDScript source line.
        if re.search(r"\\n(?=\s*(?:#|[A-Za-z_]))", line):
            failures.append(f"{path.relative_to(root)}:{number}: literal escaped newline")
if failures:
    print("\n".join(failures), file=sys.stderr)
    sys.exit(1)
print("GDScript escaped-newline guard OK")
