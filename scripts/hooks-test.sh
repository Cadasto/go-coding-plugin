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
[ "$fails" -eq 0 ] || exit 1
