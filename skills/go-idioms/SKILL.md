---
name: go-idioms
description: Modern idiomatic Go (the `modernize` analyzer set). This skill should be used when the user writes, reviews, or modernizes Go and wants current-version idioms — range-over-int, `min`/`max`, `slices`/`maps`, `strings.Cut`, `cmp.Or`, `sync.OnceFunc`, iterators, `slog.LogAttrs`, `new(expr)` (Go 1.26), dropped loop-var copies. Framed so advice equals tooling (`go fix ./...` on Go 1.26, or `golangci-lint --enable-only=modernize`). Errors→`go-errors`, concurrency→`go-concurrency`, tests→`go-testing`. Not for golangci-lint configuration (use `go-linting`) or non-Go languages.
---

# go-idioms — modern Go (modernize)

**Advice == tooling.** The `modernize` analyzers flag and usually auto-fix everything below. Run
them, don't hand-audit. As of **Go 1.26** the rewritten `go fix` is the canonical runner — it ships
the full modernizer suite in the toolchain itself:

```
go fix ./...                                        # Go 1.26+: applies the built-in modernizers
golangci-lint run --enable-only=modernize --fix     # any toolchain (same analyzers, via golangci-lint)
```

Both draw on the same `golang.org/x/tools` engine as gopls, so their fixes agree. This skill
explains *why* and catches what review notices before the tool runs. **Check `go.mod` first** —
gate each idiom on the module's Go version (the `Since` column below); don't apply a Go 1.26 idiom to
a repo pinned to 1.25 or older.

## Prefer → over (since)

| Prefer | Over | Since |
|---|---|---|
| `new(expr)` — e.g. `Field: new(30)`, `new(int64(req.Limit))` | a named temp + `&tmp`, or a `ptr[T](v)` helper, for optional/pointer fields | 1.26 |
| `for i := range n` | `for i := 0; i < n; i++` | 1.22 |
| `min(a, b)` / `max(a, b)` builtins | hand-rolled helpers | 1.21 |
| *(drop)* `x := x` loop-var copy | pre-1.22 capture workaround | 1.22 |
| `slices.Sort/Contains/Equal`, `slices.Collect`, `maps.Keys` | hand-rolled sort/contains/dedup | 1.21–1.23 |
| `strings.Cut` / `CutPrefix` / `CutSuffix` | `Index` + manual slicing | 1.18/1.20 |
| `cmp.Or(a, b, …)` | nested `if x == "" { x = y }` | 1.22 |
| `sync.OnceFunc` / `OnceValue` | `sync.Once` + a captured var | 1.21 |
| `iter.Seq[V]` / range-over-func | `Visit(callback)` patterns, exposing slices | 1.23 |
| `slog.LogAttrs(ctx, lvl, msg, attrs…)` on hot paths | key-value variadic `slog` (allocates) | 1.21 |
| `errors.Join` | manual multi-error concat → `go-errors` | 1.20 |
| `wg.Go(...)` | `wg.Add(1)`/`defer wg.Done()` → `go-concurrency` | 1.25 |
| `for b.Loop()` | `for i := 0; i < b.N; i++` → `go-testing` | 1.24 |
| typed `atomic.Int64` | bare-int `atomic.Add*` → `go-concurrency` | 1.19 |

Idioms are a moving target — let the tool (pinned to the repo's toolchain) be the source of
truth so advice never drifts from the user's `go fix`. Go 1.26 also lifts the ban on a generic type
referencing itself in its own type-parameter list (e.g. `type Adder[A Adder[A]] interface{ Add(A) A }`),
so self-referential constraints no longer need a workaround — but that's a hand-written pattern, not
something a modernizer rewrites.

## Sources
- `modernize` — <https://pkg.go.dev/golang.org/x/tools/go/analysis/passes/modernize>
- `go fix` (rewritten in 1.26) — <https://go.dev/blog/gofix>; range-over-func — <https://go.dev/blog/range-functions>
- `slog` — <https://go.dev/blog/slog>; Go 1.21–1.26 release notes (`new(expr)`, self-ref generics — <https://go.dev/doc/go1.26>)

---
*Decomposition inspired by [`samber/cc-skills-golang`](https://github.com/samber/cc-skills-golang) (MIT © 2026 Samuel Berthe); rules grounded in the sources above.*
