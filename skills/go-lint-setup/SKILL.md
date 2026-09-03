---
name: go-lint-setup
description: Scaffold the reference golangci-lint v2 config into a Go repo. This skill should be used when the user runs `/go-lint-setup` or asks to "set up", "scaffold", "add", or "bootstrap" golangci-lint or a `.golangci.yml` for a Go project — it writes the plugin's reference v2 config (modernize + stack linters) and will not overwrite an existing config unprompted, or asks why golangci-lint v2 rejects a config, about migrating a v1 config, which linters the default set enables, how to adopt modernize/errorlint in an existing repo, what `golangci-lint fmt` does, how to write a `linters.exclusions` rule, or how to suppress a finding with `//nolint`. Not for non-Go projects.
argument-hint: optional target path (defaults to .golangci.yml)
allowed-tools: Read, Write, Glob, Bash
---

# go-lint-setup — scaffold, adopt, or debug golangci-lint v2

> **Bundled `references/` is at the plugin root** (beside `skills/`, two levels above this file) — *not* under this skill. Read `references/golangci.v2.yml` as `${CLAUDE_PLUGIN_ROOT}/references/golangci.v2.yml` on Claude Code, or `../../references/golangci.v2.yml` from this skill's directory, or Glob for the installed `references/golangci.v2.yml` (host-agnostic).

Scaffold the plugin's reference **golangci-lint v2** config into a repo that has none, or adopt or
debug an existing config already in the repo — schema questions, migration, which linters,
`//nolint`, exclusions. Scaffolding is a single interaction.

Asked to set up or scaffold a config → Steps 1–3 below. Asked about an existing config (rejected
keys, migration, which linters, `//nolint`, exclusions) → skip to *Adopting or debugging an
existing config*; do not write a file.

Steps:

1. **Check for an existing config** — `.golangci.yml`, `.golangci.yaml`, `.golangci.toml`,
   `.golangci.json`. If one exists, do **not** overwrite it: show how it differs from the reference
   and ask before changing anything. If it's a **v1** config (no `version` key and/or an
   `enable-all`/top-level `linters:` list), warn that v1 will not parse under golangci-lint v2 and
   offer to migrate — the supported path is `golangci-lint migrate` (in-place, keeps a `.bck` backup,
   drops comments), not a hand-port.
2. **Write** the config below to `.golangci.yml` (or the path given in `$ARGUMENTS`).
3. **Report how to run it:** `golangci-lint run`, and `golangci-lint run --fix` for the auto-fixable
   findings (`modernize` + the formatters). Suggest pinning an exact `golangci-lint` version in CI in
   one place (the action's `version:` input) with an automated bump PR — see *Adopting or debugging
   an existing config* below; don't invent a version number here, point at the releases page.

Config to write (mirrors `references/golangci.v2.yml` — keep the two in sync):

```yaml
version: "2"
linters:
  default: standard
  enable:
    - modernize
    - errorlint
    - exhaustive
    - bodyclose
    - rowserrcheck
    - sqlclosecheck
    - noctx
    - contextcheck
    - containedctx
    - perfsprint
    - usetesting
    - nolintlint
    - revive
formatters:
  enable:
    - gofumpt
    - goimports
```

For what each linter does and why, see *Adopting or debugging an existing config* below, or the
inline comments in `references/golangci.v2.yml`.

## Adopting or debugging an existing config

golangci-lint **v2** (Mar 2025) changed the config schema from v1 — **a v1 config will not parse**:

- Top-level `version: "2"` is required.
- `linters.default: standard | all | none | fast` selects the base set (no more `enable-all`).
  `standard` = errcheck, govet, ineffassign, staticcheck, unused.
- **Formatters moved to their own `formatters:` section** (gofmt/gofumpt/goimports are no longer
  "linters"), with their settings under `formatters.settings`. `golangci-lint fmt` runs that section.
- **Exclusions moved under `linters`**: v1's `issues.exclude-rules` → `linters.exclusions.rules`,
  and `issues.exclude-dirs`/`exclude-files` → `linters.exclusions.paths`. `linters-settings` split
  into `linters.settings` + `formatters.settings`. A config that still uses the old key names —
  `issues:`, `linters-settings:`, `enable-all` — is v1 and needs `golangci-lint migrate` (Step 1
  above), not a hand-port; `migrate` rewrites in place, keeps a `.golangci.bck.yml` backup, and
  takes `--format {yml,yaml,toml,json}` — it drops comments and unknown/deprecated keys, so re-add
  comments and diff the result.

**Common breakage when bumping the pin:** run `--fix` first, then either land the leftover findings
or add an explicit `linters.exclusions.rules` entry with a reason. If the pinned build rejects a
linter name from the reference config, the pin is too old — bump it rather than deleting the linter.

**Adopting `modernize`:** it is the single highest-leverage linter in the reference set — it
operationalizes most `go-idioms` rules on the same engine as gopls/`go fix`, so the plugin's advice
stays consistent with the toolchain. As of **Go 1.26** the rewritten `go fix ./...` runs that same
modernizer suite from the toolchain itself; keep `modernize` in golangci-lint so CI enforces it
reproducibly against the pinned version rather than whatever toolchain a developer happens to have.
`errorlint` pairs with it in the reference config (`%w` + `errors.Is`/`AsType` discipline — see
`go-errors`).

**Go 1.27 needs golangci-lint ≥ v2.13.0** (released 2026-08-19 — the same day as Go 1.27 itself) for
Go 1.27 support; anything v2.12.x or earlier predates it — a compatibility floor, not a pin (see
*Discipline once adopted*). Source: <https://golangci-lint.run/docs/product/changelog/#2130>.

### Discipline once adopted

- **Pin an exact version in CI, in exactly one place — and keep the pin moving.** Upstream's own
  recommendation is a specific release, not `latest`: a new release can add or retune linters and
  turn every build red at once, with no code change to blame. Put the version in a single source of
  truth — the `golangci/golangci-lint-action` `version:` input (it also caches, and beats a plain
  binary install) or the install script's tag — never copied across several workflows and Makefiles.
  Then let Renovate/Dependabot raise the bump as its own PR, so the version stays current *and*
  every rule-set change arrives reviewable. This skill deliberately names no blessed version; read
  the changelog for the current line.
- **Install the release binary, not from source.** Upstream states that `go install`/`go get`, the
  tools pattern, and `tool` directives "aren't guaranteed to work" — they compile golangci-lint with
  whatever local Go version is around. Use the binary, the action, or the Docker image, from a
  release built with Go ≥ the module's toolchain (1.26+) so it can parse the language version.
- **Suppress narrowly, and say why.** `//nolint:errcheck // best-effort close on a read-only handle`
  — never a bare `//nolint` (it disables every linter on that line) and never a blanket
  file-level disable where a `linters.exclusions.rules` entry with a path pattern is the honest
  answer. `nolintlint` enforces the specific-and-explained form.

## Sources
- golangci-lint docs — <https://golangci-lint.run/docs/>; v1→v2 migration guide (`migrate`, key moves) — <https://golangci-lint.run/docs/product/migration-guide/>
- v2 announcement (`fmt`, `formatters`) — <https://ldez.github.io/blog/2025/03/23/golangci-lint-v2/>
- `modernize` — <https://pkg.go.dev/golang.org/x/tools/go/analysis/passes/modernize>

---
*Decomposition inspired by [`samber/cc-skills-golang`](https://github.com/samber/cc-skills-golang) (MIT © 2026 Samuel Berthe); rules grounded in the sources above.*
