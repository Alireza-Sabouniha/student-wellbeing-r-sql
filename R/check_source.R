# Run from the project root: Rscript R/check_source.R path/to/data.csv
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 1L) {
  stop("Supply data.csv extracted from the official journal supplement.")
}

read_source <- function(path) {
  read.csv(path, colClasses = "character", check.names = FALSE,
           na.strings = NULL, fileEncoding = "UTF-8-BOM")
}

exercise <- read_source("data/students.csv")
published <- read_source(args[1])
headers_match <- identical(names(exercise), tolower(names(published)))
stopifnot(headers_match)
names(published) <- tolower(names(published))
stopifnot(identical(exercise, published))

sample_counts <- table(factor(exercise$inter_dom, levels = c("Inter", "Dom", "")))
stopifnot(identical(as.integer(sample_counts), c(201L, 67L, 18L)))
cat(sprintf("Matched %d rows and %d columns in order.\n",
            nrow(exercise), ncol(exercise)))
print(sample_counts)
