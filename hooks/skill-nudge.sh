#!/usr/bin/env bash
# PostToolUse / afterFileEdit hook: after a Go file is edited, name ONE go-coding skill the edit
# calls for — printed as a hook systemMessage (Claude Code) or a plain line (Cursor). Deterministic
# trigger for three focused skills a usage analysis showed load far less often than the router:
# go-testing, go-concurrency, go-errors. Always exits 0; never blocks an edit.
#
# A test file always routes to go-testing, even when it also spawns goroutines — the test skill
# owns how to test concurrency. At most three nudges reach a session, one per skill.
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

# Pull one JSON string field out of the payload. The body pattern `(\\.|[^"\\])*` matches an
# escaped character or an ordinary one, so an embedded \" does not end the match early.
json_field() { printf '%s' "$payload" | grep -oE "\"$1\"[[:space:]]*:[[:space:]]*\"(\\\\.|[^\"\\\\])*\""; }

# What gets matched: the text the edit ADDS, where the host hands it over — Edit's new_string,
# Write's content. old_string and tool_response are deliberately excluded: deleting an fmt.Errorf
# is not an error path this edit introduces, and tool_response echoes surrounding lines the edit
# never touched. Cursor's afterFileEdit passes only a path, so that host matches the whole file
# and the message says so. No fallback from one to the other — falling back to the file on an
# empty extraction would restore exactly the false positives this avoids.
case "$payload" in
  *'"tool_input"'*) subject="$(json_field new_string; json_field content)"; what="this edit";;
  *)                subject="$(cat "$f")"; what="this file";;
esac

skill=""; topic=""
case "$f" in *_test.go) skill="go-testing"; topic="a test file";; esac
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
