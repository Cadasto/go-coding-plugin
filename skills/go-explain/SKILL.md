---
name: go-explain
description: One-shot lookup/explanation of a single Go idiom, standard, or tool. This skill should be used when the user runs `/go-explain <topic>` or asks to "explain", "look up", or "what's the modern way to do" a specific Go construct (e.g. error wrapping, `synctest`, `wg.Go`, `min`/`max`, `internal/` layout) — returning the modern form, the enforcing linter, and a cited source. For applying a standard while writing or reviewing code, use the focused go-* skill (`go-errors`, `go-concurrency`, …). Not for non-Go languages.
argument-hint: a Go topic (e.g. error wrapping, synctest, wg.Go, min/max, internal layout)
allowed-tools: Read, Grep, Glob
---

# go-explain — one-shot Go lookup

Explain the Go idiom, standard, or tool named in **$ARGUMENTS** — concisely, in one interaction.

Cover, in a few lines:

1. **The modern form** — what idiomatic Go does today, with the Go version it landed in.
2. **Over what** — the older pattern it replaces, if any.
3. **Enforcement** — the tool that flags or fixes it (`gofmt`/`gofumpt`, `go vet`, a `golangci-lint`
   linter such as `modernize`/`errorlint`, or `go test -race`), with the exact command to run.
4. **Source** — cite one authoritative reference: Effective Go, Go Code Review Comments, the Google
   or Uber Go style guide, a `go.dev/blog` post, or `pkg.go.dev`.

Tailor to the repo's Go version when a `go.mod` is present — don't recommend a Go 1.26 idiom (e.g.
`new(expr)`) for a module pinned to 1.25 or older. For a fuller treatment, route to the matching
skill: `go-errors`, `go-concurrency`,
`go-testing`, `go-idioms`, `go-linting`, or `go-layout`.

Keep it tight — this is a lookup, not a lecture. If `$ARGUMENTS` is empty, ask what to explain.
