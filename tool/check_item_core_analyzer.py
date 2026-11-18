#!/usr/bin/env python3
"""CI guard: fail on new analyzer diagnostics while reporting known debt.

The baseline is a frozen upper bound, not an exemption or an analyzer PASS.
A timed-out or crashed analyzer ALWAYS fails. A successful full analyzer
(return code 0) passes only when there are no reported diagnostics.
"""
from __future__ import annotations

import argparse
from collections import Counter
import json
from pathlib import Path
import re
import sys

ANSI = re.compile(r"\x1b\[[0-9;]*m")
DIAGNOSTIC = re.compile(
    r"\b(info|warning|error) • .*? • "
    r"([\w/.-]+):\d+:\d+ • ([a-z0-9_]+)\s*$"
)
SUMMARY = re.compile(r"(\d+) issues? found\.")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--log", type=Path, required=True)
    parser.add_argument("--baseline", type=Path, required=True)
    parser.add_argument("--analyzer-exit", type=int, required=True)
    args = parser.parse_args()

    if args.analyzer_exit not in (0, 1):
        print(
            f"FAIL: analyzer did not finish normally, exit={args.analyzer_exit}",
            file=sys.stderr,
        )
        return 1

    report = ANSI.sub("", args.log.read_text(encoding="utf-8"))
    ceiling = json.loads(args.baseline.read_text(encoding="utf-8"))[
        "diagnostics"
    ]
    issues = Counter()
    for line in report.splitlines():
        match = DIAGNOSTIC.search(line)
        if match:
            severity, path, diagnostic = match.groups()
            issues[f"{path}|{diagnostic}|{severity}"] += 1

    totals = SUMMARY.findall(report)
    if args.analyzer_exit == 1 and not totals:
        print("FAIL: analyzer exit 1 without a parsed diagnostic summary")
        return 1
    if totals and int(totals[-1]) != sum(issues.values()):
        print("FAIL: parsed diagnostic count differs from analyzer summary")
        return 1
    if args.analyzer_exit == 0 and issues:
        print("FAIL: analyzer reported diagnostics despite exit 0")
        return 1

    new_or_growing = {
        key: count
        for key, count in sorted(issues.items())
        if count > ceiling.get(key, 0)
    }
    print(
        f"Full analyzer exit={args.analyzer_exit}; "
        f"observed={sum(issues.values())}; "
        f"legacy ceiling={sum(ceiling.values())}"
    )
    if new_or_growing:
        print("FAIL: new or growing analyzer diagnostics:")
        for key, count in new_or_growing.items():
            print(f"  {key}: {count}, prior ceiling={ceiling.get(key, 0)}")
        return 1
    if issues:
        print(
            "PASS NON-REGRESSION ONLY: existing analyzer diagnostics remain; "
            "full flutter analyze is NOT clean."
        )
    else:
        print("PASS: flutter analyze clean")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
