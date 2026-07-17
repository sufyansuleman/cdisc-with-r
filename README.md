# CDISC with R

*SDTM, ADaM and TLFs from scratch using a simulated Phase III trial*

A free, self-paced, hands-on course on CDISC clinical data standards in
R. You take raw data from a simulated Phase III trial (codename
**GLPX-001**) and carry it all the way to submission-ready datasets and
outputs: SDTM domains, ADaM datasets, define-XML, tables/listings/
figures, and Dataset-JSON. All data is synthetic — no real patient
information appears anywhere in this repository.

<!-- TODO: add the Zenodo DOI badge here after the first release is
minted, following the pattern in basic_statistics. -->

## Start here

**[Open the online book](https://sufyansuleman.github.io/cdisc-with-r/)** —
this is the main way to use the course. Everything in this repo is just
the authoring source behind it.

New here? Go through it in this order:

1. **Setup** — tools, packages, and a reproducible workflow
2. **Part 1 — Foundations** — why clinical data standards exist, and
   the GLPX-001 trial you will work with throughout
3. **Part 2 — SDTM** — study data tabulation: concepts, the DM domain,
   events and findings domains, and define-XML
4. **Part 3 — ADaM** — analysis datasets: concepts, ADSL, ADAE and ADLB
5. **Part 4 — Outputs and Submission** — TLFs, the ADRG, and
   Dataset-JSON

## Who this is for

- Statistical programmers and biostatisticians moving into clinical
  trial work in the pharmaceutical industry
- R users in clinical research who need to produce or consume
  CDISC-standard datasets
- Anyone preparing data for a regulatory submission who wants to
  understand the pipeline end to end

## Working with this repo

Clone, then enable the commit hooks (once per clone):

```bash
git config core.hooksPath .githooks
```

This course pins its package versions with **renv** — reproducibility
is part of the subject matter, and the `renv.lock` file is itself a
teaching artifact. To set up:

```r
renv::restore()
```

then render the book with:

```bash
quarto render
```

The `.Rprofile` points Linux machines at Posit Public Package Manager
binaries so `renv::restore()` takes minutes, not tens of minutes.
macOS and Windows get binaries from the standard repositories — no
action needed.

The site is rendered locally into `docs/` and committed; GitHub Pages
serves `docs/`. There is no CI (see CI-NOTES.md).

## Exercises and solutions

Exercises are part of this public book. Worked solutions, extra
exercises, specs and instructor material live in the private paid-tier
repository.

## Contributing

This repo (`sessions/`) is the authoring source for the online book.
Spotted a typo, unclear explanation, or have a suggestion? Issues and
PRs are welcome.

## Citation

If you use this course in your teaching or research, please cite:

Suleman, S. (2026). *CDISC with R*. Zenodo.
<!-- TODO: add DOI URL after the first Zenodo release. -->

## Licence

Prose content: [CC BY-NC-SA 4.0](LICENSE). Code: [MIT](LICENSE-CODE).
