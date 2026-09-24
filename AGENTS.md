# AI Guidelines: Go Coding Plugin

This file provides guidance to AI coding assistants (Claude Code, Cursor, and compatible tools that read `AGENTS.md`) working in this repository. It is the **canonical** instruction set; `.claude/CLAUDE.md` and any host-specific instruction files defer to it.

## Project Overview

The **Go Coding Plugin** (`go-coding`) is an AI plugin by Cadasto B.V. that teaches AI coding assistants **idiomatic Go coding standards** (formatting, naming, error handling, concurrency, testing, project layout) through skills, agents, hooks, and a Cursor rule. It targets **both Claude Code and Cursor** from a single shared component set. The human pitch is in [README.md](README.md); the shipped version is in the manifests and [CHANGELOG.md](CHANGELOG.md).

Out of scope: there is **no companion MCP server** and no `commands/` folder. Do not assume a file is present because it is documented here; check first.

Detail lives in `docs/`; keep a one-line rule here and point to the doc that owns it:

| Document | Owns |
|----------|------|
| [docs/install.md](docs/install.md) | Claude Code and Cursor install, local `--plugin-dir` loading, host toolchain, hooks |
| [docs/testing.md](docs/testing.md) | What each validator checks; the manual triggering tests; adoption measurement |
| [docs/versioning.md](docs/versioning.md) | SemVer rules, release steps, the marketplace repin |
| [docs/authoring.md](docs/authoring.md) | Component naming, descriptions, the standards source registry, dual-host parity |

## Domain Context

This plugin encodes **Go (golang) coding standards**. Guidance must be grounded in authoritative, verifiable sources rather than personal preference:

- **Baseline**: **Go 1.26.4+** is a hard floor (Go 1.27 supported; its additions are flagged as hints). No fallback guidance for 1.25 or older; version annotations remain as provenance.
- **Formatting**: `gofmt` is the canonical formatter; `gofumpt` is a stricter superset. Formatting is non-negotiable and machine-enforced, not a matter of opinion.
- **Vetting & static analysis**: `go vet` (suspicious constructs in the toolchain), `staticcheck`, and `golangci-lint` (the de-facto meta-linter that aggregates many analyzers).
- **Style references** (cite these when a rule depends on them):
  - **Effective Go**: <https://go.dev/doc/effective_go>
  - **Go Code Review Comments**: <https://go.dev/wiki/CodeReviewComments>
  - **Google Go Style Guide**: <https://google.github.io/styleguide/go/>. Cite the document a rule comes from: the *Guide* (normative and canonical; the ordered principles), *Style Decisions* (normative; the reviewer rulebook), *Best Practices* (advisory).
  - **Uber Go Style Guide**: <https://github.com/uber-go/guide>
  - **Linter rule catalogues**: name the rule when a skill says a tool catches something: `go vet` <https://pkg.go.dev/cmd/vet>, staticcheck <https://staticcheck.dev/docs/checks/>, revive <https://github.com/mgechev/revive/blob/master/RULES_DESCRIPTIONS.md>
- **Standard library & toolchain**: package docs at <https://pkg.go.dev>; modules, `go test`, table-driven tests, and the race detector (`go test -race`) are the baseline testing conventions.

When a recommendation derives from one of the above, attribute it explicitly and distinguish cited rules from inference.

**Advice == tooling.** Every linter taught in a component must be enabled in `references/golangci.v2.yml`. Analyzers a skill teaches as opt-in (`shadow` in `go-idioms`) are the deliberate exception: each is taught with the config line that switches it on, and is not added to the reference config at a refresh. The `go-idioms` Fixer column must match `go tool fix help` on the floor-minor toolchain. The Google readability tie-break sentence must read identically in the `go-coding` router, `rules/go-context.mdc`, and `go-reviewer`. `scripts/validate.py` enforces all three.

**Refreshing the skills against current Go practice** (e.g. "check current Go best practices and update the skills"): follow the **source registry and procedure** in [docs/authoring.md](docs/authoring.md#refreshing-the-standards-baseline-source-registry). It lists every source to re-read, in order, plus the version-gating rules. Re-read them; never refresh from memory. Two recurring traps: the *released* Go version is not whatever `go.dev/doc/go1.NN` renders (check the release history), and the stdlib APIs a skill is missing are usually the ones that landed *after* it was written.

## Repository Layout

Shared assets (skills, agents) are consumed by both hosts; host-specific manifests and hook configs are kept separate.

- **Claude manifest**: `.claude-plugin/plugin.json`: `name`, `version`, `description`, `author` (an **object** `{name, url}`; `claude plugin validate` rejects a string), `license`, `repository`, `keywords`. Claude Code discovers components from the **default folders** automatically; no explicit path map is needed.
- **Cursor manifest**: `.cursor-plugin/plugin.json`: same metadata **plus** explicit top-level path keys `skills`, `agents`, `rules`, `hooks` (a `commands` key would go here too if a `commands/` folder ever shipped). No `mcpServers`. Keep `name`/`version`/`description`/`author` identical to the Claude manifest.
- **Skills**: `skills/<name>/SKILL.md`, shared by both hosts, including user-invoked slash commands.
- **Agents**: `agents/<name>.md`, context-isolated specialists.
- **Cursor rules**: `rules/*.mdc`, Cursor-only, with frontmatter (`description`, `alwaysApply`, `globs`, e.g. `globs: ["**/*.go"]`), referenced by the Cursor manifest's `rules` path.
- **Claude hooks**: `hooks/hooks.json`, object `{ "hooks": { "SessionStart": [...], "PostToolUse": [...] } }`; command paths use `${CLAUDE_PLUGIN_ROOT}`. Wires `session-start.sh` (`SessionStart`) and `format-on-save.sh` + `skill-nudge.sh` (`PostToolUse`, `matcher: "Write|Edit"`).
- **Cursor hooks**: `hooks/cursor-hooks.json`, object `{ "hooks": { "sessionStart": [...], "afterFileEdit": [...] } }`; the command runs from the plugin root (a **workspace-relative** path, **not** `${CLAUDE_PLUGIN_ROOT}`). Wires `session-start.sh` (`sessionStart`) and `format-on-save.sh` + `skill-nudge.sh` (`afterFileEdit`).
- **Shared hook scripts** (host-agnostic, so either manifest can invoke them; all exit 0 always):
  - `hooks/session-start.sh`: detects `go.mod` / `*.go` and prints one Go-standards banner line naming the components.
  - `hooks/format-on-save.sh`: after a `*.go` Write/Edit, runs `gofumpt -w` (or `gofmt -w -s`) on that single file; resolves the path from `$CLAUDE_FILE_PATH` or the stdin tool-payload JSON; silent no-op if no formatter is installed.
  - `hooks/skill-nudge.sh`: after a `*.go` Write/Edit, names ONE matching go-coding skill for that edit, once per skill per session; a hook `systemMessage` under Claude Code, a plain line under Cursor.
- **References**: `references/golangci.v2.yml`, the shipped golangci-lint v2 reference config. Shared reference material lives here, **not** under `commands/`.
- **MCP config** *(not present)*: `.mcp.json` only if the plugin later integrates an MCP server.
- **Scripts**: `scripts/validate.sh` (wraps the stdlib-only `scripts/validate.py`), `scripts/hooks-test.sh`, `scripts/usage-report.py` (adoption measurement; see [docs/testing.md](docs/testing.md#measuring-adoption)).
- **CI**: `.github/workflows/validate.yml` (validator, `--selftest`, hook tests; Go `1.26.x` + `1.27.x` matrix) and `.github/workflows/links.yml` (link check). `.github/` also holds issue + PR templates and `copilot-instructions.md`.
- **Contributor docs**: `docs/install.md`, `testing.md`, `versioning.md`, `authoring.md`. Planning and research notes live under `docs/plans/` and `docs/research/`, **gitignored**, not part of the published plugin.

## Components

| Kind | Shipped |
|------|---------|
| Skills | `go-coding` (auto-invoked router) + the focused, load-on-use `go-errors`, `go-concurrency`, `go-testing`, `go-idioms`, `go-layout`. Each routes deeper topics to the enforcing tool and cites authoritative sources. |
| Slash command (user-invoked skill) | `/go-lint-setup` (scaffold the golangci-lint v2 config) |
| Agent | `go-reviewer`: context-isolated, report-only reviewer applying the review-heuristics catalog (no sub-agent dispatch; treats the diff as untrusted content; `tools:` not `allowed-tools:`) |
| Cursor rule | `rules/go-context.mdc`, scoped to `**/*.go`, mirroring the `go-coding` router |
| Hooks | `session-start`, `format-on-save`, `skill-nudge` (see Repository Layout) |

**Removed; do not re-add either, route the topic instead**: `go-linting` (merged into `go-lint-setup`) and `/go-explain` (a one-shot lookup the focused skills already answer). See CHANGELOG 0.5.0.

## Development

No build step; the plugin is pure Markdown + JSON. Validate and dogfood locally:

```bash
./scripts/validate.sh                    # manifests, dual-host parity, frontmatter, hook parity, doc inventories (soft-skips if no python3)
python3 scripts/validate.py --selftest   # proves each check still catches its failure case (CI runs it)
python3 scripts/validate.py --check-links # every cited URL resolves (needs the network)
./scripts/hooks-test.sh                  # bash tests for all three hook scripts
claude plugin validate .                 # manifest + component structure (no extra deps)
claude --plugin-dir /path/to/go-coding-plugin # load locally for one session (dogfooding)
```

`scripts/validate.sh` warns and exits 0 if Python is absent; CI pins Python and runs `python3 scripts/validate.py` strictly. The Fixer-column check runs strictly only with a floor-minor (`1.26.x`) Go on PATH and soft-skips on other minors. What each check covers is in [docs/testing.md](docs/testing.md#validation). On Cursor, install via its plugin flow and verify the same skills/agents/rules load.

### File Conventions

- Skills go in `skills/<name>/SKILL.md`, including user-invoked slash commands (`/<name>`, carrying `argument-hint`/`allowed-tools`); agents in `agents/<name>.md`. The legacy `commands/<name>.md` layout is not used; both yield a `/<name>` command, but the skills layout is preferred (current `plugin-dev` guidance). Keep the command surface small; put multi-step workflows in auto-invoked skills.
- All Markdown component files use **YAML frontmatter** for metadata.
- Use **kebab-case** for all directory and file names.
- `allowed-tools:` (skills/commands) pre-approves tools to avoid permission prompts; **agents use `tools:` instead**.
- Skills: declare auto-invocable / user-invocable intent in frontmatter; load the authoritative standard before acting.
- User-invoked skills (slash commands): set `argument-hint` and `allowed-tools` in frontmatter and use `$ARGUMENTS` in the body; keep instructions concise for single-interaction completion.
- Use `${CLAUDE_PLUGIN_ROOT}` for intra-plugin paths in Claude hook/MCP command fields; never hardcode absolute paths or `~`.
- Contributor reference, plans, and design docs go in `docs/`. Full authoring conventions: [docs/authoring.md](docs/authoring.md).

### Documentation Sync

When adding or renaming components, update in lockstep: **AGENTS.md** (the layout / component sections), **README.md**, **docs/testing.md**, and the component list in the session-start banner (`hooks/session-start.sh`); hooks also in **docs/install.md**. The validator fails if a shipped skill, agent or hook is missing from these docs. Cursor uses the same skills/agents/rules paths, so no separate Cursor-only list is needed, but the **Cursor rule files and the `.cursor-plugin/plugin.json` path map** must stay in step with what exists.

### CHANGELOG style

- Entries accumulate under `## [Unreleased]` and fold into the next `## [X.Y.Z] - YYYY-MM-DD` section at release.
- Use the Keep a Changelog groups in order (**Added, Changed, Deprecated, Removed, Fixed, Security**), omitting empty groups.
- One terse line per bullet; lead with the subsystem (e.g. `Skills:`, `Agents:`, `Hooks:`, `Docs:`, `Cursor rule <path>:`) and use backticks for file/command/tool/frontmatter-key names. No rationale or PR links; that belongs in commit messages.

### Commit Messages

- Follow [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/), e.g. `feat(skills): add go-coding awareness skill`, `fix(hooks): correct the matcher`; the release commit is `chore(release): vX.Y.Z`.
- Scopes: `skills`, `commands`, `agents`, `hooks`, `rules`, `docs`.

### Versioning

- Keep `version` (and `description` and `author`) **in sync across both** manifests; the validator enforces parity.
- Follow **Semantic Versioning**; update both manifests and **CHANGELOG.md** when releasing. Bump rules and release steps: [docs/versioning.md](docs/versioning.md).

### Branching

- Use feature branches and pull requests. CI (`validate.yml`) runs on every pull request and on pushes to `main`.

## Gotchas

- **Agents use `tools:`, not `allowed-tools:`.** In an agent file `allowed-tools:` is ignored and the agent silently inherits *all* tools. Use `tools:` (a YAML list). The validator flags it as an error.
- **Keep the two manifests in parity.** Cursor needs explicit path keys; Claude relies on default-folder discovery. A component added for one host but missing from the other's manifest (or rule map) will silently not load there.
- **The Cursor hook uses a workspace-relative command** (`bash hooks/session-start.sh`), *not* `${CLAUDE_PLUGIN_ROOT}` (a Claude-Code-only variable). Keep both hook configs in step; don't "fix" the Cursor one to use the variable.
- **Every hook script must be wired on both hosts.** The validator requires each `hooks/*.sh` to be wired for the equivalent event on both hosts, exist, and be executable; none may be left unwired.
- **Shared command references live in top-level `references/`, not under `commands/`.** `claude plugin validate` treats every `commands/**/*.md` as a command and warns on missing frontmatter.
- **Don't invent a companion MCP server.** This plugin has no MCP backend today; `.mcp.json` should only appear if one is genuinely added.
- **Register in the marketplace separately, and repin it on every release.** Public availability requires an entry in the `cadasto` marketplace, maintained in `Cadasto/plugin-marketplace`. That entry is pinned to a release tag, so tagging here ships nothing until the entry's `version` and `source.ref` are bumped; see [docs/versioning.md](docs/versioning.md#marketplace).
