# palette.R — the CDISC with R course palette.
#
# ONE place for course colours. Every figure sources this file and uses
# these values; no figure hard-codes a colour. This is a PALETTE, not a
# theme: plots keep the plain cosmo / theme_bw() look of the reference
# course. Do not grow this into a design system.
#
# Colourblind-safe by construction. Roughly 8% of a pharma audience cannot
# reliably separate red from green, and this course's later work (forest
# plots, TLF shells) leans on colour to carry meaning — so safety here is
# correctness, not taste.
#
#   - Categorical series -> Okabe-Ito qualitative palette (Okabe & Ito 2008),
#     designed to stay distinguishable under the common colour-vision
#     deficiencies.
#   - Continuous scales   -> viridis (ggplot2::scale_*_viridis_*), perceptually
#     uniform and equally CVD-safe. No extra package required.

# Okabe-Ito qualitative palette. Named so figures can refer to a hue by
# meaning rather than hex.
okabe_ito <- c(
  black          = "#000000",
  orange         = "#E69F00",
  sky_blue       = "#56B4E9",
  bluish_green   = "#009E73",
  yellow         = "#F0E442",
  blue           = "#0072B2",
  vermillion     = "#D55E00",
  reddish_purple = "#CC79A7",
  grey           = "#999999"
)

# Treatment-arm colours for GLPX-001. Blue / orange is the highest-contrast
# accessible pair in Okabe-Ito and reads clearly in greyscale too. Arms are
# also encoded by shape in every figure, so identity never rests on colour
# alone.
arm_colours <- c(
  "GLPX 10 mg" = unname(okabe_ito["blue"]),
  "Placebo"    = unname(okabe_ito["orange"])
)
