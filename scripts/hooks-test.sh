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
run_case "go repo with lint config names /go-explain"  "$t/go-with-lint" "/go-explain <topic>"
run_case_absent "go repo with lint config omits lint-setup" "$t/go-with-lint" "/go-lint-setup"
run_case "go repo without lint config offers setup"    "$t/go-no-lint"   "/go-lint-setup"
run_case "non-go repo is silent"                        "$t/not-go"       ""

nudge() { # FILE SESSION -> stdout
  printf '{"session_id":"%s","tool_name":"Edit","tool_input":{"file_path":"%s"}}' "$2" "$1" | bash "$here/hooks/skill-nudge.sh"
}
s="test-$$"; rm -f "${TMPDIR:-/tmp}/go-coding-nudge.$s."*
: > "$t/a_test.go"; printf 'package a\nfunc f(){ go func(){}() }\n' > "$t/w.go"; printf 'package a\nimport "fmt"\nvar e = fmt.Errorf("x")\n' > "$t/e.go"; : > "$t/plain.go"; : > "$t/readme.md"
chk() { local name="$1" got="$2" expect="$3"; case "$got" in *"$expect"*) echo "ok   $name";; *) echo "FAIL $name: got '$got'"; fails=$((fails+1));; esac; }
chk_silent() { local name="$1" got="$2"; if [ -z "$got" ]; then echo "ok   $name"; else echo "FAIL $name: expected silence, got '$got'"; fails=$((fails+1)); fi; }
chk "test file nudges go-testing"         "$(nudge "$t/a_test.go" "$s")" "go-coding:go-testing"
chk_silent "second test file is silent"   "$(nudge "$t/a_test.go" "$s")"
chk "goroutine nudges go-concurrency"     "$(nudge "$t/w.go" "$s")" "go-coding:go-concurrency"
chk "fmt.Errorf nudges go-errors"         "$(nudge "$t/e.go" "$s")" "go-coding:go-errors"
chk_silent "plain go file is silent"      "$(nudge "$t/plain.go" "$s")"
chk_silent "non-go file is silent"        "$(nudge "$t/readme.md" "$s")"
rm -f "${TMPDIR:-/tmp}/go-coding-nudge.$s."*

[ "$fails" -eq 0 ] || exit 1
