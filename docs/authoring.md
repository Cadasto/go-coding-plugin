# Skill, command, agent, and rule authoring conventions

The detailed companion to [AGENTS.md](../AGENTS.md) (which is authoritative); this expands on the
*how*. The shipped components are the reference examples.

## Naming & layout

- **Components are kebab-case** and namespaced `<plugin>:<component>` (for example
  `go-coding:go-errors`) — don't repeat the plugin's words in a component name. A component's
  frontmatter `name` MUST equal its directory (skills) or filename stem (agents);
  `scripts/validate.py` enforces this.
- `skills/<name>/SKILL.md` (includes user-invoked slash commands) · `agents/<name>.md` ·
  `rules/<name>.mdc`. Shared reference material (for example `references/golangci.v2.yml`) lives in
  top-level `references/`. The legacy `commands/<name>.md` layout is not used.

## Skill vs agent vs rule

- **Skill (auto-invoked)** — a load-on-use procedure or router. Only its `description` is always-on,
  so keep that lean (the instruction budget is finite). The `go-coding` router + the `go-*`
  standards skills are the model.
- **Skill (user-invoked / slash command)** — a thin one-shot `skills/<name>/SKILL.md` that also
  carries `argument-hint` + `allowed-tools`; use `$ARGUMENTS` in the body. Invoked as `/<name>`. See
  `/go-lint-setup`. (The legacy `commands/` folder is not used.)
- **Agent** — a context-isolated specialist. Use **`tools:`** (a YAML block list), **never**
  `allowed-tools:` — in an agent that key is silently ignored and the agent inherits *all* tools.
  See `go-reviewer` (report-only, no sub-agent dispatch).
- **Cursor rule** — a Cursor-only `.mdc` with `description` / `globs` / `alwaysApply` that mirrors a
  skill for the Cursor host. See `rules/go-context.mdc`.

## The `description` (the trigger)

For skills the `description` is always-on metadata: keep it lean (~50–75 words), third person —
*what + scope*, 3–5 representative triggers ("This skill should be used when…"), and a short
"Not for …" anti-trigger. For commands it's the one-line palette entry; pair it with `argument-hint`.

**YAML gotcha:** a `description` value with an unquoted `: ` (colon-space) — for example writing
`version: "2"` inline — makes a real YAML parser read it as a nested mapping, so the component loads
with *empty* metadata (every field silently dropped). `claude plugin validate` catches this, and
`scripts/validate.py` guards against it too. Reword or quote the value.

## Body

- **Deterministic beats prose.** Point at the tool that enforces a rule (`gofmt`/`gofumpt`,
  `go vet`, a `golangci-lint` linter, `modernize`, `go test -race`) rather than re-deriving it.
  Ground every judgment rule in a cited source (Effective Go, Go Code Review Comments, the Google or
  Uber style guide, a `go.dev/blog` post, `pkg.go.dev`) — do not invent rules.
- Imperative voice; explain *why* a rule matters rather than relying on bare MUST/NEVER. Keep skill
  bodies focused — the always-on cost is the `description`; the body loads on use.

## Refreshing the standards baseline (source registry)

When asked to *refresh the skills against current Go practice*, re-read these sources in this order
and update the affected skill bodies — do not refresh from memory, and do not add a rule without a
citation. Everything the skills assert should be traceable to one of these.

**Tier 1 — normative, always check first**

| Source | URL | What it settles |
|---|---|---|
| Release notes for the baseline version | `https://go.dev/doc/go1.NN` | new APIs/idioms, experiments, removals |
| Release history | <https://go.dev/doc/devel/release> | what is actually *released* vs. draft — the baseline claim in AGENTS.md depends on this |
| Package docs | `https://pkg.go.dev/<pkg>` | exact signatures + the "added in go1.NN" annotation for every version gate |
| Effective Go | <https://go.dev/doc/effective_go> | foundational idiom |
| Go Code Review Comments | <https://go.dev/wiki/CodeReviewComments> | the review-rule catalogue (naming, errors, concurrency, API shape) |
| Doc comment syntax | <https://go.dev/doc/comment> | `gofmt`-formatted doc comments, doc links |

**Tier 2 — style guides (attribute when a rule comes from one, and name the document)**

- Google Go Style Guide — three documents of different weight, ranked by Google itself; a citation
  names which one:
  - the *Guide* — <https://google.github.io/styleguide/go/guide> — **normative and canonical**: the five ordered readability principles
    (clarity, simplicity, concision, maintainability, consistency) and, under simplicity, *least mechanism*. The
    tie-break order the router, the Cursor rule and the reviewer use — one identical sentence in all
    three, checked by `scripts/validate.py`.
  - *Style Decisions* — <https://google.github.io/styleguide/go/decisions> — **normative, not canonical**: the reviewer rulebook — naming,
    commentary, imports, errors, language, common libraries, useful test failures. The main Google
    source for skill rules.
  - *Best Practices* — <https://google.github.io/styleguide/go/best-practices> — **advisory**: patterns with trade-offs (test doubles, option structs,
    error structure, shadowing, table-test literals).
  Google-internal guidance is not adopted: flag conventions, Google's own logging library and
  verbosity levels, protocol-buffer stubs, and CLI library choices.
- Uber Go Style Guide — <https://github.com/uber-go/guide>

**Tier 3 — the enforcing tools (this is what keeps "advice == tooling" true)**

- **`go tool fix help` on the floor-version toolchain** — the authority for which fixers `go fix`
  actually ships (the plain rows in the `go-idioms` **Fixer** column); `go fix` blog —
  <https://go.dev/blog/gofix>
- `modernize` per-fixer docs — <https://pkg.go.dev/golang.org/x/tools/go/analysis/passes/modernize>
  — tracks x/tools **tip**, usually ahead of the toolchain: the source for **†** rows, never
  evidence that a fixer ships in `go fix`
- golangci-lint docs — <https://golangci-lint.run/docs/> · v1→v2 migration —
  <https://golangci-lint.run/docs/product/migration-guide/> · changelog (for the CI pin) —
  <https://golangci-lint.run/docs/product/changelog/>
- `go.dev/blog` for feature-specific posts (`synctest`, `testing-b-loop`, `slog`, `range-functions`,
  `examples`)
- **Linter rule catalogues** — when a skill says a tool catches something, the rule id or name comes
  from here, not from memory: `go vet` analyzers <https://pkg.go.dev/cmd/vet>; staticcheck checks
  <https://staticcheck.dev/docs/checks/>; revive rules <https://github.com/mgechev/revive/blob/master/RULES_DESCRIPTIONS.md>; errorlint
  <https://github.com/polyfloyd/go-errorlint>; gofumpt rules <https://github.com/mvdan/gofumpt#added-rules>;
  the golangci-lint linters index <https://golangci-lint.run/docs/linters/>

**Revision record** — the mutable sources, as last read. A refresh diffs each against its recorded
revision first, so it reads what changed rather than everything, then updates this table.

| Source | Revision read | Checked |
|---|---|---|
| Go Code Review Comments (`golang/wiki` mirror, `CodeReviewComments.md`) | `228ca0b` (2026-09-01) | 2026-09-09 |
| Google Go Style Guide (`google/styleguide`, `go/`) | `c098353` (2026-03-18) | 2026-09-09 |
| Uber Go Style Guide (`uber-go/guide`) | `1d60a91` (2026-04-15) | 2026-09-09 |
| revive rule descriptions (`mgechev/revive`, `RULES_DESCRIPTIONS.md`) | `803cd04` (2026-09-03) | 2026-09-09 |
| Effective Go, doc comment syntax, `cmd/vet`, package docs | versioned with the Go release — read at go1.27.1 | 2026-09-09 |

**Procedure**

1. Confirm the current *released* Go version (release history) — a draft `go1.NN` page is not a
   baseline. Guidance for an unreleased version goes in as one *italic, explicitly labelled*
   sentence (`*Go 1.NN (draft, expected …)*`), never as a rule.
   **The baseline is a hard floor** (currently **Go 1.26.4+**; Go 1.27 is supported too, with its
   additions flagged as hints rather than folded into the floor): recommend the modern form flat, with
   no "on 1.NN+ modules prefer…" hedging and no fallback branch for older toolchains. Keep the
   version annotation (`Since`, "(Go 1.24)") — that is provenance, and it tells a reader on an older
   module what a bump would buy. When the floor moves, delete the guidance below it.
2. Diff each `go-*` skill against Tier 1 for the baseline and the two prior versions — the common
   miss is a stdlib API that landed *after* a skill was written (`errors.AsType`, `t.ArtifactDir`).
3. Verify every version gate in `pkg.go.dev`'s "added in" annotation before writing a `Since` cell.
4. Re-check the Tier 3 tool names — a renamed or dropped fixer/linter turns a rule into a wrong
   command (`waitgroup` → `waitgroupgo`).
   **Run the tool, don't read about it:** when a floor-version toolchain is available,
   `go tool fix help` settles fixer names in one command — pkg.go.dev's modernize page tracks
   x/tools tip, which is usually ahead of what `go fix` ships; same idea for linters
   (`golangci-lint help linters` on the pinned build). `scripts/validate.py` enforces both
   halves: every linter taught in components must be enabled in `references/golangci.v2.yml`,
   and — when a floor-minor Go toolchain is on PATH (CI's matrix installs both `1.26.x` and
   `1.27.x`; locally it soft-skips with a note) — the `go-idioms` Fixer column is verified against
   `go tool fix help`: plain names must be registered, † names must not be. An analyzer a skill
   teaches as *opt-in* — `shadow` in `go-idioms` — is the deliberate exception to the first half: it
   is taught together with the config line that switches it on, and is not added to the reference
   config at a refresh. The floor minor lives in `GO_FLOOR_MINOR` in the script and in the
   workflow's matrix floor entry (`1.26.x`) — move all three (docs baseline included) together.
   **Never hardcode a tool version in a component.** A named `golangci-lint` release rots within
   weeks and nobody remembers why it was chosen; the skills carry the *pin policy* (pin exactly, one
   source of truth, automated bump PR) plus the changelog URL, and let the consuming repo own the
   number. The same goes for `gopls`/`gofumpt` versions outside `docs/install.md`.
5. Keep the two copies of the reference lint config in sync: `references/golangci.v2.yml` and the
   scaffold block in `go-lint-setup`.
6. Run `python3 scripts/validate.py --check-links` — every cited URL must still resolve; a moved
   page is fixed in the same refresh.
7. Update the **Revision record** above, then record the refresh in **CHANGELOG.md** under
   `## [Unreleased]`.

## Dual-host parity

Skills, commands, and agents are shared by both hosts. The **Cursor** manifest
(`.cursor-plugin/plugin.json`) must declare each component path, plus a `.mdc` mirror wherever a
Cursor rule is wanted; **Claude** discovers the default folders automatically. Keep the two
manifests' `name`/`version`/`description`/`author` identical (`scripts/validate.py` checks parity),
and the Cursor hook command **workspace-relative** (`bash hooks/session-start.sh`), never
`${CLAUDE_PLUGIN_ROOT}`.

## Before committing

Run `./scripts/validate.sh` and `claude plugin validate .`, then test triggering locally — see
[testing.md](testing.md). When adding or renaming a component, sync **AGENTS.md**, **README.md**,
and **CHANGELOG.md** in lockstep.
