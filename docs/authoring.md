# Skill, Command, Agent, and Rule Authoring Conventions

The detailed companion to [AGENTS.md](../AGENTS.md) (which is authoritative); this expands on the
*how*. The shipped components are the reference examples.

## Naming & layout

- **Components are kebab-case** and namespaced `<plugin>:<component>` (e.g.
  `go-coding-plugin:go-errors`) — don't repeat the plugin's words in a component name. A component's
  frontmatter `name` MUST equal its directory (skills) or filename stem (agents);
  `scripts/validate.py` enforces this.
- `skills/<name>/SKILL.md` (includes user-invoked slash commands) · `agents/<name>.md` ·
  `rules/<name>.mdc`. Shared reference material (e.g. `references/golangci.v2.yml`) lives in
  top-level `references/`. The legacy `commands/<name>.md` layout is not used.

## Skill vs agent vs rule

- **Skill (auto-invoked)** — a load-on-use procedure or router. Only its `description` is always-on,
  so keep that lean (the instruction budget is finite). The `go-coding` router + the `go-*`
  standards skills are the model.
- **Skill (user-invoked / slash command)** — a thin one-shot `skills/<name>/SKILL.md` that also
  carries `argument-hint` + `allowed-tools`; use `$ARGUMENTS` in the body. Invoked as `/<name>`. See
  `/go-explain`, `/go-lint-setup`. (The legacy `commands/` folder is not used.)
- **Agent** — a context-isolated specialist. Use **`tools:`** (a YAML block list), **never**
  `allowed-tools:` — in an agent that key is silently ignored and the agent inherits *all* tools.
  See `go-reviewer` (read-only, no sub-agent dispatch).
- **Cursor rule** — a Cursor-only `.mdc` with `description` / `globs` / `alwaysApply` that mirrors a
  skill for the Cursor host. See `rules/go-context.mdc`.

## The `description` (the trigger)

For skills the `description` is always-on metadata: keep it lean (~50–75 words), third person —
*what + scope*, 3–5 representative triggers ("This skill should be used when…"), and a short
"Not for …" anti-trigger. For commands it's the one-line palette entry; pair it with `argument-hint`.

**YAML gotcha:** a `description` value with an unquoted `: ` (colon-space) — e.g. writing
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
