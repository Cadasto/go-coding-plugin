---
name: go-idioms
description: Modern idiomatic Go (the `modernize` analyzer set). This skill should be used when the user writes, reviews, or modernizes Go and wants current-version idioms — range-over-int, `min`/`max`, `slices`/`maps`, `strings.Cut`, `any` over `interface{}`, iterators, `omitzero` json tags, `os.Root`, `new(expr)` and `errors.AsType` (Go 1.26), dropped loop-var copies — or asks which modernize fixer owns a rewrite. Framed so advice equals tooling (`go fix ./...`, or `golangci-lint --enable-only=modernize`). Not for golangci-lint configuration (use `go-linting`) or non-Go languages.
---

# go-idioms — modern Go (modernize)

**Advice == tooling.** The `modernize` analyzers flag and usually auto-fix most of what follows — the
**Fixer** column says which, and the last section covers what no fixer will do for you. Run the tool,
don't hand-audit. As of **Go 1.26** the rewritten `go fix` is the canonical runner — it ships the
modernizer suite in the toolchain itself:

```
go fix ./...                                        # Go 1.26+: applies the built-in modernizers
golangci-lint run --enable-only=modernize --fix     # any toolchain (same analyzers, via golangci-lint)
```

Both draw on the same `golang.org/x/tools` engine as gopls, so their fixes agree. This skill
explains *why* and catches what review notices before the tool runs. **Check `go.mod` first** —
gate each idiom on the module's Go version (the `Since` column below); don't apply a Go 1.26 idiom to
a repo pinned to 1.25 or older.

## Prefer → over (since)

The **Fixer** column names the `modernize` analyzer that owns each rewrite — cite it when explaining
or attributing a change, and use `go tool fix help` to see which analyzers the installed toolchain
actually ships (in golangci-lint the whole set is the single `modernize` linter). `—` means no fixer
exists: review has to catch it.

| Prefer | Over | Since | Fixer |
|---|---|---|---|
| `new(expr)` — e.g. `Field: new(30)`, `new(int64(req.Limit))` | a `ptr[T](v)` helper or a hand-written `tmp := v; &tmp`, for optional/pointer fields | 1.26 | `newexpr` |
| `errors.AsType[E](err)` | `errors.As(err, &target)` → `go-errors` | 1.26 | `errorsastype` |
| `for i := range n` | `for i := 0; i < n; i++` | 1.22 | `rangeint` |
| `min(a, b)` / `max(a, b)` builtins | hand-rolled helpers | 1.21 | `minmax` |
| *(drop)* `x := x` loop-var copy | pre-1.22 capture workaround | 1.22 | `forvar` |
| `any` | `interface{}` | 1.18 | `any` |
| `slices.Sort/Contains/Equal`, `slices.Collect`, `maps.Keys`, `slices.Concat` | hand-rolled sort/contains/dedup/append chains | 1.21–1.23 | `slices*`, `mapsloop`, `appendclipped` |
| `for i, v := range slices.Backward(s)` | `for i := len(s)-1; i >= 0; i--` | 1.23 | `slicesbackward` |
| `strings.Cut` / `CutPrefix` / `CutSuffix` | `Index` + manual slicing | 1.18/1.20 | `stringscut`, `stringscutprefix` |
| `strings.SplitSeq` / `FieldsSeq` | ranging over `strings.Split`/`Fields` (allocates a slice) | 1.24 | `stringsseq` |
| `omitzero` on a struct-typed json field | `omitempty`, which does **nothing** for struct fields — a zero `time.Time` still marshals | 1.24 | `omitzero` |
| `t.Context()` in tests | `context.WithCancel(context.Background())` → `go-testing` | 1.24 | `testingcontext` |
| `reflect.TypeFor[T]()` | `reflect.TypeOf((*T)(nil)).Elem()` | 1.22 | `reflecttypefor` |
| `cmp.Or(a, b, …)` | nested `if x == "" { x = y }` | 1.22 | — |
| `sync.OnceFunc` / `OnceValue` | `sync.Once` + a captured var | 1.21 | — |
| `iter.Seq[V]` / range-over-func | `Visit(callback)` patterns, exposing slices | 1.23 | `stditerators` |
| `slog.LogAttrs(ctx, lvl, msg, attrs…)` on hot paths | key-value variadic `slog` (allocates) | 1.21 | — |
| `errors.Join` | manual multi-error concat → `go-errors` | 1.20 | — |
| `wg.Go(...)` | `wg.Add(1)`/`defer wg.Done()` → `go-concurrency` | 1.25 | `waitgroupgo` |
| `for b.Loop()` | `for i := 0; i < b.N; i++` → `go-testing` | 1.24 | `bloop` |
| typed `atomic.Int64` | bare-int `atomic.Add*` → `go-concurrency` | 1.19 | `atomictypes` |

Idioms are a moving target — let the tool (pinned to the repo's toolchain) be the source of
truth so advice never drifts from the user's `go fix`. Go 1.26 also lifts the ban on a generic type
referencing itself in its own type-parameter list (e.g. `type Adder[A Adder[A]] interface{ Add(A) A }`),
so self-referential constraints no longer need a workaround — but that's a hand-written pattern, not
something a modernizer rewrites.

## Modern, but no fixer will do it for you

- **`os.OpenRoot(dir)` → `*os.Root`** (1.24) for anything that opens a caller-supplied path: its
  methods cannot escape the directory, including via symlink. Replaces `filepath.Join` plus
  hand-written `..`/prefix checks — the traversal-bug pattern those checks keep getting wrong.
- **`rand.Text()`** from `crypto/rand` (1.24) for tokens, nonces, and IDs — not `math/rand`, and not
  a hand-rolled base64 of `rand.Read`. Security-sensitive randomness always comes from `crypto/rand`.
- **`var s []T`, not `s := []T{}`** — the nil slice is the idiomatic empty slice (append works,
  `len` is 0). Reach for the non-nil literal only when something genuinely distinguishes them
  (e.g. marshalling `[]` vs `null`).
- **`slices.Sorted(maps.Keys(m))`** (1.23) when iterating a map for output — map order is random, and
  unstable output is a flaky-test and noisy-diff source.

*Go 1.27 (draft, expected Aug 2026) adds the `atomictypes`, `embedlit`, `slicesbackward`, and
`unsafefuncs` fixers to `go fix`, renames `waitgroup` → `waitgroupgo`, and drops `fmtappendf`; it also
lands `encoding/json/v2` + `encoding/json/jsontext` (v1 is reimplemented on v2, opt out with
`GOEXPERIMENT=nojsonv2`), `strings.CutLast`/`bytes.CutLast`, and a stdlib `uuid` package. A
golangci-lint built against newer `x/tools` may carry those fixers before the toolchain does.*

## Sources
- `modernize` (per-fixer docs, the Fixer column) — <https://pkg.go.dev/golang.org/x/tools/go/analysis/passes/modernize>
- `go fix` (rewritten in 1.26) — <https://go.dev/blog/gofix>; range-over-func — <https://go.dev/blog/range-functions>
- `slog` — <https://go.dev/blog/slog>; Go 1.21–1.26 release notes (`new(expr)`, self-ref generics — <https://go.dev/doc/go1.26>)
- `os.Root` / `omitzero` / `rand.Text` — <https://go.dev/doc/go1.24>; Code Review Comments (Declaring Empty Slices, Crypto Rand) — <https://go.dev/wiki/CodeReviewComments>

---
*Decomposition inspired by [`samber/cc-skills-golang`](https://github.com/samber/cc-skills-golang) (MIT © 2026 Samuel Berthe); rules grounded in the sources above.*
