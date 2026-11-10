if (!file.exists("report.Rmd")) {
  stop("Open student-wellbeing.Rproj before running render.R.", call. = FALSE)
}

if (!file.exists("data/students.csv")) {
  stop("Place students.csv in data/. See data/README.md for the source.", call. = FALSE)
}

required_packages <- c("readr", "dplyr", "ggplot2", "scales", "DBI",
                       "RSQLite", "knitr", "rmarkdown", "sandwich", "lmtest")
available <- vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)
missing_packages <- required_packages[!available]

if (length(missing_packages) > 0) {
  message("Installing missing R packages: ", paste(missing_packages, collapse = ", "))
  install.packages(missing_packages, repos = "https://cloud.r-project.org")

  available <- vapply(missing_packages, requireNamespace, logical(1), quietly = TRUE)
  if (any(!available)) {
    stop("R could not load these packages after installation: ",
         paste(missing_packages[!available], collapse = ", "),
         ". Check the installation messages above and run render.R again.",
         call. = FALSE)
  }
}

rmarkdown::render(
  input = "report.Rmd",
  output_file = "index.html",
  output_dir = "docs",
  envir = new.env(parent = globalenv()),
  encoding = "UTF-8"
)
