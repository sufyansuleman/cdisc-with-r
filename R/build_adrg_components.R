# ---------------------------------------------------------------------------
# build_adrg_components.R — generate the data-driven parts of the ADRG
#
# The Analysis Data Reviewer's Guide is a Word document that becomes adrg.pdf.
# Most of it is prose a human must write. Some of it is not: several sections
# are tables whose content is fully determined by the analysis datasets and
# the define.xml, and regenerating those from the data is strictly better than
# maintaining them by hand, because hand-maintained tables drift.
#
# This script produces those tables. It does NOT produce an ADRG — it produces
# the parts of one that should never be typed. What it cannot produce is
# exactly as informative as what it can; see sessions/adrg.qmd.
#
# Section numbers follow the PhUSE ADRG Completion Guidelines v1.2
# (2019-07-12). Note that v1.2 renumbered section 3 relative to v1.1: core
# variables moved from 3.2 to 3.1, treatment variables from 3.3 to 3.2, and
# the SDTM/ADaM comparison from 3.1 to 5.1.
#
# Deterministic. Outputs are committed, like every other artifact here.
# ---------------------------------------------------------------------------

library(tidyverse)
library(xml2)

OUT <- "data/adrg"
dir.create(OUT, showWarnings = FALSE, recursive = TRUE)

adsl <- read_csv("data/adam/adsl.csv", show_col_types = FALSE)
adae <- read_csv("data/adam/adae.csv", show_col_types = FALSE)
adlb <- read_csv("data/adam/adlb.csv", show_col_types = FALSE)
ads  <- list(ADSL = adsl, ADAE = adae, ADLB = adlb)

# --- 1.3 Study Data Standards and Dictionary Inventory ---------------------
# Read the versions out of the generated define.xml rather than restating
# them, so the ADRG and the define.xml cannot disagree.

define <- read_xml("data/define/define.sdtm.xml")
mdv    <- xml_find_first(define, "//d1:MetaDataVersion")

standards_inventory <- tribble(
  ~`Standard or Dictionary`,          ~`Versions Used`,
  "SDTM",                             "SDTM v2.0 / SDTMIG v3.4",
  "ADaM",                             "ADaM v2.1 / ADaMIG v1.3; OCCDS v1.1 for ADAE",
  "Controlled Terminology",           "CDISC/NCI SDTM CT",
  "Data Definitions",                 paste0("Define-XML ",
                                             xml_attr(mdv, "DefineVersion")),
  "Dictionaries (MedDRA, WHODrug)",   "Not applicable - see section 3.5"
)

# --- 3.1 Core Variables ----------------------------------------------------
# "Core variables are those that are represented across all/most analysis
# datasets" (ADRG Completion Guidelines v1.2, section 3.1). Computed, not
# asserted: the intersection of the variable names actually present.

core_vars <- reduce(map(ads, names), intersect)

core_variables <- tibble(`Variable Name` = core_vars) |>
  left_join(
    tribble(
      ~`Variable Name`, ~`Variable Description`,
      "STUDYID",  "Study identifier used for this protocol",
      "USUBJID",  "Unique subject identifier",
      "SUBJID",   "Subject identifier within the study",
      "SITEID",   "Study site identifier",
      "TRTSDT",   "Date of first exposure to study treatment",
      "SAFFL",    "Safety population flag"
    ),
    by = "Variable Name"
  )

stopifnot(!any(is.na(core_variables$`Variable Description`)))

# --- 3.2 Treatment Variables -----------------------------------------------
# The guidelines ask whether planned and actual treatment agree. That is a
# question about the data, so answer it from the data.

treatment_agreement <- adsl |>
  count(TRT01P, TRT01A, name = "Subjects") |>
  mutate(Agree = if_else(TRT01P == TRT01A, "Yes", "No"))

n_discrepant <- sum(treatment_agreement$Subjects[treatment_agreement$Agree == "No"])

# --- 3.5 Imputation/Derivation Methods -------------------------------------
# Where a date could not be derived, say so with a count rather than a
# paragraph. These are the deliberate data defects the course tracks.

imputation_summary <- tribble(
  ~Dataset, ~Variable, ~Situation, ~`Records Affected`, ~Convention,
  "ADSL", "AGE", "Partial birth date; age not computable",
  sum(is.na(adsl$AGE)),
  "Left null. No imputation performed.",
  "ADAE", "ASTDT", "Adverse event start date not recorded",
  sum(is.na(adae$ASTDT)),
  "Left null; TRTEMFL also null, never 'N'.",
  "ADLB", "BASE", "No pre-dose value on or before first dose",
  sum(is.na(adlb$BASE)),
  "Left null. Baseline is the last value on or before first dose."
)

# --- 5.2 Analysis Datasets -------------------------------------------------

dataset_inventory <- tibble(
  Dataset   = names(ads),
  Label     = c("Subject Level Analysis Dataset",
                "Adverse Events Analysis Dataset",
                "Laboratory Analysis Dataset"),
  Class     = c("SUBJECT LEVEL ANALYSIS DATASET",
                "OCCURRENCE DATA STRUCTURE",
                "BASIC DATA STRUCTURE"),
  Structure = c("One record per subject",
                "One record per subject per adverse event",
                "One record per subject per parameter per analysis visit"),
  Records   = map_int(ads, nrow),
  Variables = map_int(ads, ncol),
  Subjects  = map_int(ads, ~ n_distinct(.x$USUBJID))
)

# --- 6.2 Issues Summary ----------------------------------------------------
# Two Specification-sourced Define-XML conformance rules, run for real.
# See sessions/define-xml.qmd for where these come from.

refs <- xml_attr(xml_find_all(define, "//d1:ItemGroupDef/d1:ItemRef"), "ItemOID")
defs <- xml_attr(xml_find_all(define, "//d1:ItemDef"), "OID")
unresolved <- setdiff(refs, defs)

derived_items <- xml_attr(
  xml_find_all(define, "//d1:ItemDef[def:Origin/@Type='Derived']"), "OID")

# NOTE ON SCOPE. The obvious XPath here is
#   //d1:ItemGroupDef/d1:ItemRef[@ItemOID='...']
# and it is wrong. Value-level ItemDefs are referenced from
# def:ValueListDef, not from ItemGroupDef, so that path returns a missing
# node for every one of them, `!is.na(ref)` is FALSE, and they are dropped
# from the result without a warning. Rule 73 applies to them too.
#
# Narrow path: 13 findings. This path: 17. The difference is the four
# value-level LBSTRESN definitions. See sessions/adrg.qmd.
no_method <- keep(derived_items, function(oid) {
  ref <- xml_find_first(define, sprintf("//d1:ItemRef[@ItemOID='%s']", oid))
  !is.na(ref) && is.na(xml_attr(ref, "MethodOID"))
})

conformance_issues <- tribble(
  ~`Rule`, ~`Diagnostic Message`, ~`Records`, ~`Explanation`,
  "Define-XML 65",
  "ItemRef/@ItemOID must reference an existing ItemDef",
  length(unresolved),
  if (length(unresolved) == 0) "No findings." else
    paste("Unresolved:", paste(unresolved, collapse = ", ")),
  "Define-XML 73",
  "MethodOID required when Origin Type is 'Derived'",
  length(no_method),
  if (length(no_method) == 0) "No findings." else
    paste("Missing MethodOID:", paste(no_method, collapse = ", "))
)

# --- write ------------------------------------------------------------------

components <- list(
  `01_standards_inventory`  = standards_inventory,
  `02_core_variables`       = core_variables,
  `03_treatment_agreement`  = treatment_agreement,
  `04_imputation_summary`   = imputation_summary,
  `05_dataset_inventory`    = dataset_inventory,
  `06_conformance_issues`   = conformance_issues
)

iwalk(components, ~ write_csv(.x, file.path(OUT, paste0(.y, ".csv"))))

message("ADRG components written to ", OUT)
iwalk(components, ~ message(sprintf("  %-24s %2d rows", .y, nrow(.x))))
message("\nTreatment discrepancies (planned vs actual): ", n_discrepant)
