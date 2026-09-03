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
  lint=" · /go-lint-setup scaffolds golangci-lint v2 (no config found)"
  for cfg in .golangci.yml .golangci.yaml .golangci.toml .golangci.json; do
    [ -e "$cfg" ] && lint="" && break
  done
  echo "› Go workspace — go-coding: load go-coding then the skill for your diff (go-errors · go-testing · go-idioms · go-concurrency · go-layout); /go-explain <topic> for a one-shot idiom lookup; go-reviewer for a diff review${lint}. gofmt/golangci-lint v2 + gopls-lsp recommended."
fi

exit 0
