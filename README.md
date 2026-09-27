# CDISC with R

*SDTM, ADaM and TLFs from scratch using a simulated Phase III trial*

[![DOI](https://zenodo.org/badge/1239168209.svg)](https://doi.org/10.5281/zenodo.22994995)

A free, self-paced, hands-on course on CDISC clinical data standards in
R. You take raw data from a simulated Phase III trial (codename
**GLPX-1**) and carry it all the way to submission-ready datasets and
outputs: SDTM domains, ADaM datasets, define-XML, tables, listings and
figures, and Dataset-JSON. All data is synthetic. No real patient
information appears anywhere in this repository.

Most CDISC courses hand you a finished SDTM domain and walk you through
its columns. This one hands you the raw export instead: five files, birth
dates recorded four different ways, one subject enrolled twice. You build the domain
yourself, decide what to do about the duplicate, and defend the
decision.

Every claim about a standard is cited to the section of the
Implementation Guide it comes from (`SDTMIG v3.4, §4.4.4`, `ADaMIG v1.3,
§3.3.8`), so you can check it, and so you learn where to look when the
next question arrives.

## Start here

**[Open the online book](https://sufyansuleman.github.io/cdisc-with-r/)**.
That is the main way to use the course. Everything in this repo is the
authoring source behind it.

New here? Go through it in this order:

1. **Setup**: tools, packages, and a reproducible workflow
2. **Part 1, Foundations**: why clinical data standards exist, and the
   GLPX-1 trial you will work with throughout
3. **Part 2, SDTM**: study data tabulation. Concepts, the DM domain,
   events and findings domains, and define-XML
4. **Part 3, ADaM**: analysis datasets. Concepts, ADSL, ADAE and ADLB
5. **Part 4, Outputs and Submission**: TLFs, the ADRG, and Dataset-JSON

## What you actually build

The trial is a simulated Phase III, randomised, double-blind,
placebo-controlled study of a fictional GLP-1 agent in type 2 diabetes:
400 subjects, 12 sites, 8 visits.

Working from its raw export, you build:

| Stage | Datasets | Some of what it covers |
|---|---|---|
| **SDTM** | DM, AE, LB, VS | `USUBJID` construction, the study-day rule (no day 0), controlled terminology, original vs standardised results, reference ranges |
| **ADaM** | ADSL, ADAE, ADLB | population flags, treatment dates, treatment emergence (`TRTEMFL`), occurrence flags, `PARAM`/`AVAL`, and the baseline (`ABLFL`) every change is measured from |
| **Outputs** | TLFs, define.xml, ADRG, Dataset-JSON | what a reviewer actually receives, and the two file formats it travels in |

The simulator plants a small number of deliberate data defects: a
duplicated lab record, a missing start date, a sex value that disagrees
between two sources. Learning to find and resolve those is most of the
job, so the course resolves them on the page rather than shipping clean
data.

## Status

**All sessions are written.** Prose written, every code chunk executed
against the repository's data, every standards claim cited to its
Implementation Guide section, every exercise built on computed numbers:

- Setup
- Part 1: Why Standards, The GLPX-1 Trial
- Part 2: SDTM Concepts, DM, Events (AE), Findings (LB/VS), Define-XML
- Part 3: ADaM Concepts, ADSL, ADAE, ADLB
- Part 4: TLFs, Define-XML from a Specification Workbook, the ADRG,
  Dataset-JSON

Eleven exercises, one for every session that builds something.

The course targets the standard versions a 2024 study start would be
held to: **SDTMIG v3.4** (with SDTM v2.0), **ADaMIG v1.3** (with ADaM
v2.1), **OCCDS v1.1** for adverse events, **Define-XML v2.1** and
**Dataset-JSON v1.1**.

The book is maintained in the open, so corrections land continuously.

## Who this is for

- Statistical programmers and biostatisticians moving into clinical
  trial work in the pharmaceutical industry
- R users in clinical research who need to produce or consume
  CDISC-standard datasets
- Anyone preparing data for a regulatory submission who wants to
  understand the pipeline end to end

No prior CDISC knowledge is assumed. The course takes for granted that
you have never opened an Implementation Guide.

## What is in this repo

```
sessions/      the course sessions (authoring source for the book)
exercises/     exercise sets; solutions live in the private repo
notes/         internal authoring and strategy notes
R/             the build pipeline, in order:
                 simulate_trial.R        seeded raw export
                 build_sdtm.R            raw -> SDTM
                 build_adam.R            SDTM -> ADaM
                 author_spec_workbook.R  the specification workbook (run once)
                 build_define.R          workbook -> define.xml
                 build_adrg_components.R the ADRG's generated tables
                 build_dataset_json.R    SDTM -> .xpt and Dataset-JSON
                 palette.R               figure colours
data/raw/      the simulated raw export, defects included
data/sdtm/     built SDTM domains
data/adam/     built ADaM datasets
data/spec/     the SDTM specification workbook (source of truth for metadata)
data/define/   generated define.xml, its HTML rendering and check report
data/adrg/     the ADRG's data-driven tables
data/xpt/      SAS Transport v5 files
data/json/     Dataset-JSON files, plus the size comparison
docs/          the rendered book, served by GitHub Pages
```

The pipeline is deterministic: `simulate_trial.R` is seeded and nothing
downstream contains randomness, so `data/raw/`, `data/sdtm/` and
`data/adam/` regenerate byte-identically from source. Every generated
artifact is committed rather than ignored, so a session can read a finished
dataset, define.xml or transport file without rebuilding the chain.

The submission artifacts under `data/define/`, `data/xpt/` and `data/json/`
are the one exception, and deliberately so: each records the moment it was
written, so re-running the build changes a creation timestamp and nothing
else. `datasetJSONCreationDateTime` is a *required* attribute of the
standard. A file that claimed a constant creation time would be reproducible
and wrong.

`data/spec/SDTM_METADATA.xlsx` is the one artifact that is authored rather
than derived. It stands in for the specification a sponsor's standards group
maintains, and `build_define.R` reads it without ever writing it.

## Working with this repo

Clone, then open `cdisc-with-r.Rproj` in RStudio. That sets the working
directory to the project root, which every code chunk assumes.

Enable the commit hooks (once per clone):

```bash
git config core.hooksPath .githooks
```

This course pins its package versions with **renv**. Reproducibility is
part of the subject matter here, and `renv.lock` is itself a teaching
artifact. To set up:

```r
renv::restore()
```

then render the book with:

```bash
quarto render
```

The `.Rprofile` points Linux machines at Posit Public Package Manager
binaries so `renv::restore()` takes minutes rather than tens of minutes.
macOS and Windows get binaries from the standard repositories, with no
action needed.

The site is rendered locally into `docs/` and committed; GitHub Pages
serves `docs/`. There is no CI (see [notes/CI-NOTES.md](notes/CI-NOTES.md)).

## Exercises and solutions

Exercises are part of this public book. Worked solutions, extra
exercises, specs and instructor material live in the private paid-tier
repository.

## Contributing

This repo is the authoring source for the online book. Spotted a typo,
an unclear explanation, or a standards claim you think is wrong? Issues
and pull requests are welcome. Corrections to citations are especially
welcome.

## Citation

If you use this course in your teaching or research, please cite:

Suleman, S. (2026). *CDISC with R* (Version 1.0.0) [Course].
Zenodo. https://doi.org/10.5281/zenodo.22994995

BibTeX:

```bibtex
@misc{suleman_cdisc_with_r,
  author       = {Suleman, Sufyan},
  title        = {{CDISC with R: SDTM, ADaM and TLFs from scratch
                   using a simulated Phase III trial}},
  year         = {2026},
  version      = {1.0.0},
  publisher    = {Zenodo},
  doi          = {10.5281/zenodo.22994995},
  url          = {https://sufyansuleman.github.io/cdisc-with-r/}
}
```

That DOI always resolves to the most recent version. To cite this
release specifically, use `10.5281/zenodo.22994996`.

## Licence

Prose content: [CC BY-NC-SA 4.0](LICENSE). Code: [MIT](LICENSE-CODE).
