#!/usr/bin/env bash
# SessionStart (Claude Code) / sessionStart (Cursor) hook: print one Go-standards context
# line when a Go workspace is detected. Always exits 0.
#
# Claude Code runs the hook in the project directory and reads plain stdout.
# Cursor runs a plugin hook from the plugin install and reads additional_context
# from JSON, so there the script first changes into CURSOR_PROJECT_DIR.
set -u
# The plugin install holding this script, read before any cd: the banner names gosym's absolute path.
gosym="$(cd "$(dirname "$0")/.." 2>/dev/null && pwd)/skills/go-coding/scripts/gosym"

# CURSOR_PLUGIN_ROOT is set only for a Cursor plugin hook, so Claude Code started from a
# Cursor terminal still takes the Claude Code path. Without a usable CURSOR_PROJECT_DIR the
# hook stays silent rather than inspect the plugin install.
cursor=""
if [ -n "${CURSOR_PLUGIN_ROOT:-}" ]; then
  cursor=1
  [ -n "${CURSOR_PROJECT_DIR:-}" ] || exit 0
  cd "$CURSOR_PROJECT_DIR" 2>/dev/null || exit 0
fi

is_go_workspace() {
  [ -f go.mod ] && return 0
  # Bounded search so session start stays fast; ignore vendor/ and .git/.
  if find . -maxdepth 4 -name '*.go' -not -path './vendor/*' -not -path './.git/*' 2>/dev/null \
      | grep -q .; then
    return 0
  fi
  return 1
}

if is_go_workspace; then
  lint=" · /go-lint-setup scaffolds golangci-lint v2 (no config found)"
  for cfg in .golangci.yml .golangci.yaml .golangci.toml .golangci.json; do
    [ -e "$cfg" ] && lint="" && break
  done
  tail="; go-reviewer for a diff review${lint}. gofmt/golangci-lint v2; gopls for symbol lookups (gopls-lsp plugin, or from the shell ${gosym} -C <dir> def|refs|impl|calls <Name>)."
  if [ -n "$cursor" ]; then
    # The install path is the one part built from outside text: escape it for the JSON string.
    tail="$(printf '%s' "$tail" | sed 's/\\/\\\\/g; s/"/\\"/g')"
    line="› Go workspace — go-coding: open /go-coding, then the skill for your diff (/go-errors · /go-testing · /go-idioms · /go-concurrency · /go-layout)${tail}"
    printf '{"additional_context":"%s"}\n' "$line"
  else
    line="› Go workspace — go-coding: load go-coding then the skill for your diff (go-errors · go-testing · go-idioms · go-concurrency · go-layout)${tail}"
    echo "$line"
  fi
fi

exit 0
