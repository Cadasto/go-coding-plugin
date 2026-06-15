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

### Install (local working copy, for development)

```bash
claude plugin add /path/to/go-coding-plugin
```

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

Installing the plugin itself needs no Go toolchain — it is pure Markdown + JSON. But its **enforcement** layer only delivers value when the standard Go tools are on the host `PATH`: the `format-on-save` hook shells out to a formatter, the golangci-lint v2 reference config lists `gofumpt`/`goimports` as formatters, and the recommended official `gopls-lsp` plugin (`@claude-plugins-official`) drives `gopls`. The plugin targets **Go 1.25** + golangci-lint v2.

At minimum the host should provide:

| Tool | Provided by | Used for | If missing |
|------|-------------|----------|------------|
| **Go 1.25.x** | [go.dev/dl](https://go.dev/dl/) / package manager | everything; satisfies `go.mod` `go 1.25.x` | no toolchain at all |
| **`gofmt`** | the Go distribution | `format-on-save.sh` fallback (`gofmt -w -s`) | n/a — always ships with Go |
| **`gofumpt`** | `go install` | `format-on-save.sh` primary (`gofumpt -w`), stricter gofmt superset | hook degrades to `gofmt` |
| **`goimports`** | `go install` | `goimports` formatter in the golangci-lint v2 config (import grouping/pruning) | import-group formatting skipped |
| **`gopls`** (v0.21.1) | `go install` | the `gopls-lsp` plugin (defs/refs/diagnostics/rename/vulncheck) | no code intelligence |

### Install / upgrade Go (official tarball, Linux)

Pick the latest **1.25.x** patch from <https://go.dev/dl/> and the build matching your platform (`linux-amd64` shown):

```bash
# replace the version with the current latest 1.25.x patch
curl -fLO https://go.dev/dl/go1.25.11.linux-amd64.tar.gz
sudo rm -rf /usr/local/go                                  # remove any prior install (don't overlay)
sudo tar -C /usr/local -xzf go1.25.11.linux-amd64.tar.gz
export PATH=$PATH:/usr/local/go/bin                        # add to your shell profile if not already present
go version                                                 # → go version go1.25.11 linux/amd64
```

> macOS/Windows or a package manager (Homebrew `go`, `winget`, distro packages) work equally well — the only requirement is that `go version` reports **1.25.x**. `gofmt` is included in every Go distribution, so nothing extra is needed for the hook's fallback path.

### Install the supporting tools

`go install` drops binaries in `$(go env GOPATH)/bin` (default `~/go/bin`) — make sure that directory is on your `PATH`. Run these **after** Go is in place so they compile against your 1.25 toolchain:

```bash
go install mvdan.cc/gofumpt@latest                    # stricter gofmt superset (hook primary)
go install golang.org/x/tools/cmd/goimports@latest    # import grouping / pruning
go install golang.org/x/tools/gopls@v0.21.1           # language server for the gopls-lsp plugin (pinned: v0.21.1, verified against Go 1.25.x)
```

Verify:

```bash
go version            # → 1.25.x
command -v gofmt      # ships with Go (in GOROOT/bin)
gofumpt --version
command -v goimports  # goimports has no --version flag
gopls version        # → golang.org/x/tools/gopls v0.21.1
```

These are **host-only** dev tools; the plugin still works without them (the format hook degrades to `gofmt`, then to a silent no-op). Full-tree `golangci-lint` runs separately — often in a pinned container — so it does not depend on these host binaries.

## Hooks

The plugin ships two host-agnostic hooks (Claude `hooks/hooks.json`, Cursor `hooks/cursor-hooks.json`):

- **`session-start.sh`** — on session start, detects a Go workspace (`go.mod`/`*.go`) and prints one standards line.
- **`format-on-save.sh`** — after each edit of a `*.go` file (Claude `PostToolUse` on `Write`/`Edit`; Cursor `afterFileEdit`), runs **`gofumpt -w`** on that file, or **`gofmt -w -s`** when `gofumpt` is not installed. It is **host-only** (no container round-trip), **edits the file in place**, and is a **silent no-op** when no Go formatter is on `PATH` — so install `gofmt` (ships with Go) or `gofumpt` to benefit. It never blocks an edit. This is per-file formatting only; run `golangci-lint` and your tests via CI/`make` for full-tree checks.

> The Cursor wiring targets the `afterFileEdit` event; if your Cursor version exposes a different post-edit event or payload shape, adjust `hooks/cursor-hooks.json` and the path-extraction in `format-on-save.sh` accordingly.
