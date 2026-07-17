# simulate_trial.R — GLPX-001 synthetic trial data generator
#
# GLPX-001 is a SIMULATED Phase III, randomised, double-blind,
# placebo-controlled trial of GLPX (a fictional GLP-1-class agent) in
# adults with type 2 diabetes: GLPX 10 mg once weekly vs placebo, 1:1,
# 26 weeks. Primary endpoint: change in HbA1c from baseline to week 26
# (central lab). Key secondary: percent change in body weight (vital
# signs). Every value produced here is synthetic. No real patient
# information is used, referenced, or derivable from this code or its
# output.
#
# Output: one CSV per raw source, written to data/raw/. These files
# imitate what a study team actually receives BEFORE standardisation:
# an EDC export (dm, ae, vs, ex; uppercase columns) and a central-lab
# vendor file (lb; lowercase columns, its own conventions). They are
# deliberately NOT SDTM — mapping them to SDTM is what the course
# teaches — so column names and values here must never be mistaken for
# CDISC standards.
#
# DELIBERATE DEFECTS — these are curriculum, never "clean them up":
#   D1  partial and missing birth dates          -> sessions/sdtm-dm.qmd
#   D2  one subject enrolled at two sites        -> sessions/sdtm-dm.qmd
#   D3  an AE with no start date                 -> sessions/sdtm-events-findings.qmd
#   D4  a lab result with a missing unit         -> sessions/sdtm-events-findings.qmd
#   D5  an out-of-range value that is real       -> sessions/sdtm-events-findings.qmd, sessions/adae-adlb.qmd
#   D6  a duplicate lab record                   -> sessions/sdtm-events-findings.qmd
#   D7  sex disagrees between EDC and lab file   -> sessions/sdtm-dm.qmd
#
# Reproducibility: fixed seed; identical output on every run.

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(purrr)
  library(tibble)
  library(readr)
})

set.seed(20260717)

# ---- Trial design parameters -----------------------------------------------

n_subjects <- 400
n_sites    <- 12
arms       <- c("GLPX 10 mg", "Placebo")

# Visit schedule: screening two weeks before dosing, then treatment visits.
visits <- tibble(
  visit    = c("SCREENING", "BASELINE", "WEEK 4", "WEEK 8",
               "WEEK 12", "WEEK 16", "WEEK 20", "WEEK 26"),
  visitday = c(-14L, 1L, 29L, 57L, 85L, 113L, 141L, 182L)
)
n_visits <- nrow(visits)

fmt_date <- function(x) format(x, "%Y-%m-%d")

# ---- Subject-level frame (internal; feeds every domain simulator) ----------

make_subjects <- function(n_subjects, n_sites, arms) {
  site_ids <- 100L + seq_len(n_sites)

  tibble(
    subjid  = sprintf("%03d-%03d", sample(site_ids, n_subjects, replace = TRUE),
                      seq_len(n_subjects)),
    arm     = sample(rep(arms, length.out = n_subjects)),
    sex     = sample(c("M", "F"), n_subjects, replace = TRUE,
                     prob = c(0.55, 0.45)),
    age     = pmin(pmax(round(rnorm(n_subjects, 58, 9)), 25), 84),
    randdt  = as.Date("2024-01-15") +
      sample(0:180, n_subjects, replace = TRUE),
    # ~8% discontinue early; data stops at a random day before week 26
    lastday = ifelse(runif(n_subjects) < 0.08,
                     sample(30:170, n_subjects, replace = TRUE), 182L)
  ) |>
    mutate(
      siteid  = substr(subjid, 1, 3),
      birthdt = randdt - round(age * 365.25) -
        sample(0:364, n_subjects, replace = TRUE),
      # baseline disease state
      hba1c_bl  = round(pmin(pmax(rnorm(n_subjects, 8.4, 0.9), 7.0), 11.0), 1),
      weight_bl = round(pmin(pmax(rnorm(n_subjects, 92, 15), 55), 160), 1),
      height    = round(ifelse(sex == "M", rnorm(n_subjects, 176, 7),
                               rnorm(n_subjects, 163, 6)), 0)
    )
}

# ---- Domain simulators ------------------------------------------------------

simulate_dm <- function(subjects) {
  dm <- subjects |>
    transmute(
      SUBJID  = subjid,
      SITEID  = siteid,
      BIRTHDT = fmt_date(birthdt),
      SEX     = sex,
      RACE    = sample(c("WHITE", "ASIAN", "BLACK OR AFRICAN AMERICAN", "OTHER"),
                       n(), replace = TRUE, prob = c(0.72, 0.14, 0.09, 0.05)),
      ETHNIC  = sample(c("NOT HISPANIC OR LATINO", "HISPANIC OR LATINO"),
                       n(), replace = TRUE, prob = c(0.91, 0.09)),
      COUNTRY = sample(c("DNK", "DEU", "GBR", "ESP", "POL"),
                       n(), replace = TRUE, prob = c(0.2, 0.3, 0.2, 0.15, 0.15)),
      RANDDT  = fmt_date(randdt),
      ARM     = arm
    )

  # D1: partial and missing birth dates (site staff couldn't obtain full
  # DOB). Teaches date imputation in sessions/sdtm-dm.qmd.
  dm$BIRTHDT[5]  <- substr(dm$BIRTHDT[5], 1, 7)   # "YYYY-MM"
  dm$BIRTHDT[23] <- substr(dm$BIRTHDT[23], 1, 7)
  dm$BIRTHDT[57] <- substr(dm$BIRTHDT[57], 1, 4)  # "YYYY"
  dm$BIRTHDT[141] <- ""                            # missing entirely

  # D2: subject 12 was screened at one site, moved, and was enrolled
  # again at another site under the same subject number — two DM rows,
  # same SUBJID, different SITEID. Teaches the one-row-per-subject rule
  # in sessions/sdtm-dm.qmd.
  dup <- dm[12, ]
  dup$SITEID <- ifelse(dm$SITEID[12] == "101", "108", "101")
  dup$RANDDT <- fmt_date(as.Date(dm$RANDDT[12]) + 21)
  dm <- bind_rows(dm, dup) |> arrange(SUBJID)

  dm
}

simulate_ae <- function(subjects) {
  # Per-arm incidence: GI and hypoglycaemia events are more frequent on
  # GLPX, as expected for the drug class.
  dictionary <- tribble(
    ~term,                     ~p_glpx, ~p_pbo,
    "Nausea",                    0.28,   0.08,
    "Vomiting",                  0.12,   0.04,
    "Diarrhoea",                 0.18,   0.09,
    "Decreased appetite",        0.15,   0.03,
    "Constipation",              0.10,   0.06,
    "Headache",                  0.12,   0.11,
    "Dizziness",                 0.08,   0.06,
    "Hypoglycaemia",             0.09,   0.04,
    "Injection site reaction",   0.10,   0.02,
    "Nasopharyngitis",           0.14,   0.13
  )

  ae <- pmap_dfr(subjects, function(subjid, arm, randdt, lastday, ...) {
    p <- if (arm == "GLPX 10 mg") dictionary$p_glpx else dictionary$p_pbo
    hit <- runif(nrow(dictionary)) < p
    if (!any(hit)) return(NULL)
    events <- dictionary$term[hit]
    onset  <- sample(seq_len(max(lastday - 7, 14)), length(events), replace = TRUE)
    dur    <- pmax(1, rgeom(length(events), 0.15))
    tibble(
      SUBJID  = subjid,
      AETERM  = events,
      AESTDT  = fmt_date(randdt + onset),
      AEENDT  = ifelse(onset + dur > lastday, "",          # ongoing at last contact
                       fmt_date(randdt + onset + dur)),
      AESEV   = sample(c("MILD", "MODERATE", "SEVERE"), length(events),
                       replace = TRUE, prob = c(0.62, 0.31, 0.07)),
      AESER   = "N",
      AEOUT   = ifelse(onset + dur > lastday, "NOT RECOVERED", "RECOVERED")
    )
  })

  # Verbatim terms arrive as free text: uneven case and one misspelling,
  # as they genuinely do from sites. Teaches coding/cleaning discussions.
  i <- sample(nrow(ae), 25)
  ae$AETERM[i[1:12]]  <- toupper(ae$AETERM[i[1:12]])
  ae$AETERM[i[13:22]] <- tolower(ae$AETERM[i[13:22]])
  ae$AETERM[i[23]]    <- "Diarrea"
  ae$AETERM[i[24]]    <- "nausea and vomitting"

  # One severe hypoglycaemia requiring hospitalisation: the trial's only
  # serious AE. Teaches seriousness vs severity in sessions/adae-adlb.qmd.
  sev <- which(ae$AETERM == "Hypoglycaemia")[1]
  ae$AESEV[sev] <- "SEVERE"
  ae$AESER[sev] <- "Y"

  # D3: one AE reported by phone; the start date was never obtained.
  # Teaches missing-date handling in sessions/sdtm-events-findings.qmd.
  ae$AESTDT[nrow(ae) %/% 2] <- ""

  arrange(ae, SUBJID, AESTDT)
}

simulate_lb <- function(subjects, visits) {
  # Central-lab vendor file: lowercase columns, its own conventions,
  # carries its own demographics (which is how D7 becomes possible).
  panel <- tribble(
    ~test,    ~unit,     ~mean_f,  ~sd,
    "HBA1C",  "%",        NA,      0.25,   # trajectory handled below
    "GLUC",   "mmol/L",   9.6,     1.1,
    "ALT",    "U/L",      27,      8,
    "CREAT",  "umol/L",   NA,      9       # sex-dependent mean below
  )

  grid <- subjects |>
    select(subjid, sex, arm, randdt, lastday, hba1c_bl) |>
    crossing(visits) |>
    filter(visitday <= lastday) |>
    crossing(select(panel, test, unit, sd))

  lb <- grid |>
    mutate(
      # treatment effect on HbA1c: GLPX falls ~1.4 points by week 26,
      # placebo drifts down ~0.3; other analytes stay flat around their
      # physiological mean. TODO: refine trajectories when the TLF
      # session needs specific table values.
      frac   = pmax(visitday, 0) / 182,
      target = case_when(
        test == "HBA1C" & arm == "GLPX 10 mg" ~ hba1c_bl - 1.4 * frac,
        test == "HBA1C"                       ~ hba1c_bl - 0.3 * frac,
        test == "GLUC"  & arm == "GLPX 10 mg" ~ 9.6 - 2.1 * frac,
        test == "GLUC"                        ~ 9.6 - 0.4 * frac,
        test == "ALT"                         ~ 27,
        test == "CREAT" & sex == "M"          ~ 80,
        test == "CREAT"                       ~ 65
      ),
      result = round(pmax(target + rnorm(n(), 0, sd), 0.1),
                     ifelse(test %in% c("HBA1C", "GLUC"), 1, 0)),
      colldt = fmt_date(randdt + visitday + sample(-2:2, n(), replace = TRUE))
    ) |>
    transmute(subjid, sex, visit, colldt, test, result, unit)

  # D5: one screening HbA1c of 13.9% — far out of range and REAL: a
  # genuinely poorly controlled patient, not a data error. Teaches that
  # range checks flag values for review, not deletion
  # (sessions/sdtm-events-findings.qmd, sessions/adae-adlb.qmd).
  hi <- which(lb$test == "HBA1C" & lb$visit == "SCREENING")[7]
  lb$result[hi] <- 13.9

  # D4: one result arrived with the unit field blank.
  # Teaches unit reconciliation in sessions/sdtm-events-findings.qmd.
  lb$unit[which(lb$test == "GLUC")[40]] <- ""

  # D7: the lab file has this subject as "M"; the EDC has "F". One of
  # them is wrong and the mapping has to decide which. Teaches source
  # reconciliation in sessions/sdtm-dm.qmd.
  mismatch_id <- subjects$subjid[subjects$sex == "F"][1]
  lb$sex[lb$subjid == mismatch_id] <- "M"

  # D6: one record was transmitted twice by the vendor — a byte-perfect
  # duplicate. Teaches de-duplication in sessions/sdtm-events-findings.qmd.
  lb <- bind_rows(lb, lb[200, ])

  arrange(lb, subjid, colldt, test)
}

simulate_vs <- function(subjects, visits) {
  grid <- subjects |>
    select(subjid, arm, randdt, lastday, weight_bl, height) |>
    crossing(visits) |>
    filter(visitday <= lastday)

  vs <- grid |>
    mutate(
      frac   = pmax(visitday, 0) / 182,
      SYSBP  = round(rnorm(n(), 132 - ifelse(arm == "GLPX 10 mg", 3, 0) * frac, 10)),
      DIABP  = round(rnorm(n(), 82, 7)),
      PULSE  = round(rnorm(n(), 74 + ifelse(arm == "GLPX 10 mg", 2, 0) * frac, 8)),
      # key secondary endpoint: ~5% weight loss on GLPX vs ~0.6% on placebo
      WEIGHT = round(weight_bl *
                       (1 - ifelse(arm == "GLPX 10 mg", 0.05, 0.006) * frac) +
                       rnorm(n(), 0, 0.6), 1),
      VSDT   = fmt_date(randdt + visitday)
    ) |>
    select(SUBJID = subjid, VISIT = visit, VSDT, SYSBP, DIABP, PULSE, WEIGHT) |>
    pivot_longer(c(SYSBP, DIABP, PULSE, WEIGHT),
                 names_to = "TEST", values_to = "RESULT") |>
    mutate(UNIT = case_when(
      TEST %in% c("SYSBP", "DIABP") ~ "mmHg",
      TEST == "PULSE"               ~ "beats/min",
      TEST == "WEIGHT"              ~ "kg"
    ))

  # Height is measured once, at screening.
  ht <- subjects |>
    transmute(SUBJID = subjid, VISIT = "SCREENING",
              VSDT = fmt_date(randdt - 14), TEST = "HEIGHT",
              RESULT = height, UNIT = "cm")

  bind_rows(vs, ht) |> arrange(SUBJID, VSDT, TEST)
}

simulate_ex <- function(subjects) {
  subjects |>
    transmute(
      SUBJID  = subjid,
      DRUG    = ifelse(arm == "GLPX 10 mg", "GLPX", "PLACEBO"),
      DOSE    = ifelse(arm == "GLPX 10 mg", 10, 0),
      DOSEU   = "mg",
      FREQ    = "QW",
      EXSTDT  = fmt_date(randdt),
      EXENDT  = fmt_date(randdt + lastday)
    ) |>
    arrange(SUBJID)
}

# ---- Entry point ------------------------------------------------------------

main <- function(out_dir = file.path("data", "raw")) {
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

  subjects <- make_subjects(n_subjects, n_sites, arms)

  raw <- list(
    dm_raw = simulate_dm(subjects),
    ae_raw = simulate_ae(subjects),
    lb_raw = simulate_lb(subjects, visits),
    vs_raw = simulate_vs(subjects, visits),
    ex_raw = simulate_ex(subjects)
  )

  # na = "" so missing values land in the CSVs as true empty fields,
  # exactly as they arrive from an EDC or vendor transfer.
  iwalk(raw, \(df, name) write_csv(df, file.path(out_dir, paste0(name, ".csv")), na = ""))
  iwalk(raw, \(df, name) message(sprintf("%s: %d rows x %d cols", name, nrow(df), ncol(df))))

  invisible(raw)
}

if (sys.nframe() == 0L) {
  main()
}
