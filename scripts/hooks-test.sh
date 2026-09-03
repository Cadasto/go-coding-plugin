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

nudge() { # FILE SESSION [EDIT_TEXT] -> stdout. Claude Code shape: a tool_input payload, so the
          # hook classifies from the edit text, not from the whole file.
  printf '{"session_id":"%s","tool_name":"Edit","tool_input":{"file_path":"%s","new_string":"%s"}}' "$2" "$1" "${3:-}" | bash "$here/hooks/skill-nudge.sh"
}
nudge_path() { # FILE SESSION -> stdout. Cursor shape: a path and no tool_input, so the hook falls
               # back to classifying from the whole file.
  printf '{"session_id":"%s","file_path":"%s"}' "$2" "$1" | bash "$here/hooks/skill-nudge.sh"
}
s="test-$$"; rm -f "${TMPDIR:-/tmp}/go-coding-nudge.$s."*
: > "$t/a_test.go"; printf 'package a\nfunc f(){ go func(){}() }\n' > "$t/w.go"; printf 'package a\nimport "fmt"\nvar e = fmt.Errorf("x")\n' > "$t/e.go"; : > "$t/plain.go"; : > "$t/readme.md"
chk() { local name="$1" got="$2" expect="$3"; case "$got" in *"$expect"*) echo "ok   $name";; *) echo "FAIL $name: got '$got'"; fails=$((fails+1));; esac; }
chk_silent() { local name="$1" got="$2"; if [ -z "$got" ]; then echo "ok   $name"; else echo "FAIL $name: expected silence, got '$got'"; fails=$((fails+1)); fi; }
# chk matches by substring, which is delivery-channel-agnostic: the nudge text appears whether
# wrapped as {"systemMessage":"..."} (Claude Code) or printed as a plain line (Cursor). These six
# cases therefore exercise whichever path is active for the ambient CLAUDE_PLUGIN_ROOT (unset in a
# plain shell, so normally the Cursor/plain path); the two delivery-channel cases below force each
# path explicitly.
chk "test file nudges go-testing"         "$(nudge "$t/a_test.go" "$s")" "go-coding:go-testing"
chk_silent "second test file is silent"   "$(nudge "$t/a_test.go" "$s")"
chk "goroutine edit nudges go-concurrency" "$(nudge "$t/w.go" "$s" 'go func(){}()')" "go-coding:go-concurrency"
chk "fmt.Errorf edit nudges go-errors"    "$(nudge "$t/e.go" "$s" 'fmt.Errorf')" "go-coding:go-errors"
chk_silent "plain go file is silent"      "$(nudge "$t/plain.go" "$s")"
chk_silent "non-go file is silent"        "$(nudge "$t/readme.md" "$s")"
rm -f "${TMPDIR:-/tmp}/go-coding-nudge.$s."*

# Classify from the edit, not the file: an unrelated edit inside an error-heavy file must stay
# silent. Whole-file matching would claim "this edit touches an error path" for every file that
# merely defines a sentinel somewhere, which is most of a real Go repo.
sedit="$s-edit"; rm -f "${TMPDIR:-/tmp}/go-coding-nudge.$sedit."*
chk_silent "unrelated edit in an error-heavy file is silent" "$(nudge "$t/e.go" "$sedit" '// tidy the doc comment')"
chk "path-only payload falls back to the file" "$(nudge_path "$t/e.go" "$sedit")" "go-coding:go-errors"
rm -f "${TMPDIR:-/tmp}/go-coding-nudge.$sedit."*

# Delivery channel (F4): a fresh fixture + session per case so dedupe cannot silence it, and each
# host path forced explicitly rather than relying on the ambient CLAUDE_PLUGIN_ROOT.
: > "$t/e2.go"; printf 'package a\nimport "fmt"\nvar e = fmt.Errorf("x")\n' > "$t/e2.go"
sjson="$s-json"; rm -f "${TMPDIR:-/tmp}/go-coding-nudge.$sjson."*
chk "nudge is a systemMessage under Claude" "$(CLAUDE_PLUGIN_ROOT=/x nudge "$t/e2.go" "$sjson" 'fmt.Errorf')" '{"systemMessage":'
rm -f "${TMPDIR:-/tmp}/go-coding-nudge.$sjson."*

scursor="$s-cursor"; rm -f "${TMPDIR:-/tmp}/go-coding-nudge.$scursor."*
# Built directly (not via nudge_path()) per the sketch: env -u only strips CLAUDE_PLUGIN_ROOT from
# an external-command invocation, and the path-only payload already lacks hook_event_name.
out="$(printf '{"session_id":"%s","file_path":"%s"}' "$scursor" "$t/e2.go" | env -u CLAUDE_PLUGIN_ROOT bash "$here/hooks/skill-nudge.sh")"
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
