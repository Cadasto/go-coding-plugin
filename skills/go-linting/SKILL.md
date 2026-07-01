---
name: go-linting
description: golangci-lint v2 setup and adoption for Go. This skill should be used when the user configures, upgrades, or debugs Go linting — the `.golangci.yml` file, the golangci-lint v2 schema (the versioned config, the `linters.default` set, the separate formatters section), the `modernize` linter, or stack linters (errorlint, bodyclose, rowserrcheck, sqlclosecheck, noctx, contextcheck). Not for what individual idioms mean (use the `go-idioms` skill) or writing rules by hand.
---

# go-linting — golangci-lint v2

> **Bundled `references/` is at the plugin root** (beside `skills/`, two levels above this file) — *not* under this skill. Read `references/golangci.v2.yml` as `${CLAUDE_PLUGIN_ROOT}/references/golangci.v2.yml` on Claude Code, or `../../references/golangci.v2.yml` from this skill's directory, or Glob for the installed `references/golangci.v2.yml` (host-agnostic).

golangci-lint **v2** (Mar 2025) is the de-facto meta-linter and the deterministic core of this
plugin. Its schema changed from v1 — **v1 config will not parse**:

- Top-level `version: "2"` is required.
- `linters.default: standard | all | none | fast` selects the base set (no more `enable-all`).
  `standard` = errcheck, govet, ineffassign, staticcheck, unused.
- **Formatters moved to their own `formatters:` section** (gofmt/gofumpt/goimports are no longer
  "linters").

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
    - revive          # configurable golint successor
formatters:
  enable: [gofumpt, goimports]
```

## Adoption

- Run: `golangci-lint run`; auto-fix what's fixable (incl. `modernize` and formatters):
  `golangci-lint run --fix`.
- **Pin the version in CI** for reproducibility (the Cadasto Go repos pin `v2.11.4`); a version
  drift silently changes the rule set.
- `modernize` is the single highest-leverage linter — it operationalizes most `go-idioms` rules on
  the same engine as gopls/`go fix`, so the plugin's advice stays consistent with the toolchain. As
  of **Go 1.26** the rewritten `go fix ./...` runs that same modernizer suite from the toolchain
  itself; keep `modernize` in golangci-lint for CI reproducibility and to cover toolchains older
  than 1.26. Use golangci-lint built with a Go version ≥ the module's toolchain (Go 1.26 support
  landed in the golangci-lint releases built with 1.26).
- Adopt the shipped reference config `references/golangci.v2.yml`, or run `/go-lint-setup` to
  scaffold it into a repo (it won't overwrite an existing config without asking).

## Sources
- golangci-lint docs — <https://golangci-lint.run/docs/>
- v2 migration — <https://ldez.github.io/blog/2025/03/23/golangci-lint-v2/>
- `modernize` — <https://pkg.go.dev/golang.org/x/tools/go/analysis/passes/modernize>

---
*Decomposition inspired by [`samber/cc-skills-golang`](https://github.com/samber/cc-skills-golang) (MIT © 2026 Samuel Berthe); rules grounded in the sources above.*
