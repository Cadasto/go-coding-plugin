---
name: go-concurrency
description: Idiomatic, leak-free Go concurrency. This skill should be used when the user writes or reviews Go goroutines, channels, `sync`/`atomic`, `context`, `errgroup`, or worker pools — goroutine lifetimes/leaks, context propagation, typed atomics, mutex misuse, or data races. Pair with `go test -race`, `go vet`, and `goleak`. Defers time/concurrency *testing* mechanics to `go-testing` (synctest). Not for non-Go languages.
---

# go-concurrency — Go concurrency

Deterministic backstop: `go test -race ./...`, `go vet ./...` (catches copylocks, lost cancel),
and `go.uber.org/goleak`. The race detector is the source of truth — run it before reasoning.
On **Go 1.26+** the runtime also ships an experimental `goroutineleak` profile in `runtime/pprof`
that reports leaked goroutines — a toolchain-native complement to `goleak` for leak hunts (enable it
with `GOEXPERIMENT=goroutineleakprofile` at build time).

## Rules

- **Every goroutine needs a known lifetime.** Tie it to a `context` or a done signal. A goroutine
  that can block forever on a channel send/recv after its reader has returned is a leak — the
  single most common Go concurrency bug.
- **Prefer `wg.Go(func(){ … })`** (Go 1.25) over `wg.Add(1); go func(){ defer wg.Done() }()` — it
  removes the Add/Done-mismatch footgun.
- **For groups that can fail, use `golang.org/x/sync/errgroup`:** the first non-nil error cancels
  the group's derived context; `g.SetLimit(n)` bounds concurrency. Don't hand-roll error+WaitGroup
  plumbing.
- **Typed atomics** (Go 1.19): `atomic.Int64`, `atomic.Bool`, `atomic.Pointer[T]` — not
  `atomic.AddInt64(&x, …)` on a bare int. Typed forms are self-documenting and can't be read
  non-atomically by accident.
- **Context discipline:** pass `ctx context.Context` as the first parameter; **never store it in a
  struct** (`containedctx`); don't reach for `context.Background()` deep in a call stack — thread
  the caller's ctx. HTTP/SQL/RPC calls must carry it (`noctx`), and set a client timeout.
- **Don't copy `sync.Mutex`/`sync.WaitGroup` by value** (`go vet` copylocks). Guard shared maps —
  a concurrent map write panics; `-race` catches it.
- **Channels:** close on the *send* side, never the receive side; a `nil` channel blocks forever
  (useful for disabling a `select` arm, a bug everywhere else).
- **Testing time/concurrency:** use **`testing/synctest`** (stable since Go 1.25) — fake clock +
  deterministic scheduling. See `go-testing`.

## Sources
- synctest — <https://go.dev/blog/synctest>; Go 1.25/1.26 release notes — <https://go.dev/doc/go1.26>
- `goroutineleak` profile (Go 1.26, experimental) — <https://pkg.go.dev/runtime/pprof>
- Code Review Comments (Goroutine Lifetimes, Contexts) — <https://go.dev/wiki/CodeReviewComments>
- Uber Go Style Guide (Concurrency) — <https://github.com/uber-go/guide>

---
*Decomposition inspired by [`samber/cc-skills-golang`](https://github.com/samber/cc-skills-golang) (MIT © 2026 Samuel Berthe); rules grounded in the sources above.*
