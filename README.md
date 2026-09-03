# Go Coding Plugin

An AI plugin by **Cadasto B.V.** that teaches AI coding assistants **idiomatic Go coding standards** — formatting, naming, error handling, concurrency, testing, and project layout — through skills, an agent, three hooks (session-start, format-on-save, skill-nudge), and a Cursor rule. It targets **both Claude Code and Cursor** from a single shared component set.

## Install

**Claude Code** — from the Cadasto marketplace:

```
/plugin marketplace add Cadasto/plugin-marketplace
/plugin install go-coding@cadasto
```

Or load a local working copy for a single session: `claude --plugin-dir /path/to/go-coding-plugin`.

**Cursor**: add this repository as a plugin (Settings → Plugins). See [`docs/install.md`](docs/install.md) for both hosts.

**Prerequisites** — the plugin installs without a Go toolchain, but its hooks and enforcement guidance expect **Go 1.26.4+** (Go 1.27 supported; its additions are flagged as hints) plus `gofmt`, `gofumpt`, `goimports`, and `gopls` on the host `PATH`. See [Host toolchain (minimal requirements)](docs/install.md#host-toolchain-minimal-requirements) for what each tool drives and copy-paste install commands.

## Component surface

| Component | Status | Purpose |
|-----------|--------|---------|
| Skill `go-coding` | shipped | Auto-invoked router: sends each Go topic to the enforcing tool and the focused skill below; recommends `gopls-lsp`. |
| Session-start hook | shipped | Detects a Go workspace (`go.mod`/`*.go`) and prints one standards line; dual-host. |
| Format-on-save hook | shipped | After each `Write`/`Edit` of a `*.go` file, runs `gofumpt -w` (or `gofmt -w -s`) on it; dual-host, host-only, silent no-op if no formatter is installed. |
| Skill-nudge hook | shipped | After each `Write`/`Edit` of a `*.go` file, names ONE matching go-coding skill for that edit, once per skill per session; dual-host — delivered as a hook `systemMessage` under Claude Code, a plain line under Cursor. |
| Skills `go-errors`, `go-concurrency`, `go-testing`, `go-idioms`, `go-layout` | shipped | Load-on-use standards — each rule cited, framed around the enforcing linter (`modernize`, `errorlint`, `-race`, …). `go-layout` also owns naming, doc comments, and exported-API shape. |
| Agent `go-reviewer` | shipped | Report-only, context-isolated Go reviewer for what linters miss; severity-ranked findings, no sub-agent dispatch. Its grant excludes `Write`/`Edit` but includes `Bash` to run the linters, so no-edit is a contract it keeps rather than a sandbox that enforces it. |
| Skill `/go-lint-setup` (user-invoked) | shipped | Slash-command skill — scaffold, adopt, or debug the golangci-lint v2 config in a repo. |
| Lint config `references/golangci.v2.yml` | shipped | Reference golangci-lint v2 config (`modernize` + stack linters). |
| Cursor rule `go-context.mdc` | shipped | `**/*.go`-scoped guidance mirroring the router for Cursor. |
| Scripts `scripts/hooks-test.sh`, `scripts/usage-report.py` | shipped | Dev tooling, not part of the installed component surface: a bash test harness for the hooks, and a stdlib-only adoption-report generator over local session transcripts. |

Guidance is grounded in authoritative sources — [Effective Go](https://go.dev/doc/effective_go), [Go Code Review Comments](https://go.dev/wiki/CodeReviewComments), the [Google](https://google.github.io/styleguide/go/) and [Uber](https://github.com/uber-go/guide) style guides — and the standard toolchain (`gofmt`/`gofumpt`, `go vet`, `staticcheck`, `golangci-lint`, `go test -race`).

## Using with subagent orchestrators

Subagents do not inherit the parent session's skills. A plan runner that dispatches implementers
and reviewers must say so in every brief:

- **Implementer brief:** "Before writing code, invoke the Skill tool with `go-coding:go-coding`, then
  the focused skills matching your diff (see its *Route, then load* table). Run `golangci-lint run`
  on every touched package before committing."
- **Reviewer brief:** "Before reading the diff, load `go-coding:go-coding` plus `go-errors`,
  `go-testing` and the skills the diff calls for; cite the rule a finding rests on. Do not dispatch
  `go-reviewer` — you are the review seat."

Use `go-reviewer` directly when no such seat exists (an ad-hoc "review this file" request).

## Development

No build step — the plugin is pure Markdown + JSON. Validate locally:

```bash
./scripts/validate.sh        # manifests, parity, paths, frontmatter, hooks, doc inventories, linters, fixers
./scripts/hooks-test.sh      # bash tests for hooks/session-start.sh + hooks/skill-nudge.sh
claude plugin validate .     # manifest + component structure
```

Beyond the shared structural checks, the validator enforces two invariants specific to this plugin: **advice equals tooling** — every linter a component teaches must be reachable from the reference config — and, when a Go toolchain at the floor minor is on `PATH`, the `go-idioms` **Fixer** column is verified against `go tool fix help`, so a renamed or retired fixer fails the build rather than shipping as advice.

## Documentation

- [docs/install.md](docs/install.md) — install on both hosts, and the Go toolchain each hook expects
- [docs/testing.md](docs/testing.md) — validate and dogfood
- [docs/versioning.md](docs/versioning.md) — SemVer policy and release steps
- [docs/authoring.md](docs/authoring.md) — skill / command / agent / rule authoring conventions

See [`AGENTS.md`](AGENTS.md) for contributor conventions.

## License

[MIT](LICENSE)
