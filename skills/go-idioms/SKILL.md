---
name: go-idioms
description: Modern idiomatic Go (`modernize`), Go 1.27+. This skill should be used when a diff has a rewritable construct, when the user asks to modernize Go, run `go fix`, or which fixer owns a rewrite (range-over-int, `min`/`max`, `slices`/`maps`, `strings.Cut`/`CutLast`, `omitzero`, `new(expr)`, `errors.AsType`), or when code could use a newer standard form no fixer applies (generic methods, `encoding/json/v2`, `uuid`, `os.Root`), a shadowed `err`, or a dead `break`. Not for linter configuration (go-lint-setup). Go only.
---

# go-idioms — modern Go (modernize)

**Advice == tooling.** The `modernize` analyzers flag and usually auto-fix most of what follows — the
**Fixer** column says which, and the last section covers what no fixer automates. Run the tool,
don't hand-audit. The `go fix` rewritten in Go 1.26 is the canonical runner — it ships the
modernizer suite in the toolchain itself:

```
go fix -diff ./...                                  # preview the rewrite as a unified diff (clean tree first)
go fix ./...                                        # apply; -<fixer> runs one, -<fixer>=false excludes one
golangci-lint run --enable-only=modernize --fix     # the same x/tools suite, at golangci-lint's pinned snapshot
```

Both draw on the same `golang.org/x/tools` engine as gopls; golangci-lint pins its own, often newer,
snapshot, so it can offer a rewrite before the toolchain's `go fix` does. On the **Go 1.27+**
baseline every row applies as written. The `Since` column is provenance: a module whose `go`
directive is older skips the rows newer than it, and the tools hold that line — `go fix` offers
only rewrites the directive allows, and `go vet`'s `stdversion` check (run by `go test` from Go
1.27) flags a standard-library symbol newer than the directive.

## Prefer → over (since)

The **Fixer** column names the analyzer that owns each rewrite: plain = registered in the Go 1.27
toolchain's `go fix` (ground truth: `go tool fix help`; per-fixer docs: `go tool fix help <name>`);
**†** = only in the newer x/tools suite (golangci-lint's `modernize`, gopls), not yet in the
toolchain's `go fix` (no row needs it at present); `—` = no fixer: review or a linter has to catch it.

| Prefer | Over | Since | Fixer |
|---|---|---|---|
| `new(expr)` — e.g. `Field: new(30)`, `new(int64(req.Limit))` | a `ptr[T](v)` helper or a hand-written `tmp := v; &tmp`, for optional/pointer fields | 1.26 | `newexpr` |
| `errors.AsType[E](err)` | `errors.As(err, &target)` → `go-errors` | 1.26 | `errorsastype` |
| `for i := range n` | `for i := 0; i < n; i++` | 1.22 | `rangeint` |
| `min(a, b)` / `max(a, b)` builtins | hand-rolled helpers | 1.21 | `minmax` |
| *(drop)* `x := x` loop-var copy | pre-1.22 capture workaround | 1.22 | `forvar` |
| `any` | `interface{}` | 1.18 | `any` |
| `slices.Sort/Contains`, `slices.Collect`, `maps.Keys` | hand-rolled sort/contains/map loops | 1.21–1.23 | `slicescontains`, `slicessort`, `mapsloop` |
| `for i, v := range slices.Backward(s)` | `for i := len(s)-1; i >= 0; i--` | 1.23 | `slicesbackward` |
| `strings.Cut` / `CutPrefix` / `CutSuffix` | `Index` + manual slicing | 1.18/1.20 | `stringscut`, `stringscutprefix` |
| `strings.CutLast` / `bytes.CutLast` | `LastIndex` + manual slicing | 1.27 | `stringscut` through golangci-lint for now; the 1.27 toolchain's fixer rewrites `Index` only |
| `strings.SplitSeq` / `FieldsSeq` | ranging over `strings.Split`/`Fields` (allocates a slice) | 1.24 | `stringsseq` |
| `fmt.Fprintf(w, …)` when the bytes go to a writer; `fmt.Appendf(b, …)` to append to a buffer you already have | `w.Write([]byte(fmt.Sprintf(…)))`; `append(b, fmt.Sprintf(…)...)`. Go 1.27 removed the `fmtappendf` fixer: its `fmt.Appendf(nil, …)` rewrite was rarely the clearer form | 1.19 | — (staticcheck QF1012, standard set, flags the `Write` form) |
| `omitzero` on a struct-typed json field, and instead of `omitempty` on a bool, number, pointer or interface field | `omitempty`, which does **nothing** for struct fields (a zero `time.Time` still marshals) and which v2 redefines by the JSON value; `omitzero` means the same in v1 and v2. Check a type with an `IsZero` method first: `omitzero` calls it, so a non-nil `*time.Time` at the zero time is dropped | 1.24 | `omitzero` (struct-typed fields only) |
| `t.Context()` in tests | `context.WithCancel(context.Background())` → `go-testing` | 1.24 | `testingcontext` |
| `reflect.TypeFor[T]()` | `reflect.TypeOf((*T)(nil)).Elem()` | 1.22 | `reflecttypefor` |
| `cmp.Or(a, b, …)` | nested `if x == "" { x = y }` | 1.22 | — |
| `sync.OnceFunc` / `OnceValue` | `sync.Once` + a captured var | 1.21 | — |
| `iter.Seq[V]` / range-over-func | `Visit(callback)` patterns, exposing slices | 1.23 | `stditerators` |
| `slog.LogAttrs(ctx, lvl, msg, attrs…)` on hot paths | key-value variadic `slog` (allocates) | 1.21 | — |
| `errors.Join` | manual multi-error concat → `go-errors` | 1.20 | — |
| `wg.Go(...)` | `wg.Add(1)`/`defer wg.Done()` → `go-concurrency` | 1.25 | `waitgroupgo` |
| `for b.Loop()` | `for i := 0; i < b.N; i++` → `go-testing`; convert by hand, the automatic rewrite was withdrawn | 1.24 | — |
| typed `atomic.Int64` | bare-int `atomic.Add*` → `go-concurrency` | 1.19 | `atomictypes` |
| `T{x: 1}` — a field promoted from an embedded struct keyed directly | `T{U: U{x: 1}}`, the nested literal the embedded struct used to need | 1.27 | `embedlit` |
| `unsafe.Add(ptr, n)` | `unsafe.Pointer(uintptr(ptr) + uintptr(n))` | 1.17 | `unsafefuncs` |

## Modern, but no fixer automates it

- **Generic methods** (1.27): a method may declare its own type parameters —
  `func (l List[E]) Map[R any](f func(E) R) List[R]`. Put a generic operation on the type it
  belongs to instead of a package-level `MapList(l, f)`: the package scope stays uncrowded and calls
  chain left to right. A generic method never satisfies an interface method (interfaces cannot
  declare type parameters), so it organises code; it does not implement contracts. Function type
  inference also reaches composite literals, conversions and channel sends from 1.27, so an explicit
  `F[int]` whose target type already fixes the argument can go.
- **Self-referential constraints** (1.26): a generic type may reference itself in its own
  type-parameter list (`type Adder[A Adder[A]] interface{ Add(A) A }`), so the old workaround is no
  longer needed.
- **`encoding/json/v2` for new code** (1.27): the Go JSON tutorial now teaches it — `Options` per
  call, `MarshalWrite`/`UnmarshalRead` that stream without an intermediate `[]byte`, and stricter
  defaults (invalid UTF-8 and duplicate names rejected, case-sensitive field matching, a nil slice or
  map marshals as `[]`/`{}`); `encoding/json/jsontext` is the token-level layer beneath it. **Keep
  v1 in existing code**: it now runs on the v2 implementation with v1 behaviour (only error text may
  change), unmarshals faster for free, and stays supported — moving a package to v2 changes its wire
  behaviour, so it is a reviewed change, not a rename. If v1 output does shift after the upgrade,
  `GOEXPERIMENT=nojsonv2` at build time restores the old implementation while it is fixed (the
  opt-out is due to be removed). Code written against the 1.25/1.26 `GOEXPERIMENT=jsonv2` preview
  needs updating: the `inline` tag option is now `embed`; the `format` and `unknown` tag options, the
  `DiscardUnknownMembers` option and the `SkipFunc` error are gone; the `string` tag option and
  `MatchCaseInsensitiveNames` changed behaviour; full list in the release notes.
- **`uuid` from the standard library** (1.27) for new code, instead of a third-party UUID module:
  `uuid.New()` (version 4 today) for most IDs, `uuid.NewV7()` when keys should sort by creation time
  (database indexes), `uuid.Parse` for input. `uuid.MustParse` follows `go-errors`' `Must` rule:
  constants only, never input. Replacing an existing third-party UUID type at an API boundary is a
  deliberate change, not a cleanup.
- **Close an HTTP response body; don't drain it** (1.27). `net/http`'s `Transport` now drains an
  unread HTTP/1 body in the background on `Close` (up to 256 KB or 50 ms), so a hand-written
  `io.Copy(io.Discard, resp.Body)` before `Close` is redundant, and an unbounded one can cost more
  than a new connection; the Go team's advice is `defer resp.Body.Close()` and nothing more. HTTP/2
  never needed the drain.
- **`url.Values.Clone` and `(*url.URL).Clone`** (1.27) for a copy you will change:
  `maps.Clone(values)` shares each key's value slice with the original.
- **`os.OpenRoot(dir)` → `*os.Root`** (1.24) for anything that opens a caller-supplied path: its
  methods cannot escape the directory, including via symlink. Replaces `filepath.Join` plus
  hand-written `..`/prefix checks — the traversal-bug pattern those checks keep getting wrong.
- **`rand.Text()`** from `crypto/rand` (1.24) for tokens, nonces, and IDs — not `math/rand`, and not
  a hand-rolled base64 of `rand.Read`. Security-sensitive randomness always comes from `crypto/rand`.
- **`var s []T`, not `s := []T{}`** — the nil slice is the idiomatic empty slice (append works,
  `len` is 0). Reach for the non-nil literal only when something genuinely distinguishes them
  (e.g. marshalling `[]` vs `null` with v1 `encoding/json`).
- **`slices.Sorted(maps.Keys(m))`** (1.23) when iterating a map for output — map order is random, and
  unstable output is a flaky-test and noisy-diff source.
- **A nested `:=` can shadow `err` or `ctx`.** `if v, err := f(); err != nil { … }` inside a function
  that already has an `err` declares a second one; the outer stays nil and a later `return err`
  reports success. Use `=` to assign into the existing variable, or give the inner one another name.
  Nothing in the standard set reports this; the `shadow` analyzer from `golang.org/x/tools` does
  when enabled (in golangci-lint: `linters.settings.govet.enable: [shadow]`) — it is noisy on
  legitimate reuse, so a repo enables it deliberately rather than by default.
- **No `break` at the end of a `switch` case.** Go cases do not fall through, so a `break` as the
  last statement of a case is dead text; `staticcheck` S1023 (standard set) flags exactly that.
  Earlier in a case a `break` still does work — it leaves the `switch` from that point — and a
  labelled `break` leaves the enclosing loop instead; neither of those is dead text.

## Sources
- `modernize` (per-fixer docs, the Fixer column) — <https://pkg.go.dev/golang.org/x/tools/go/analysis/passes/modernize>; withdrawn fixers: `fmtappendf` — <https://go.dev/issue/77581>, `bloop` — <https://go.dev/issue/74967>
- `go fix` (rewritten in 1.26) — <https://go.dev/blog/gofix>; range-over-func — <https://go.dev/blog/range-functions>
- `slog` — <https://go.dev/blog/slog>; Go 1.21–1.26 release notes (`new(expr)`, self-ref generics — <https://go.dev/doc/go1.26>)
- `os.Root` / `omitzero` / `rand.Text` — <https://go.dev/doc/go1.24>; Code Review Comments (Declaring Empty Slices, Crypto Rand) — <https://go.dev/wiki/CodeReviewComments>
- Go 1.27 release notes (generic methods, type inference, promoted-field keys, `go fix` changes, `stdversion`, `encoding/json/v2`, `uuid`, `CutLast`, `net/url` `Clone`) — <https://go.dev/doc/go1.27>; Generic methods — <https://go.dev/blog/generic-methods>; HTTP/1 connection reuse — <https://go.dev/blog/http-connection-reuse>
- JSON tutorial (v2) — <https://go.dev/doc/tutorial/json>; v1 → v2 differences — <https://pkg.go.dev/encoding/json#hdr-Migrating_to_v2>; `uuid` — <https://pkg.go.dev/uuid>
- Google Go Style Decisions (Switch and break, Nil slices) — <https://google.github.io/styleguide/go/decisions>; Best Practices (Shadowing) — <https://google.github.io/styleguide/go/best-practices>; staticcheck S1023 — <https://staticcheck.dev/docs/checks/#S1023>, QF1012 — <https://staticcheck.dev/docs/checks/#QF1012>; `shadow` analyzer — <https://pkg.go.dev/golang.org/x/tools/go/analysis/passes/shadow>

---
*Decomposition inspired by [`samber/cc-skills-golang`](https://github.com/samber/cc-skills-golang) (MIT © 2026 Samuel Berthe); rules grounded in the sources above.*
