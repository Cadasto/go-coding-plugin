#!/usr/bin/env bash
# PostToolUse / afterFileEdit hook (host-agnostic): format the just-edited Go file.
#
# Runs `gofumpt -w` (the stricter gofmt superset) when gofumpt is on PATH, else
# `gofmt -w -s`. Host-only by design — formatting is cheap and instantaneous; a
# container round-trip on every edit would dominate a save hook's latency budget.
# Silent no-op when no Go formatter is installed (the session-start hook already
# recommends installing one), and ALWAYS exits 0 so it can never block an edit.
#
# File-path resolution, in order:
#   1. $CLAUDE_FILE_PATH          — set by Claude Code for Write/Edit hooks (fast path).
#   2. tool payload JSON on stdin — Claude (`tool_input.file_path`) or Cursor
#      `afterFileEdit` (`file_path`). Extracted without a jq/python dependency.
set -u

f="${CLAUDE_FILE_PATH:-}"

# Fall back to the JSON the host pipes in on stdin (Cursor; newer Claude payloads).
# Guard on a non-tty stdin so a manual run without a pipe doesn't block on `cat`.
if [ -z "$f" ] && [ ! -t 0 ]; then
  payload="$(cat)"
  f="$(printf '%s' "$payload" \
        | grep -oE '"file_?[Pp]ath"[[:space:]]*:[[:space:]]*"[^"]+"' \
        | head -n1 \
        | sed -E 's/.*"([^"]+)"$/\1/')"
fi

[ -n "$f" ] || exit 0                      # nothing to format
case "$f" in *.go) ;; *) exit 0 ;; esac    # Go source files only
[ -f "$f" ] || exit 0                      # path not resolvable from here (e.g. relative) — skip

if command -v gofumpt >/dev/null 2>&1; then
  gofumpt -w "$f" || true
elif command -v gofmt >/dev/null 2>&1; then
  gofmt -w -s "$f" || true
fi

exit 0
