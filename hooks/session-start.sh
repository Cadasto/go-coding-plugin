#!/usr/bin/env bash
# SessionStart hook (host-agnostic): print one Go-standards context line when a Go
# workspace is detected. Always exits 0 so the assistant reads stdout and is never blocked.
set -u

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
  echo "› Go workspace detected — go-coding standards available (ask for a Go review or idiom guidance; gofmt + golangci-lint v2 and the gopls-lsp plugin recommended)."
fi

exit 0
