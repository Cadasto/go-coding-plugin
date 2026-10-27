#!/usr/bin/env bash
# PostToolUse (Claude Code) / afterFileEdit (Cursor) hook: format the just-edited Go file.
#
# Runs `gofumpt -w` (the stricter gofmt superset) when gofumpt is on PATH, else
# `gofmt -w -s`. Host-only by design — formatting is cheap and instantaneous; a
# container round-trip on every edit would dominate a save hook's latency budget.
# Silent no-op when no Go formatter is installed (the session-start hook already
# recommends installing one), and ALWAYS exits 0 so it can never block an edit.
#
# File-path resolution, in order:
#   1. $CLAUDE_FILE_PATH          — explicit override for tests and manual runs; no host sets it.
#   2. tool payload JSON on stdin — Claude `tool_input.file_path` (always absolute), Cursor
#      `afterFileEdit` `file_path` (documented absolute), or a Cursor `tool_input.path`.
#      Extracted without a jq/python dependency.
#   3. Under Cursor (CURSOR_PLUGIN_ROOT set, or cursor_version in the payload), a relative path
#      is joined to CURSOR_PROJECT_DIR: a Cursor plugin hook runs in the plugin install.
set -u

f="${CLAUDE_FILE_PATH:-}"; payload=""

# Otherwise read the JSON payload both hosts pipe in on stdin.
# Guard on a non-tty stdin so a manual run without a pipe doesn't block on `cat`.
if [ -z "$f" ] && [ ! -t 0 ]; then
  payload="$(cat)"
  f="$(printf '%s' "$payload" \
        | grep -oE '"(file_?[Pp]ath|path)"[[:space:]]*:[[:space:]]*"[^"]+"' \
        | head -n1 \
        | sed -E 's/.*"([^"]+)"$/\1/')"
fi

# The same Cursor test and join as skill-nudge.sh. A case pattern rather than grep, so a run with
# CLAUDE_FILE_PATH set needs no external command.
cursor="${CURSOR_PLUGIN_ROOT:-}"
case "$payload" in *'"cursor_version"'*) cursor=1 ;; esac
if [ -n "$cursor" ] && [ -n "${CURSOR_PROJECT_DIR:-}" ]; then
  case "$f" in
    /*|"") ;;
    *) f="${CURSOR_PROJECT_DIR%/}/$f" ;;
  esac
fi

[ -n "$f" ] || exit 0                      # nothing to format
case "$f" in *.go) ;; *) exit 0 ;; esac    # Go source files only
[ -f "$f" ] || exit 0                      # no such file (deleted, or relative with nothing to join) — skip

if command -v gofumpt >/dev/null 2>&1; then
  gofumpt -w "$f" || true
elif command -v gofmt >/dev/null 2>&1; then
  gofmt -w -s "$f" || true
fi

exit 0
