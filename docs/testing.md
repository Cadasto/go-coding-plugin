# Testing and Validation

This is a pure-content repository — JSON manifests + Markdown components. There is no build
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
- **Standards skills** — a topic prompt should engage the matching skill (e.g. error wrapping → `go-errors`, a flaky time-based test → `go-testing`/`go-concurrency`, linter setup → `go-linting`).
- **`go-reviewer` agent** — ask for a Go code review; it returns severity-ranked findings and does not spawn sub-agents.
- **Slash commands (skills)** — `/go-explain <topic>` and `/go-lint-setup`.
- **Cursor rule** — in Cursor, open a `.go` file and confirm `go-context.mdc` attaches.

After editing content, reinstall (or restart the session) to pick up changes.
