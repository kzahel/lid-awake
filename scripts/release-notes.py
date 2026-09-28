#!/usr/bin/env python3
"""Extract the required changelog section for a release."""

import re
import sys
from pathlib import Path


def main() -> int:
    if len(sys.argv) != 2 or not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", sys.argv[1]):
        print("Usage: scripts/release-notes.py MAJOR.MINOR.PATCH", file=sys.stderr)
        return 1

    version = sys.argv[1]
    changelog = Path(__file__).resolve().parent.parent / "CHANGELOG.md"
    lines = changelog.read_text().splitlines()
    heading = f"## [{version}]"
    matches = [index for index, line in enumerate(lines) if line.strip() == heading]
    if len(matches) != 1:
        print(f"Expected exactly one {heading} section in {changelog}", file=sys.stderr)
        return 1

    start = matches[0] + 1
    end = next((index for index in range(start, len(lines)) if lines[index].startswith("## ")), len(lines))
    notes = "\n".join(lines[start:end]).strip()
    if not notes or not any(line.startswith("- ") for line in notes.splitlines()):
        print(f"{heading} needs at least one release note", file=sys.stderr)
        return 1
    print(notes)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
