---
name: go-linting
description: golangci-lint v2 setup and adoption for Go. This skill should be used when the user configures, upgrades, or debugs Go linting — the `.golangci.yml` file, the v2 schema (versioned config, `linters.default` set, separate formatters section, `linters.exclusions`), migrating a v1 config, `golangci-lint fmt`, suppressing a finding with `//nolint`, the `modernize` linter, or stack linters (errorlint, bodyclose, noctx, usetesting, …). Not for what individual idioms mean (use `go-idioms`) or writing rules by hand.
---

# go-linting — golangci-lint v2

> **Bundled `references/` is at the plugin root** (beside `skills/`, two levels above this file) — *not* under this skill. Read `references/golangci.v2.yml` as `${CLAUDE_PLUGIN_ROOT}/references/golangci.v2.yml` on Claude Code, or `../../references/golangci.v2.yml` from this skill's directory, or Glob for the installed `references/golangci.v2.yml` (host-agnostic).

golangci-lint **v2** (Mar 2025) is the de-facto meta-linter and the deterministic core of this
plugin. Its schema changed from v1 — **v1 config will not parse**:

- Top-level `version: "2"` is required.
- `linters.default: standard | all | none | fast` selects the base set (no more `enable-all`).
  `standard` = errcheck, govet, ineffassign, staticcheck, unused.
- **Formatters moved to their own `formatters:` section** (gofmt/gofumpt/goimports are no longer
  "linters"), with their settings under `formatters.settings`. `golangci-lint fmt` runs that section.
- **Exclusions moved under `linters`**: v1's `issues.exclude-rules` → `linters.exclusions.rules`,
  and `issues.exclude-dirs`/`exclude-files` → `linters.exclusions.paths`. `linters-settings` split
  into `linters.settings` + `formatters.settings`.
- **Don't hand-port a v1 config — run `golangci-lint migrate`.** It rewrites in place, keeps a
  `.golangci.bck.yml` backup, and takes `--format {yml,yaml,toml,json}`. It drops comments and
  unknown/deprecated keys, so re-add comments and diff the result.

## Reference config (v2)

```yaml
version: "2"
linters:
  default: standard
  enable:
    - modernize       # highest value: range-int, min/max, slices/maps, wg.Go, strings.Cut…
    - errorlint       # %w + errors.Is/As discipline
    - bodyclose       # unclosed http.Response.Body
    - rowserrcheck    # unchecked sql.Rows.Err
    - sqlclosecheck   # unclosed sql.Rows/Stmt
    - noctx           # HTTP/SQL without context
    - contextcheck    # context not propagated
    - containedctx    # context.Context stored in a struct
    - perfsprint      # fmt.Sprintf where a cheaper call exists
    - usetesting      # os.Setenv/os.Chdir/context.Background in tests → the t.* forms
    - nolintlint      # a //nolint must name a linter and carry a reason
    - revive          # configurable golint successor
formatters:
  enable: [gofumpt, goimports]
```

## Adoption

- Run: `golangci-lint run`; auto-fix what's fixable (incl. `modernize` and formatters):
  `golangci-lint run --fix`. `golangci-lint fmt` applies only the `formatters:` section.
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
  release built with Go ≥ your module's toolchain (1.26+) so it can parse the language version.
- **Bumping the pin:** run `--fix` first, then either land the leftover findings or add an explicit
  `linters.exclusions.rules` entry with a reason. If the pinned build rejects a linter name from the
  reference config, the pin is too old — bump it rather than deleting the linter.
- **Suppress narrowly, and say why.** `//nolint:errcheck // best-effort close on a read-only handle`
  — never a bare `//nolint` (it disables every linter on that line) and never a blanket
  file-level disable where a `linters.exclusions.rules` entry with a path pattern is the honest
  answer. `nolintlint` enforces the specific-and-explained form.
- `modernize` is the single highest-leverage linter — it operationalizes most `go-idioms` rules on
  the same engine as gopls/`go fix`, so the plugin's advice stays consistent with the toolchain. As
  of **Go 1.26** the rewritten `go fix ./...` runs that same modernizer suite from the toolchain
  itself; keep `modernize` in golangci-lint so CI enforces it reproducibly against the pinned
  version rather than whatever toolchain a developer happens to have.
- Adopt the shipped reference config `references/golangci.v2.yml`, or run `/go-lint-setup` to
  scaffold it into a repo (it won't overwrite an existing config without asking).

## Sources
- golangci-lint docs — <https://golangci-lint.run/docs/>; v1→v2 migration guide (`migrate`, key moves) — <https://golangci-lint.run/docs/product/migration-guide/>
- v2 announcement (`fmt`, `formatters`) — <https://ldez.github.io/blog/2025/03/23/golangci-lint-v2/>
- `modernize` — <https://pkg.go.dev/golang.org/x/tools/go/analysis/passes/modernize>

---
*Decomposition inspired by [`samber/cc-skills-golang`](https://github.com/samber/cc-skills-golang) (MIT © 2026 Samuel Berthe); rules grounded in the sources above.*
