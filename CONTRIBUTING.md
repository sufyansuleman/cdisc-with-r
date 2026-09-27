# Contributing to CDISC with R

This course is in development in one specific sense: everything is
written and every number is executed, but no cohort has run it yet. The
explanations have not been tested against real questions from real
learners. If you know this material, you will find things to argue with.

Please do. Corrections are the most useful thing anyone can send.

## What is most valuable

In rough order:

1. **A standards claim that is wrong.** A section reference that does not
   say what the course says it says, a version that has moved on, an
   origin or derivation that would not survive review. These matter most
   because the whole course rests on being accurate about the standards.
2. **An explanation that lost you.** If you stopped following, that is a
   defect in the writing, not in you. Say where you stopped. You do not
   need to suggest a fix.
3. **Something a sponsor would not accept.** Practice differs between
   sponsors and that is fine. But if the course teaches something no
   sponsor would sign off, that is worth knowing.
4. **A missing trap.** A problem you have hit in real work that the
   course does not mention.
5. **Typos and broken links.** Genuinely welcome, and the fastest to
   merge.

## How to report it

**Open an [issue](../../issues)** for anything that is not a typo. An
issue first usually saves everyone work, because the fix is often not the
obvious one.

A useful report contains:

- **Where.** The session and, for code, which example or chunk.
- **What the course says**, quoted.
- **Why that is wrong**, with a citation if it is a standards claim. The
  Implementation Guide section number is what settles these: "SDTMIG
  v3.4 §6.3.5.6 says X" ends an argument that "I think it should be X"
  cannot.

For code, paste the actual error and the output of `sessionInfo()`.

**Setup problems are not issues.** They belong in
[Discussions](../../discussions), with `renv::status()` and
`sessionInfo()`.

## Pull requests

Welcome, and for small fixes go straight ahead.

For anything larger, open an issue first. The course has a deliberate
structure and some things that look like omissions are choices, which are
usually documented in the session itself.

If you do send a PR:

- **Keep it focused.** One fix per PR is much easier to review than five.
- **Cite standards claims** in the PR description.
- **Do not re-render the book.** `docs/` is committed, but the render is
  slow and produces a large diff. Change the `.qmd` and leave `docs/`
  alone; it gets rebuilt on release.
- **Follow the existing prose style.** 72-character wrap, sentence case
  headings, no em dashes.
- **Numbers must be executed, not asserted.** If you change something
  that produces a number, the number in the prose has to come from
  running the code. This is the rule the whole course is built on.

### Commit messages

Short, imperative, no trailing attribution lines. A commit hook enforces
the second part.

## What is out of scope

- **Submission strategy, agency interaction, or what a reviewer will look
  for.** The author has not run a submission, and the course says so
  rather than inventing plausible prose. Contributions that add this kind
  of material will be declined even when they are correct, unless they
  are cited to a published document.
- **Real data.** All data here is synthetic. Please never attach real
  study data, real patient information, or anything from an actual
  submission, even redacted.
- **CDISC reference material.** The Implementation Guides are
  copyrighted. Cite them by section; do not paste them or commit the
  PDFs.
- **Adding CI.** A deliberate decision, with reasons recorded in
  `notes/CI-NOTES.md`.

## Credit

Anyone whose issue or pull request changes the course appears in the
repository's contributor list. Substantial contributions are
acknowledged by name in the session they improved.

The course is archived on Zenodo with a DOI, so that credit is citable.
If you contribute something substantial and want to be listed as a
contributor in the citation metadata (`CITATION.cff`), say so in the
issue or PR and it will be added.

## Licence

Prose is [CC BY-NC-SA 4.0](LICENSE); code is [MIT](LICENSE-CODE). By
contributing you agree your contribution is released under the same
terms. Do not contribute material you cannot license this way, and note
that content under a ShareAlike licence from elsewhere cannot be
incorporated.
