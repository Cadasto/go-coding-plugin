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

## Hooks

The plugin ships two host-agnostic hooks (Claude `hooks/hooks.json`, Cursor `hooks/cursor-hooks.json`):

- **`session-start.sh`** — on session start, detects a Go workspace (`go.mod`/`*.go`) and prints one standards line.
- **`format-on-save.sh`** — after each edit of a `*.go` file (Claude `PostToolUse` on `Write`/`Edit`; Cursor `afterFileEdit`), runs **`gofumpt -w`** on that file, or **`gofmt -w -s`** when `gofumpt` is not installed. It is **host-only** (no container round-trip), **edits the file in place**, and is a **silent no-op** when no Go formatter is on `PATH` — so install `gofmt` (ships with Go) or `gofumpt` to benefit. It never blocks an edit. This is per-file formatting only; run `golangci-lint` and your tests via CI/`make` for full-tree checks.

> The Cursor wiring targets the `afterFileEdit` event; if your Cursor version exposes a different post-edit event or payload shape, adjust `hooks/cursor-hooks.json` and the path-extraction in `format-on-save.sh` accordingly.
