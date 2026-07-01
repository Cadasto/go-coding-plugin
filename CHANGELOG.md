# Changelog

All notable changes to this project will be documented in this file.

The format is based on Keep a Changelog, and this project adheres to Semantic Versioning.

- Keep a Changelog: https://keepachangelog.com/en/1.1.0/
- Semantic Versioning: https://semver.org/spec/v2.0.0.html

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
