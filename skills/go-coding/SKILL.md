---
name: go-coding
description: This skill should be used when a Go task spans multiple areas, is unspecified, or the question is which tool or standard applies — it routes each topic to the deterministic tool, then to the focused go-* skill that owns it (go-errors, go-concurrency, go-testing, go-idioms, go-lint-setup, go-layout for layout/naming/API design). Go coding-standards router for idiomatic Go — Go 1.26.4+ (Go 1.27 supported; its additions are flagged as hints), golangci-lint v2. For a single, already-identified topic load that skill directly. Loading this router alone does not apply the standards — it names the focused skill to load next. Not for non-Go languages or domain/business rules.
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
| Static analysis / likely bugs | `go vet ./...`, `golangci-lint run` | `go-lint-setup` |
| Modern idioms (range-int, `min`/`max`, `slices`/`maps`, `wg.Go`, `strings.Cut`, `new(expr)`, `errors.AsType`) | `go fix ./...` (the toolchain's modernizer suite), or `golangci-lint run --enable-only=modernize` for CI reproducibility | `go-idioms` |
| Errors (`%w`, `errors.Is`/`AsType`, `errors.Join`, sentinel/typed, enum dispatch) | `golangci-lint run --enable-only=errorlint,exhaustive` | `go-errors` |
| Concurrency (goroutine leaks, ctx lifecycle, atomics) | `go test -race ./...`, `go vet ./...` | `go-concurrency` |
| Testing (table-driven, `t.Parallel`, `t.Context`, `B.Loop`, `testing/synctest`) | `go test -race ./...`; use `testing/synctest` for time/concurrency tests | `go-testing` |
| Layout, naming & API surface (`internal/`, initialisms, receiver type, in-band errors, doc comments) | `golangci-lint run --enable-only=revive` (`var-naming`, `receiver-naming`, `exported`), `gofmt` for doc-comment layout; the rest is judgment | `go-layout` |
| Code intelligence (defs/refs/diagnostics/rename/vulncheck) | install the **`gopls-lsp`** plugin | — |

Open the focused `go-*` skill for the topic — it carries the cited rules and the judgment; run the
tool in the middle column to enforce them. Don't invent rules: each skill cites its sources.

## Route, then load

The router is an index, not the standard. Before writing or reviewing Go you MUST load the focused
skill matching the change — with the Skill tool (`go-coding:go-errors`, …), not by recalling it:

| The diff touches… | Load |
|---|---|
| any `_test.go`, a benchmark, a fuzz target, a "verified by temporarily breaking it" claim | `go-testing` |
| `fmt.Errorf`, `errors.*`, a sentinel, a typed error, a `switch` over an enum | `go-errors` |
| a loop, map, slice, string split, `interface{}`, a struct literal that could be `new(expr)` | `go-idioms` |
| `go func`, `chan`, `sync.`, `atomic.`, `errgroup`, `context.With*`, a `Close` on a goroutine-owned resource | `go-concurrency` |
| a new package, an exported identifier, a `cmd/` or `internal/` decision, a doc comment on an API | `go-layout` |
| `.golangci.y*ml`, a linter complaint you do not understand | `go-lint-setup` |

One load per skill per session is enough; the skill stays in context. Orchestrators dispatching
implementer or reviewer subagents carry this table into every brief — a subagent does not inherit
the parent session's skills.

## Minimum checklist (when a second load is not affordable)

Apply these even if you load nothing else; they are the rules the focused skills most often catch:

- Wrap with `fmt.Errorf("…: %w", err)`; inspect with `errors.Is` / `errors.AsType` and guard the
  result (`ok && v != nil` — a typed-nil pointer satisfies the match). Never swallow an error.
- Every guard has a test that fails when the guard is deleted; a "temporarily broke it by hand"
  check is not evidence — commit it as a can-fail test. Table-driven `t.Run` with got/want messages.
- `range n`, `min`/`max`, `slices`/`maps`, `strings.Cut`, `any`; `go fix ./...` before hand-edits.
- `ctx` first; no goroutine without an owner that waits for it; `t.Context()` in tests.
- Run `gofmt`/`gofumpt` and `golangci-lint run` — never reason out what a tool decides.

## Authoritative sources (cite, don't guess)

- Effective Go — <https://go.dev/doc/effective_go>
- Go Code Review Comments — <https://go.dev/wiki/CodeReviewComments>
- Google Go Style Guide — <https://google.github.io/styleguide/go/>
- Uber Go Style Guide — <https://github.com/uber-go/guide>
- Package & toolchain docs — <https://pkg.go.dev>

## For a focused review

Dispatch the `go-reviewer` agent — a report-only, context-isolated reviewer that applies the
review-heuristics catalog and returns severity-ranked findings on a diff or file.

Two user-invoked skills round out the surface: `/go-explain <topic>` for a one-shot idiom lookup,
and `/go-lint-setup` to scaffold the reference golangci-lint v2 config into a repo.

---
*Top-level structure adapted from [`samber/cc-skills-golang`](https://github.com/samber/cc-skills-golang) (MIT © 2026 Samuel Berthe).*
