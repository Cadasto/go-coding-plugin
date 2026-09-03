# Changelog

All notable changes to this project will be documented in this file.

The format is based on Keep a Changelog, and this project adheres to Semantic Versioning.

- Keep a Changelog: https://keepachangelog.com/en/1.1.0/
- Semantic Versioning: https://semver.org/spec/v2.0.0.html

## [0.5.0] - 2026-09-04

Makes the `go-coding` router route. A usage analysis of local session transcripts found the router
loading often and the focused skills almost never, so this release adds a hop table, a post-edit
nudge, trigger-first descriptions and a banner that names the next step. It also shrinks the
surface — `go-linting` merged into `go-lint-setup`, `/go-explain` removed — adds Go 1.27 support on
the existing Go 1.26.4+ floor, and ships a script for measuring adoption.

### Added
- Skill `go-coding` — a "Route, then load" table mapping diff content to the skill to load, and a
  minimum checklist for when a second load is not affordable.
- Skill `go-coding`, agent `go-reviewer` — "Writing for the human": anything a person reads (PR
  text, review findings, a question) states the effect before the mechanism, in plain English, short.
- Hook `hooks/skill-nudge.sh` — after a Go edit, names one skill the edit calls for. Under Claude
  Code it matches only the text the edit adds (`tool_input.new_string`, or `content` for a write),
  not the file and not the deleted text; Cursor passes a path alone, so there it matches the file
  and says so. Once per skill per session, at most three per session; a `systemMessage` under
  Claude Code, a plain line under Cursor.
- Script `scripts/hooks-test.sh` — 28 bash tests over all three hooks, on production-shaped
  payloads, asserting exit status as well as output, with can-fail controls proving the silence
  assertions can actually fail. Runs in CI.
- Script `scripts/usage-report.py` — stdlib-only adoption report from local session transcripts;
  counting rules and the 50% target in `docs/testing.md`.
- Docs `README.md` — implementer and reviewer brief templates for orchestrators, since a subagent
  does not inherit the parent session's skills.
- Skills `go-idioms`, `go-lint-setup` — Go 1.27 hints (generic methods, json/v2-backed
  `encoding/json`, the four new `go fix` modernizers, `stdversion` by default under `go test`) and
  the golangci-lint ≥ v2.13.0 floor for Go 1.27.
- CI `.github/workflows/validate.yml` — Go matrix `1.26.x` + `1.27.x`, `fail-fast: false`; the
  floor leg keeps the strict `go-idioms` Fixer-column check.
- Validation `scripts/validate.py` — hook parity (the same script wired for the equivalent event on
  both hosts, existing and executable, none left unwired) and doc component inventories (every
  shipped skill, agent and hook named where the docs claim to list them).
- Validation `scripts/validate.py --selftest` — rebuilds each structural check's failure case in a
  temporary tree and requires the check to catch it, and to stay quiet once the defect is removed.
  Runs in CI, because a green run over a valid tree says nothing about whether a check still checks.

### Changed
- Skills — descriptions rewritten trigger-first and shortened 10% (4,619 → 4,163 characters).
  Always-on context competes with the session's real work. `go-idioms` in particular no longer
  triggers on "writes or reviews Go", which was nearly every Go turn.
- Skill `go-lint-setup` — absorbs `go-linting`'s config-schema, adoption and upgrade-breakage
  content; re-fronted as "scaffold, adopt, or debug".
- Hook `hooks/session-start.sh` — the banner names the hop and the focused skills, and offers
  `/go-lint-setup` only when the workspace has no golangci-lint config.
- Agent `go-reviewer`, skill `go-coding` — one review seat per diff: where a workflow already has a
  reviewer, that reviewer loads the skills itself instead of `go-reviewer` being dispatched beside it.
- Cursor rule `rules/go-context.mdc` — brought level with the router: the diff→skill mapping, the
  minimum checklist, and the plain-English rule for anything a person reads. Drops the Claude-only
  `${CLAUDE_PLUGIN_ROOT}` reference from a Cursor-only file.
- Skills `go-idioms`, `go-testing` — four Go 1.27 claims corrected against their sources: v1
  `encoding/json` stays the default (the release notes say users are not required to migrate);
  `embedlit` folds a promoted field into the parent literal rather than a post-literal assignment;
  `unsafefuncs` gains the table row its prose already assumed; `stdversion` is dated to when `go
  test` starts running it by default, not to the check's existence. `httptest.NewTestServer` now
  carries its signature.
- Docs `docs/install.md` — `gopls` pin moves to v0.23.x, the line that adds Go 1.27 support.
- Docs `docs/testing.md` — adds the missing `format-on-save` triggering check.
- Skills, agent, Cursor rule, docs — Go 1.26.4+ remains the hard floor; Go 1.27 is supported and its
  additions are flagged as hints. `docs/install.md` recommends the latest 1.27.x patch.

### Removed
- Skill `go-linting` — merged into `go-lint-setup`, the skill the router and banner point at.
- Skill `/go-explain` — one-shot lookups are what the focused skills already do, with the same
  citations and the code in view.

## [0.4.1] - 2026-08-25

Corrects three component defects and the docs that described them: a `PostToolUse` hook timeout that was five hours rather than twenty seconds, a reviewer agent calling itself read-only while holding `Bash`, and `go-lint-setup` offering a migration it had no tool grant to run.

### Changed
- Docs: `README.md` — `go-reviewer` is described as **report-only**, not read-only. Its grant excludes `Write`/`Edit` but includes `Bash` so it can run the linters, which makes no-edit a contract the agent keeps rather than a sandbox that enforces it. `docs/authoring.md` follows. The same wording still stands in `agents/go-reviewer.md` and `skills/go-coding/SKILL.md`.
- Docs: `README.md` — the `validate.sh` comment claimed only "dual-host parity + frontmatter". The validator also checks component paths, kebab-case names, hook configs, that every linter a component teaches is reachable from the reference config, and — with a floor-minor Go toolchain on `PATH` — the `go-idioms` Fixer column against `go tool fix help`. Those last two are now described rather than left invisible.
- Docs: sentence-case H1s in `docs/testing.md`, `docs/versioning.md`, `docs/authoring.md`; "for example" over "e.g."; `docs/testing.md` opens with its subject rather than "There is".
- Docs: `docs/versioning.md`, `AGENTS.md` — release step 8: bump catalog `version` and `source.ref` after tagging.

### Fixed
- Hooks: the `PostToolUse` formatter declared `"timeout": 20000`. Claude Code reads a hook timeout in **seconds** (`hook.timeout * 1000` internally), so that was 5 hours 33 minutes, not 20 seconds — a hung `gofumpt` would have stalled the session instead of being cut off. Now `20`.
- Agents, Skills: `go-reviewer` described itself as **read-only** while declaring `Bash`, which writes. It is **report-only**: the body now says no-edit is a contract it keeps rather than a sandbox that keeps it, and adds an explicit ban on `-w` / `--fix` / any in-place formatter flag, which is the concrete way a reviewer holding `Bash` could edit by accident. `skills/go-coding/SKILL.md` follows.
- Skills: `go-lint-setup` offers to run `golangci-lint migrate` but declared `allowed-tools: Read, Write, Glob` — no `Bash`, so it could not do what it offered. Added `Bash`, matching this repo's own advice-equals-tooling principle.

- Docs: `README.md` had no route to `docs/versioning.md` or `docs/authoring.md` — two of the four contributor documents were unreachable from it. Added a Documentation section listing all four.
- Docs: `claude plugin add` is not a Claude Code command. `README.md`, `docs/install.md`, `docs/versioning.md` (the dogfood release step), and `AGENTS.md` load a local working copy with `claude --plugin-dir <path>`, which applies to that session only.

## [0.4.0] - 2026-08-05

Grounds the standards set on a **Go 1.26.4+ hard floor**, widens `go-layout` to naming + API surface, replaces the pinned golangci-lint version with a pin *policy*, and makes "advice == tooling" machine-checked (taught linters vs the reference config; the `go-idioms` Fixer column vs the floor toolchain's `go tool fix help`).

### Added
- Agents: `go-reviewer` — three review dimensions: **silent dispatch defaults** (pass-through `default` over an internal enum; paired dispatch sites maintained as independent switches), **sensitive-value echo in errors/logs** at a boundary (driver messages quoting stored values, request bodies in wrapped errors), and **comment–code drift** in the diff.
- Skills: `go-errors` — fail-loudly-on-impossible-dispatch rule (loud `default` + `exhaustive` linter or enum-completeness test) and boundary-errors-carry-classification-not-payload rule (pass the class/code, keep the raw message internal).
- Skills: `go-testing` — golden files pin *shape*, not behaviour: pair a golden of an externally executed artefact (SQL, wire requests, rendered configs) with at least one live-execution test.
- Skills: `go-errors` — `errors.AsType[E]` (Go 1.26) leads typed-error inspection, preferred over `errors.As` (`errorsastype` modernizer converts call sites); `%w` goes last unless the sentinel is the sentence; check `Close` on written files (`errors.Join` into a named result); keep the happy path at minimal indentation; never let a panic cross a package boundary.
- Skills: `go-testing` — `t.Context` (1.24), `t.ArtifactDir` (1.26) vs `t.TempDir`, `t.Output`/`t.Attr` (1.25); `t.Setenv`/`t.Chdir`/`cryptotest.SetGlobalRandom` are process-global and unusable under `t.Parallel`; failure messages must carry call/input/got/want; helpers set up, the test body asserts.
- Skills: `go-concurrency` — cancellation causes (`WithCancelCause` + `context.Cause`, `WithTimeoutCause`), `context.WithoutCancel` for work outliving a request, `context.AfterFunc`, prefer-synchronous-APIs, and explicit cleanup over `runtime.AddCleanup`/`SetFinalizer`.
- Skills: `go-idioms` — **Fixer** column naming the owning analyzer per row, audited against Go 1.26.4 `go tool fix help` (plain = in the toolchain's `go fix`; **†** = x/tools/golangci-lint `modernize` only, e.g. `errorsastype`, `bloop`, `atomictypes`, `slicesbackward`); rows for `any`, `omitzero`, `testingcontext`, `stringsseq`, `reflecttypefor`, `fmt.Appendf`; a `go fix` recipe (`-diff` preview, per-fixer `-<name>`/`-<name>=false` selection); new "no fixer automates it" section (`os.OpenRoot`, `crypto/rand.Text`, nil slices, sorted map iteration).
- Skills: `go-layout` — naming (initialism casing, `MixedCaps`, name-length-tracks-scope, receiver names, no `Get` prefix, `<pkg>test` doubles), signatures/API surface (receiver type, in-band errors, named results, option struct vs variadic options, accept interfaces/return concrete types, useful zero value), and doc-comment conventions.
- Skills: `go-linting` — `golangci-lint migrate` for v1 configs, `golangci-lint fmt`, the `linters.exclusions`/`formatters.settings` moves, and `//nolint:<linter> // reason` discipline.
- Lint config: `usetesting`, `nolintlint` + `exhaustive` in `references/golangci.v2.yml`, the `go-linting` block, and `/go-lint-setup` (`exhaustive` was taught by `go-errors`/`go-reviewer` but not shipped).
- Agents: `go-reviewer` — **exported-surface & naming slips** dimension; discarded-`Close`-on-a-written-file folded into resource leaks; `errors.AsType` in sentinel/typed-error breakage.
- Docs: `docs/authoring.md` — "Refreshing the standards baseline (source registry)": tiered source list plus the procedure for re-grounding the skills against current Go practice; **AGENTS.md** points at it for refresh requests.
- Validation: `scripts/validate.py` — two advice == tooling cross-checks: every linter a component teaches (`--enable-only=…` or "the `<name>` linter") must be enabled in `references/golangci.v2.yml`, and the `go-idioms` **Fixer** column is verified against the floor toolchain's `go tool fix help` (plain names must be registered, † names must not be; soft-skips locally without Go). CI (`validate.yml`) now pins Go `1.26.x` alongside Python to run the Fixer check strictly.
- Skills: `go-errors` — terse wrap context (`"new store: %w"`, no `"failed to"` pile-up); `go-layout` — `main` owns process exit (`os.Exit`/`log.Fatal` only in `main`, `run() error` pattern) and `init()` restricted to cheap deterministic setup.
- Skills: `go-coding` router — routes to the `/go-explain` and `/go-lint-setup` user-invoked skills.

### Changed
- Agents: `go-reviewer` — frontmatter `description` converted to prose triggers (was ~313 words of `<example>` blocks); worked scenarios moved to a "When to invoke" body section.
- Skills: `go-coding`/`go-explain` descriptions trimmed to the ~50–75-word always-on budget; skill bodies swept to imperative form (second-person phrasing removed).
- Skills / agent / Cursor rule / docs: **Go 1.26.4+ is now a hard floor** — the "works with 1.25+" framing and the per-idiom "check `go.mod` before applying" hedging are gone from `go-coding`, `go-errors`, `go-idioms`, `go-explain`, `go-reviewer`, `rules/go-context.mdc`, `README.md` and `docs/install.md`. Version annotations (`Since`, "(Go 1.24)") stay as provenance.
- Skills: `go-linting`, `/go-lint-setup`, `references/golangci.v2.yml` — no blessed golangci-lint version anywhere; replaced with a pin *policy* (exact version, one source of truth, `golangci-lint-action` `version:` input, automated bump PR, `--fix`-then-triage on bump) and upstream's warning against `go install`/`tool`-directive installs.
- Docs: `docs/authoring.md` — refresh procedure gains the hard-floor rule, "never hardcode a tool version in a component", and "run the tool, don't read about it" (floor-toolchain `go tool fix help` is the authority for shipped fixers; the Tier 3 registry now marks pkg.go.dev's modernize page as x/tools *tip* — source for † rows only).
- Skills / Cursor rule: `go-layout` widens from project layout to layout **+ naming + API surface**; the `go-coding` router and `rules/go-context.mdc` route naming/doc-comment/API-shape questions there and name `revive` as the deterministic backstop.
- Skills: labelled Go 1.27 forward notes (draft, expected Aug 2026) only where they change advice — `goroutineleak` on by default, `synctest.Sleep` + `httptest.NewTestServer`, † fixers graduating into `go fix`, `encoding/json/v2`.

## [0.3.0] - 2026-07-01

Retargets the standards baseline to **Go 1.26** (1.26.4+) while keeping version-gated guidance valid for 1.25 modules.

### Added
- Skills: `go-idioms` — `new(expr)` row (Go 1.26 pointer/optional-field initialization) and a note on self-referencing generic type parameters.
- Skills: `go-testing` — `testing/cryptotest.SetGlobalRandom` for deterministic crypto tests (Go 1.26); note that the pre-1.25 `GOEXPERIMENT=synctest` (`synctest.Run`) API was removed in Go 1.26.
- Skills: `go-concurrency` — experimental `goroutineleak` profile in `runtime/pprof` (Go 1.26) as a toolchain-native complement to `goleak`.

### Changed
- Skills / agent / Cursor rule: standards baseline moved from Go 1.25 to **Go 1.26** in `go-coding`, `go-idioms`, `go-linting`, `go-explain`, the `go-reviewer` agent, and `rules/go-context.mdc`; all keep working against 1.25 modules via the `Since`/`go.mod` version-gating already in `go-idioms`.
- Skills: `go-idioms`, `go-linting`, `go-coding`, `rules/go-context.mdc` — frame `go fix ./...` as the canonical modernizer runner on Go 1.26 (rewritten atop the analysis framework), with `golangci-lint --enable-only=modernize` for CI reproducibility and older toolchains.
- Docs: `docs/install.md` and `README.md` — minimum host toolchain raised to **Go 1.26.x** (1.26.4+); tarball example updated to `go1.26.4`; `gopls` pin moved to `v0.22.x` (the line that adds Go 1.26 support).
- Manifests: `version` → `0.3.0` in both `.claude-plugin/plugin.json` and `.cursor-plugin/plugin.json`.

## [0.2.1] - 2026-06-18

### Added
- Docs: `docs/install.md` — "Host toolchain (minimal requirements)" section (Go 1.25.x plus `gofmt`/`gofumpt`/`goimports`/`gopls`, with install and verify commands); `README.md` gains a **Prerequisites** pointer to it.

### Changed
- Docs: pin the `gopls` install to `@v0.21.1` (verified against Go 1.25.x) in `docs/install.md`.

### Fixed
- Skills / Cursor rule: make the plugin-root `references/golangci.v2.yml` citation resolvable (`${CLAUDE_PLUGIN_ROOT}/references/…` / `../../` / Glob); the bare path failed a first Read. `go-lint-setup` inlines it, unchanged.

## [0.2.0] - 2026-06-14

Adds automatic Go formatting on save, and renames the plugin to `go-coding` (install identifier now `go-coding@cadasto`; the repository stays `go-coding-plugin`).

### Added
- Hooks: `hooks/format-on-save.sh` — after a `Write`/`Edit` of a `*.go` file, runs `gofumpt -w` (or `gofmt -w -s`) on that file; host-only, silent no-op if no formatter, exits 0 always. Wired via `hooks/hooks.json` (Claude `PostToolUse`, `matcher: "Write|Edit"`, `${CLAUDE_PLUGIN_ROOT}`) and `hooks/cursor-hooks.json` (Cursor `afterFileEdit`, workspace-relative).

### Changed
- Plugin `name` renamed from `go-coding-plugin` to `go-coding` in both manifests; install/usage identifiers updated across the docs. The repository name, URLs, and local-path examples are unchanged.

## [0.1.0] - 2026-06-13

First tagged release — the full dual-host (Claude Code + Cursor) Go-standards surface: the `go-coding` router skill, six load-on-use standards skills, a context-isolated review agent, two slash commands, a shipped golangci-lint v2 reference config, and a Cursor rule. Pure Markdown + JSON, grounded in Go 1.25 + golangci-lint v2 with cited sources; no MCP backend.

### Added
- Dual-host manifests (`.claude-plugin/plugin.json`, `.cursor-plugin/plugin.json`) with parity-enforced metadata.
- Validation harness: `scripts/validate.py` (manifests, dual-host parity, declared component paths, kebab-case names, hook-config JSON, and skill/agent/command frontmatter — agents must use `tools:` not `allowed-tools:`) and the `scripts/validate.sh` soft-skip wrapper.
- CI: `.github/workflows/validate.yml` (pins Python, strict in CI).
- Community files under `.github/` (issue templates, PR template, Copilot instructions).
- Docs: `docs/install.md` and `docs/testing.md`.
- Skills: `go-coding` router skill — routes each Go topic (formatting, static analysis, idioms, errors, concurrency, testing, layout) to the enforcing tool and the focused `go-*` skill; recommends the `gopls-lsp` plugin. Only its frontmatter `description` is always-on.
- Hooks: host-agnostic `hooks/session-start.sh` (detects `go.mod`/`*.go`, prints one context line, exits 0) wired via `hooks/hooks.json` (Claude, `${CLAUDE_PLUGIN_ROOT}`) and `hooks/cursor-hooks.json` (Cursor, workspace-relative); `.cursor-plugin/plugin.json` now declares the `hooks` path.
- Skills: standards set — `go-errors`, `go-concurrency`, `go-testing`, `go-idioms`, `go-linting`, `go-layout`. Load-on-use; each rule cited and framed around its enforcing linter (`errorlint`, `-race`/`goleak`, `testing/synctest`, `modernize`, golangci-lint v2). Decomposition adapted from `samber/cc-skills-golang` (MIT).
- Agents: `go-reviewer` — context-isolated, read-only Go reviewer for what linters miss (silent error swallowing, goroutine leaks, context misuse, resource leaks, sentinel breakage, unsafe atomics, modernization debt, slog hot-path). Inlined review dimensions, a no-sub-agents guard, untrusted-diff handling, and severity-ranked output; declares `tools:` (read-only), never `allowed-tools:`.
- Slash commands (user-invoked skills): `/go-explain` (explain a Go idiom/standard/tool — modern form, enforcing linter, cited source) and `/go-lint-setup` (scaffold the reference golangci-lint v2 config into a repo; won't overwrite an existing config without asking).
- References: `references/golangci.v2.yml` — shipped golangci-lint v2 reference config (`linters.default: standard` plus `modernize`, `errorlint`, `bodyclose`, `rowserrcheck`, `sqlclosecheck`, `noctx`, `contextcheck`, `containedctx`, `perfsprint`, `revive`; formatters `gofumpt` + `goimports`).
- Cursor rule: `rules/go-context.mdc` (`globs: ["**/*.go"]`) mirroring the `go-coding` router; declared via the Cursor manifest's `rules` path.
- Docs: `docs/versioning.md` (SemVer policy + release steps) and `docs/authoring.md` (skill/command/agent/rule authoring conventions, incl. the frontmatter colon-space gotcha).
