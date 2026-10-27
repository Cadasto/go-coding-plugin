#!/usr/bin/env bash
# PostToolUse hook: after a Go file is edited, name ONE go-coding skill the edit calls for.
# Claude Code reads hookSpecificOutput.additionalContext. Cursor postToolUse (Write|StrReplace)
# reads additional_context. afterFileEdit documents no output, so the nudge is not wired there. Deterministic
# trigger for three focused skills a usage analysis showed load far less often than the router:
# go-testing, go-concurrency, go-errors. Always exits 0; never blocks an edit.
#
# A test file always routes to go-testing, even when it also spawns goroutines — the test skill
# owns how to test concurrency. At most three nudges reach a session, one per skill.
set -u
f="${CLAUDE_FILE_PATH:-}"; sid=""; payload=""
if [ ! -t 0 ]; then
  payload="$(cat)"
  [ -n "$f" ] || f="$(printf '%s' "$payload" | grep -oE '"(file_?[Pp]ath|path)"[[:space:]]*:[[:space:]]*"[^"]+"' | head -n1 | sed -E 's/.*"([^"]+)"$/\1/')"
  sid="$(printf '%s' "$payload" | grep -oE '"(session|conversation)_id"[[:space:]]*:[[:space:]]*"[^"]+"' | head -n1 | sed -E 's/.*"([^"]+)"$/\1/')"
fi
[ -n "$f" ] || exit 0
# Cursor plugin hooks run in the plugin install. A relative tool path is relative to the workspace.
cursor=0
if [ -n "${CURSOR_PLUGIN_ROOT:-}" ] || printf '%s' "$payload" | grep -q '"cursor_version"'; then
  cursor=1
fi
if [ "$cursor" -eq 1 ] && [ -n "${CURSOR_PROJECT_DIR:-}" ]; then
  case "$f" in
    /*) ;;
    *) f="${CURSOR_PROJECT_DIR%/}/$f" ;;
  esac
fi
case "$f" in *.go) ;; *) exit 0 ;; esac
[ -f "$f" ] || exit 0
[ -n "$sid" ] || sid="ppid$PPID"

# Pull one JSON string field out of the payload. The body pattern `(\\.|[^"\\])*` matches an
# escaped character or an ordinary one, so an embedded \" does not end the match early.
json_field() { printf '%s' "$payload" | grep -oE "\"$1\"[[:space:]]*:[[:space:]]*\"(\\\\.|[^\"\\\\])*\""; }

# What gets matched: the text the edit ADDS — Edit or StrReplace new_string, or Write content.
# old_string and tool_response are excluded. A payload with neither key (a path-only run, or a
# Cursor Write whose input fields are absent) matches the whole file. An empty new_string does
# not fall back to the file: that would treat a deletion as the surrounding code.
case "$payload" in
  *'"new_string"'*|*'"content"'*) subject="$(json_field new_string; json_field content)"; what="this edit";;
  *)                              subject="$(cat "$f")"; what="this file";;
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
if [ "$cursor" -eq 1 ]; then
  how="read /${skill}"
else
  how="load go-coding:${skill}"
fi
msg="› go-coding: ${what} touches ${topic} — ${how} before continuing."
# Cursor first: its payload also carries hook_event_name, and postToolUse reads additional_context.
if [ "$cursor" -eq 1 ]; then
  printf '{"additional_context":"%s"}\n' "$msg"
elif [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] || printf '%s' "$payload" | grep -q '"hook_event_name"'; then
  # Claude Code: additionalContext reaches the model; a top-level systemMessage reaches only the user.
  printf '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"%s"}}\n' "$msg"
else
  printf '%s\n' "$msg"                           # a manual run: plain line
fi
exit 0
