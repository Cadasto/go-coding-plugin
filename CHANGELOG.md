# Changelog

All notable changes to this project will be documented in this file.

The format is based on Keep a Changelog, and this project adheres to Semantic Versioning.

- Keep a Changelog: https://keepachangelog.com/en/1.1.0/
- Semantic Versioning: https://semver.org/spec/v2.0.0.html

## [Unreleased]

### Added
- Hooks: `hooks/format-on-save.sh` — after a `Write`/`Edit` of a `*.go` file, runs `gofumpt -w` (or `gofmt -w -s`) on that file; host-only, silent no-op if no formatter, exits 0 always. Wired via `hooks/hooks.json` (Claude `PostToolUse`, `matcher: "Write|Edit"`, `${CLAUDE_PLUGIN_ROOT}`) and `hooks/cursor-hooks.json` (Cursor `afterFileEdit`, workspace-relative).

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
