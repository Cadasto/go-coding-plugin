# Installing the Go Coding Plugin

> This plugin is pure Markdown + JSON — there is no build step and **no MCP server** to wire up.

This plugin is distributed for both [Claude Code](https://docs.claude.com/en/docs/claude-code/plugins) (`.claude-plugin/`) and [Cursor](https://cursor.com/docs/plugins) (`.cursor-plugin/`). Skill, agent, and rule content is shared; only the manifest and hook layer differ.

## Claude Code

### Install (from the Cadasto marketplace)

```
/plugin marketplace add Cadasto/plugin-marketplace
/plugin install go-coding@cadasto
```

The marketplace name is `cadasto`, so the plugin is addressed as `go-coding@cadasto`.

### Load a local working copy (for development)

```bash
claude --plugin-dir /path/to/go-coding-plugin
```

`--plugin-dir` loads the plugin from disk for **that session only** — it does not persist, which makes it the right tool for dogfooding an unreleased working copy. It is repeatable (`--plugin-dir A --plugin-dir B`) and also accepts a `.zip`.

Claude Code has **no `plugin add` subcommand**. `claude plugin install` resolves names from a configured marketplace, not filesystem paths, and `claude plugin marketplace add <path>` expects a marketplace manifest (`.claude-plugin/marketplace.json`) — which a single-plugin repository like this one does not have. For a persistent install, go through the marketplace above.

### Inspect / update

```bash
claude plugin validate .                 # manifest + component structure
claude plugin details go-coding   # component inventory + projected token cost
```

```
/plugin marketplace update cadasto
/plugin update go-coding
```

A session restart is required for an update to take effect.

## Cursor

Add this repository as a plugin (Cursor **Settings → Plugins**, via Git URL or local path). The repo root contains `.cursor-plugin/plugin.json`, which declares the `skills`, `agents`, `rules`, and `hooks` paths. After changing content locally, reload or reinstall the plugin so Cursor picks it up.

## Host toolchain (minimal requirements)

Installing the plugin itself needs no Go toolchain — it is pure Markdown + JSON. But its **enforcement** layer only delivers value when the standard Go tools are on the host `PATH`: the `format-on-save` hook shells out to a formatter, the golangci-lint v2 reference config lists `gofumpt`/`goimports` as formatters, and the recommended official `gopls-lsp` plugin (`@claude-plugins-official`) drives `gopls`. The plugin targets **Go 1.26.4+** + golangci-lint v2 as a hard floor — it does not carry fallback guidance for 1.25 or older modules.

At minimum the host should provide:

| Tool | Provided by | Used for | If missing |
|------|-------------|----------|------------|
| **Go 1.26.4+ (1.27.x recommended)** | [go.dev/dl](https://go.dev/dl/) / package manager | everything; satisfies a `go.mod` `go 1.26.x` or `1.27.x` directive; `go fix ./...` runs the modernizers | no toolchain at all |
| **`gofmt`** | the Go distribution | `format-on-save.sh` fallback (`gofmt -w -s`) | n/a — always ships with Go |
| **`gofumpt`** | `go install` | `format-on-save.sh` primary (`gofumpt -w`), stricter gofmt superset | hook degrades to `gofmt` |
| **`goimports`** | `go install` | `goimports` formatter in the golangci-lint v2 config (import grouping/pruning) | import-group formatting skipped |
| **`gopls`** (v0.22.x) | `go install` | the `gopls-lsp` plugin (defs/refs/diagnostics/rename/vulncheck) | no code intelligence |

### Install / upgrade Go (official tarball, Linux)

Pick the latest **1.27.x** patch (**go1.27.1** at time of writing) from <https://go.dev/dl/> and the build matching your platform (`linux-amd64` shown) — the plugin's floor is **Go 1.26.4 or newer**, so an existing 1.26.4+ toolchain also works and nothing below requires the upgrade:

```bash
# replace the version with the current latest 1.27.x patch (go1.27.1 at time of writing; 1.26.4+ also works)
curl -fLO https://go.dev/dl/go1.27.1.linux-amd64.tar.gz
sudo rm -rf /usr/local/go                                  # remove any prior install (don't overlay)
sudo tar -C /usr/local -xzf go1.27.1.linux-amd64.tar.gz
export PATH=$PATH:/usr/local/go/bin                        # add to your shell profile if not already present
go version                                                 # → go version go1.27.1 linux/amd64
```

> macOS/Windows or a package manager (Homebrew `go`, `winget`, distro packages) work equally well — the only requirement is that `go version` reports **1.26.4 or newer** (1.27.x recommended). `gofmt` is included in every Go distribution, so nothing extra is needed for the hook's fallback path.

### Install the supporting tools

`go install` drops binaries in `$(go env GOPATH)/bin` (default `~/go/bin`) — make sure that directory is on your `PATH`. Run these **after** Go is in place so they compile against your installed toolchain (1.26.4+ or 1.27.x):

```bash
go install mvdan.cc/gofumpt@latest                    # stricter gofmt superset (hook primary)
go install golang.org/x/tools/cmd/goimports@latest    # import grouping / pruning
go install golang.org/x/tools/gopls@v0.22.0           # language server for the gopls-lsp plugin (pinned: v0.22.x — the gopls line that adds Go 1.26 support; use @latest for the newest patch)
```

Verify:

```bash
go version            # → 1.27.x (or 1.26.4+ on the floor)
command -v gofmt      # ships with Go (in GOROOT/bin)
gofumpt --version
command -v goimports  # goimports has no --version flag
gopls version        # → golang.org/x/tools/gopls v0.22.x
```

These are **host-only** dev tools; the plugin still works without them (the format hook degrades to `gofmt`, then to a silent no-op). Full-tree `golangci-lint` runs separately — often in a pinned container — so it does not depend on these host binaries. On Go 1.27, that container/pin needs **golangci-lint ≥ v2.13.0** (released 2026-08-19, the release that added Go 1.27 support) — see <https://golangci-lint.run/docs/product/changelog/#2130>; anything older predates 1.27 support.

## Hooks

The plugin ships two host-agnostic hooks (Claude `hooks/hooks.json`, Cursor `hooks/cursor-hooks.json`):

- **`session-start.sh`** — on session start, detects a Go workspace (`go.mod`/`*.go`) and prints one standards line.
- **`format-on-save.sh`** — after each edit of a `*.go` file (Claude `PostToolUse` on `Write`/`Edit`; Cursor `afterFileEdit`), runs **`gofumpt -w`** on that file, or **`gofmt -w -s`** when `gofumpt` is not installed. It is **host-only** (no container round-trip), **edits the file in place**, and is a **silent no-op** when no Go formatter is on `PATH` — so install `gofmt` (ships with Go) or `gofumpt` to benefit. It never blocks an edit. This is per-file formatting only; run `golangci-lint` and your tests via CI/`make` for full-tree checks.

> The Cursor wiring targets the `afterFileEdit` event; if your Cursor version exposes a different post-edit event or payload shape, adjust `hooks/cursor-hooks.json` and the path-extraction in `format-on-save.sh` accordingly.
