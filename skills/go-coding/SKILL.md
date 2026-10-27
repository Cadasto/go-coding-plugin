---
name: go-coding
description: Go coding-standards router. This skill should be used when a Go task spans several areas, is unspecified, or the question is which tool or standard applies, including where a Go symbol is defined, used, implemented or called — it names the deterministic tool to run, then the focused skill that owns the topic (go-errors, go-concurrency, go-testing, go-idioms, go-layout, go-lint-setup). Loading the router alone does not apply the standards — load the skill it names next. For one already-identified topic, load that skill directly. Go only; not for business rules.
---

# go-coding — Go standards router

Route the Go task to the right standard and tool (Go 1.26.4+, with Go 1.27 additions flagged as
hints; golangci-lint v2) — this skill is a router, not an encyclopedia. Two principles drive it:

- **Deterministic beats prose.** Whatever a formatter or linter enforces, run the tool — don't
  reason it out by hand. The plugin's value is judgment the model lacks, not re-deriving tooling.
- **Don't rebuild code intelligence.** Ask `gopls`, not `grep`, where a symbol is defined, who uses
  it, who implements it and who calls it: `grep` matches the name, so it cannot tell `a.Close` from
  `b.Close`, and it cannot see which types satisfy an interface (Go never writes `implements`). The
  official **`gopls-lsp`** plugin (`@claude-plugins-official`) provides the `LSP` tool, which also
  covers diagnostics, rename and vulncheck. How to ask: *Symbol questions* below.

## Routing table

| Topic | Run now (deterministic) | Deeper skill |
|---|---|---|
| Formatting | `gofmt -l` / `gofumpt -l` (+ `goimports`) — machine-enforced, non-negotiable | — |
| Static analysis / likely bugs | `go vet ./...`, `golangci-lint run` | `go-lint-setup` |
| Modern idioms (range-int, `min`/`max`, `slices`/`maps`, `wg.Go`, `strings.Cut`, `new(expr)`, `errors.AsType`) | `go fix ./...` (the toolchain's modernizer suite), or `golangci-lint run --enable-only=modernize` for CI reproducibility | `go-idioms` |
| Errors (`%w`, `errors.Is`/`AsType`, `errors.Join`, sentinel/typed, enum dispatch) | `golangci-lint run --enable-only=errorlint,exhaustive` | `go-errors` |
| Concurrency (goroutine leaks, ctx lifecycle, atomics) | `go test -race ./...`, `go vet ./...` | `go-concurrency` |
| Testing (table-driven, `t.Parallel`, `t.Context`, `B.Loop`, `testing/synctest`) | `go test -race ./...`; use `testing/synctest` for time/concurrency tests | `go-testing` |
| Layout, naming & API surface (`internal/`, imports, initialisms, receiver type, in-band errors, struct literals, doc comments) | `golangci-lint run --enable-only=revive` (`var-naming`, `receiver-naming`, `exported`, `blank-imports`, `dot-imports`), `go vet` (`composites`), `gofmt` for doc-comment layout; the rest is judgment | `go-layout` |
| Symbol questions (where defined, who uses it, who implements it, who calls it) | `gopls`, per *Symbol questions* below; `grep` stays for text, docs and config | — |

## Symbol questions

Where a Go symbol is defined, who uses it, who implements it, who calls it:

1. With a language-server tool (Claude Code's `LSP`) whose root is the checkout being changed, use it.
2. Otherwise run `gopls` from the shell, with `cd` in the same command so it answers from the
   checkout or worktree being changed: `cd <checkout> && gopls workspace_symbol -matcher casesensitive <Name>`.
   Each hit prints `<file>:<line>:<col>-<col> <Name> <Kind>`; its first field is the definition.
3. Pass that first field, unchanged, to `gopls references` (every use, resolved by type),
   `gopls implementation` (an interface's types, or the interfaces a type satisfies) or
   `gopls call_hierarchy` (callers and callees; functions and methods only). `gopls definition`
   takes the position of a use, not a name. A position off the identifier makes `gopls` exit 2.
4. If `gopls` is missing, the call is refused, or it exits non-zero, use `grep` and say so.

The command line is experimental (<https://go.dev/gopls/command-line>); `gopls help <command>`
shows what the installed version takes.

## Route, then load

The router is an index, not the standard. Before writing or reviewing Go you MUST load the focused
skill matching the change — with the Skill tool (`go-coding:go-errors`, …), not by recalling it:

| The diff touches… | Load |
|---|---|
| any `_test.go`, a benchmark, a fuzz target, a "verified by temporarily breaking it" claim | `go-testing` |
| `fmt.Errorf`, `errors.*`, a sentinel, a typed error, a `Must` helper, a `switch` over an enum | `go-errors` |
| a loop, map, slice, string split, `interface{}`, a struct literal that could be `new(expr)`, a nested `:=` on `err` | `go-idioms` |
| `go func`, `chan`, `sync.`, `atomic.`, `errgroup`, `context.With*`, a `Close` on a goroutine-owned resource | `go-concurrency` |
| a new package, an exported identifier, a `cmd/` or `internal/` decision, an import block, a struct literal of a foreign type, a doc comment on an API | `go-layout` |
| `.golangci.y*ml`, a linter complaint you do not understand | `go-lint-setup` |

One load per skill per session is enough; the skill stays in context. Orchestrators dispatching
implementer or reviewer subagents carry this table and the *Symbol questions* section into every
brief, with the absolute path of the checkout or worktree being changed — a subagent does not
inherit the parent session's skills, and may start in a different folder.

## Minimum checklist (when a second load is not affordable)

Apply these even if you load nothing else; they are the rules the focused skills most often catch:

- Wrap with `fmt.Errorf("…: %w", err)`; inspect with `errors.Is` / `errors.AsType` and guard the
  result (`ok && v != nil` — a typed-nil pointer satisfies the match). Never swallow an error.
- Every guard has a test that fails when the guard is deleted; a "temporarily broke it by hand"
  check is not evidence — commit it as a can-fail test. Table-driven `t.Run` with got/want messages.
- `range n`, `min`/`max`, `slices`/`maps`, `strings.Cut`, `any`; `go fix ./...` before hand-edits.
- `ctx` first; no goroutine without an owner that waits for it; `t.Context()` in tests.
- Run `gofmt`/`gofumpt` and `golangci-lint run` — never reason out what a tool decides.

## Tie-breaks (when two valid forms compete)

When both forms pass the tools, decide by the order Google's Go Style Guide gives for readable code:
clarity, then simplicity (with its rule of least mechanism: the most standard tool that expresses
the idea), then concision, then maintainability, then consistency. Say which attribute decided it;
"more idiomatic" on its own is not a reason. Source: <https://google.github.io/styleguide/go/guide> (normative and canonical).

## Writing for the human

Anything a person reads — a PR description, a review comment, a question, a design choice put to
them — goes in plain English, not Go shorthand. State the effect before the mechanism ("the request
keeps running after the caller gives up", not "ctx leak in the errgroup"), and expand a term the
first time it appears or leave it out. Keep it short: a few sentences per point, and a decision they
must make gets the options plus a recommendation, not an essay. Identifiers, commands and linter
names stay verbatim — it is the prose around them that must be plain.

## Authoritative sources (cite, don't guess)

- Effective Go — <https://go.dev/doc/effective_go>
- Go Code Review Comments — <https://go.dev/wiki/CodeReviewComments>
- Google Go Style Guide — <https://google.github.io/styleguide/go/> — three documents, cite the one a rule comes from: the *Guide* (<https://google.github.io/styleguide/go/guide>, normative and canonical: the principles), *Style Decisions* (<https://google.github.io/styleguide/go/decisions>, normative: the reviewer rulebook), *Best Practices* (<https://google.github.io/styleguide/go/best-practices>, advisory)
- Uber Go Style Guide — <https://github.com/uber-go/guide>
- Package & toolchain docs — <https://pkg.go.dev>
- Linter rule catalogues (name the rule, not just the tool) — `go vet` <https://pkg.go.dev/cmd/vet>; staticcheck <https://staticcheck.dev/docs/checks/>; revive <https://github.com/mgechev/revive/blob/master/RULES_DESCRIPTIONS.md>; golangci-lint linters <https://golangci-lint.run/docs/linters/>

## For a focused review

Dispatch the `go-reviewer` agent — a report-only, context-isolated reviewer that loads these skills,
applies the review-heuristics catalog and returns severity-ranked findings on a diff or file.

If a workflow already owns the reviewer seat, that reviewer loads the focused skills itself instead —
one review seat per diff.

`/go-lint-setup` scaffolds the reference golangci-lint v2 config into a repo.

---
*Top-level structure adapted from [`samber/cc-skills-golang`](https://github.com/samber/cc-skills-golang) (MIT © 2026 Samuel Berthe).*
