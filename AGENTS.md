# AI Guidelines: Go Coding Plugin

This file provides guidance to AI coding assistants (Claude Code, Cursor, and compatible tools that read `AGENTS.md`) working in this repository. It is the **canonical** instruction set; `.claude/CLAUDE.md` and any host-specific instruction files defer to it.

## Project Overview

The **Go Coding Plugin** is an AI plugin by Cadasto B.V. that teaches AI coding assistants **idiomatic Go coding standards** — formatting, naming, error handling, concurrency, testing, and project layout — through skills, commands, agents, hooks, and Cursor rules. It targets **both Claude Code and Cursor** from a single shared component set.

> **Current status — v0.1.0.** A complete dual-host (Claude Code + Cursor) Go-standards set that validates clean (`./scripts/validate.sh` + `claude plugin validate .`): the auto-invoked `go-coding` **router** skill; the focused standards skills `go-errors`, `go-concurrency`, `go-testing`, `go-idioms`, `go-linting`, `go-layout`; the read-only `go-reviewer` agent; the user-invoked `/go-explain` and `/go-lint-setup` skills; a shipped `references/golangci.v2.yml`; the `rules/go-context.mdc` Cursor rule; and a host-agnostic `session-start` hook. Do not assume a file is present because it is documented here — check first.

## Domain Context

This plugin encodes **Go (golang) coding standards**. Guidance must be grounded in authoritative, verifiable sources rather than personal preference:

- **Formatting** — `gofmt` is the canonical formatter; `gofumpt` is a stricter superset. Formatting is non-negotiable and machine-enforced, not a matter of opinion.
- **Vetting & static analysis** — `go vet` (suspicious constructs in the toolchain), `staticcheck`, and `golangci-lint` (the de-facto meta-linter that aggregates many analyzers).
- **Style references** (cite these when a rule depends on them):
  - **Effective Go** — <https://go.dev/doc/effective_go>
  - **Go Code Review Comments** — <https://go.dev/wiki/CodeReviewComments>
  - **Google Go Style Guide** — <https://google.github.io/styleguide/go/>
  - **Uber Go Style Guide** — <https://github.com/uber-go/guide>
- **Standard library & toolchain** — package docs at <https://pkg.go.dev>; modules, `go test`, table-driven tests, and the race detector (`go test -race`) are the baseline testing conventions.

When a recommendation derives from one of the above, attribute it explicitly and distinguish cited rules from inference.

## Repository Layout

This repo supports **both Claude Code and Cursor**. Shared assets (skills, commands, agents) are consumed by both hosts; host-specific manifests and hook configs are kept separate.

- **Claude manifest**: `.claude-plugin/plugin.json` — `name`, `version`, `description`, `author` (an **object** `{name, url}` — `claude plugin validate` rejects a string), `license`, `repository`, `keywords`. Claude Code discovers components from the **default folders** (`skills/`, `commands/`, `agents/`, `hooks/`) automatically; no explicit path map is needed.
- **Cursor manifest**: `.cursor-plugin/plugin.json` — same metadata **plus** explicit top-level path keys (`skills`, `rules`, `agents`, `commands`, `hooks`). No `mcpServers` — this plugin has no MCP backend. Keep `name`/`version`/`description`/`author` identical to the Claude manifest.
- **Skills**: `skills/<name>/SKILL.md` — shared by both hosts. Shipped: `go-coding` (auto-invoked router) plus the focused, load-on-use `go-errors`, `go-concurrency`, `go-testing`, `go-idioms`, `go-linting`, `go-layout` standards skills.
- **Slash commands** are authored as **user-invoked skills** (`skills/<name>/SKILL.md` with `argument-hint` + `allowed-tools`), not the legacy `commands/` folder — both yield a `/<name>` command, but the skills layout is preferred (current `plugin-dev` guidance). Keep the surface small; put multi-step workflows in auto-invoked skills. Shipped: `/go-explain` (idiom/standard lookup) and `/go-lint-setup` (scaffold the golangci-lint v2 config).
- **Agents**: `agents/<name>.md` — context-isolated specialists. Shipped: `go-reviewer` (read-only Go diff/file reviewer applying the review-heuristics catalog; `tools:` not `allowed-tools:`).
- **Cursor rules**: `rules/*.mdc` — Cursor-only rule guidance with frontmatter (`description`, `alwaysApply`, `globs`, e.g. `globs: ["**/*.go"]`), referenced by the Cursor manifest's `rules` path. Shipped: `rules/go-context.mdc` (mirrors the `go-coding` router).
- **Claude hooks**: `hooks/hooks.json` — object `{ "hooks": { "SessionStart": [ { "hooks": [ { "type": "command", "command": "..." } ] } ] } }`; use `${CLAUDE_PLUGIN_ROOT}` in command paths. Present — wires `session-start.sh`.
- **Cursor hooks**: `hooks/cursor-hooks.json` — object `{ "hooks": { "sessionStart": [...] } }`; the command runs from the plugin root (a **workspace-relative** path, **not** `${CLAUDE_PLUGIN_ROOT}`). Present.
- **Shared hook script**: `hooks/session-start.sh` — detects `go.mod` / `*.go`, prints one Go-standards context line, exits 0 always. Host-agnostic so both manifests can invoke it. Present.
- **MCP config** *(optional, not present)*: `.mcp.json` — only if the plugin later integrates an MCP server. There is no companion MCP server today; do not reference one.
- **Validation**: `scripts/validate.sh` wraps `scripts/validate.py` to check both manifests, dual-host parity, declared component paths, kebab-case names, hook-config JSON, and skill/command/agent frontmatter (**agents must use `tools:` not `allowed-tools:`** — flagged as an error). The Python is stdlib-only. `.github/workflows/validate.yml` pins Python and runs the validator strictly.
- **Contributor docs**: `docs/` for human-facing references — `install.md`, `testing.md`, `versioning.md`, `authoring.md`. `.github/` holds issue + PR templates, `copilot-instructions.md`, and the CI workflow. (Planning and research working notes are kept locally under `docs/`, **gitignored** — not part of the published plugin.)

### Component surface

The full component surface — all shipped:

- **Skills** — *shipped*: `go-coding` (auto-invoked router) + `go-errors`, `go-concurrency`, `go-testing`, `go-idioms`, `go-linting`, `go-layout`. Each routes deeper topics to the enforcing tool and cites authoritative sources.
- **Slash commands** — *shipped* as user-invoked skills: `/go-explain` (idiom/standard lookup) and `/go-lint-setup` (scaffold the golangci-lint v2 config).
- **Agent** — *shipped*: `go-reviewer`, a context-isolated, read-only reviewer applying the review-heuristics catalog (no sub-agent dispatch; treats the diff as untrusted content).
- **Cursor rule** — *shipped*: `rules/go-context.mdc`, scoped to `**/*.go`, mirroring the `go-coding` router for Cursor.

## Development

### Testing & validating

No build step — the plugin is pure Markdown + JSON. Validate and dogfood locally:

```bash
./scripts/validate.sh                    # dual-host parity / frontmatter (soft-skips if no python3)
claude plugin validate .                 # manifest + component structure (no extra deps)
claude plugin add /path/to/go-coding-plugin   # install locally for dogfooding
```

`scripts/validate.sh` wraps `scripts/validate.py`; it warns and skips gracefully if Python is absent, while CI pins Python and runs the validator strictly. On Cursor, install via its plugin flow and verify the same skills/agents/rules load.

### File Conventions

- Skills go in `skills/<name>/SKILL.md` — this includes user-invoked slash commands (`/<name>`, carrying `argument-hint`/`allowed-tools`); agents in `agents/<name>.md`. The legacy `commands/<name>.md` layout is not used.
- All Markdown component files use **YAML frontmatter** for metadata.
- Use **kebab-case** for all directory and file names.
- `allowed-tools:` (skills/commands) pre-approves tools to avoid permission prompts; **agents use `tools:` instead** — `allowed-tools:` in an agent file is silently ignored and the agent inherits *all* tools.
- Skills: declare auto-invocable / user-invocable intent in frontmatter; load the authoritative standard before acting.
- User-invoked skills (slash commands): set `argument-hint` and `allowed-tools` in frontmatter and use `$ARGUMENTS` in the body; keep instructions concise for single-interaction completion.
- Use `${CLAUDE_PLUGIN_ROOT}` for intra-plugin paths in Claude hook/MCP command fields — never hardcode absolute paths or `~`.
- Contributor reference, plans, and design docs go in `docs/`. Shared command reference material goes in a top-level `references/` dir, **not** under `commands/` (host validators treat every `commands/**/*.md` as a command and warn on missing frontmatter).

### Documentation Sync

When adding or renaming components, update in lockstep: **AGENTS.md** (the layout / component sections), **README.md**, and the session-start hook's "Available: …" list. Cursor uses the same skills/agents/rules paths, so no separate Cursor-only list is needed — but the **Cursor rule files and the `.cursor-plugin/plugin.json` path map** must stay in step with what exists.

### Versioning

- Keep `version` (and, for consistency, `description` and `author`) **in sync across both** `.claude-plugin/plugin.json` and `.cursor-plugin/plugin.json`.
- Follow **Semantic Versioning**; update both manifests and **CHANGELOG.md** (Keep a Changelog format) when releasing.

### CHANGELOG style

- Entries accumulate under `## [Unreleased]` and fold into the next `## [X.Y.Z] - YYYY-MM-DD` section at release.
- Use the Keep a Changelog groups in order — **Added, Changed, Deprecated, Removed, Fixed, Security** — omitting empty groups.
- One terse line per bullet; lead with the subsystem (`Skills:`, `Commands:`, `Cursor rule <path>:`) and use backticks for file/command/tool/frontmatter-key names. No rationale or PR links — that belongs in commit messages.

### Commit Messages & Branching

- Follow [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/), e.g. `feat(skills): add go-coding awareness skill`, `fix(commands): correct allowed-tools`.
- Scopes: `skills`, `commands`, `agents`, `hooks`, `rules`, `docs`.
- Use feature branches and pull requests; PR validation runs on every push.

## Gotchas

- **Agents use `tools:`, not `allowed-tools:`.** In an agent file `allowed-tools:` is ignored and the agent silently inherits *all* tools. Use `tools:` (a YAML list).
- **Keep the two manifests in parity.** Cursor needs explicit path keys (`skills`/`rules`/`agents`/`commands`/`hooks`); Claude relies on default-folder discovery. A component added for one host but missing from the other's manifest (or rule map) will silently not load there.
- **The Cursor hook uses a workspace-relative command** (`bash hooks/session-start.sh`), *not* `${CLAUDE_PLUGIN_ROOT}` (a Claude-Code-only variable). Keep both hook configs in step; don't "fix" the Cursor one to use the variable.
- **Shared command references live in top-level `references/`, not under `commands/`.** `claude plugin validate` treats every `commands/**/*.md` as a command and warns on missing frontmatter.
- **Don't invent a companion MCP server.** This plugin has no MCP backend today; `.mcp.json` should only appear if one is genuinely added.
