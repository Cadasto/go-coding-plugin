---
name: go-testing
description: Idiomatic Go testing. This skill should be used when the user writes or reviews Go tests, benchmarks, or fuzz targets — table-driven tests, `t.Parallel`, `testing.B.Loop`, the race detector, goroutine-leak detection, `testing/synctest` for time/concurrency, fuzzing, or golden files. Pair with `go test -race`. Not for non-Go test frameworks; error-wrapping belongs to `go-errors`.
---

# go-testing — Go testing

Deterministic backstop: `go test -race ./...` (always, in CI), `go test -bench`, `go test -fuzz`.

## Rules

- **Table-driven tests:** a named-case slice + `t.Run(tc.name, func(t *testing.T){ … })`. Since Go
  1.22 the `tc := tc` copy is unnecessary — drop it (`modernize`/`copyloopvar` flag it).
- **`t.Parallel()`** on independent tests to cut wall-clock; watch for shared mutable state and
  loop-var capture in the parallel body.
- **Benchmarks: `for b.Loop() { … }`** (Go 1.24) — it handles timer reset and run scaling; replaces
  `for i := 0; i < b.N; i++` plus manual `b.ResetTimer()`.
- **`-race` is non-negotiable** for any code touching goroutines; wire it into CI.
- **Goroutine-leak detection:** `go.uber.org/goleak` — `goleak.VerifyTestMain(m)` or per-test
  `defer goleak.VerifyNone(t)`.
- **`testing/synctest` (stable since Go 1.25) is the default for time/concurrency tests** — timeouts,
  tickers, retries, `context` cancellation. It runs the bubble on a *fake clock* with deterministic
  scheduling, so "5-second" waits complete in microseconds and flakiness disappears. Wrap with
  `synctest.Test(t, func(t *testing.T){ … })`; `synctest.Wait()` blocks until every goroutine in the
  bubble is durably blocked. Reach for it instead of `time.Sleep`-based polling. (The pre-1.25
  `GOEXPERIMENT=synctest` API — `synctest.Run` — was removed in Go 1.26; use the stable `synctest.Test`.)
- **Fuzzing** (`func FuzzX(f *testing.F)`) for parsers, codecs, and anything consuming untrusted
  bytes. **Golden files** (an `-update` flag writing `testdata/*.golden`) for large structured output.
- **Deterministic crypto tests (Go 1.26):** `testing/cryptotest.SetGlobalRandom` pins a
  deterministic randomness source for the test's duration — reach for it instead of hand-injecting a
  custom `io.Reader` when testing code that draws from `crypto/rand`.
- **Assertions:** stdlib + small helpers (`t.Helper()`) is often enough; `testify` is fine — match
  the repo, don't mix styles.

## Sources
- synctest — <https://go.dev/blog/synctest>; `testing.B.Loop` — <https://go.dev/blog/testing-b-loop>
- `testing` package — <https://pkg.go.dev/testing>; Go 1.22/1.24/1.25/1.26 release notes — <https://go.dev/doc/go1.26>
- `testing/cryptotest` (Go 1.26) — <https://pkg.go.dev/testing/cryptotest>
- `go.uber.org/goleak` — <https://pkg.go.dev/go.uber.org/goleak>

---
*Decomposition inspired by [`samber/cc-skills-golang`](https://github.com/samber/cc-skills-golang) (MIT © 2026 Samuel Berthe); rules grounded in the sources above.*
