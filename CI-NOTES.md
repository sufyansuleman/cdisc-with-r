# CI Notes — documentation only, nothing is wired up

**No course in this family uses CI.** All courses render locally into
`docs/`, which is committed and served by GitHub Pages. This file
exists so that, if CI is ever added later, it is added with eyes open.

## Why there is no CI

CI on the Quarto + R stack has burned this project before: a drifting
`ubuntu-latest` image, no lockfile, packages compiling from source for
twenty minutes, and no cache. The failure modes cost hours and produce
nothing a local render does not. Content first.

## If CI is ever added, it needs ALL of these

- An `renv.lock` in the repo (dependency pinning is a precondition, not
  an option).
- P3M binary repos in `.Rprofile` so Linux runners install binaries,
  not source (see TEMPLATE-USAGE.md §3 — keep the OS-conditional form).
- `runs-on: ubuntu-22.04` — **never `ubuntu-latest`**. The `__linux__`
  P3M URL codename (`jammy` = 22.04) must match the runner image; when
  the runner moves, both move together, deliberately.
- `r-lib/actions/setup-renv@v2` (which caches the renv library) — never
  a bare `install.packages()` step.

## renv fallback ladder

renv is an environment layer, not a content layer — no `.qmd` knows it
exists, so it is removable at any time without touching content.
Escalate in this order:

1. `renv::status()` — usually the project is just out of sync →
   `renv::snapshot()`.
2. One package won't install → `renv::install("pkg")` or pin an older
   version. Don't fight the lockfile over one package.
3. Windows build failure → install Rtools44 (one-time fix; the most
   common Windows R failure).
4. Quarto can't see the library → confirm Quarto runs from the project
   directory; `.Rprofile` normally handles it.
5. **Escape hatch**: `renv::deactivate()` → renders against the system
   library; keep writing.
6. **Full retreat**: delete `renv.lock`, add `setup.R`, switch to
   SIMPLE mode. Zero content changes.

**Rule: if the dependency layer costs more than one hour, deactivate it
and keep writing. The course is the asset.**
