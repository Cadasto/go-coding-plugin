#!/usr/bin/env bash
# PostToolUse / afterFileEdit hook: after a Go file is edited, print ONE line naming the go-coding
# skill the edit calls for — once per skill per session. Deterministic trigger for the focused
# skills a usage analysis showed are rarely loaded. Always exits 0; never blocks an edit.
set -u
f="${CLAUDE_FILE_PATH:-}"; sid=""
if [ ! -t 0 ]; then
  payload="$(cat)"
  [ -n "$f" ] || f="$(printf '%s' "$payload" | grep -oE '"file_?[Pp]ath"[[:space:]]*:[[:space:]]*"[^"]+"' | head -n1 | sed -E 's/.*"([^"]+)"$/\1/')"
  sid="$(printf '%s' "$payload" | grep -oE '"session_id"[[:space:]]*:[[:space:]]*"[^"]+"' | head -n1 | sed -E 's/.*"([^"]+)"$/\1/')"
fi
[ -n "$f" ] || exit 0
case "$f" in *.go) ;; *) exit 0 ;; esac
[ -f "$f" ] || exit 0
[ -n "$sid" ] || sid="ppid$PPID"
skill=""; topic=""
case "$f" in *_test.go) skill="go-testing"; topic="a test file";; esac
if [ -z "$skill" ] && grep -qE 'go func|chan |<-chan|chan<-|sync\.|atomic\.|errgroup\.' "$f"; then skill="go-concurrency"; topic="goroutines, channels or sync"; fi
if [ -z "$skill" ] && grep -qE 'fmt\.Errorf|errors\.(Is|As|AsType|New|Join)' "$f"; then skill="go-errors"; topic="an error path"; fi
[ -n "$skill" ] || exit 0
marker="${TMPDIR:-/tmp}/go-coding-nudge.${sid}.${skill}"
[ -e "$marker" ] && exit 0
: > "$marker" 2>/dev/null || true
echo "› go-coding: this edit touches ${topic} — load go-coding:${skill} before continuing."
exit 0
