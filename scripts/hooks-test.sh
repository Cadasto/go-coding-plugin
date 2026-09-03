#!/usr/bin/env bash
# Bash tests for the plugin hooks. Run: ./scripts/hooks-test.sh  (exit 0 = all pass)
set -u
here="$(cd "$(dirname "$0")/.." && pwd)"; fails=0
run_case() { # NAME DIR EXPECT_SUBSTRING (empty = expect no output)
  local name="$1" dir="$2" expect="$3" out
  out="$(cd "$dir" && bash "$here/hooks/session-start.sh")"
  if [ -z "$expect" ]; then [ -z "$out" ] || { echo "FAIL $name: expected silence, got: $out"; fails=$((fails+1)); return; }
  else case "$out" in *"$expect"*) ;; *) echo "FAIL $name: missing '$expect' in: $out"; fails=$((fails+1)); return;; esac; fi
  echo "ok   $name"
}
run_case_absent() { # NAME DIR UNEXPECTED_SUBSTRING
  local name="$1" dir="$2" unexpected="$3" out
  out="$(cd "$dir" && bash "$here/hooks/session-start.sh")"
  case "$out" in *"$unexpected"*) echo "FAIL $name: unexpected '$unexpected' in: $out"; fails=$((fails+1)); return;; esac
  echo "ok   $name"
}
t="$(mktemp -d)"; trap 'rm -rf "$t"' EXIT
mkdir -p "$t/go-with-lint" "$t/go-no-lint" "$t/not-go"
printf 'module x\n\ngo 1.26.0\n' > "$t/go-with-lint/go.mod"; : > "$t/go-with-lint/.golangci.yml"
printf 'module x\n\ngo 1.26.0\n' > "$t/go-no-lint/go.mod"
run_case "go repo with lint config names the hop"      "$t/go-with-lint" "load go-coding then the skill for your diff"
run_case "go repo with lint config names go-reviewer"  "$t/go-with-lint" "go-reviewer for a diff review"
run_case_absent "go repo with lint config omits lint-setup" "$t/go-with-lint" "/go-lint-setup"
run_case_absent "banner names no removed skill"        "$t/go-no-lint"   "go-explain"
run_case "go repo without lint config offers setup"    "$t/go-no-lint"   "/go-lint-setup"
run_case "non-go repo is silent"                        "$t/not-go"       ""

# --- skill-nudge -------------------------------------------------------------------------------
# Payload builders. p_edit/p_write mirror a real Claude Code PostToolUse payload: hook_event_name,
# tool_input with BOTH old_string and new_string, and a tool_response echoing nearby file text.
# That shape is the point — a hook that greps the raw payload passes a new_string-only fixture and
# still misfires in production, where old_string and tool_response carry the code around the edit.
p_edit() { # SESSION FILE OLD NEW RESPONSE
  printf '{"session_id":"%s","hook_event_name":"PostToolUse","tool_name":"Edit","tool_input":{"file_path":"%s","old_string":"%s","new_string":"%s"},"tool_response":{"filePath":"%s","originalFile":"%s"}}' \
    "$1" "$2" "$3" "$4" "$2" "${5:-}"
}
p_write() { # SESSION FILE CONTENT
  printf '{"session_id":"%s","hook_event_name":"PostToolUse","tool_name":"Write","tool_input":{"file_path":"%s","content":"%s"}}' "$1" "$2" "$3"
}
p_path() { # SESSION FILE  — Cursor afterFileEdit: a path, no tool_input, no hook_event_name
  printf '{"session_id":"%s","file_path":"%s"}' "$1" "$2"
}

# Every case asserts exit 0 as well as the output: Claude Code treats a non-zero PostToolUse hook as
# a failed hook, and a bare $(...) would swallow that.
hook() { # NAME PAYLOAD -> echoes stdout; flags a non-zero exit
  local name="$1" out st
  out="$(printf '%s' "$2" | bash "$here/hooks/skill-nudge.sh")"; st=$?
  [ "$st" -eq 0 ] || { echo "FAIL $name: hook exited $st (a non-zero PostToolUse hook is a failed hook)"; fails=$((fails+1)); }
  printf '%s' "$out"
}
chk() { local name="$1" got="$2" expect="$3"; case "$got" in *"$expect"*) echo "ok   $name";; *) echo "FAIL $name: got '$got'"; fails=$((fails+1));; esac; }
chk_silent() { local name="$1" got="$2"; if [ -z "$got" ]; then echo "ok   $name"; else echo "FAIL $name: expected silence, got '$got'"; fails=$((fails+1)); fi; }

s="test-$$"; rm -f "${TMPDIR:-/tmp}/go-coding-nudge.$s."*
: > "$t/a_test.go"; printf 'package a\nfunc f(){ go func(){}() }\n' > "$t/w.go"; printf 'package a\nimport "fmt"\nvar e = fmt.Errorf("x")\n' > "$t/e.go"; : > "$t/plain.go"; : > "$t/readme.md"

chk "test file nudges go-testing"          "$(hook t "$(p_edit "$s" "$t/a_test.go" 'x := 1' 'x := 2')")" "go-coding:go-testing"
chk_silent "second test file is silent"    "$(hook t2 "$(p_edit "$s" "$t/a_test.go" 'x := 2' 'x := 3')")"
chk "goroutine edit nudges go-concurrency" "$(hook c "$(p_edit "$s" "$t/w.go" '' 'go func(){}()')")" "go-coding:go-concurrency"
chk "fmt.Errorf edit nudges go-errors"     "$(hook e "$(p_edit "$s" "$t/e.go" '' 'return fmt.Errorf(\"x: %w\", err)')")" "go-coding:go-errors"
chk "Write content nudges too"             "$(hook w "$(p_write "$s-w" "$t/w.go" 'package a\nfunc f(){ go func(){}() }')")" "go-coding:go-concurrency"
chk_silent "plain go file is silent"       "$(hook p "$(p_edit "$s" "$t/plain.go" '' 'const x = 1')")"
chk_silent "non-go file is silent"         "$(hook n "$(p_edit "$s" "$t/readme.md" '' 'fmt.Errorf')")"
rm -f "${TMPDIR:-/tmp}/go-coding-nudge.$s."* "${TMPDIR:-/tmp}/go-coding-nudge.$s-w."*

# The whole point of classifying from the edit. Each of these payloads carries fmt.Errorf somewhere
# a naive grep would find it — the old text being deleted, the tool_response echo, the file on disk
# — while the text the edit ADDS is a doc-comment tidy. All must stay silent.
sedit="$s-edit"; rm -f "${TMPDIR:-/tmp}/go-coding-nudge.$sedit."*
chk_silent "edit that only deletes an error path is silent" \
  "$(hook d "$(p_edit "$sedit" "$t/e.go" 'return fmt.Errorf(\"x\")' 'return nil')")"
# Its own session: otherwise the case above would have consumed the go-errors marker and this one
# would pass by dedupe rather than by classifying correctly.
chk_silent "edit beside an error path is silent" \
  "$(hook b "$(p_edit "$sedit-beside" "$t/e.go" '// old comment' '// tidy the doc comment' 'package a\nimport \"fmt\"\nvar e = fmt.Errorf(\"x\")')")"
chk "path-only payload falls back to the file" "$(hook f "$(p_path "$sedit" "$t/e.go")")" "go-coding:go-errors"
chk "path-only payload says 'this file'"       "$(hook f2 "$(p_path "$sedit-2" "$t/e.go")")" "this file touches"
chk "edit payload says 'this edit'"            "$(hook f3 "$(p_edit "$sedit-3" "$t/a_test.go" '' 'x := 1')")" "this edit touches"
rm -f "${TMPDIR:-/tmp}/go-coding-nudge.$sedit"*

# Delivery channel: a fresh fixture + session per case so dedupe cannot silence it, and each host
# path forced explicitly rather than relying on the ambient CLAUDE_PLUGIN_ROOT.
printf 'package a\nimport "fmt"\nvar e = fmt.Errorf("x")\n' > "$t/e2.go"
sjson="$s-json"; rm -f "${TMPDIR:-/tmp}/go-coding-nudge.$sjson."*
out="$(CLAUDE_PLUGIN_ROOT=/x hook j "$(p_edit "$sjson" "$t/e2.go" '' 'fmt.Errorf')")"
chk "CLAUDE_PLUGIN_ROOT delivers a systemMessage" "$out" '{"systemMessage":'
rm -f "${TMPDIR:-/tmp}/go-coding-nudge.$sjson."*

# hook_event_name alone must be enough — CLAUDE_PLUGIN_ROOT is not set for hooks in every context,
# and the nudge has to carry the skill name, not just be well-formed JSON.
shook="$s-hookevent"; rm -f "${TMPDIR:-/tmp}/go-coding-nudge.$shook."*
out="$(printf '%s' "$(p_edit "$shook" "$t/e2.go" '' 'fmt.Errorf')" | env -u CLAUDE_PLUGIN_ROOT bash "$here/hooks/skill-nudge.sh")"; st=$?
[ "$st" -eq 0 ] || { echo "FAIL hook_event_name without CLAUDE_PLUGIN_ROOT: exited $st"; fails=$((fails+1)); }
chk "hook_event_name alone delivers a systemMessage" "$out" '{"systemMessage":'
chk "that systemMessage names the skill"             "$out" "go-coding:go-errors"
rm -f "${TMPDIR:-/tmp}/go-coding-nudge.$shook."*

scursor="$s-cursor"; rm -f "${TMPDIR:-/tmp}/go-coding-nudge.$scursor."*
# Built directly (not via hook()): env -u only strips CLAUDE_PLUGIN_ROOT from an external-command
# invocation, and the path-only payload already lacks hook_event_name.
out="$(printf '%s' "$(p_path "$scursor" "$t/e2.go")" | env -u CLAUDE_PLUGIN_ROOT bash "$here/hooks/skill-nudge.sh")"; st=$?
[ "$st" -eq 0 ] || { echo "FAIL nudge is a plain line under Cursor: exited $st"; fails=$((fails+1)); }
case "$out" in
  '{'*) echo "FAIL nudge is a plain line under Cursor: got JSON '$out'"; fails=$((fails+1));;
  *"go-coding:go-errors"*) echo "ok   nudge is a plain line under Cursor";;
  *) echo "FAIL nudge is a plain line under Cursor: got '$out'"; fails=$((fails+1));;
esac
rm -f "${TMPDIR:-/tmp}/go-coding-nudge.$scursor."*

# Can-fail control (F3): prove chk_silent and run_case_absent actually fail on bad input, so a
# broken helper (e.g. always echoing "ok") can't hide a real regression above. Each probe runs in a
# `$(...)` subshell — already isolated from this shell's `fails` — with its own `fails=0` so the
# probe's internal increment never has a chance to leak into the suite's real count.
selftest() { local name="$1" out="$2"; case "$out" in FAIL*) echo "ok   $name";; *) echo "FAIL $name: helper did not fail on bad input: '$out'"; fails=$((fails+1));; esac; }
selftest "can-fail: chk_silent rejects non-empty"     "$( fails=0; chk_silent "probe" "not-empty" )"
selftest "can-fail: run_case_absent rejects presence" "$( fails=0; run_case_absent "probe" "$t/go-no-lint" "/go-lint-setup" )"

[ "$fails" -eq 0 ] || exit 1
