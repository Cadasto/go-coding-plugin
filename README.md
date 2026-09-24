# Go Coding Plugin

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Version](https://img.shields.io/badge/version-0.6.0-blue)](CHANGELOG.md)
[![Claude Code](https://img.shields.io/badge/Claude_Code-plugin-D97757?logo=anthropic&logoColor=white)](https://claude.ai/code)
[![Cursor](https://img.shields.io/badge/Cursor-plugin-000?logo=cursor&logoColor=white)](https://cursor.com)
[![Keep a Changelog](https://img.shields.io/badge/Keep%20a%20Changelog-1.1.0-E05735)](CHANGELOG.md)

An AI plugin by **Cadasto B.V.** that teaches AI coding assistants idiomatic Go coding standards: formatting, naming, error handling, concurrency, testing, and project layout. It adds skills, an agent, and three hooks (session-start, format-on-save, skill-nudge) for **[Claude Code](https://claude.ai/code)** and **[Cursor](https://cursor.com)** from one shared component set, plus a Cursor rule.

The plugin owns the judgement layer of Go standards. Formatting, vetting and linting stay with the deterministic tools (`gofmt`/`gofumpt`, `go vet`, `staticcheck`, `golangci-lint`, `go test -race`): each skill names the tool that enforces a rule and cites the source a judgement rule comes from, and the `go-reviewer` agent reports what those tools miss. It covers Go only and carries no business rules.

**Requirements.** A Claude Code or Cursor host. The plugin is pure Markdown + JSON, with no build step and no MCP server, and it installs without a Go toolchain. Its hooks and enforcement guidance expect **Go 1.26.4+** (Go 1.27 supported; its additions are flagged as hints) plus `gofmt`, `gofumpt`, `goimports`, and `gopls` on the host `PATH`, and golangci-lint v2 (v2.13.0 or newer on Go 1.27) for full-tree linting. See [Host toolchain (minimal requirements)](docs/install.md#host-toolchain-minimal-requirements) for what each tool drives and copy-paste install commands.

## Table of contents

- [Features](#features)
- [Installation](#installation)
- [Components](#components)
- [Using with subagent orchestrators](#using-with-subagent-orchestrators)
- [Development](#development)
- [Documentation](#documentation)
- [License](#license)

## Features

- **Routing:** the auto-invoked `go-coding` router sends each Go topic to the enforcing tool, then to the focused skill that owns it.
- **Focused standards:** `go-errors`, `go-concurrency`, `go-testing`, `go-idioms`, and `go-layout` load on use, with each rule cited and framed around the linter that enforces it.
- **Linter setup:** `/go-lint-setup` scaffolds, adopts, or debugs a golangci-lint v2 config, based on the shipped `references/golangci.v2.yml`.
- **Review:** the report-only `go-reviewer` agent returns severity-ranked findings for what linters miss.
- **Format on save:** a hook runs `gofumpt -w` (or `gofmt -w -s`) on each edited `*.go` file.
- **Skill nudges:** after a `*.go` edit, a hook names one matching skill, once per skill per session.
- **Cursor parity:** Cursor gets the same skills, agent, and hooks, plus `rules/go-context.mdc` mirroring the router.

## Installation

**Claude Code**: from the Cadasto marketplace:

```text
/plugin marketplace add Cadasto/plugin-marketplace
/plugin install go-coding@cadasto
```

Or load a local working copy for a single session: `claude --plugin-dir /path/to/go-coding-plugin`.

**Cursor**: add this repository as a plugin (Settings → Plugins, from a Git URL or a local path). The repo includes a Cursor manifest at [`.cursor-plugin/plugin.json`](.cursor-plugin/plugin.json); skills, agents, and hook scripts are shared with the Claude plugin.

See [docs/install.md](docs/install.md) for marketplace, local-development, update, and Cursor install details.

## Components

| Component | Status | Purpose |
|-----------|--------|---------|
| Skill `go-coding` | shipped | Auto-invoked router: sends each Go topic to the enforcing tool and the focused skill below; recommends `gopls-lsp`. |
| Session-start hook | shipped | Detects a Go workspace (`go.mod`/`*.go`) and prints one standards line; dual-host. |
| Format-on-save hook | shipped | After each `Write`/`Edit` of a `*.go` file, runs `gofumpt -w` (or `gofmt -w -s`) on it; dual-host, host-only, silent no-op if no formatter is installed. |
| Skill-nudge hook | shipped | After each `Write`/`Edit` of a `*.go` file, names ONE matching go-coding skill for that edit, once per skill per session; dual-host: delivered as a hook `systemMessage` under Claude Code, a plain line under Cursor. |
| Skills `go-errors`, `go-concurrency`, `go-testing`, `go-idioms`, `go-layout` | shipped | Load-on-use standards, each rule cited and framed around the enforcing linter (`modernize`, `errorlint`, `-race`, …). `go-layout` also owns naming, doc comments, and exported-API shape. |
| Agent `go-reviewer` | shipped | Report-only, context-isolated Go reviewer for what linters miss; severity-ranked findings, no sub-agent dispatch. Its grant excludes `Write`/`Edit` but includes `Bash` to run the linters, so no-edit is a contract it keeps rather than a sandbox that enforces it. |
| Skill `/go-lint-setup` (user-invoked) | shipped | Slash-command skill: scaffolds, adopts, or debugs the golangci-lint v2 config in a repo. |
| Lint config `references/golangci.v2.yml` | shipped | Reference golangci-lint v2 config (`modernize` + stack linters). |
| Cursor rule `go-context.mdc` | shipped | `**/*.go`-scoped guidance mirroring the router for Cursor. |
| Scripts `scripts/hooks-test.sh`, `scripts/usage-report.py` | shipped | Dev tooling, not part of the installed component surface: a bash test harness for the hooks, and a stdlib-only adoption-report generator over local session transcripts. |

Guidance is grounded in [Effective Go](https://go.dev/doc/effective_go), [Go Code Review Comments](https://go.dev/wiki/CodeReviewComments), the [Google Go Style Guide](https://google.github.io/styleguide/go/) (its *Guide*, *Style Decisions*, and *Best Practices*), the [Uber Go Style Guide](https://github.com/uber-go/guide), and the standard toolchain (`gofmt`/`gofumpt`, `go vet`, `staticcheck`, `golangci-lint`, `go test -race`).

## Using with subagent orchestrators

Subagents do not inherit the parent session's skills. A plan runner that dispatches implementers
and reviewers must say so in every brief:

- **Implementer brief:** "Before writing code, invoke the Skill tool with `go-coding:go-coding`, then
  the focused skills matching your diff (see its *Route, then load* table). Run `golangci-lint run`
  on every touched package before committing."
- **Reviewer brief:** "Before reading the diff, load `go-coding:go-coding` plus `go-errors`,
  `go-testing` and the skills the diff calls for; cite the rule a finding rests on. Do not dispatch
  `go-reviewer`: you are the review seat."

Use `go-reviewer` directly when no such seat exists (an ad-hoc "review this file" request).

## Development

The plugin has no build step. Validate locally:

```bash
./scripts/validate.sh        # manifests, parity, paths, frontmatter, hooks, doc inventories, linters, fixers
./scripts/hooks-test.sh      # bash tests for hooks/session-start.sh + hooks/skill-nudge.sh
claude plugin validate .     # manifest + component structure
```

Beyond the shared structural checks, the validator enforces two invariants specific to this plugin. The first is **advice equals tooling**: every linter a component teaches must be reachable from the reference config. The second applies when a Go toolchain at the floor minor is on `PATH`: the `go-idioms` **Fixer** column is verified against `go tool fix help`, so a renamed or retired fixer fails the build rather than shipping as advice.

## Documentation

- [docs/install.md](docs/install.md): install on both hosts, and the Go toolchain each hook expects
- [docs/testing.md](docs/testing.md): validate and dogfood
- [docs/versioning.md](docs/versioning.md): SemVer policy and release steps
- [docs/authoring.md](docs/authoring.md): skill, command, agent, and rule authoring conventions

See [AGENTS.md](AGENTS.md) for contributor conventions.

## License

[MIT](LICENSE)
