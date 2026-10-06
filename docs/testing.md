# Testing and validation

This page is for contributors checking a change before a pull request or a release: what each validator checks, how to exercise the components by hand, and how to measure skill adoption. The repository is pure content (JSON manifests and Markdown components) with no build step or package manager, so testing means validating structure, then loading a working copy and exercising the components.

## Validation

- **Manifest / component validation**: `./scripts/validate.sh`, a wrapper around `scripts/validate.py`; see [What `scripts/validate.py` checks](#what-scriptsvalidatepy-checks). Without Python 3 the wrapper prints a warning and exits 0 instead of failing; install `python3` for the full local check, or rely on `claude plugin validate .` and CI. CI installs Python 3 and calls `python3 scripts/validate.py` directly, so the full check never silently skips there.
- **Validator self-test**: `python3 scripts/validate.py --selftest` (also run by CI) rebuilds each structural check's failure case in a temporary tree and requires the check to catch it, so a check that has quietly stopped checking cannot pass as green. It also exercises the link checker's fetch policy (HEAD then GET, one retry on a transport error or an HTTP 429/503, a 404 reported as broken) against a local HTTP server, with no network access.
- **Link check**: with `python3 scripts/validate.py --check-links`, every URL cited in skills, agents, rules, and docs must resolve. Needs the network, so it is its own switch; CI runs it weekly and on pull requests that touch those files, the checker itself, or its workflow (`.github/workflows/links.yml`).
- **Hook tests**: `./scripts/hooks-test.sh` (also run by CI on every PR) runs bash tests for all three hook scripts (`hooks/session-start.sh`, `hooks/format-on-save.sh`, `hooks/skill-nudge.sh`), including a can-fail self-test block that proves the negative-case helpers actually fail on bad input.
- **Official validator**: `claude plugin validate .` checks the manifest and component structure (no extra dependencies).
- **Structural review**: run the `plugin-dev:plugin-validator` agent after creating or modifying components.
- **Skill quality review**: run the `plugin-dev:skill-reviewer` agent for how well each description triggers, progressive disclosure, and content structure.
- **Token cost**: `claude plugin details go-coding` shows the inventory and projected token cost; keep skill metadata lean.

### What `scripts/validate.py` checks

Structural checks:

- Both manifests parse as JSON and carry the required fields, with a lowercase `name` of alphanumerics, hyphens, and periods, and they agree on `name`, `version`, `description`, and `author` (dual-host parity).
- Every component path a manifest declares exists inside the plugin directory, and skill, agent, command, and rule names are kebab-case.
- Hook-config JSON is valid, and hook parity holds: the same `hooks/*.sh` is wired for the equivalent event on both hosts, each wired script exists and is executable, and none is left unwired.
- SKILL.md, agent, and command frontmatter carries the required keys, with `name` equal to the directory or filename stem. **An agent that declares `allowed-tools:` fails**: the key is ignored, so the agent would inherit every tool.
- `rules/*.mdc` frontmatter carries a `description`, and no frontmatter value contains an unquoted `: ` or ` #`, which a YAML parser would read as a nested mapping or a comment, silently dropping the metadata.
- Doc component inventories: every shipped skill, agent, and hook is named in the docs that list them (`README.md`, `AGENTS.md`, and this page; `docs/install.md` for the hooks only).

Three invariants specific to this plugin:

- **Advice equals tooling**: every linter a component teaches (through `--enable-only=…` or "the `<name>` linter") must be enabled in `references/golangci.v2.yml`, so no skill tells an agent to rely on a linter the reference config does not ship; and the `/go-lint-setup` scaffold block must enable the same default, linters and formatters as that file, so a scaffolded repo lints with the config the components are checked against.
- **Fixer column**: when a Go toolchain at the floor minor (`GO_FLOOR_MINOR`) is on `PATH`, the `go-idioms` **Fixer** column is verified against `go tool fix help`: plain names must be registered, † names must not be, so a renamed or retired fixer fails the build instead of shipping as advice. Locally it soft-skips without that toolchain; CI installs it.
- **Tie-break sentence**: the Google readability tie-break sentence, which ranks clarity first and consistency last (`TIE_BREAK_SENTENCE` in the script holds the exact text), must appear verbatim in each of the `go-coding` router, `rules/go-context.mdc`, and `go-reviewer`.

## Local triggering tests

Load your working copy with `--plugin-dir` (see [install.md](install.md)), then exercise each component:

- **Session-start hook**: open a repo with a `go.mod`/`*.go`; one Go-standards line should print at session start (and nothing in a non-Go repo).
- **`go-coding` router**: ask for a Go review or idiom help; it should route to the enforcing tool and the focused skill.
- **Standards skills**: a topic prompt should engage the matching skill (for example error wrapping → `go-errors`, a flaky time-based test → `go-testing`/`go-concurrency`, linter setup → `go-lint-setup`).
- **Format-on-save hook**: save a deliberately mis-formatted `*.go` file; `format-on-save.sh` should reformat that one file in place (`gofumpt -w`, or `gofmt -w -s` when `gofumpt` is absent) and say nothing when neither is installed.
- **Skill-nudge hook**: edit a `_test.go` file; the nudge should name `go-coding:go-testing` (as `additionalContext` under Claude Code, which adds no visible transcript line; confirm delivery with `claude --debug`; a plain line under Cursor), and the model should **act** on it by loading the skill; delivery alone is not enough. A second edit to a `_test.go` file in the same session should be silent (once per skill per session), and so should an edit that does not itself touch the topic: a doc-comment fix in a file that defines a sentinel elsewhere must not claim the edit touches an error path.
- **`go-reviewer` agent**: ask for a Go code review; it loads `go-coding:go-coding` and the focused skills for the diff with the Skill tool, returns severity-ranked findings that cite them, and does not spawn sub-agents.
- **`/go-lint-setup`**: run it in a Go repo without a golangci-lint config and confirm it writes the reference v2 config; run it in a repo that already has one and confirm it does not overwrite it unprompted.
- **Cursor rule**: in Cursor, open a `.go` file and confirm `go-context.mdc` attaches.

After editing content, restart the session (or reload the plugin in Cursor) to pick up changes.

## Measuring adoption

The layout and concurrency skills, and the router's dispatch behaviour, were shaped by a usage analysis of local Claude Code session transcripts. `scripts/usage-report.py` (stdlib-only) reproduces that measurement so adoption stays checkable over time:

```bash
python3 scripts/usage-report.py --since YYYY-MM-DD --out report.md
```

Run with no arguments to scan `~/.claude/projects` from the beginning and print the report to stdout; `--since` narrows to a start date, `--out` writes the report to a file instead. `--help` repeats the counting rules.

**Counted:** a `Skill` tool invocation whose `skill` input starts with `go-coding:`; a `Task`/`Agent` tool invocation with `subagent_type` `go-coding:go-reviewer`; a user `<command-name>` invocation naming a go-coding skill. Events are split into main-session, subagent, and user-invoked, per month. The report renders two tables: "Per skill / agent" counts every event (so a skill loaded three times in one session counts three times), and "Sessions with >=1 event, per skill / agent" counts distinct sessions instead, so a skill loaded three times in one session counts once there. The 50% target below is read off the sessions table: (sessions loading a given focused skill) / (sessions loading `go-coding:go-coding`).

**Not counted:** the SessionStart banner line, or skill-body text echoed back inside tool results: only structured tool invocations and explicit slash-command text count. Nor is Cursor: the script reads Claude Code transcripts (`~/.claude/projects`) only, so the numbers describe adoption on one of the two hosts.

**Target:** the focused standards skills (`go-errors`, `go-testing`, `go-idioms`, `go-lint-setup`, `go-layout`, `go-concurrency`) should load on at least 50% of sessions where the `go-coding` router itself loads, and `go-layout` / `go-concurrency` specifically should show non-zero counts in any period where the corresponding work (project layout/API design, or goroutines/channels/context) is actually touched.
