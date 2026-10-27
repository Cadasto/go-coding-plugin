#!/usr/bin/env bash
# Bash tests for the plugin hooks. Run: ./scripts/hooks-test.sh  (exit 0 = all pass)
set -u
# Run from a Cursor terminal or hook, these would turn every Claude Code case below into a Cursor one.
unset CURSOR_PLUGIN_ROOT CURSOR_PROJECT_DIR
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
printf 'module x\n\ngo 1.27.0\n' > "$t/go-with-lint/go.mod"; : > "$t/go-with-lint/.golangci.yml"
printf 'module x\n\ngo 1.27.0\n' > "$t/go-no-lint/go.mod"
run_case "go repo with lint config names the hop"      "$t/go-with-lint" "load go-coding then the skill for your diff"
run_case "go repo with lint config names go-reviewer"  "$t/go-with-lint" "go-reviewer for a diff review"
run_case "go repo banner routes symbol lookups to gopls" "$t/go-with-lint" "gopls for symbol lookups"
run_case "go repo banner names the gopls shell route"  "$t/go-with-lint" "gopls references/implementation from the shell"
run_case_absent "go repo with lint config omits lint-setup" "$t/go-with-lint" "/go-lint-setup"
run_case_absent "banner names no removed skill"        "$t/go-no-lint"   "go-explain"
run_case "go repo without lint config offers setup"    "$t/go-no-lint"   "/go-lint-setup"
run_case "non-go repo is silent"                        "$t/not-go"       ""
# Cursor runs the hook in the plugin install and reads additional_context. The plugin
# directory here is the other fixture, so a missed cd would inspect the wrong tree.
out="$(cd "$t/not-go" && CURSOR_PLUGIN_ROOT="$t/not-go" CURSOR_PROJECT_DIR="$t/go-no-lint" bash "$here/hooks/session-start.sh")"
case "$out" in
  '{"additional_context":"› Go workspace — go-coding: open /go-coding'*) echo "ok   Cursor session-start inspects CURSOR_PROJECT_DIR";;
  *) echo "FAIL Cursor session-start inspects CURSOR_PROJECT_DIR: got '$out'"; fails=$((fails+1));;
esac
case "$out" in *"/go-errors"*) echo "ok   Cursor banner names a slash skill";; *) echo "FAIL Cursor banner names a slash skill: got '$out'"; fails=$((fails+1));; esac
if command -v python3 >/dev/null 2>&1; then
  if printf '%s' "$out" | python3 -c 'import json,sys; json.load(sys.stdin)' 2>/dev/null; then echo "ok   Cursor session-start emits valid JSON"; else echo "FAIL Cursor session-start emits valid JSON: '$out'"; fails=$((fails+1)); fi
fi
out="$(cd "$t/go-no-lint" && CURSOR_PLUGIN_ROOT="$t/go-no-lint" CURSOR_PROJECT_DIR="$t/not-go" bash "$here/hooks/session-start.sh")"
if [ -z "$out" ]; then echo "ok   Cursor session-start ignores a non-Go project"; else echo "FAIL Cursor session-start ignores a non-Go project: got '$out'"; fails=$((fails+1)); fi
# Without a usable CURSOR_PROJECT_DIR the hook stays silent rather than inspect the plugin install,
# a Go module here, so a missing variable can never report the wrong tree.
out="$(cd "$t/go-no-lint" && CURSOR_PLUGIN_ROOT="$t/go-no-lint" bash "$here/hooks/session-start.sh")"
if [ -z "$out" ]; then echo "ok   Cursor session-start without CURSOR_PROJECT_DIR is silent"; else echo "FAIL Cursor session-start without CURSOR_PROJECT_DIR is silent: got '$out'"; fails=$((fails+1)); fi
out="$(cd "$t/go-no-lint" && CURSOR_PLUGIN_ROOT="$t/go-no-lint" CURSOR_PROJECT_DIR="$t/missing" bash "$here/hooks/session-start.sh")"
if [ -z "$out" ]; then echo "ok   Cursor session-start with a missing CURSOR_PROJECT_DIR is silent"; else echo "FAIL Cursor session-start with a missing CURSOR_PROJECT_DIR is silent: got '$out'"; fails=$((fails+1)); fi
# Claude Code started from a Cursor terminal inherits CURSOR_PROJECT_DIR but not CURSOR_PLUGIN_ROOT:
# it inspects its own directory and prints the plain line.
out="$(cd "$t/go-no-lint" && CURSOR_PROJECT_DIR="$t/not-go" bash "$here/hooks/session-start.sh")"
case "$out" in
  '› Go workspace — go-coding: load go-coding then'*) echo "ok   session-start in a Cursor terminal takes the Claude Code path";;
  *) echo "FAIL session-start in a Cursor terminal takes the Claude Code path: got '$out'"; fails=$((fails+1));;
esac

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
p_path() { # SESSION FILE  — a manual run: a path, no tool_input, no hook_event_name, no cursor_version
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
# plain.go on disk is empty, so only the Write content can trigger this one.
chk "Write content nudges too"             "$(hook w "$(p_write "$s-w" "$t/plain.go" 'package a\nfunc f(){ go func(){}() }')")" "this edit touches goroutines"
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
chk_silent "a deletion (empty new_string) does not fall back to the file" \
  "$(hook d2 "$(p_edit "$sedit-del" "$t/e.go" 'var e = fmt.Errorf(\"x\")' '')")"
chk "path-only payload falls back to the file" "$(hook f "$(p_path "$sedit" "$t/e.go")")" "go-coding:go-errors"
chk "path-only payload says 'this file'"       "$(hook f2 "$(p_path "$sedit-2" "$t/e.go")")" "this file touches"
chk "edit payload says 'this edit'"            "$(hook f3 "$(p_edit "$sedit-3" "$t/a_test.go" '' 'x := 1')")" "this edit touches"
rm -f "${TMPDIR:-/tmp}/go-coding-nudge.$sedit"*

# The once-per-session marker must not leak an error into the hook's stderr when it cannot be
# written; the nudge itself still arrives.
smark="$s-mark"
out="$(printf '%s' "$(p_edit "$smark" "$t/e.go" '' 'fmt.Errorf')" | TMPDIR="$t/no-such-dir" bash "$here/hooks/skill-nudge.sh" 2>&1 >/dev/null)"
chk_silent "an unwritable marker directory writes nothing to stderr" "$out"

# Delivery channel: a fresh fixture + session per case so dedupe cannot silence it, and each host
# path forced explicitly rather than relying on the ambient CLAUDE_PLUGIN_ROOT.
printf 'package a\nimport "fmt"\nvar e = fmt.Errorf("x")\n' > "$t/e2.go"
sjson="$s-json"; rm -f "${TMPDIR:-/tmp}/go-coding-nudge.$sjson."*
out="$(CLAUDE_PLUGIN_ROOT=/x hook j "$(p_edit "$sjson" "$t/e2.go" '' 'fmt.Errorf')")"
chk "CLAUDE_PLUGIN_ROOT delivers additionalContext" "$out" '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":'
rm -f "${TMPDIR:-/tmp}/go-coding-nudge.$sjson."*

# hook_event_name alone must be enough — CLAUDE_PLUGIN_ROOT is not set for hooks in every context,
# and the nudge has to carry the skill name, not just be well-formed JSON.
shook="$s-hookevent"; rm -f "${TMPDIR:-/tmp}/go-coding-nudge.$shook."*
out="$(printf '%s' "$(p_edit "$shook" "$t/e2.go" '' 'fmt.Errorf')" | env -u CLAUDE_PLUGIN_ROOT bash "$here/hooks/skill-nudge.sh")"; st=$?
[ "$st" -eq 0 ] || { echo "FAIL hook_event_name without CLAUDE_PLUGIN_ROOT: exited $st"; fails=$((fails+1)); }
chk "hook_event_name alone delivers additionalContext" "$out" '"additionalContext":'
chk "that additionalContext names the skill"          "$out" "go-coding:go-errors"
rm -f "${TMPDIR:-/tmp}/go-coding-nudge.$shook."*

sman="$s-manual"; rm -f "${TMPDIR:-/tmp}/go-coding-nudge.$sman."*
# A path-only payload with no Cursor marker is a manual run: a plain line, not JSON.
out="$(printf '%s' "$(p_path "$sman" "$t/e2.go")" | env -u CLAUDE_PLUGIN_ROOT bash "$here/hooks/skill-nudge.sh")"; st=$?
[ "$st" -eq 0 ] || { echo "FAIL manual path-only nudge: exited $st"; fails=$((fails+1)); }
case "$out" in
  '{'*) echo "FAIL manual path-only nudge is a plain line: got JSON '$out'"; fails=$((fails+1));;
  *"go-coding:go-errors"*) echo "ok   manual path-only nudge is a plain line";;
  *) echo "FAIL manual path-only nudge is a plain line: got '$out'"; fails=$((fails+1));;
esac
rm -f "${TMPDIR:-/tmp}/go-coding-nudge.$sman."*

# Claude Code started from a Cursor terminal inherits CURSOR_PROJECT_DIR but not
# CURSOR_PLUGIN_ROOT, and its payload has no cursor_version: it keeps Claude's form.
sterm="$s-term"; rm -f "${TMPDIR:-/tmp}/go-coding-nudge.$sterm."*
out="$(printf '%s' "$(p_edit "$sterm" "$t/e2.go" '' 'fmt.Errorf')" | env -u CLAUDE_PLUGIN_ROOT CURSOR_PROJECT_DIR="$t" bash "$here/hooks/skill-nudge.sh")"
chk "a Cursor terminal keeps Claude's hookSpecificOutput" "$out" '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"› go-coding: this edit touches an error path — load go-coding:go-errors'
rm -f "${TMPDIR:-/tmp}/go-coding-nudge.$sterm."*

# Cursor postToolUse. Its payload carries cursor_version and hook_event_name; the nudge must be
# additional_context naming /<skill>, not Claude's hookSpecificOutput. Cursor documents
# tool_input for Shell only, so both edit shapes reported for it are covered, neither captured
# here: StrReplace with tool_input.path (github.com/awslabs/aidlc-workflows/pull/2873) and
# Write with {file_path, content}, for search-and-replace edits too
# (github.com/pbakaus/impeccable/pull/1069).
p_cursor_edit() { # CONVERSATION FILE NEW
  printf '{"conversation_id":"%s","hook_event_name":"postToolUse","cursor_version":"3.21.18","workspace_roots":["/w"],"tool_name":"StrReplace","tool_input":{"path":"%s","old_string":"x","new_string":"%s"},"tool_output":"{\\"path\\":\\"/elsewhere.go\\"}","tool_use_id":"t","cwd":"","duration":1}' \
    "$1" "$2" "$3"
}
p_cursor_write() { # CONVERSATION FILE CONTENT
  printf '{"conversation_id":"%s","hook_event_name":"postToolUse","cursor_version":"3.21.18","workspace_roots":["/w"],"tool_name":"Write","tool_input":{"file_path":"%s","content":"%s"},"tool_output":"{}","tool_use_id":"t","cwd":"","duration":1}' \
    "$1" "$2" "$3"
}
nudge_cursor() { # PAYLOAD [ENV...] -> stdout of skill-nudge under a bare Cursor payload
  local payload="$1"; shift
  printf '%s' "$payload" | env -u CLAUDE_PLUGIN_ROOT "$@" bash "$here/hooks/skill-nudge.sh"
}
scur="$s-cursor"; rm -f "${TMPDIR:-/tmp}/go-coding-nudge.$scur"*
out="$(nudge_cursor "$(p_cursor_edit "$scur" "$t/e2.go" 'return fmt.Errorf(\"x\")')")"; st=$?
[ "$st" -eq 0 ] || { echo "FAIL Cursor StrReplace nudge: exited $st"; fails=$((fails+1)); }
case "$out" in
  '{"additional_context":"› go-coding: this edit touches an error path — read /go-errors'*) echo "ok   Cursor StrReplace nudge returns additional_context";;
  *) echo "FAIL Cursor StrReplace nudge returns additional_context: got '$out'"; fails=$((fails+1));;
esac
if command -v python3 >/dev/null 2>&1; then
  if printf '%s' "$out" | python3 -c 'import json,sys; json.load(sys.stdin)' 2>/dev/null; then echo "ok   Cursor skill-nudge emits valid JSON"; else echo "FAIL Cursor skill-nudge emits valid JSON: '$out'"; fails=$((fails+1)); fi
fi
# conversation_id is Cursor's session key: the same conversation is nudged once, a new one again.
chk_silent "Cursor nudge is once per conversation" "$(nudge_cursor "$(p_cursor_edit "$scur" "$t/e2.go" 'return fmt.Errorf(\"x\")')")"
chk "a new Cursor conversation is nudged again" "$(nudge_cursor "$(p_cursor_edit "$scur-2" "$t/e2.go" 'return fmt.Errorf(\"x\")')")" "read /go-errors"
# A Write's content can be the whole file, so under Cursor it says "this file". plain.go on disk
# is empty, so only the content can trigger it.
chk "Cursor Write content nudges, as 'this file'" "$(nudge_cursor "$(p_cursor_write "$scur-w" "$t/plain.go" 'go func(){}()')")" \
  '{"additional_context":"› go-coding: this file touches goroutines, channels or sync — read /go-concurrency'
chk "Cursor tool_input without edit text matches the file" "$(nudge_cursor "$(printf '{"conversation_id":"%s","cursor_version":"3.21.18","tool_name":"Write","tool_input":{"path":"%s"}}' "$scur-n" "$t/e2.go")")" \
  '{"additional_context":"› go-coding: this file touches an error path — read /go-errors'
chk "an absolute Cursor path is not re-rooted" "$(nudge_cursor "$(p_cursor_edit "$scur-a" "$t/e2.go" 'errors.New(\"y\")')" CURSOR_PROJECT_DIR="$t/elsewhere")" "read /go-errors"
chk "CURSOR_PLUGIN_ROOT alone selects Cursor's form" \
  "$(nudge_cursor "$(printf '{"conversation_id":"%s","hook_event_name":"postToolUse","tool_input":{"path":"%s","new_string":"errors.New(\\"z\\")"}}' "$scur-r" "$t/e2.go")" CURSOR_PLUGIN_ROOT=/plugin)" \
  '{"additional_context":"› go-coding: this edit touches an error path — read /go-errors'
rm -f "${TMPDIR:-/tmp}/go-coding-nudge.$scur"*
printf 'package a\nfunc f() {}\n' > "$t/rel.go"
srel="$s-rel"; rm -f "${TMPDIR:-/tmp}/go-coding-nudge.$srel."*
out="$(nudge_cursor "$(p_cursor_edit "$srel" "rel.go" 'go func(){}()')")"
if [ -z "$out" ]; then echo "ok   relative Cursor path without CURSOR_PROJECT_DIR is silent"; else echo "FAIL relative Cursor path without CURSOR_PROJECT_DIR is silent: got '$out'"; fails=$((fails+1)); fi
out="$(nudge_cursor "$(p_cursor_edit "$srel" "rel.go" 'go func(){}()')" CURSOR_PROJECT_DIR="$t")"
case "$out" in
  *'read /go-concurrency'*) echo "ok   relative Cursor path is joined to CURSOR_PROJECT_DIR";;
  *) echo "FAIL relative Cursor path is joined to CURSOR_PROJECT_DIR: got '$out'"; fails=$((fails+1));;
esac
rm -f "${TMPDIR:-/tmp}/go-coding-nudge.$srel."*

# --- format-on-save ----------------------------------------------------------------------------
# Needs a formatter; without gofmt or gofumpt on PATH the hook is a deliberate no-op and there is
# nothing to assert beyond "exits 0", which the last case covers.
fmt_hook() { # PAYLOAD -> exit status recorded, stdout dropped
  printf '%s' "$1" | bash "$here/hooks/format-on-save.sh" >/dev/null 2>&1
}
if command -v gofmt >/dev/null 2>&1 || command -v gofumpt >/dev/null 2>&1; then
  printf 'package a\nfunc  f( ) {\n}\n' > "$t/messy.go"
  before="$(cat "$t/messy.go")"
  fmt_hook "$(p_write "$s-fmt" "$t/messy.go" 'x')"; st=$?
  after="$(cat "$t/messy.go")"
  if [ "$st" -ne 0 ]; then echo "FAIL format-on-save exits 0: exited $st"; fails=$((fails+1));
  elif [ "$before" = "$after" ]; then echo "FAIL format-on-save reformats a messy Go file: file unchanged"; fails=$((fails+1));
  else echo "ok   format-on-save reformats a messy Go file"; fi

  # A second run must be a fixpoint — a formatter that keeps rewriting an already-formatted file
  # would churn every save.
  fmt_hook "$(p_write "$s-fmt" "$t/messy.go" 'x')"
  if [ "$(cat "$t/messy.go")" = "$after" ]; then echo "ok   format-on-save is idempotent"; else echo "FAIL format-on-save is idempotent: second run changed the file"; fails=$((fails+1)); fi

  printf 'not  go  source\n' > "$t/keep.md"
  fmt_hook "$(p_write "$s-fmt" "$t/keep.md" 'x')"
  if [ "$(cat "$t/keep.md")" = 'not  go  source' ]; then echo "ok   format-on-save leaves a non-go file alone"; else echo "FAIL format-on-save leaves a non-go file alone: file was rewritten"; fails=$((fails+1)); fi

  # Path resolution under Cursor. Each case runs from $t/elsewhere, so a relative path reaches the
  # file only through the join to CURSOR_PROJECT_DIR.
  mkdir -p "$t/ws" "$t/elsewhere"
  fmt_case() { # NAME WANT(changed|same) FILE PAYLOAD [ENV...]
    local name="$1" want="$2" file="$3" payload="$4" before got=same; shift 4
    printf 'package a\nfunc  f( ) {\n}\n' > "$file"; before="$(cat "$file")"
    (cd "$t/elsewhere" && printf '%s' "$payload" | env "$@" bash "$here/hooks/format-on-save.sh" >/dev/null 2>&1)
    [ "$(cat "$file")" = "$before" ] || got=changed
    if [ "$got" = "$want" ]; then echo "ok   $name"; else echo "FAIL $name: file $got, want $want"; fails=$((fails+1)); fi
  }
  p_after_edit() { printf '{"conversation_id":"c","hook_event_name":"afterFileEdit","cursor_version":"3.21.18","file_path":"%s","edits":[]}' "$1"; }
  fmt_case "format-on-save joins a relative Cursor path" changed "$t/ws/r1.go" "$(p_after_edit r1.go)" \
    CURSOR_PLUGIN_ROOT="$t/elsewhere" CURSOR_PROJECT_DIR="$t/ws"
  fmt_case "format-on-save takes cursor_version as Cursor" changed "$t/ws/r2.go" "$(p_after_edit r2.go)" \
    CURSOR_PROJECT_DIR="$t/ws"
  fmt_case "format-on-save keeps an absolute Cursor path" changed "$t/ws/r3.go" "$(p_after_edit "$t/ws/r3.go")" \
    CURSOR_PLUGIN_ROOT="$t/elsewhere" CURSOR_PROJECT_DIR="$t/elsewhere"
  fmt_case "format-on-save reads a tool_input path" changed "$t/ws/r4.go" "$(printf '{"tool_input":{"path":"%s"}}' "$t/ws/r4.go")"
  fmt_case "format-on-save does not join outside Cursor" same "$t/ws/r5.go" \
    '{"session_id":"s","hook_event_name":"PostToolUse","tool_input":{"file_path":"r5.go"}}' CURSOR_PROJECT_DIR="$t/ws"
else
  echo "ok   format-on-save cases skipped (no gofmt/gofumpt on PATH)"
fi

# No formatter on PATH at all: the hook must stay silent and still exit 0. CLAUDE_FILE_PATH is set
# so the hook never needs cat/grep/sed, which an empty PATH would also take away — this case is
# about the missing formatter, not about a crippled shell.
out="$(CLAUDE_FILE_PATH="$t/plain.go" PATH=/nonexistent "$BASH" "$here/hooks/format-on-save.sh" </dev/null 2>&1)"; st=$?
if [ "$st" -eq 0 ] && [ -z "$out" ]; then echo "ok   format-on-save is a silent no-op without a formatter"; else echo "FAIL format-on-save is a silent no-op without a formatter: exit $st, output '$out'"; fails=$((fails+1)); fi

# Can-fail control (F3): prove chk_silent and run_case_absent actually fail on bad input, so a
# broken helper (e.g. always echoing "ok") can't hide a real regression above. Each probe runs in a
# `$(...)` subshell — already isolated from this shell's `fails` — with its own `fails=0` so the
# probe's internal increment never has a chance to leak into the suite's real count.
selftest() { local name="$1" out="$2"; case "$out" in FAIL*) echo "ok   $name";; *) echo "FAIL $name: helper did not fail on bad input: '$out'"; fails=$((fails+1));; esac; }
selftest "can-fail: chk_silent rejects non-empty"     "$( fails=0; chk_silent "probe" "not-empty" )"
selftest "can-fail: run_case_absent rejects presence" "$( fails=0; run_case_absent "probe" "$t/go-no-lint" "/go-lint-setup" )"

[ "$fails" -eq 0 ] || exit 1
