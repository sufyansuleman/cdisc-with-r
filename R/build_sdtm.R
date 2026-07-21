# build_sdtm.R — GLPX-001 raw -> SDTM datasets
#
# Reads the raw EDC/vendor CSVs in data/raw/ and writes standardised SDTM
# domains to data/sdtm/. This is the "production" companion to the
# teaching sessions: each SDTM-building session (sdtm-dm, sdtm-events,
# sdtm-findings) explains one domain from raw data, and this script
# reifies exactly those mappings so that later sessions (ADaM, TLFs) and
# any learner who clones the repo can read a finished, conformant SDTM
# without rebuilding the whole chain.
#
# DETERMINISTIC. The raw CSVs are fixed-seed output of simulate_trial.R;
# nothing here is random. data/sdtm/*.csv is therefore fully reproducible
# from simulate_trial.R + build_sdtm.R alone. The generated CSVs are
# committed (not gitignored) for that reason.
#
# Mappings follow SDTMIG v3.4 and the decisions recorded in the sessions.
# Domains grow as their sessions are written:
#   DM  -> sessions/sdtm-dm.qmd
#   AE  -> sessions/sdtm-events.qmd
#   LB, VS -> sessions/sdtm-findings.qmd   (added when that session lands)

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(readr)
  library(purrr)
  library(stringr)
})

# ---- shared helpers --------------------------------------------------------

# SDTMIG v3.4 §4.4.4: reference date is study day 1; the day before is -1;
# there is no study day 0. Not for duration arithmetic (use raw dates).
study_day <- function(date, ref) {
  date <- as.Date(date); ref <- as.Date(ref)
  d <- as.integer(date - ref)
  if_else(is.na(date) | is.na(ref), NA_integer_,
          if_else(date >= ref, d + 1L, d))
}

read_raw <- function(name) {
  read_csv(file.path("data", "raw", name), show_col_types = FALSE,
           col_types = cols(.default = col_character()))
}

STUDYID <- "GLPX001"

# ---- DM (Demographics; special-purpose) ------------------------------------
# See sessions/sdtm-dm.qmd for the reasoning behind each decision.

build_dm <- function() {
  dm_raw <- read_raw("dm_raw.csv")
  ex_raw <- read_raw("ex_raw.csv")

  dm_raw |>
    # D2: one DM record per subject — the row represents the person, not
    # the enrolment event. Ordered so the choice is deterministic.
    arrange(SUBJID, RANDDT) |>
    distinct(SUBJID, .keep_all = TRUE) |>
    # USUBJID built from immutable facts only (never SITEID: subject
    # 101-012 changed sites).
    mutate(
      STUDYID = STUDYID,
      DOMAIN  = "DM",
      USUBJID = paste(STUDYID, SUBJID, sep = "-")
    ) |>
    left_join(ex_raw |> select(SUBJID, EXSTDT, EXENDT), by = "SUBJID") |>
    mutate(
      RFSTDTC  = EXSTDT,                 # first exposure = the clock
      RFENDTC  = EXENDT,
      RFXSTDTC = EXSTDT,
      RFXENDTC = EXENDT,
      RFICDTC  = NA_character_,          # consent date not collected
      RFPENDTC = EXENDT,                 # last known contact in-study
      DTHDTC   = NA_character_,
      DTHFL    = NA_character_,
      # D1: partial/missing birth dates kept at true precision (no imputation)
      BRTHDTC  = na_if(BIRTHDT, ""),
      age_ok   = !is.na(BRTHDTC) & nchar(BRTHDTC) == 10,
      AGE      = if_else(age_ok,
                         floor(as.numeric(as.Date(RFSTDTC) - as.Date(BRTHDTC)) / 365.25),
                         NA_real_),
      AGEU     = if_else(age_ok, "YEARS", NA_character_),
      # D3: SEX from the EDC (site-entered source outranks the lab copy);
      # the lab-file disagreement for 111-003 is a logged query, not a
      # change to this value.
      SEX      = SEX,
      ARMCD    = case_when(ARM == "GLPX 10 mg" ~ "GLPX10",
                           ARM == "Placebo"    ~ "PBO"),
      ACTARM   = ARM,
      ACTARMCD = ARMCD,
      ARMNRS   = NA_character_,
      ACTARMUD = NA_character_
    ) |>
    select(STUDYID, DOMAIN, USUBJID, SUBJID,
           RFSTDTC, RFENDTC, RFXSTDTC, RFXENDTC, RFICDTC, RFPENDTC,
           DTHDTC, DTHFL, SITEID, BRTHDTC, AGE, AGEU, SEX, RACE, ETHNIC,
           ARMCD, ARM, ACTARMCD, ACTARM, ARMNRS, ACTARMUD, COUNTRY)
}

# ---- AE (Adverse Events; Events class) -------------------------------------
# See sessions/sdtm-events.qmd. One record per adverse event per subject.
# AETERM kept verbatim; AEDECOD (MedDRA) is left null — dictionary coding
# is a licensed step this course names but does not perform.

build_ae <- function(dm) {
  ae_raw <- read_raw("ae_raw.csv")

  ae_raw |>
    left_join(dm |> select(SUBJID, USUBJID, RFSTDTC), by = "SUBJID") |>
    # stable order for sequence numbering (D4's null start date sorts last)
    arrange(USUBJID, AESTDT, AETERM) |>
    group_by(USUBJID) |>
    mutate(AESEQ = row_number()) |>
    ungroup() |>
    transmute(
      STUDYID = STUDYID,
      DOMAIN  = "AE",
      USUBJID,
      AESEQ,
      AETERM,                              # verbatim; not modified
      AEDECOD = NA_character_,             # MedDRA PT — coding step, not done here
      AESEV,                               # MILD / MODERATE / SEVERE
      AESER,                               # Y / N — seriousness, not severity
      # raw outcome strings are not CT values; map to the OUT codelist
      AEOUT = case_when(
        AEOUT == "RECOVERED"     ~ "RECOVERED/RESOLVED",
        AEOUT == "NOT RECOVERED" ~ "NOT RECOVERED/NOT RESOLVED"
      ),
      AESTDTC = na_if(AESTDT, ""),         # D4: 103-199 has no start date -> null
      AEENDTC = na_if(AEENDT, ""),         # blank = ongoing at last contact
      AESTDY  = study_day(na_if(AESTDT, ""), RFSTDTC),
      AEENDY  = study_day(na_if(AEENDT, ""), RFSTDTC)
    )
}

# ---- entry point -----------------------------------------------------------

main <- function(out_dir = file.path("data", "sdtm")) {
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

  dm <- build_dm()
  ae <- build_ae(dm)

  sdtm <- list(dm = dm, ae = ae)

  iwalk(sdtm, \(df, name) {
    write_csv(df, file.path(out_dir, paste0(name, ".csv")), na = "")
    message(sprintf("%s: %d rows x %d cols", name, nrow(df), ncol(df)))
  })

  invisible(sdtm)
}

if (sys.nframe() == 0L) {
  main()
}
