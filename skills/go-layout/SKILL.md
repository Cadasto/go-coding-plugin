---
name: go-layout
description: Go project layout and package design. This skill should be used when the user structures a Go module or names packages — `internal/`, `cmd/`, start-flat-then-grow, package naming, avoiding `util`/`common` grab-bags, or deciding whether hexagonal/DDD ceremony is warranted. Counters imported Java/C# structure. Not for build tooling or for non-layout idioms (→ `go-idioms`).
---

# go-layout — project & package structure

The Go community consensus is *minimalism*; resist imported ceremony.

## Rules

- **`internal/` is the one true consensus.** Packages under `internal/` cannot be imported from
  outside the module subtree — use it to keep implementation private while exporting a small surface.
- **Start flat; grow as needed.** A new module is often one package at the root. Add
  `cmd/<binary>/main.go` when you have multiple binaries and `internal/<pkg>/` when you need privacy
  — not before. `golang-standards/project-layout` is community-made, **explicitly not official and
  contested**; don't treat its deep tree as a starting requirement.
- **Package names are part of the API:** short, lowercase, single word, no underscores or
  camelCase. The caller writes `chi.NewRouter()`, so don't stutter (`chi.ChiRouter`). Avoid
  `util`, `common`, `helpers`, `base` grab-bags — name by what the package *provides*.
- **No Java/C# transplants:** no `*Manager`/`*Impl`/`*Factory` reflexes, no one-type-per-file rule,
  no interface-for-everything. Define interfaces *where they're consumed*, keep them small, and
  return concrete types.
- **Hexagonal / ports-and-adapters / DDD is a tool, not a default** — justified for larger services
  with real external-boundary complexity, overkill for a CLI or a small service.
- **Files:** one package per directory; `package foo` for `foo.go` + `foo_test.go`; use
  `package foo_test` for black-box tests that exercise only the exported API.

## Sources
- Effective Go — <https://go.dev/doc/effective_go>
- Code Review Comments (Package Names, Interfaces) — <https://go.dev/wiki/CodeReviewComments>
- Google Go Style Guide — <https://google.github.io/styleguide/go/>; `internal/` — <https://pkg.go.dev/cmd/go#hdr-Internal_Directories>

---
*Decomposition inspired by [`samber/cc-skills-golang`](https://github.com/samber/cc-skills-golang) (MIT © 2026 Samuel Berthe); rules grounded in the sources above.*
