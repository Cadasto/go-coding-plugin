---
name: go-idioms
description: Modern idiomatic Go (the `modernize` linter set). This skill should be used when the user writes, reviews, or modernizes Go and wants current-version idioms — range-over-int, `min`/`max`, `slices`/`maps`, `strings.Cut`, `cmp.Or`, `sync.OnceFunc`, iterators, `slog.LogAttrs`, dropped loop-var copies. Framed so advice equals tooling (`golangci-lint --enable-only=modernize` / `go fix`). Errors→`go-errors`, concurrency→`go-concurrency`, tests→`go-testing`. Not for golangci-lint configuration (use `go-linting`) or non-Go languages.
---

# go-idioms — modern Go (modernize)

**Advice == tooling.** The `modernize` analyzer (in `golang.org/x/tools`, the same engine as gopls
and `go fix`) flags and usually auto-fixes everything below. Run it, don't hand-audit:

```
golangci-lint run --enable-only=modernize --fix    # or: go fix ./...
```

This skill explains *why* and catches what review notices before the linter runs. **Check `go.mod`
first** — don't apply a Go 1.25 idiom to a repo pinned older.

## Prefer → over (since)

| Prefer | Over | Since |
|---|---|---|
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

Idioms are a moving target — let the linter (pinned to the repo's toolchain) be the source of
truth so advice never drifts from the user's `go fix`.

## Sources
- `modernize` — <https://pkg.go.dev/golang.org/x/tools/go/analysis/passes/modernize>
- `go fix` / tool evolution — <https://go.dev/blog/gofix>; range-over-func — <https://go.dev/blog/range-functions>
- `slog` — <https://go.dev/blog/slog>; Go 1.21–1.25 release notes

---
*Decomposition inspired by [`samber/cc-skills-golang`](https://github.com/samber/cc-skills-golang) (MIT © 2026 Samuel Berthe); rules grounded in the sources above.*
