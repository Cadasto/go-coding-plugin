---
name: go-errors
description: Idiomatic Go error handling. This skill should be used when the user writes, reviews, or debugs Go error code — wrapping with `%w`, inspecting via `errors.Is`/`errors.AsType`, sentinel vs typed errors, `errors.Join`, unchecked `Close` errors, when panic is legitimate, enum-switch dispatch defaults, keeping payload values out of boundary errors/logs, or chasing a silently-swallowed or context-losing error. Pair with the `errorlint` linter (set it up via `go-linting`). Not for non-Go languages.
---

# go-errors — Go error handling

Deterministic backstop: `golangci-lint run --enable-only=errorlint`, plus `errcheck` (in the
`standard` set) for unchecked errors. Run the tool first; this skill is the judgment around it.

## Rules

- **Wrap with `%w` when the caller may need to inspect the cause** (Go 1.13):
  `return fmt.Errorf("read config %s: %w", path, err)`. Use `%v` *only* to deliberately sever the
  chain (e.g. to avoid leaking an internal error type across an API boundary) — and say so.
  Put `%w` **last** so the message reads outside-in; a leading `%w` is right only when the sentinel
  *is* the sentence: `fmt.Errorf("%w: %s", ErrNotFound, key)`.
- **The `%v`-where-`%w` trap:** formatting a cause with `%v` discards the chain, so downstream
  `errors.Is`/`errors.As` silently fail. `errorlint` flags it.
- **Inspect with `errors.Is` (sentinel) / `errors.As` (typed)** — never `err == ErrX` or a type
  assertion once any layer wraps, or you get *sentinel breakage* (the comparison silently stops
  matching). (Go 1.13; `errors.As` target must be a pointer.)
- **Prefer `errors.AsType[E]` over `errors.As`** (Go 1.26):
  `if perr, ok := errors.AsType[*fs.PathError](err); ok { … }`. It is the generic form —
  compile-time-checked target, no pointer to prepare, no reflection, and it cannot panic on a
  mistyped target the way `errors.As` can. `errors.As` is not deprecated, so existing call sites are
  not bugs; the `errorsastype` modernizer converts them (`go fix ./...`).
- **Sentinel errors** (`var ErrNotFound = errors.New("not found")`) for expected, comparable
  conditions that are part of your API contract — keep the set small and documented.
  **Typed errors** (a struct implementing `error`) when callers need fields (`*PathError`).
- **`errors.Join(err1, err2)`** (Go 1.20) to aggregate independent failures (cleanup, validation)
  — replaces manual concatenation and most third-party multierror use.
- **Never swallow:** no `_ = f()` on an error you care about; no empty `if err != nil {}`. Handle,
  wrap-and-return, or (deliberately, with a comment) ignore.
- **Check `Close` on anything written to.** `defer f.Close()` discards a failed flush — the write
  looks successful and the file is truncated. Capture it into a named result:
  `defer func() { err = errors.Join(err, f.Close()) }()`. `errcheck` flags the discarded form;
  read-only handles are the one safe place to drop it (say so with `_ =`).
- **Keep the happy path at minimal indentation** — handle the error and return early; no `else`
  after a terminating `if`. Error flow goes in the indented branch, business logic does not.
- **Don't panic across a package boundary.** Errors are the mechanism for anything a caller can
  plausibly hit; panic is for programmer error, API misuse, and genuinely unreachable states. If a
  package uses panic internally for unwinding, `recover` it inside that package and return an error
  — a panic must never escape into a caller.
- **Fail loudly on impossible dispatch:** a `switch` over an internal enum/kind gets a `default`
  that returns an error (panic only for the genuinely unreachable) — never a silent pass-through
  that lets a later-added member ride the weakest arm. Pin exhaustiveness with the `exhaustive`
  linter or a completeness test that iterates the enum.
- **Boundary errors carry classification, not payload:** upstream messages can embed data values —
  a database driver quoting the offending stored value, a validator echoing the request body. At a
  logging or API boundary, pass the stable class/code (e.g. SQLSTATE) and keep the raw message
  internal — the message-content analogue of severing an internal error *type* with `%v`.
- **Add context at each layer, log once at the boundary.** Wrapping at every level *and* logging at
  every level produces duplicate noise — return wrapped, log at the top.
- **Error strings:** lowercase, no trailing punctuation (they get wrapped): `"cannot parse %q"`.

## Sources
- Go 1.13 errors — <https://go.dev/blog/go1.13-errors>; `errors.AsType` (Go 1.26) — <https://pkg.go.dev/errors#AsType>
- Code Review Comments (Error Strings, Handle Errors, Indent Error Flow, Don't Panic) — <https://go.dev/wiki/CodeReviewComments>
- Google Go Style Guide (Error Handling, Panics, `%w` placement) — <https://google.github.io/styleguide/go/best-practices>
- Uber Go Style Guide (Errors) — <https://github.com/uber-go/guide>
- `os.File.Close` returns write errors — <https://pkg.go.dev/os#File.Close>

---
*Decomposition inspired by [`samber/cc-skills-golang`](https://github.com/samber/cc-skills-golang) (MIT © 2026 Samuel Berthe); rules grounded in the sources above.*
