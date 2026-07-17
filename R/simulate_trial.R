# simulate_trial.R — GLPX-001 synthetic trial data generator (skeleton)
#
# Generates the raw data for GLPX-001, a SIMULATED Phase III,
# two-arm, multi-site clinical trial used throughout the course.
# Every value produced here is synthetic. No real patient information
# is used, referenced, or derivable from this code or its output.
#
# Output: one CSV per source dataset, written to data/raw/.
# Reproducibility: a fixed seed at the top makes every run identical.

set.seed(20260717)

# ---- Trial design parameters -----------------------------------------------

n_subjects <- 400            # total randomised subjects
n_sites    <- 12             # investigational sites
n_visits   <- 8              # scheduled visits per subject
arms       <- c("GLPX", "Placebo")   # two-arm design

# ---- Domain simulators ------------------------------------------------------
# Each function returns a data.frame shaped like a raw (pre-SDTM) capture
# of that data. Statistical detail is deliberately left TODO; the course
# fills these in as the relevant sessions are written.

simulate_dm <- function(n_subjects, n_sites, arms) {
  # Demographics: one row per subject.
  # TODO: subject IDs, site allocation, randomised arm, age/sex/race
  #       distributions, reference start/end dates.
  stop("TODO: implement simulate_dm()")
}

simulate_ae <- function(dm) {
  # Adverse events: zero or more rows per subject.
  # TODO: event terms from a small fixed dictionary, onset relative to
  #       treatment start, severity, seriousness, outcome.
  stop("TODO: implement simulate_ae()")
}

simulate_lb <- function(dm, n_visits) {
  # Laboratory results: one row per subject x visit x test.
  # TODO: a small panel of tests with reference ranges and plausible
  #       within-subject trajectories.
  stop("TODO: implement simulate_lb()")
}

simulate_vs <- function(dm, n_visits) {
  # Vital signs: one row per subject x visit x measurement.
  # TODO: heart rate, blood pressure, weight; visit-to-visit noise.
  stop("TODO: implement simulate_vs()")
}

simulate_ex <- function(dm) {
  # Exposure: dosing records per subject.
  # TODO: dose, unit, frequency, start/end dates consistent with DM.
  stop("TODO: implement simulate_ex()")
}

# ---- Entry point ------------------------------------------------------------

main <- function(out_dir = file.path("data", "raw")) {
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

  dm <- simulate_dm(n_subjects, n_sites, arms)
  write.csv(dm, file.path(out_dir, "dm_raw.csv"), row.names = FALSE)

  write.csv(simulate_ae(dm),           file.path(out_dir, "ae_raw.csv"), row.names = FALSE)
  write.csv(simulate_lb(dm, n_visits), file.path(out_dir, "lb_raw.csv"), row.names = FALSE)
  write.csv(simulate_vs(dm, n_visits), file.path(out_dir, "vs_raw.csv"), row.names = FALSE)
  write.csv(simulate_ex(dm),           file.path(out_dir, "ex_raw.csv"), row.names = FALSE)

  invisible(NULL)
}

if (sys.nframe() == 0L) {
  main()
}
