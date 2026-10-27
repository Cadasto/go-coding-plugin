#!/usr/bin/env bash
# PostToolUse hook: after a Go file is edited, name ONE go-coding skill the edit calls for.
# Claude Code reads hookSpecificOutput.additionalContext; Cursor postToolUse reads
# additional_context (Cursor's afterFileEdit documents no output fields, so the nudge is not
# wired there). A deterministic trigger for three focused skills a usage analysis showed load far
# less often than the router: go-testing, go-concurrency, go-errors. Always exits 0; never blocks
# an edit.
#
# A test file always routes to go-testing, even when it also spawns goroutines — the test skill
# owns how to test concurrency. At most three nudges reach a session, one per skill.
set -u
f="${CLAUDE_FILE_PATH:-}"; sid=""; payload=""
if [ ! -t 0 ]; then
  payload="$(cat)"
  [ -n "$f" ] || f="$(printf '%s' "$payload" | grep -oE '"(file_?[Pp]ath|path)"[[:space:]]*:[[:space:]]*"[^"]+"' | head -n1 | sed -E 's/.*"([^"]+)"$/\1/')"
  # Cursor names the session conversation_id.
  sid="$(printf '%s' "$payload" | grep -oE '"(session|conversation)_id"[[:space:]]*:[[:space:]]*"[^"]+"' | head -n1 | sed -E 's/.*"([^"]+)"$/\1/')"
fi
[ -n "$f" ] || exit 0
# Cursor: CURSOR_PLUGIN_ROOT is set for a plugin hook only, and every Cursor payload carries
# cursor_version. A plugin hook runs in the plugin install, and Cursor documents no tool_input
# keys for its edit tools, so a relative path is taken as relative to the workspace.
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

# What gets matched: the text the edit ADDS, new_string (an Edit or StrReplace) or content (a
# Write). old_string is left out: deleting an fmt.Errorf adds no error path. Claude's
# tool_response and Cursor's tool_output echo code the edit never touched; neither can match,
# since tool_response's keys are camelCase and tool_output is a JSON string whose quotes are
# escaped. A payload with neither key (a manual path-only run) matches the whole file. An empty
# new_string does not fall back to the file: that would read a deletion as the code around it.
case "$payload" in
  *'"new_string"'*|*'"content"'*) subject="$(json_field new_string; json_field content)"; what="this edit";;
  *)                              subject="$(cat "$f")"; what="this file";;
esac
# Cursor may report a search-and-replace edit as a Write carrying the whole file
# (github.com/pbakaus/impeccable/pull/1069), so there only new_string is the edit's own text.
if [ "$cursor" -eq 1 ]; then case "$payload" in *'"new_string"'*) ;; *) what="this file";; esac; fi

skill=""; topic=""
case "$f" in *_test.go) skill="go-testing"; topic="a test file";; esac
if [ -z "$skill" ] && printf '%s' "$subject" | grep -qE 'go func|chan |<-chan|chan<-|sync\.|atomic\.|errgroup\.'; then skill="go-concurrency"; topic="goroutines, channels or sync"; fi
if [ -z "$skill" ] && printf '%s' "$subject" | grep -qE 'fmt\.Errorf|errors\.(Is|As|AsType|New|Join)'; then skill="go-errors"; topic="an error path"; fi
[ -n "$skill" ] || exit 0
marker="${TMPDIR:-/tmp}/go-coding-nudge.${sid}.${skill}"
[ -e "$marker" ] && exit 0
# The braces apply 2>/dev/null to the redirection too, so an unwritable TMPDIR prints nothing.
{ : > "$marker"; } 2>/dev/null || true
if [ "$cursor" -eq 1 ]; then
  how="read /${skill}"
else
  how="load go-coding:${skill}"
fi
# what, topic, skill and how are fixed literals set in this script (no quotes or backslashes), so
# msg needs no JSON escaping before it goes into printf. If any is ever built from outside text,
# escape it first: printf does no JSON escaping of its own.
msg="› go-coding: ${what} touches ${topic} — ${how} before continuing."
# Cursor first: its payload also carries hook_event_name, and postToolUse reads additional_context.
if [ "$cursor" -eq 1 ]; then
  printf '{"additional_context":"%s"}\n' "$msg"
elif [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] || printf '%s' "$payload" | grep -q '"hook_event_name"'; then
  # Claude Code: additionalContext reaches the model; a top-level systemMessage reaches only the
  # user (https://code.claude.com/docs/en/hooks).
  printf '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"%s"}}\n' "$msg"
else
  printf '%s\n' "$msg"                           # a manual run: plain line
fi
exit 0
