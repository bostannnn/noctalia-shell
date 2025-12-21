#!/usr/bin/env python3
"""
Fix legacy Taskwarrior description corruption caused by passing `+:tag` / `-:tag`
as argv tokens. Those tokens were interpreted as plain text and ended up inside
task descriptions (e.g. "-:someday").

This script finds tasks whose description contains whitespace-delimited tokens
matching `[+-]:<tag>` and removes those tokens from the description.

Dry-run by default. Use --apply to write changes.
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from dataclasses import dataclass
from typing import Iterable


TOKEN_RE = re.compile(r"(^|\s)([+-]):([A-Za-z0-9_-]+)(?=\s|$)")
WS_RE = re.compile(r"\s+")


@dataclass(frozen=True)
class Fix:
    id: int | None
    uuid: str
    before: str
    after: str


def run_task_export(status: str) -> list[dict]:
    proc = subprocess.run(
        ["task", f"status:{status}", "export"],
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    if proc.returncode != 0:
        raise RuntimeError(proc.stderr.strip() or f"task export failed for status:{status}")
    out = proc.stdout.strip()
    if not out or out == "[]":
        return []
    return json.loads(out)


def compute_fixed_description(description: str) -> str:
    # Remove tokens like "-:someday" or "+:tag" when they are separate tokens.
    def _sub(match: re.Match[str]) -> str:
        prefix = match.group(1)
        # Preserve a single leading space if present; we'll normalize later.
        return prefix

    cleaned = TOKEN_RE.sub(_sub, description)
    cleaned = WS_RE.sub(" ", cleaned).strip()
    return cleaned


def find_fixes(tasks: Iterable[dict]) -> list[Fix]:
    fixes: list[Fix] = []
    for task in tasks:
        uuid = str(task.get("uuid") or "").strip()
        if not uuid:
            continue
        before = str(task.get("description") or "")
        after = compute_fixed_description(before)
        if before != after and after:
            fixes.append(Fix(id=task.get("id"), uuid=uuid, before=before, after=after))
    return fixes


def apply_fix(fix: Fix) -> None:
    # Pass description as a single argv element (Taskwarrior will accept spaces within an arg).
    cmd = ["task", "rc.confirmation:off", fix.uuid, "modify", f"description:{fix.after}"]
    proc = subprocess.run(cmd, check=False, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if proc.returncode != 0:
        raise RuntimeError(proc.stderr.strip() or proc.stdout.strip() or f"task modify failed for {fix.uuid}")


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--apply",
        action="store_true",
        help="Apply changes (default is dry-run).",
    )
    parser.add_argument(
        "--status",
        action="append",
        default=[],
        help="Task status to scan (repeatable). Default: pending and waiting.",
    )
    args = parser.parse_args(argv)

    statuses = args.status or ["pending", "waiting"]

    all_tasks: dict[str, dict] = {}
    for st in statuses:
        for task in run_task_export(st):
            uuid = str(task.get("uuid") or "").strip()
            if uuid:
                all_tasks[uuid] = task

    fixes = find_fixes(all_tasks.values())
    if not fixes:
        print("No tasks with legacy '+:tag'/'-:tag' tokens found.")
        return 0

    print(f"Found {len(fixes)} task(s) to fix:")
    for f in fixes:
        label = f"id={f.id}" if f.id is not None else f"uuid={f.uuid}"
        print(f"- {label}: {f.before!r} -> {f.after!r}")

    if not args.apply:
        print("\nDry-run only. Re-run with --apply to modify tasks.")
        return 0

    for f in fixes:
        apply_fix(f)

    print("\nApplied.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))

