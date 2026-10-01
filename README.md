# Go Coding Plugin

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Version](https://img.shields.io/badge/version-0.6.0-blue)](CHANGELOG.md)
[![Claude Code](https://img.shields.io/badge/Claude_Code-plugin-D97757?logo=anthropic&logoColor=white)](https://docs.claude.com/en/docs/claude-code/overview)
[![Cursor](https://img.shields.io/badge/Cursor-plugin-000?logo=cursor&logoColor=white)](https://cursor.com)
[![Keep a Changelog](https://img.shields.io/badge/Keep%20a%20Changelog-1.1.0-E05735)](CHANGELOG.md)

An AI plugin by **Cadasto B.V.** that teaches AI coding assistants idiomatic Go coding standards: formatting, naming, error handling, concurrency, testing, and project layout. It is for anyone who has an assistant write or review Go. It adds seven skills, a report-only review agent, and three hooks (session-start, format-on-save, skill-nudge) for **[Claude Code](https://docs.claude.com/en/docs/claude-code/overview)** and **[Cursor](https://cursor.com)** from one shared component set, plus a Cursor rule.

The plugin owns the judgement layer of Go standards. Formatting, vetting, and linting stay with the deterministic tools (`gofmt`/`gofumpt`, `go vet`, `staticcheck`, `golangci-lint`, `go test -race`): each skill names the tool that enforces a rule and cites the source a judgement rule comes from, and the `go-reviewer` agent reports what those tools miss. It covers Go only and carries no business rules.

**Requirements.** A Claude Code or Cursor host. The plugin is pure Markdown + JSON, with no build step and no MCP server, and it installs without a Go toolchain. Its hooks and enforcement guidance expect **Go 1.26.4+** (Go 1.27 supported; its additions are flagged as hints) with `gofmt`, `gofumpt`, `goimports`, and `gopls` on the host `PATH`, and golangci-lint v2 (v2.13.0 or newer on Go 1.27) for full-tree linting. See [Host toolchain (minimal requirements)](docs/install.md#host-toolchain-minimal-requirements) for what each tool drives and copy-paste install commands.

## Table of contents

- [Features](#features)
- [Installation](#installation)
- [Components](#components)
- [Using with subagent orchestrators](#using-with-subagent-orchestrators)
- [Development](#development)
- [Documentation](#documentation)
- [License](#license)

## Features

- **Routing**: you ask about a Go topic; the auto-invoked `go-coding` router names the tool that enforces it and the focused skill that owns it.
- **Focused standards**: `go-errors`, `go-concurrency`, `go-testing`, `go-idioms`, and `go-layout` load on use, with each rule cited and framed around the linter that enforces it.
- **Linter setup**: `/go-lint-setup` scaffolds the reference golangci-lint v2 config (`references/golangci.v2.yml`), or adopts or debugs the one a repo already has.
- **Review**: the report-only `go-reviewer` agent returns severity-ranked findings for what linters miss.
- **Format on save**: a hook runs `gofumpt -w` (or `gofmt -w -s`) on each edited `*.go` file.
- **Skill nudges**: after a `*.go` edit, a hook names one matching skill, once per skill per session.
- **Cursor parity**: Cursor gets the same skills, agent, and hooks, plus `rules/go-context.mdc` mirroring the router.

## Installation

**Claude Code**, from the Cadasto marketplace:

```text
/plugin marketplace add Cadasto/plugin-marketplace
/plugin install go-coding@cadasto
```

Or load a local working copy for a single session: `claude --plugin-dir /path/to/go-coding-plugin`.

**Cursor**: add this repository as a plugin (Settings → Plugins, from a Git URL or a local path). The repo includes a Cursor manifest at [`.cursor-plugin/plugin.json`](.cursor-plugin/plugin.json); skills, agents, references, and hook scripts are shared with the Claude plugin.

See [docs/install.md](docs/install.md) for marketplace, local-development, update, and Cursor install details.

## Components

| Component | Purpose |
|-----------|---------|
| Skill `go-coding` | Auto-invoked router: sends each Go topic to the enforcing tool and the focused skill that owns it; recommends the official `gopls-lsp` plugin. |
| Skills `go-errors`, `go-concurrency`, `go-testing`, `go-idioms`, `go-layout` | Load-on-use standards, each rule cited and framed around the enforcing linter (`modernize`, `errorlint`, `-race`, …). `go-layout` also owns naming, doc comments, and exported-API shape. |
| Skill `/go-lint-setup` | User-invoked: scaffolds, adopts, or debugs the golangci-lint v2 config in a repo. Never overwrites an existing config unprompted. |
| Agent `go-reviewer` | Report-only, context-isolated Go reviewer for what linters miss. Returns severity-ranked findings and dispatches no sub-agents. Its tool grant excludes `Write` and `Edit` but includes `Bash` to run the linters, so report-only is a contract it keeps rather than a sandbox that enforces it. |
| Session-start hook | Detects a Go workspace (`go.mod` or `*.go`) and prints one standards line; dual-host. |
| Format-on-save hook | After each `Write`/`Edit` of a `*.go` file, runs `gofumpt -w` (or `gofmt -w -s`) on that file, on the host; dual-host. A silent no-op when no formatter is installed. |
| Skill-nudge hook | After each `Write`/`Edit` of a `*.go` file, names one matching go-coding skill, once per skill per session; dual-host. Arrives as a hook `systemMessage` under Claude Code and as a plain line under Cursor. |
| Lint config `references/golangci.v2.yml` | Reference golangci-lint v2 config (`modernize` plus the stack linters). |
| Cursor rule `go-context.mdc` | `**/*.go`-scoped guidance mirroring the router for Cursor. |

The guidance draws on [Effective Go](https://go.dev/doc/effective_go), [Go Code Review Comments](https://go.dev/wiki/CodeReviewComments), the [Google Go Style Guide](https://google.github.io/styleguide/go/) (its *Guide*, *Style Decisions*, and *Best Practices*), the [Uber Go Style Guide](https://github.com/uber-go/guide), and the standard toolchain (`gofmt`/`gofumpt`, `go vet`, `staticcheck`, `golangci-lint`, `go test -race`).

## Using with subagent orchestrators

Subagents do not inherit the parent session's skills. A plan runner that dispatches implementers and reviewers must tell them, in every brief, to load the skills:

- **Implementer brief**: "Before writing code, invoke the Skill tool with `go-coding:go-coding`, then the focused skills matching your diff (see its *Route, then load* table). Run `golangci-lint run` on every touched package before committing."
- **Reviewer brief**: "Before reading the diff, load `go-coding:go-coding` plus `go-errors`, `go-testing` and the skills the diff calls for; cite the rule a finding rests on. Do not dispatch `go-reviewer`: you are the review seat."

Use `go-reviewer` directly when no such seat exists, as with an ad-hoc "review this file" request.

## Development

The plugin has no build step. Validate locally:

```bash
./scripts/validate.sh        # manifests, parity, paths, frontmatter, hooks, doc inventories, linters, fixers, tie-break
./scripts/hooks-test.sh      # bash tests for the three hook scripts
claude plugin validate .     # manifest + component structure
```

Beyond the structural checks, the validator enforces three invariants specific to this plugin: advice equals tooling, the `go-idioms` Fixer column, and the Google tie-break sentence. [What `scripts/validate.py` checks](docs/testing.md#what-scriptsvalidatepy-checks) in docs/testing.md defines each one and the drift it guards against.

`scripts/usage-report.py` measures how often the skills and the `go-reviewer` agent load, from local Claude Code session transcripts; see [Measuring adoption](docs/testing.md#measuring-adoption).

## Documentation

- [docs/install.md](docs/install.md): install on both hosts, and the Go toolchain each hook expects
- [docs/testing.md](docs/testing.md): validate and dogfood
- [docs/versioning.md](docs/versioning.md): SemVer policy and release steps
- [docs/authoring.md](docs/authoring.md): skill, agent, and rule authoring conventions

See [AGENTS.md](AGENTS.md) for contributor conventions.

## License

[MIT](LICENSE)
