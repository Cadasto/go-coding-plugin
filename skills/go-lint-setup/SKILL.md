---
name: go-lint-setup
description: Scaffold the reference golangci-lint v2 config into a Go repo. This skill should be used when the user runs `/go-lint-setup` or asks to "set up", "scaffold", "add", or "bootstrap" golangci-lint or a `.golangci.yml` for a Go project — it writes the plugin's reference v2 config (modernize + stack linters) and will not overwrite an existing config unprompted. For understanding what the linters do or migrating a v1 config, use `go-linting`. Not for non-Go projects.
argument-hint: optional target path (defaults to .golangci.yml)
allowed-tools: Read, Write, Glob
---

# go-lint-setup — scaffold golangci-lint v2

Scaffold the plugin's reference **golangci-lint v2** config into the current repo so its linting
matches the `go-coding` standards. Single interaction.

Steps:

1. **Check for an existing config** — `.golangci.yml`, `.golangci.yaml`, `.golangci.toml`,
   `.golangci.json`. If one exists, do **not** overwrite it: show how it differs from the reference
   and ask before changing anything. If it's a **v1** config (no `version` key and/or an
   `enable-all`/top-level `linters:` list), warn that v1 will not parse under golangci-lint v2 and
   offer to migrate.
2. **Write** the config below to `.golangci.yml` (or the path given in `$ARGUMENTS`).
3. **Report how to run it:** `golangci-lint run`, and `golangci-lint run --fix` for the auto-fixable
   findings (`modernize` + the formatters). Suggest pinning the `golangci-lint` version in CI so the
   rule set is reproducible.

Config to write (mirrors `references/golangci.v2.yml` — keep the two in sync):

```yaml
version: "2"
linters:
  default: standard
  enable:
    - modernize
    - errorlint
    - bodyclose
    - rowserrcheck
    - sqlclosecheck
    - noctx
    - contextcheck
    - containedctx
    - perfsprint
    - revive
formatters:
  enable:
    - gofumpt
    - goimports
```

For what each linter does and why, see the `go-linting` skill.
