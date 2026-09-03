# Testing and validation

This is a pure-content repository — JSON manifests + Markdown components, with no build
step or package manager. Testing means validating structure, then installing locally and
exercising the components.

## Validation

- **Manifest / component validation** — `./scripts/validate.sh` (also run by CI on every PR): checks both `plugin.json` manifests, dual-host parity (name/version/description/author agree), declared component paths, kebab-case names, hook-config JSON, and SKILL.md / agent / command frontmatter (including `name` == directory/filename, and that agents declare `tools:` not `allowed-tools:`). The wrapper runs `scripts/validate.py`; if Python 3 isn't installed it prints a warning and skips (exit 0) rather than failing — install `python3` for the full local check, or rely on `claude plugin validate .` and CI. CI pins Python so the deep check always runs there.
- **Official validator** — `claude plugin validate .`: checks the manifest and component structure (no extra dependencies).
- **Structural review** — run the `plugin-dev:plugin-validator` agent after creating or modifying components.
- **Skill quality review** — run the `plugin-dev:skill-reviewer` agent: description-triggering quality, progressive disclosure, content structure.
- **Token cost** — `claude plugin details go-coding` shows the inventory and projected token cost; keep skill/command metadata lean.

## Local triggering tests

Install from your working copy (see [install.md](install.md)), then exercise each component:

- **Session-start hook** — open a repo with a `go.mod`/`*.go`; one Go-standards line should print at session start (and nothing in a non-Go repo).
- **`go-coding` router** — ask for a Go review or idiom help; it should route to the enforcing tool and the focused skill.
- **Standards skills** — a topic prompt should engage the matching skill (for example error wrapping → `go-errors`, a flaky time-based test → `go-testing`/`go-concurrency`, linter setup → `go-lint-setup`).
- **`go-reviewer` agent** — ask for a Go code review; it returns severity-ranked findings and does not spawn sub-agents.
- **Slash commands (skills)** — `/go-explain <topic>` and `/go-lint-setup`.
- **Cursor rule** — in Cursor, open a `.go` file and confirm `go-context.mdc` attaches.

After editing content, reinstall (or restart the session) to pick up changes.

## Measuring adoption

The layout and concurrency skills, and the router's dispatch behavior, were shaped by
a usage analysis of local Claude Code session transcripts. `scripts/usage-report.py`
(stdlib-only) reproduces that measurement so adoption stays checkable over time:

```
python3 scripts/usage-report.py --since YYYY-MM-DD --out report.md
```

Run with no arguments to scan `~/.claude/projects` from the beginning and print the
report to stdout; `--since` narrows to a start date, `--out` writes the report to a
file instead. `--help` repeats the counting rules.

**Counted:** a `Skill` tool invocation whose `skill` input starts with `go-coding:`; a
`Task`/`Agent` tool invocation with `subagent_type` `go-coding:go-reviewer`; a user
`<command-name>` invocation naming a go-coding skill. Events are split into main-session,
subagent, and user-invoked, per month, and deduplicated by session.

**Not counted:** the SessionStart banner line, or skill-body text echoed back inside
tool results — only structured tool invocations and explicit slash-command text count.

**Target:** the focused standards skills (`go-errors`, `go-testing`, `go-idioms`,
`go-linting`, `go-lint-setup`, `go-layout`, `go-concurrency`) should load on at least
50% of sessions where the `go-coding` router itself loads, and `go-layout` /
`go-concurrency` specifically should show non-zero counts in any period where the
corresponding work (project layout/API design, or goroutines/channels/context) is
actually touched.
