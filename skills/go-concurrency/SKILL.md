---
name: go-concurrency
description: Idiomatic, leak-free Go concurrency. This skill should be used when a diff or question contains go func, chan, select, sync.WaitGroup/Mutex/Once, atomic, errgroup, context.WithCancel/Timeout/Cause, a retry or backoff loop, a worker pool, per-request cancellation, or a Close on a goroutine-owned resource — goroutine lifetime and leaks, context propagation and cancel causes, work outliving a request, typed atomics, mutex misuse, data races. Pair with go test -race and goleak. Time-dependent tests belong to go-testing (synctest). Go only.
---

# go-concurrency — Go concurrency

Deterministic backstop: `go test -race ./...`, `go vet ./...` (catches copylocks, lost cancel),
and `go.uber.org/goleak`. The race detector is the source of truth — run it before reasoning.
The runtime also reports leaked goroutines itself: the `goroutineleak` profile (Go 1.27, no build
flag) — `pprof.Lookup("goroutineleak")`, or `/debug/pprof/goroutineleak` under `net/http/pprof`.
It finds goroutines blocked forever on a channel, a `select`, or a `sync` lock, `WaitGroup` or
`Cond`, with few false positives, but misses a leak whose channel or lock stays reachable from a
global or a running goroutine, and never counts I/O or syscalls. Keep `goleak` and `synctest` in
tests; the profile covers production, where they cannot. Collect it infrequently (every few hours —
a leak stays visible once it happens); each collection slows that garbage-collection cycle.

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
- **Make cancellation say *why*.** `ctx.Err()` only ever reports `context.Canceled` or
  `DeadlineExceeded`, which is useless for diagnosis when several budgets nest. Use
  `context.WithCancelCause` + `cancel(err)` (Go 1.20) and read `context.Cause(ctx)`, or
  `WithTimeoutCause`/`WithDeadlineCause` (1.21) so the expiring layer names itself. `errors.Is(err,
  context.Canceled)` keeps working — the cause rides alongside, it doesn't replace `Err()`.
- **Work that must outlive the request:** `context.WithoutCancel(ctx)` (Go 1.21) drops cancellation
  but keeps the values (trace, auth, request ID) — reach for it instead of `context.Background()`,
  which throws those away. Give the derived context its own timeout, and tie it to a shutdown path;
  "outlives the request" must not mean "outlives the process silently".
- **`context.AfterFunc(ctx, f)`** (Go 1.21) instead of a goroutine whose only job is to `select` on
  `ctx.Done()` and clean up; the returned `stop` unregisters it if the work finished first.
- **Don't copy `sync.Mutex`/`sync.WaitGroup` by value** (`go vet` copylocks). Guard shared maps —
  a concurrent map write panics; `-race` catches it.
- **Channels:** close on the *send* side, never the receive side; a `nil` channel blocks forever
  (useful for disabling a `select` arm, a bug everywhere else).
- **Prefer synchronous APIs.** Return the result; let the caller decide to run it in a goroutine. A
  function that spawns internally and hands back a channel — or takes a completion callback —
  imposes its concurrency model on every caller and hides the goroutine's lifetime, which is exactly
  where leaks come from.
- **Cleanup is explicit, never finalized.** Release resources in `Close`/`defer`. `runtime.AddCleanup`
  (Go 1.24, preferred over the older `runtime.SetFinalizer`: multiple cleanups per object, works on
  interior pointers, no leak on reference cycles) is a backstop for OS/native handles only — a
  cleanup may never run, so no correctness may depend on it.
- **Keep secrets out of goroutine labels.** On a module at Go 1.27 or later, a crash traceback prints
  each goroutine's `runtime/pprof` labels, so a label ends up wherever crash output goes. Label with
  classes (route, job kind, tenant tier), never tokens or personal data; `GODEBUG=tracebacklabels=0`
  turns the printing off.
- **Testing time/concurrency:** use **`testing/synctest`** (stable since Go 1.25) — fake clock +
  deterministic scheduling. See `go-testing`.

## Sources
- synctest — <https://go.dev/blog/synctest>; Go 1.25/1.26 release notes — <https://go.dev/doc/go1.26>
- `goroutineleak` profile (generally available in Go 1.27; limitations, cost) — <https://go.dev/blog/goroutine-leak-profiles>, <https://pkg.go.dev/runtime/pprof>; traceback labels — <https://go.dev/doc/go1.27>
- `context` (`Cause`, `WithoutCancel`, `AfterFunc`, `WithTimeoutCause`) — <https://pkg.go.dev/context>; `runtime.AddCleanup` — <https://pkg.go.dev/runtime#AddCleanup>
- Code Review Comments (Goroutine Lifetimes, Contexts, Synchronous Functions) — <https://go.dev/wiki/CodeReviewComments>
- Uber Go Style Guide (Concurrency) — <https://github.com/uber-go/guide>

---
*Decomposition inspired by [`samber/cc-skills-golang`](https://github.com/samber/cc-skills-golang) (MIT © 2026 Samuel Berthe); rules grounded in the sources above.*
