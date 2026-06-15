# Go Coding Plugin

An AI plugin by **Cadasto B.V.** that teaches AI coding assistants **idiomatic Go coding standards** — formatting, naming, error handling, concurrency, testing, and project layout — through skills, an agent, session-start and format-on-save hooks, and a Cursor rule. It targets **both Claude Code and Cursor** from a single shared component set.

## Install

**Claude Code** — from the Cadasto marketplace:

```
/plugin marketplace add Cadasto/plugin-marketplace
/plugin install go-coding@cadasto
```

Or from a local working copy: `claude plugin add /path/to/go-coding-plugin`.

**Cursor**: add this repository as a plugin (Settings → Plugins). See [`docs/install.md`](docs/install.md) for both hosts.

**Prerequisites** — the plugin installs without a Go toolchain, but its hooks and enforcement guidance expect **Go 1.25.x** plus `gofmt`, `gofumpt`, `goimports`, and `gopls` on the host `PATH`. See [Host toolchain (minimal requirements)](docs/install.md#host-toolchain-minimal-requirements) for what each tool drives and copy-paste install commands.

## Component surface

| Component | Status | Purpose |
|-----------|--------|---------|
| Skill `go-coding` | shipped | Auto-invoked router: sends each Go topic to the enforcing tool and the focused skill below; recommends `gopls-lsp`. |
| Session-start hook | shipped | Detects a Go workspace (`go.mod`/`*.go`) and prints one standards line; dual-host. |
| Format-on-save hook | shipped | After each `Write`/`Edit` of a `*.go` file, runs `gofumpt -w` (or `gofmt -w -s`) on it; dual-host, host-only, silent no-op if no formatter is installed. |
| Skills `go-errors`, `go-concurrency`, `go-testing`, `go-idioms`, `go-linting`, `go-layout` | shipped | Load-on-use standards — each rule cited, framed around the enforcing linter (`modernize`, `errorlint`, `-race`, …). |
| Agent `go-reviewer` | shipped | Read-only, context-isolated Go reviewer for what linters miss; severity-ranked findings, no sub-agent dispatch. |
| Skills `/go-explain`, `/go-lint-setup` (user-invoked) | shipped | Slash-command skills — idiom/standard lookup; scaffold the golangci-lint v2 config into a repo. |
| Lint config `references/golangci.v2.yml` | shipped | Reference golangci-lint v2 config (`modernize` + stack linters). |
| Cursor rule `go-context.mdc` | shipped | `**/*.go`-scoped guidance mirroring the router for Cursor. |

Guidance is grounded in authoritative sources — [Effective Go](https://go.dev/doc/effective_go), [Go Code Review Comments](https://go.dev/wiki/CodeReviewComments), the [Google](https://google.github.io/styleguide/go/) and [Uber](https://github.com/uber-go/guide) style guides — and the standard toolchain (`gofmt`/`gofumpt`, `go vet`, `staticcheck`, `golangci-lint`, `go test -race`).

## Development

No build step — the plugin is pure Markdown + JSON. Validate locally:

```bash
./scripts/validate.sh        # dual-host parity + frontmatter (soft-skips if python3 is absent)
claude plugin validate .     # manifest + component structure
```

See [`docs/testing.md`](docs/testing.md) for the full validation story and [`AGENTS.md`](AGENTS.md) for contributor conventions.

## License

[MIT](LICENSE)
