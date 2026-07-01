---
name: go-coding
description: Go coding-standards router and entry point for idiomatic Go (Go 1.26, works with 1.25+; golangci-lint v2). This skill should be used when a Go task spans multiple areas, is unspecified, or the question is which tool or standard applies — it routes each topic to the deterministic tool (gofmt/gofumpt, go vet, go fix / golangci-lint v2 modernize, go test -race), to the gopls-lsp plugin for code intelligence, and then to the focused go-* skill that owns it. For a single, already-identified topic prefer that skill directly (errors → go-errors, concurrency → go-concurrency, testing → go-testing, idioms/modernization → go-idioms, linter config → go-linting, layout → go-layout). Not for non-Go languages or domain/business rules.
---

# go-coding — Go standards router

Route the Go task to the right standard and tool — this skill is a router, not an encyclopedia.
Two principles from the project research drive it:

- **Deterministic beats prose.** Whatever a formatter or linter enforces, run the tool — don't
  reason it out by hand. The plugin's value is judgment the model lacks, not re-deriving tooling.
- **Don't rebuild code intelligence.** For defs/refs/diagnostics/rename/vulncheck, recommend the
  official **`gopls-lsp`** plugin (`@claude-plugins-official`).

## Routing table

| Topic | Run now (deterministic) | Deeper skill |
|---|---|---|
| Formatting | `gofmt -l` / `gofumpt -l` (+ `goimports`) — machine-enforced, non-negotiable | — |
| Static analysis / likely bugs | `go vet ./...`, `golangci-lint run` | `go-linting` |
| Modern idioms (range-int, `min`/`max`, `slices`/`maps`, `wg.Go`, `strings.Cut`, `new(expr)`) | `go fix ./...` (Go 1.26 applies the full modernizer suite natively), or `golangci-lint run --enable-only=modernize` on older toolchains | `go-idioms` |
| Errors (`%w`, `errors.Is`/`As`, `errors.Join`, sentinel/typed) | `golangci-lint run --enable-only=errorlint` | `go-errors` |
| Concurrency (goroutine leaks, ctx lifecycle, atomics) | `go test -race ./...`, `go vet ./...` | `go-concurrency` |
| Testing (table-driven, `t.Parallel`, `B.Loop`, `testing/synctest`) | `go test -race ./...`; use `testing/synctest` (stable since 1.25) for time/concurrency tests | `go-testing` |
| Project layout (`internal/`, start-flat) | judgment — see sources below | `go-layout` |
| Code intelligence (defs/refs/diagnostics/rename/vulncheck) | install the **`gopls-lsp`** plugin | — |

Open the focused `go-*` skill for the topic — it carries the cited rules and the judgment; run the
tool in the middle column to enforce them. Don't invent rules: each skill cites its sources.

## Authoritative sources (cite, don't guess)

- Effective Go — <https://go.dev/doc/effective_go>
- Go Code Review Comments — <https://go.dev/wiki/CodeReviewComments>
- Google Go Style Guide — <https://google.github.io/styleguide/go/>
- Uber Go Style Guide — <https://github.com/uber-go/guide>
- Package & toolchain docs — <https://pkg.go.dev>

## For a focused review

Dispatch the `go-reviewer` agent — a read-only, context-isolated reviewer that applies the
review-heuristics catalog and returns severity-ranked findings on a diff or file.

---
*Top-level structure adapted from [`samber/cc-skills-golang`](https://github.com/samber/cc-skills-golang) (MIT © 2026 Samuel Berthe).*
