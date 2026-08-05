---
name: go-testing
description: Idiomatic Go testing. This skill should be used when the user writes or reviews Go tests, benchmarks, or fuzz targets — table-driven tests, `t.Parallel` (and what cannot run under it), `t.Context`, `t.Chdir`/`t.Setenv`, `t.TempDir` vs `t.ArtifactDir`, `t.Output`, `testing.B.Loop`, the race detector, goroutine-leak detection, `testing/synctest` for time/concurrency, fuzzing, golden files, or writing failure messages that actually diagnose. Pair with `go test -race`. Not for non-Go test frameworks; error-wrapping belongs to `go-errors`.
---

# go-testing — Go testing

Deterministic backstop: `go test -race ./...` (always, in CI), `go test -bench`, `go test -fuzz`.

## Rules

- **Table-driven tests:** a named-case slice + `t.Run(tc.name, func(t *testing.T){ … })`. Since Go
  1.22 the `tc := tc` copy is unnecessary — drop it (`modernize`/`copyloopvar` flag it).
- **`t.Parallel()`** on independent tests to cut wall-clock; watch for shared mutable state and
  loop-var capture in the parallel body.
- **Process-global helpers are incompatible with `t.Parallel()`** — `t.Setenv` (Go 1.17), `t.Chdir`
  (1.24), and `cryptotest.SetGlobalRandom` (1.26) all mutate process state, so they fail in a
  parallel test *or one with a parallel ancestor*. A table whose cases need env or cwd stays serial;
  pass config explicitly instead where you can. The `usetesting` linter pushes `os.Setenv`/`os.Chdir`
  in tests towards the `t.*` forms (which restore state via `Cleanup`).
- **`t.Context()`** (Go 1.24) for any test needing a `ctx` — it is cancelled just before the test's
  `Cleanup` functions run, so goroutines under test shut down before teardown asserts on them. Use
  it over `context.Background()`; the `testingcontext` modernizer rewrites the old form. Do *not*
  use it for a fixture whose lifetime spans tests (a shared server or container started in
  `TestMain`) — that needs its own context.
- **`t.TempDir()` for scratch, `t.ArtifactDir()` (Go 1.26) for evidence.** `TempDir` is removed at
  test end; `ArtifactDir` gives each test a unique directory for output files worth keeping —
  rendered output, protocol dumps, failure snapshots — retained when `go test -artifacts` is passed.
  Don't hand-roll paths under `os.TempDir()`.
- **`t.Output()` (Go 1.25) is an `io.Writer` into the test log** — wire a `slog` handler or a
  subprocess's stdout into it so output interleaves correctly with `t.Log` under `-race` and
  parallel tests, instead of `fmt.Println` escaping to raw stdout. `t.Attr` (1.25) emits structured
  key/value metadata into `go test -json` output.
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
  *Go 1.27 (draft, expected Aug 2026) adds `synctest.Sleep` (`time.Sleep` + `Wait` in one) and
  `httptest.NewTestServer`, an in-memory server usable inside a bubble.*
- **Fuzzing** (`func FuzzX(f *testing.F)`) for parsers, codecs, and anything consuming untrusted
  bytes. **Golden files** (an `-update` flag writing `testdata/*.golden`) for large structured output.
  A golden pins *shape*, not behaviour — when it records something another system executes (SQL,
  wire requests, rendered configs), pair it with at least one test that executes the artefact for
  real; a snapshot can be stable and wrong.
- **Deterministic crypto tests (Go 1.26):** `testing/cryptotest.SetGlobalRandom(t, seed)` pins a
  deterministic randomness source for the test's duration — reach for it instead of hand-injecting a
  custom `io.Reader` when testing code that draws from `crypto/rand`. It's process-global, so it
  can't run inside a `t.Parallel()` test (or one with a parallel ancestor).
- **Failure messages must diagnose without a debugger:** name the call, the input, the result, and
  the expectation — `t.Errorf("Parse(%q) = %v, want %v", in, got, want)` — never a bare
  `t.Error("failed")`. For structs and slices print a diff (`cmp.Diff(want, got)`), not two blobs.
- **Helpers set up; the test body asserts.** Call `t.Helper()` so a failure points at the caller's
  line, and prefer a helper that *returns* a value or `error` over one that fails internally —
  assertion logic belongs where the case's context is visible. `t.Fatal` in a setup helper is fine;
  in a goroutine use `t.Error` (only the test's own goroutine may call `Fatal`). Stdlib plus small
  helpers is usually enough; `testify` is fine — match the repo, don't mix styles.

## Sources
- synctest — <https://go.dev/blog/synctest>; `testing.B.Loop` — <https://go.dev/blog/testing-b-loop>
- `testing` package (`T.Context`, `T.Chdir`, `T.Output`, `T.Attr`, `T.ArtifactDir`) — <https://pkg.go.dev/testing>; Go 1.22/1.24/1.25/1.26 release notes — <https://go.dev/doc/go1.26>
- Code Review Comments (Useful Test Failures) — <https://go.dev/wiki/CodeReviewComments>; Google Go Style Guide (Tests) — <https://google.github.io/styleguide/go/best-practices>
- `testing/cryptotest` (Go 1.26) — <https://pkg.go.dev/testing/cryptotest>
- `go.uber.org/goleak` — <https://pkg.go.dev/go.uber.org/goleak>

---
*Decomposition inspired by [`samber/cc-skills-golang`](https://github.com/samber/cc-skills-golang) (MIT © 2026 Samuel Berthe); rules grounded in the sources above.*
