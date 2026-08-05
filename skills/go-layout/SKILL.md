---
name: go-layout
description: Go project layout, naming, and API-surface design. This skill should be used when the user structures a Go module, names things, or shapes an exported API — `internal/`, `cmd/`, start-flat-then-grow, package/variable/receiver naming, initialism casing (`userID`, `HTTPServer`), pointer vs value receivers, in-band errors, named results, option structs vs variadic options, returning concrete types, or writing doc comments. Counters imported Java/C# structure. Not for build tooling or non-layout idioms (→ `go-idioms`).
---

# go-layout — layout, naming & API surface

The Go community consensus is *minimalism*; resist imported ceremony. Naming and the shape of an
exported signature are part of the API — they are as reviewable as the code.

## Layout

- **`internal/` is the one true consensus.** Packages under `internal/` cannot be imported from
  outside the module subtree — use it to keep implementation private while exporting a small surface.
- **Start flat; grow as needed.** A new module is often one package at the root. Add
  `cmd/<binary>/main.go` when there are multiple binaries and `internal/<pkg>/` when privacy is needed
  — not before. `golang-standards/project-layout` is community-made, **explicitly not official and
  contested**; don't treat its deep tree as a starting requirement.
- **No Java/C# transplants:** no `*Manager`/`*Impl`/`*Factory` reflexes, no one-type-per-file rule,
  no interface-for-everything.
- **Hexagonal / ports-and-adapters / DDD is a tool, not a default** — justified for larger services
  with real external-boundary complexity, overkill for a CLI or a small service.
- **`main` owns process exit.** Call `os.Exit`/`log.Fatal` only in `main` (ideally once, on the
  error from a `run() error` function); everything else returns errors. A deep `log.Fatal` skips
  deferred cleanup and makes the code path untestable. Same discipline for `init()`: only cheap,
  deterministic setup — no I/O, no environment reads, no mutating global state; anything more is an
  explicit constructor called from `main`.
- **Files:** one package per directory; `package foo` for `foo.go` + `foo_test.go`; use
  `package foo_test` for black-box tests that exercise only the exported API.

## Naming

- **Package names are part of the call site:** short, lowercase, single word, no underscores or
  camelCase. The caller writes `chi.NewRouter()`, so don't stutter (`chi.ChiRouter`,
  `bytes.BufferWrite`). Avoid `util`, `common`, `helpers`, `base` grab-bags — name by what the
  package *provides*.
- **`MixedCaps`, never `MAX_LENGTH` or `snake_case`** — including constants, whatever the convention
  was in the language this code came from.
- **Initialisms keep a single case throughout:** `userID`, `parseURL`, `HTTPServer`, `ServeHTTP` —
  never `userId`, `HttpServer`. Mixed casing within one identifier is the tell of a translated name.
- **Name length tracks scope.** `i`, `r`, `buf` are correct in a five-line body; anything
  package-level, long-lived, or used far from its declaration earns a descriptive name. Longer is not
  better — `idx` beats `theCurrentIndexIntoTheSlice`.
- **Receiver names are a one- or two-letter abbreviation of the type** (`c *Client`, `srv *Server`),
  identical across every method on that type. Never `self`, `this`, or `me`.
- **No `Get` prefix on accessors:** `u.Name()`, paired with `u.SetName(…)`. A verb-like name is for
  something that acts; a noun-like name for something that returns a value.
- **Test doubles live in a `<pkg>test` package** and are named for behaviour, not mechanism —
  `AlwaysDeclines`, not `MockCardProcessorImpl2`.

## Signatures & API surface

- **Receiver type:** pointer when the method mutates, when the receiver is large, or when the type
  holds a `sync` field (copying a lock is a bug — `go vet` copylocks). Value receivers for small
  immutable types. **Be consistent within a type** — don't mix pointer and value receivers.
- **Pass small fixed-size values directly.** `*int` to "avoid a copy" trades a machine word for an
  indirection plus aliasing risk.
- **No in-band errors.** Return `(T, error)` or `(T, bool)` — never `-1`, `""`, or a `nil` that means
  failure. A caller can forget to compare against a magic value; a second return value is harder to
  ignore, and `errcheck` sees it.
- **Named results only when they add information** the types don't (`(n int, err error)`), or when a
  deferred closure must assign to them (the `Close`-into-`err` idiom in `go-errors`). Bare `return`
  belongs only in short functions.
- **Two option styles, chosen by how often callers pass options:** an **option struct** as the final
  parameter when most callers set at least one field (self-documenting, grows compatibly); **variadic
  functional options** when most callers pass none. Don't erect a functional-options framework around
  two booleans.
- **Accept interfaces, return concrete types.** Define an interface in the package that *consumes*
  it, keep it to a method or three, and return the concrete type so callers get the full surface and
  new methods don't break them.
- **Prefer synchronous signatures** — let the caller add concurrency (→ `go-concurrency`).
- **Make the zero value useful where possible** (`bytes.Buffer`, `sync.Mutex` need no constructor). If
  a type genuinely requires a `New…`, the doc comment must say so.

## Doc comments

- **Every exported identifier gets one, as a full sentence starting with the name:**
  `// Serve accepts incoming connections on the listener.` That phrasing is what makes `go doc`
  output and grep both work.
- **Package comment sits directly above `package x`** with no blank line, exactly one per package,
  opening `// Package x …`.
- **`gofmt` formats doc comments** (since Go 1.19) — lists, headings, indented code blocks, and
  `[Name]`/`[pkg.Name]` doc links. Write that syntax and let the tool lay it out.
- **Document what the signature can't say:** concurrency safety, who owns and must close a returned
  resource, whether cancellation leaves partial work behind, and which errors callers can branch on.
  Don't restate parameter names.
- **Retire an exported name with a `Deprecated:` paragraph**, not by deleting it.

## Sources
- Effective Go — <https://go.dev/doc/effective_go>
- Code Review Comments (Package/Variable/Receiver Names, Initialisms, Mixed Caps, In-Band Errors, Named Result Parameters, Pass Values, Interfaces, Doc Comments) — <https://go.dev/wiki/CodeReviewComments>
- Google Go Style Guide (naming, option structs, documentation, test doubles, program initialization) — <https://google.github.io/styleguide/go/best-practices>
- Uber Go Style Guide (Exit in Main, Avoid init()) — <https://github.com/uber-go/guide>
- Doc comment syntax — <https://go.dev/doc/comment>; `internal/` — <https://pkg.go.dev/cmd/go#hdr-Internal_Directories>

---
*Decomposition inspired by [`samber/cc-skills-golang`](https://github.com/samber/cc-skills-golang) (MIT © 2026 Samuel Berthe); rules grounded in the sources above.*
