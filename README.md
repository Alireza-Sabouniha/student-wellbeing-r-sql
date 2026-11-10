# Student Well-Being in Japan

A DataCamp SQL exercise grew into a replication in R of a 2019 study on depressive symptoms among university students in Japan. I used the published survey data to check which findings held up under a different way of measuring statistical uncertainty.

**[Download the HTML report](docs/index.html?raw=true)** and open it in your browser to see the charts, results, and an explanation of what they mean. The report is self-contained.

## What I found

- **Social connectedness.** Among international students, those who reported feeling more connected also tended to report fewer depressive symptoms.
- **Stress from adapting to a different culture.** The estimated association with symptoms stayed positive. With robust standard errors, the confidence interval included zero, so the evidence for a positive association was less clear.
- **Length of stay.** Accounting for duration made little difference to the estimated associations for connectedness or stress.

The analysis describes associations among respondents to a survey at one university.

## Reproduce the analysis

1. Clone or download this repository. Follow the [data instructions](data/README.md) to obtain the published survey data and save it as `data/students.csv`. The project uses all 268 survey responses.
2. With R (4.1 or later) and RStudio installed, open `student-wellbeing.Rproj` and run this in the RStudio Console.

   ```r
   source("render.R")
   ```

3. Open `docs/index.html`. The script installs any missing R packages from CRAN, runs the analysis and SQL cross-check, and rebuilds the HTML report. The installation step needs an internet connection and permission to write to an R package library. You can also run `Rscript render.R` from the project folder if R and Pandoc are on your PATH.

## Project files

| File | Purpose |
| :--- | :--- |
| [`render.R`](render.R) | Dependency setup and report entry point |
| [`R/analysis.R`](R/analysis.R) | R replication, robust inference with `sandwich` and `lmtest`, and charts |
| [`R/check_source.R`](R/check_source.R) | Field-by-field comparison of the exercise data and journal supplement |
| [`sql/stay_summary.sql`](sql/stay_summary.sql) | Original SQL aggregation, run with SQLite |
| [`report.Rmd`](report.Rmd) | Report source |
| [`docs/index.html`](docs/index.html) | Rendered report |

## Sources

- [Nguyen, Le, and Meirmanov (2019)](https://doi.org/10.3390/su11030878)
- [Survey data descriptor and supplement](https://doi.org/10.3390/data4030124)
- [DataCamp Associate Data Analyst in SQL track](https://www.datacamp.com/tracks/associate-data-analyst-in-sql), *Analyzing Students' Mental Health* exercise
