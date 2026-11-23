#!/usr/bin/env python3
"""Fail fast on duplicate top-level GDScript methods before costly Android setup."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
DECLARATION = re.compile(r"^(?:static\s+)?func\s+([A-Za-z_][A-Za-z_0-9]*)\s*\(")


def duplicates(source: str) -> list[tuple[str, int, int]]:
    first: dict[str, int] = {}
    found: list[tuple[str, int, int]] = []
    for line_number, line in enumerate(source.splitlines(), 1):
        # Only top-level declarations; nested function text in strings/comments is ignored.
        match = DECLARATION.match(line)
        if not match:
            continue
        name = match.group(1)
        if name in first:
            found.append((name, first[name], line_number))
        else:
            first[name] = line_number
    return found


def main() -> None:
    assert duplicates("func _notification(what):\n pass\nfunc _notification(what):\n pass") == [
        ("_notification", 1, 3)
    ]
    assert duplicates("# func foo():\nfunc foo():\n pass\n func nested():\n  pass") == []
    scripts = sorted(ROOT.rglob("*.gd"))
    if not scripts:
        raise SystemExit("No GDScript files found")
    errors = [
        f"{script.relative_to(ROOT)}:{second}: duplicate {name} (first at {first})"
        for script in scripts
        for name, first, second in duplicates(script.read_text(encoding="utf-8"))
    ]
    if errors:
        raise SystemExit("\n".join(errors))
    print(f"BLACK_SIGNAL_GDSCRIPT_UNIQUE_METHODS_OK {len(scripts)}")


if __name__ == "__main__":
    main()
