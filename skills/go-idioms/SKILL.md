---
name: go-idioms
description: Modern idiomatic Go (the `modernize` analyzer set) — Go 1.26+, with Go 1.27 additions noted. This skill should be used when the user writes, reviews, or modernizes Go and wants current-version idioms — range-over-int, `min`/`max`, `slices`/`maps`, `strings.Cut`, `any` over `interface{}`, iterators, `omitzero` json tags, `os.Root`, `new(expr)` and `errors.AsType` (Go 1.26), dropped loop-var copies, or Go 1.27 additions (generic methods, json/v2-backed `encoding/json`, the `atomictypes`/`embedlit`/`slicesbackward`/`unsafefuncs` go fix modernizers) — or asks which modernize fixer owns a rewrite. Framed so advice equals tooling (`go fix ./...`, or `golangci-lint --enable-only=modernize`). Not for golangci-lint configuration (use `go-lint-setup`) or non-Go languages.
---

# go-idioms — modern Go (modernize)

**Advice == tooling.** The `modernize` analyzers flag and usually auto-fix most of what follows — the
**Fixer** column says which, and the last section covers what no fixer automates. Run the tool,
don't hand-audit. As of **Go 1.26** the rewritten `go fix` is the canonical runner — it ships the
modernizer suite in the toolchain itself:

```
go fix -diff ./...                                  # preview the rewrite as a unified diff (clean tree first)
go fix ./...                                        # apply; -<fixer> runs one, -<fixer>=false excludes one
golangci-lint run --enable-only=modernize --fix     # the x/tools modernize suite — includes the † fixers below
```

Both draw on the same `golang.org/x/tools` engine as gopls, but golangci-lint pins its own (usually
newer) snapshot of it — that gap is what the **†** marker below tracks. This skill explains *why*
and catches what review notices before the tool runs. The **baseline is Go 1.26.4+** (Go 1.27 is
supported too; its additions are flagged as hints in **Newer in Go 1.27** below), so every row
below applies as written — the `Since` column is provenance: it explains why older code looks
different, and what an older module would have to bump to before adopting the idiom.

## Prefer → over (since)

The **Fixer** column names the analyzer that owns each rewrite. Plain = registered in the Go 1.26.4
toolchain's `go fix` (ground truth: `go tool fix help`; per-fixer docs: `go tool fix help <name>`).
**†** = only in the newer `x/tools` suite so far — golangci-lint's `modernize` and gopls run it, the
1.26.4 toolchain's `go fix` does not. `—` = no fixer exists: review has to catch it. Two † rows
below (`atomictypes`, `slicesbackward`) graduate into the stock `go fix` on Go 1.27 — see
**Newer in Go 1.27** below rather than reading that as a change to this table.

| Prefer | Over | Since | Fixer |
|---|---|---|---|
| `new(expr)` — e.g. `Field: new(30)`, `new(int64(req.Limit))` | a `ptr[T](v)` helper or a hand-written `tmp := v; &tmp`, for optional/pointer fields | 1.26 | `newexpr` |
| `errors.AsType[E](err)` | `errors.As(err, &target)` → `go-errors` | 1.26 | `errorsastype` † |
| `for i := range n` | `for i := 0; i < n; i++` | 1.22 | `rangeint` |
| `min(a, b)` / `max(a, b)` builtins | hand-rolled helpers | 1.21 | `minmax` |
| *(drop)* `x := x` loop-var copy | pre-1.22 capture workaround | 1.22 | `forvar` |
| `any` | `interface{}` | 1.18 | `any` |
| `slices.Sort/Contains`, `slices.Collect`, `maps.Keys` | hand-rolled sort/contains/map loops | 1.21–1.23 | `slicescontains`, `slicessort`, `mapsloop` |
| `for i, v := range slices.Backward(s)` | `for i := len(s)-1; i >= 0; i--` | 1.23 | `slicesbackward` † |
| `strings.Cut` / `CutPrefix` / `CutSuffix` | `Index` + manual slicing | 1.18/1.20 | `stringscut`, `stringscutprefix` |
| `strings.SplitSeq` / `FieldsSeq` | ranging over `strings.Split`/`Fields` (allocates a slice) | 1.24 | `stringsseq` |
| `fmt.Appendf(b, …)` | `append(b, fmt.Sprintf(…)...)` / `[]byte(fmt.Sprintf(…))` | 1.19 | `fmtappendf` |
| `omitzero` on a struct-typed json field | `omitempty`, which does **nothing** for struct fields — a zero `time.Time` still marshals | 1.24 | `omitzero` |
| `t.Context()` in tests | `context.WithCancel(context.Background())` → `go-testing` | 1.24 | `testingcontext` |
| `reflect.TypeFor[T]()` | `reflect.TypeOf((*T)(nil)).Elem()` | 1.22 | `reflecttypefor` |
| `cmp.Or(a, b, …)` | nested `if x == "" { x = y }` | 1.22 | — |
| `sync.OnceFunc` / `OnceValue` | `sync.Once` + a captured var | 1.21 | — |
| `iter.Seq[V]` / range-over-func | `Visit(callback)` patterns, exposing slices | 1.23 | `stditerators` |
| `slog.LogAttrs(ctx, lvl, msg, attrs…)` on hot paths | key-value variadic `slog` (allocates) | 1.21 | — |
| `errors.Join` | manual multi-error concat → `go-errors` | 1.20 | — |
| `wg.Go(...)` | `wg.Add(1)`/`defer wg.Done()` → `go-concurrency` | 1.25 | `waitgroup` |
| `for b.Loop()` | `for i := 0; i < b.N; i++` → `go-testing` | 1.24 | `bloop` † |
| typed `atomic.Int64` | bare-int `atomic.Add*` → `go-concurrency` | 1.19 | `atomictypes` † |

Idioms are a moving target — let the tool (pinned to the repo's toolchain) be the source of
truth so advice never drifts from the user's `go fix`. Go 1.26 also lifts the ban on a generic type
referencing itself in its own type-parameter list (e.g. `type Adder[A Adder[A]] interface{ Add(A) A }`),
so self-referential constraints no longer need a workaround — but that's a hand-written pattern, not
something a modernizer rewrites.

## Modern, but no fixer automates it

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

*Go 1.27 (released 2026-08-19) graduates several † fixers into the toolchain's `go fix`
(`atomictypes`, `slicesbackward`, plus new `embedlit` and `unsafefuncs`), renames `waitgroup` →
`waitgroupgo`, and drops `fmtappendf`; it also lands `encoding/json/v2` + `encoding/json/jsontext`
(v1 is reimplemented on v2, opt out with `GOEXPERIMENT=nojsonv2`) and `strings.CutLast`/`bytes.CutLast`.
See **Newer in Go 1.27** below for the hints these enable — none of it is required on the 1.26 floor.*

## Newer in Go 1.27 (hints, not requirements)

Go 1.27 is additive over 1.26 — every 1.26 rule above still applies unchanged, and nothing here is
required while a module's `go` directive stays at 1.26. Once a repo's toolchain (and `go` directive)
moves to 1.27, these are worth reaching for — phrased as "available from 1.27" / "prefer … once on
1.27", never as a requirement.

| Idiom (available from 1.27) | Supersedes / complements | Fixer / linter | Since | Source |
|---|---|---|---|---|
| Generic methods — a method may declare its own type parameters | a package-level generic helper function bound to the receiver type as a workaround for "methods can't be generic" | — | 1.27 | [go.dev/doc/go1.27](https://go.dev/doc/go1.27) |
| Prefer `encoding/json/v2` + `jsontext` for new/hot JSON paths once on 1.27 | v1 `encoding/json` (still works unchanged; only exact error-message text may shift) | — | 1.27 | [go.dev/doc/go1.27](https://go.dev/doc/go1.27) |
| `atomictypes` — graduates into the stock `go fix` (previously † golangci-lint-only, row above) | raw `sync/atomic` functions | `atomictypes` | 1.27 | [go.dev/doc/go1.27](https://go.dev/doc/go1.27) |
| `slicesbackward` — graduates into the stock `go fix` (previously † golangci-lint-only, row above) | `for i := len(s)-1; i >= 0; i--` | `slicesbackward` | 1.27 | [go.dev/doc/go1.27](https://go.dev/doc/go1.27) |
| `embedlit` — folds a field assignment right after a composite literal into the literal | `t := T{}; t.Field = v` builder pattern | `embedlit` | 1.27 | [go.dev/doc/go1.27](https://go.dev/doc/go1.27) |

- **`go test` now runs the `stdversion` vet check by default** (available from 1.27): it flags use of
  stdlib symbols newer than the module's `go` directive — the guardrail that keeps a 1.26-floor
  module from silently depending on a 1.27-only symbol. Trust it over manual review for this. Source:
  [go.dev/doc/go1.27](https://go.dev/doc/go1.27).

## Sources
- `modernize` (per-fixer docs, the Fixer column) — <https://pkg.go.dev/golang.org/x/tools/go/analysis/passes/modernize>
- `go fix` (rewritten in 1.26) — <https://go.dev/blog/gofix>; range-over-func — <https://go.dev/blog/range-functions>
- `slog` — <https://go.dev/blog/slog>; Go 1.21–1.26 release notes (`new(expr)`, self-ref generics — <https://go.dev/doc/go1.26>)
- `os.Root` / `omitzero` / `rand.Text` — <https://go.dev/doc/go1.24>; Code Review Comments (Declaring Empty Slices, Crypto Rand) — <https://go.dev/wiki/CodeReviewComments>
- Go 1.27 release notes (generic methods, `stdversion`, `encoding/json/v2`, new `go fix` modernizers) — <https://go.dev/doc/go1.27>
- `atomictypes` / `slicesbackward` / `embedlit` modernizer commits — <https://github.com/golang/tools/commit/17ee9acf0e54b52b93b8250245ea261f5e4a88ec>, <https://github.com/golang/tools/commit/b96d2a55a08943af1de2914a59fb88fe0acbb897>, <https://github.com/golang/tools/commit/c2a9c879aa8aea10399b942692b75107790bbcd7>

---
*Decomposition inspired by [`samber/cc-skills-golang`](https://github.com/samber/cc-skills-golang) (MIT © 2026 Samuel Berthe); rules grounded in the sources above.*
