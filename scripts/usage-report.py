#!/usr/bin/env python3
"""Measure go-coding skill/agent adoption from local Claude Code transcripts.

Scans Claude Code session transcripts (JSONL files under a projects directory,
one subdirectory per project) for real invocations of this plugin's skills and
its `go-reviewer` agent, then renders a Markdown adoption report.

An event is counted when a transcript line is one of:

  * an ``assistant`` message containing a ``tool_use`` block with
    ``name == "Skill"`` and ``input.skill`` starting with ``go-coding:``;
  * an ``assistant`` message containing a ``tool_use`` block with
    ``name`` in (``Task``, ``Agent``) and
    ``input.subagent_type == "go-coding:go-reviewer"``;
  * a ``user`` message whose text contains a ``<command-name>...</command-name>``
    invocation naming one of this plugin's skills (bare, e.g. ``/go-lint-setup``,
    or namespaced, e.g. ``/go-coding:go-lint-setup``).

Session-start banner text and skill-body text echoed back inside tool results
are NOT scanned for matches — only structured ``tool_use`` blocks and user
``<command-name>`` invocations count. Each matching line contributes one event,
attributed to "main" or "subagent" via the transcript's ``isSidechain`` field
(subagent transcripts also live under a ``<session>/subagents/`` path).

Usage:
    python3 scripts/usage-report.py [--projects-dir DIR] [--since YYYY-MM-DD] [--out FILE]

stdlib only — no third-party imports.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path

# Skill directory names this plugin ships (used to recognize a bare, unnamespaced
# slash-command invocation such as "/go-lint-setup" as a go-coding command).
# "go-explain" and "go-linting" were removed in 0.5.0 but stay listed so a scan of
# older transcripts still resolves the events they produced.
GO_SKILL_SHORT_NAMES = {
    "go-coding", "go-concurrency", "go-errors", "go-explain", "go-idioms",
    "go-layout", "go-linting", "go-lint-setup", "go-testing",
}
GO_REVIEWER_SUBAGENT_TYPE = "go-coding:go-reviewer"

SKILL_PREFIX_RE = re.compile(r"^go-coding:")
COMMAND_NAME_RE = re.compile(r"<command-name>\s*(.*?)\s*</command-name>")

TOOL_USE_AGENT_NAMES = ("Task", "Agent")


class Event:
    """One counted invocation."""

    __slots__ = ("name", "month", "source", "session_id")

    def __init__(self, name: str, month: str, source: str, session_id: str | None):
        self.name = name
        self.month = month
        self.source = source  # "main" | "subagent" | "user"
        self.session_id = session_id


def month_of(ts: str | None) -> str:
    if not ts or len(ts) < 7:
        return "unknown"
    return ts[:7]  # YYYY-MM


def iter_transcript_files(projects_dir: Path):
    """Yield (path, is_subagent_file) for every session transcript under projects_dir."""
    if not projects_dir.is_dir():
        return
    for project_dir in sorted(p for p in projects_dir.iterdir() if p.is_dir()):
        for f in sorted(project_dir.glob("*.jsonl")):
            yield f, False
        for f in sorted(project_dir.glob("*/subagents/*.jsonl")):
            yield f, True


def canonical_command_name(raw: str) -> str | None:
    """Return the canonical `go-coding:<skill>` name for a <command-name> invocation,
    or None if it does not name a go-coding skill."""
    cmd = raw.strip().lstrip("/")
    if not cmd:
        return None
    base = cmd.split(":")[-1]
    if cmd.startswith("go-coding:"):
        return "go-coding:" + base
    if base in GO_SKILL_SHORT_NAMES:
        return "go-coding:" + base
    return None


def user_texts(message: dict) -> list[str]:
    content = message.get("content")
    if isinstance(content, str):
        return [content]
    texts = []
    if isinstance(content, list):
        for c in content:
            if isinstance(c, dict) and c.get("type") == "text":
                texts.append(c.get("text", ""))
    return texts


def scan(projects_dir: Path, since: datetime | None):
    """Scan all transcripts, returning (events, session_ids_with_event, files_scanned)."""
    events: list[Event] = []
    sessions_with_event: set[str] = set()
    files_scanned = 0

    for fpath, _is_subagent_file in iter_transcript_files(projects_dir):
        files_scanned += 1
        try:
            with fpath.open("r", errors="replace") as fh:
                for line in fh:
                    line = line.strip()
                    if not line:
                        continue
                    try:
                        obj = json.loads(line)
                    except (json.JSONDecodeError, ValueError):
                        continue

                    ts = obj.get("timestamp")
                    if since is not None:
                        parsed = parse_iso(ts)
                        if parsed is not None and parsed < since:
                            continue

                    sid = obj.get("sessionId")
                    is_sidechain = bool(obj.get("isSidechain", False))
                    typ = obj.get("type")
                    month = month_of(ts)

                    if typ == "assistant":
                        message = obj.get("message") or {}
                        content = message.get("content")
                        if not isinstance(content, list):
                            continue
                        for c in content:
                            if not isinstance(c, dict) or c.get("type") != "tool_use":
                                continue
                            tool_name = c.get("name")
                            inp = c.get("input") or {}
                            if tool_name == "Skill":
                                skill = inp.get("skill", "")
                                if isinstance(skill, str) and SKILL_PREFIX_RE.match(skill):
                                    source = "subagent" if is_sidechain else "main"
                                    events.append(Event(skill, month, source, sid))
                                    if sid:
                                        sessions_with_event.add(sid)
                            elif tool_name in TOOL_USE_AGENT_NAMES:
                                subagent_type = inp.get("subagent_type", "")
                                if subagent_type == GO_REVIEWER_SUBAGENT_TYPE:
                                    source = "subagent" if is_sidechain else "main"
                                    events.append(Event(subagent_type, month, source, sid))
                                    if sid:
                                        sessions_with_event.add(sid)

                    elif typ == "user":
                        message = obj.get("message") or {}
                        for text in user_texts(message):
                            for m in COMMAND_NAME_RE.finditer(text):
                                canon = canonical_command_name(m.group(1))
                                if canon:
                                    events.append(Event(canon, month, "user", sid))
                                    if sid:
                                        sessions_with_event.add(sid)
        except OSError as e:
            print(f"WARNING: could not read {fpath}: {e}", file=sys.stderr)

    return events, sessions_with_event, files_scanned


def parse_iso(ts: str | None):
    if not ts:
        return None
    try:
        # Transcript timestamps are ISO-8601 UTC, e.g. "2026-08-26T22:24:05.213Z".
        return datetime.fromisoformat(ts.replace("Z", "+00:00"))
    except ValueError:
        return None


def aggregate(events: list[Event]):
    """skill -> {"total": n, "main": n, "subagent": n, "user": n, "months": {month: n}}"""
    agg: dict[str, dict] = defaultdict(lambda: {
        "total": 0, "main": 0, "subagent": 0, "user": 0, "months": defaultdict(int),
    })
    for e in events:
        row = agg[e.name]
        row["total"] += 1
        row[e.source] += 1
        row["months"][e.month] += 1

    session_counts: dict[str, set] = defaultdict(set)
    for e in events:
        if e.session_id:
            session_counts[e.name].add(e.session_id)

    return agg, session_counts


def render_markdown(agg, session_counts, events, sessions_with_event, files_scanned,
                     projects_dir: Path, since: datetime | None) -> str:
    lines = []
    lines.append("# go-coding usage report")
    lines.append("")
    generated = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC")
    lines.append(f"Generated: {generated}")
    lines.append(f"Projects dir: `{projects_dir}`")
    lines.append(f"Since: {since.date().isoformat() if since else '(all time)'}")
    lines.append(f"Transcript files scanned: {files_scanned}")
    lines.append(f"Total events: {len(events)}")
    lines.append("")

    all_months = sorted({m for row in agg.values() for m in row["months"] if m != "unknown"})

    lines.append("## Per skill / agent")
    lines.append("")
    header = ["Skill/Agent", "Total", "Main", "Subagent", "User"] + all_months
    lines.append("| " + " | ".join(header) + " |")
    lines.append("|" + "|".join(["---"] * len(header)) + "|")
    for name in sorted(agg.keys()):
        row = agg[name]
        cells = [
            name,
            str(row["total"]),
            str(row["main"]),
            str(row["subagent"]),
            str(row["user"]),
        ] + [str(row["months"].get(m, 0)) for m in all_months]
        lines.append("| " + " | ".join(cells) + " |")
    if not agg:
        lines.append("| _(no events found)_ | | | | |" + "".join(" |" for _ in all_months))
    lines.append("")

    lines.append("## Sessions with >=1 event, per skill / agent")
    lines.append("")
    lines.append("| Skill/Agent | Sessions |")
    lines.append("|---|---|")
    for name in sorted(session_counts.keys()):
        lines.append(f"| {name} | {len(session_counts[name])} |")
    if not session_counts:
        lines.append("| _(no events found)_ | |")
    lines.append("")

    lines.append(f"Distinct sessions with >=1 go-coding event (any skill/agent): {len(sessions_with_event)}")
    lines.append("")

    return "\n".join(lines) + "\n"


def build_arg_parser() -> argparse.ArgumentParser:
    epilog = """\
Counting rules:
  Counted:
    - assistant tool_use block, name "Skill", input.skill starting "go-coding:"
    - assistant tool_use block, name "Task" or "Agent", input.subagent_type
      == "go-coding:go-reviewer"
    - user <command-name> invocations naming a go-coding skill (bare, e.g.
      "/go-lint-setup", or namespaced, e.g. "/go-coding:go-lint-setup")
  Not counted:
    - the SessionStart banner text
    - skill-body text echoed back inside tool results
  Each transcript session is identified by its sessionId; a session's events are
  attributed to "main" or "subagent" via the transcript's isSidechain field.
"""
    parser = argparse.ArgumentParser(
        description="Measure go-coding skill/agent adoption from local Claude Code transcripts.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=epilog,
    )
    parser.add_argument(
        "--projects-dir",
        type=Path,
        default=Path.home() / ".claude" / "projects",
        help="Directory containing Claude Code project transcript folders "
             "(default: ~/.claude/projects)",
    )
    parser.add_argument(
        "--since",
        type=str,
        default=None,
        metavar="YYYY-MM-DD",
        help="Only count events at or after this date (default: all time)",
    )
    parser.add_argument(
        "--out",
        type=Path,
        default=None,
        metavar="FILE",
        help="Write the Markdown report to FILE (default: print to stdout)",
    )
    return parser


def main(argv=None) -> int:
    parser = build_arg_parser()
    args = parser.parse_args(argv)

    since = None
    if args.since:
        try:
            since = datetime.strptime(args.since, "%Y-%m-%d").replace(tzinfo=timezone.utc)
        except ValueError:
            print(f"error: --since must be YYYY-MM-DD, got {args.since!r}", file=sys.stderr)
            return 2

    projects_dir: Path = args.projects_dir
    if not projects_dir.is_dir():
        print(f"No transcripts found: projects directory does not exist: {projects_dir}")
        return 0

    events, sessions_with_event, files_scanned = scan(projects_dir, since)

    if files_scanned == 0:
        print(f"No transcripts found: no .jsonl files under {projects_dir}")
        return 0

    agg, session_counts = aggregate(events)
    report = render_markdown(
        agg, session_counts, events, sessions_with_event, files_scanned, projects_dir, since,
    )

    if args.out:
        args.out.write_text(report)
        print(f"Wrote report to {args.out}")
    else:
        print(report)

    return 0


if __name__ == "__main__":
    sys.exit(main())
