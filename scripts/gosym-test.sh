#!/usr/bin/env bash
# Bash tests for skills/go-coding/scripts/gosym. Run: ./scripts/gosym-test.sh  (exit 0 = all pass)
# A stub gopls on PATH answers from canned output, so no Go toolchain or gopls is needed.
set -u
here="$(cd "$(dirname "$0")/.." && pwd)"; fails=0
gosym="$here/skills/go-coding/scripts/gosym"
t="$(mktemp -d)"; trap 'rm -rf "$t"' EXIT
repo="$(cd "$t" && mkdir -p repo stub && cd repo && pwd -P)"

# The stub prints what gopls would for a checkout at $repo: a loose match, an exact function, a method
# of the same name, the name in a second package, and a hit outside the checkout. GOSYM_STUB_FAIL makes
# a per-position query fail; GOSYM_STUB_MANY makes the symbol list reach gopls' cap of 100.
cat > "$t/stub/gopls" <<STUB
#!/usr/bin/env bash
case "\$1" in
  workspace_symbol)
    [ "\${4:-}" = 'Parse\$' ] || [ "\${4:-}" = 'Reader.Parse\$' ] || { echo "unexpected query: \$*" >&2; exit 9; }
    echo "$repo/internal/q/parse.go:10:6-11 Parse Function"
    echo "$repo/internal/q/reader.go:20:18-23 Reader.Parse Method"
    echo "$repo/cmd/tool/parse.go:7:6-11 Parse Function"
    echo "$repo/internal/q/parse_test.go:30:6-15 TestParse Function"
    echo "/usr/local/go/src/net/url/url.go:1:6-11 Parse Function"
    if [ -n "\${GOSYM_STUB_MANY:-}" ]; then for i in \$(seq 1 96); do echo "/x/y.go:\$i:6-11 Parse\$i Function"; done; fi ;;
  references|implementation|call_hierarchy)
    [ -z "\${GOSYM_STUB_FAIL:-}" ] || { echo "gopls: \$1 refused" >&2; exit 2; }
    echo "$repo/internal/q/use.go:3:2-7 (\$1 at \$2)" ;;
  *) echo "unexpected: \$*" >&2; exit 9 ;;
esac
STUB
chmod +x "$t/stub/gopls"
export PATH="$t/stub:$PATH"

check() { # NAME WANT_EXIT GOT_EXIT OUTPUT WANT_SUBSTRING (empty = no check) [UNWANTED_SUBSTRING]
  local name="$1" want="$2" got="$3" out="$4" sub="$5" bad="${6:-}"
  [ "$got" = "$want" ] || { echo "FAIL $name: exit $got, want $want: $out"; fails=$((fails+1)); return; }
  if [ -n "$sub" ]; then case "$out" in *"$sub"*) ;; *) echo "FAIL $name: missing '$sub' in: $out"; fails=$((fails+1)); return;; esac; fi
  if [ -n "$bad" ]; then case "$out" in *"$bad"*) echo "FAIL $name: unexpected '$bad' in: $out"; fails=$((fails+1)); return;; esac; fi
  echo "ok   $name"
}

out="$(cd "$repo" && "$gosym" def Parse 2>&1)"; rc=$?
check "def keeps exact names inside the checkout, paths relative" 0 $rc "$out" "== internal/q/parse.go:10:6-11 Parse Function" "TestParse"
check "def drops a definition outside the checkout"                0 $rc "$out" "== cmd/tool/parse.go:7:6-11 Parse Function" "url.go"
check "a bare name also finds the methods of that name"            0 $rc "$out" "Reader.Parse Method"
out="$(cd "$repo" && "$gosym" def Reader.Parse 2>&1)"; rc=$?
check "a qualified name finds only that method"                    0 $rc "$out" "Reader.Parse Method" "Parse Function"
out="$(cd "$repo" && "$gosym" refs Parse cmd/ 2>&1)"; rc=$?
check "refs asks gopls references at the definition"               0 $rc "$out" "internal/q/use.go:3:2-7 (references at cmd/tool/parse.go:7:6-11)"
check "a path part keeps the matching definition only"             0 $rc "$out" "== cmd/tool/parse.go" "internal/q/parse.go:10"
out="$(cd "$repo" && "$gosym" impl Reader.Parse 2>&1)"; rc=$?
check "impl asks gopls implementation"                             0 $rc "$out" "(implementation at"
out="$(cd "$repo" && "$gosym" calls Reader.Parse 2>&1)"; rc=$?
check "calls asks gopls call_hierarchy"                            0 $rc "$out" "(call_hierarchy at"
out="$(cd / && "$gosym" -C "$repo" def Reader.Parse 2>&1)"; rc=$?
check "-C answers for another checkout"                            0 $rc "$out" "== internal/q/reader.go:20:18-23"
out="$(cd "$repo" && "$gosym" refs Parse nowhere/ 2>&1)"; rc=$?
check "no matching definition exits 1 and says to use grep"        1 $rc "$out" "use grep and say so"
out="$(cd "$repo" && GOSYM_STUB_FAIL=1 "$gosym" refs Reader.Parse 2>&1)"; rc=$?
check "a failing gopls exits 3 with its message"                   3 $rc "$out" "refused"
out="$(cd "$repo" && GOSYM_STUB_MANY=1 "$gosym" def Parse 2>&1)"; rc=$?
check "a list at gopls' cap says a definition may be missing"      0 $rc "$out" "stopped at 100 symbols"
out="$(cd "$repo" && PATH=/usr/bin:/bin "$gosym" def Parse 2>&1)"; rc=$?
check "without gopls it exits 3 and says to use grep"              3 $rc "$out" "use grep and say so"
out="$("$gosym" find Parse 2>&1)"; rc=$?
check "an unknown question is a usage error"                       2 $rc "$out" "usage: gosym"
out="$("$gosym" def 'Parse;rm' 2>&1)"; rc=$?
check "a name that is not a Go name is refused"                    2 $rc "$out" "not a Go name"

# The helper itself must fail on bad input, or a broken check could hide a regression above.
probe="$( fails=0; check "probe" 0 1 "x" "" )"
case "$probe" in FAIL*) echo "ok   can-fail: check rejects a wrong exit";; *) echo "FAIL can-fail: check passed a wrong exit"; fails=$((fails+1));; esac

[ "$fails" -eq 0 ] || exit 1
