#!/usr/bin/env bash
# PostToolUse / afterFileEdit hook: after a Go file is edited, name ONE go-coding skill the edit
# calls for — once per skill per session — printed as a hook systemMessage (Claude Code) or a
# plain line (Cursor). Deterministic trigger for the focused skills a usage analysis showed are
# rarely loaded. Always exits 0; never blocks an edit.
#
# At most three nudges reach a session (one per skill), each on its first match.
set -u
f="${CLAUDE_FILE_PATH:-}"; sid=""; payload=""
if [ ! -t 0 ]; then
  payload="$(cat)"
  [ -n "$f" ] || f="$(printf '%s' "$payload" | grep -oE '"file_?[Pp]ath"[[:space:]]*:[[:space:]]*"[^"]+"' | head -n1 | sed -E 's/.*"([^"]+)"$/\1/')"
  sid="$(printf '%s' "$payload" | grep -oE '"session_id"[[:space:]]*:[[:space:]]*"[^"]+"' | head -n1 | sed -E 's/.*"([^"]+)"$/\1/')"
fi
[ -n "$f" ] || exit 0
case "$f" in *.go) ;; *) exit 0 ;; esac
[ -f "$f" ] || exit 0
[ -n "$sid" ] || sid="ppid$PPID"

# What gets matched: the edit itself where the host hands it over (a Claude Code PostToolUse
# payload carries the new text in tool_input, plus a few lines of surrounding context in
# tool_response), otherwise the whole file (Cursor's afterFileEdit passes only a path). Matching
# the edit is what keeps the message honest — grepping a whole file says "this edit touches an
# error path" for any file that merely happens to define a sentinel somewhere.
case "$payload" in
  *'"tool_input"'*) subject="$payload"; what="this edit";;
  *)                subject="$(cat "$f")"; what="this file";;
esac

skill=""; topic=""
case "$f" in *_test.go) skill="go-testing"; topic="a test file"; what="this edit";; esac
if [ -z "$skill" ] && printf '%s' "$subject" | grep -qE 'go func|chan |<-chan|chan<-|sync\.|atomic\.|errgroup\.'; then skill="go-concurrency"; topic="goroutines, channels or sync"; fi
if [ -z "$skill" ] && printf '%s' "$subject" | grep -qE 'fmt\.Errorf|errors\.(Is|As|AsType|New|Join)'; then skill="go-errors"; topic="an error path"; fi
[ -n "$skill" ] || exit 0
marker="${TMPDIR:-/tmp}/go-coding-nudge.${sid}.${skill}"
[ -e "$marker" ] && exit 0
: > "$marker" 2>/dev/null || true
# what/topic/skill above are fixed literals set in this script (no quotes or backslashes), so the
# message below needs no JSON escaping before it goes into printf. If any is ever built from
# variable/external text instead, escape it first — printf does no JSON escaping of its own.
msg="› go-coding: ${what} touches ${topic} — load go-coding:${skill} before continuing."
if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] || printf '%s' "$payload" | grep -q '"hook_event_name"'; then
  printf '{"systemMessage":"%s"}\n' "$msg"      # Claude Code: systemMessage reaches the model's context on exit 0
else
  printf '%s\n' "$msg"                           # Cursor afterFileEdit: plain line
fi
exit 0
