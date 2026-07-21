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

# ---- LB (Laboratory Test Results; Findings class) --------------------------
# See sessions/sdtm-findings.qmd. One record per test per time point per visit
# per subject. LBNRIND is DERIVED from the result vs the vendor reference
# range (never hard-coded). Central-lab values are collected, not derived
# (LBDRVFL null), which is why a byte-perfect duplicate is a transmission
# artefact to remove, not a real second measurement.

VISIT_NUM <- c("SCREENING" = 1, "BASELINE" = 2, "WEEK 4" = 3, "WEEK 8" = 4,
               "WEEK 12" = 5, "WEEK 16" = 6, "WEEK 20" = 7, "WEEK 26" = 8)

# Operationally-derived baseline flag (SDTMIG v3.4 §4.5.9): the last
# non-missing value prior to RFXSTDTC, per subject per test, flagged "Y".
# The authoritative analysis baseline lives in ADaM; this is the consistent
# SDTM reference flag. (Derived inline in each build to keep it readable.)

build_lb <- function(dm) {
  lb_raw <- read_raw("lb_raw.csv")

  test_name  <- c(HBA1C = "Hemoglobin A1C", GLUC = "Glucose",
                  ALT = "Alanine Aminotransferase", CREAT = "Creatinine")
  panel_unit <- c(HBA1C = "%", GLUC = "mmol/L", ALT = "U/L", CREAT = "umol/L")

  lb_raw |>
    distinct() |>                       # D6: drop the byte-perfect duplicate
    left_join(dm |> select(SUBJID, USUBJID, RFSTDTC, RFXSTDTC),
              by = c("subjid" = "SUBJID")) |>
    mutate(
      STUDYID  = STUDYID,
      DOMAIN   = "LB",
      LBTESTCD = test,
      LBTEST   = unname(test_name[test]),
      # D7: recover the blank unit from the vendor's documented panel (all
      # other results for this test carry the same unit); logged as a query.
      LBORRES  = result,
      LBORRESU = if_else(is.na(unit) | unit == "", unname(panel_unit[test]), unit),
      LBSTRESC = result,                       # no unit conversion for these analytes
      LBSTRESN = as.numeric(result),
      LBSTRESU = LBORRESU,
      LBORNRLO = ref_lo, LBORNRHI = ref_hi,    # original-unit range (Char)
      LBSTNRLO = as.numeric(ref_lo),           # standard-unit range (Num)
      LBSTNRHI = as.numeric(ref_hi),
      # LBNRIND derived from result vs range — D5's 13.9 -> HIGH, not hard-coded
      LBNRIND  = case_when(
        as.numeric(result) > as.numeric(ref_hi) ~ "HIGH",
        as.numeric(result) < as.numeric(ref_lo) ~ "LOW",
        TRUE                                    ~ "NORMAL"),
      LBDRVFL  = NA_character_,                 # central-lab value = collected
      VISIT    = visit,
      VISITNUM = unname(VISIT_NUM[visit]),
      LBDTC    = colldt,
      LBDY     = study_day(colldt, RFSTDTC)
    ) |>
    group_by(USUBJID, LBTESTCD) |>
    mutate(
      dt_       = as.Date(LBDTC),
      pre_      = !is.na(dt_) & dt_ < as.Date(RFXSTDTC) & !is.na(LBORRES),
      mx_       = suppressWarnings(max(dt_[pre_])),
      LBLOBXFL  = if_else(pre_ & is.finite(mx_) & dt_ == mx_, "Y", NA_character_)
    ) |>
    ungroup() |>
    select(-dt_, -pre_, -mx_) |>
    arrange(USUBJID, LBDTC, LBTESTCD) |>
    group_by(USUBJID) |>
    mutate(LBSEQ = row_number()) |>
    ungroup() |>
    select(STUDYID, DOMAIN, USUBJID, LBSEQ, LBTESTCD, LBTEST,
           LBORRES, LBORRESU, LBSTRESC, LBSTRESN, LBSTRESU,
           LBORNRLO, LBORNRHI, LBSTNRLO, LBSTNRHI, LBNRIND,
           LBDRVFL, LBLOBXFL, VISITNUM, VISIT, LBDTC, LBDY)
}

# ---- VS (Vital Signs; Findings class) --------------------------------------
# See sessions/sdtm-findings.qmd (exercise). Structural twin of LB, but
# VSORRESU uses the VS-specific VSRESU codelist, not the generic UNIT.

build_vs <- function(dm) {
  vs_raw <- read_raw("vs_raw.csv")

  vs_name <- c(SYSBP = "Systolic Blood Pressure", DIABP = "Diastolic Blood Pressure",
               PULSE = "Pulse Rate", WEIGHT = "Weight", HEIGHT = "Height")

  vs_raw |>
    left_join(dm |> select(SUBJID, USUBJID, RFSTDTC, RFXSTDTC), by = "SUBJID") |>
    mutate(
      STUDYID  = STUDYID,
      DOMAIN   = "VS",
      VSTESTCD = TEST,
      VSTEST   = unname(vs_name[TEST]),
      VSORRES  = RESULT,
      VSORRESU = UNIT,                          # VSRESU codelist, not UNIT
      VSSTRESC = RESULT,
      VSSTRESN = as.numeric(RESULT),
      VSSTRESU = UNIT,
      VISIT    = VISIT,
      VISITNUM = unname(VISIT_NUM[VISIT]),
      VSDTC    = VSDT,
      VSDY     = study_day(VSDT, RFSTDTC)
    ) |>
    group_by(USUBJID, VSTESTCD) |>
    mutate(
      dt_       = as.Date(VSDTC),
      pre_      = !is.na(dt_) & dt_ < as.Date(RFXSTDTC) & !is.na(VSORRES),
      mx_       = suppressWarnings(max(dt_[pre_])),
      VSLOBXFL  = if_else(pre_ & is.finite(mx_) & dt_ == mx_, "Y", NA_character_)
    ) |>
    ungroup() |>
    select(-dt_, -pre_, -mx_) |>
    arrange(USUBJID, VSDTC, VSTESTCD) |>
    group_by(USUBJID) |>
    mutate(VSSEQ = row_number()) |>
    ungroup() |>
    select(STUDYID, DOMAIN, USUBJID, VSSEQ, VSTESTCD, VSTEST,
           VSORRES, VSORRESU, VSSTRESC, VSSTRESN, VSSTRESU,
           VSLOBXFL, VISITNUM, VISIT, VSDTC, VSDY)
}

# ---- entry point -----------------------------------------------------------

main <- function(out_dir = file.path("data", "sdtm")) {
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

  dm <- build_dm()
  ae <- build_ae(dm)
  lb <- build_lb(dm)
  vs <- build_vs(dm)

  sdtm <- list(dm = dm, ae = ae, lb = lb, vs = vs)

  iwalk(sdtm, \(df, name) {
    write_csv(df, file.path(out_dir, paste0(name, ".csv")), na = "")
    message(sprintf("%s: %d rows x %d cols", name, nrow(df), ncol(df)))
  })

  invisible(sdtm)
}

if (sys.nframe() == 0L) {
  main()
}
