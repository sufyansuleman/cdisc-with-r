local({
  p3m <- if (Sys.info()[["sysname"]] == "Linux") {
    "https://packagemanager.posit.co/cran/__linux__/jammy/latest"
  } else {
    "https://packagemanager.posit.co/cran/latest"
  }
  options(repos = c(P3M = p3m, CRAN = "https://cloud.r-project.org"))
})
source("renv/activate.R")
