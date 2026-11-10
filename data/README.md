# Data

`students.csv` is the CSV supplied with DataCamp's *Analyzing Students' Mental Health* exercise. It matches `data.csv` from the [official supplement](https://www.mdpi.com/2306-5729/4/3/124/s1) in all 286 rows and 50 columns after lowercasing column names. The [data descriptor](https://doi.org/10.3390/data4030124) identifies 268 survey responses and lists the dataset license as CC BY. The 18 additional rows lack an international/domestic label and do not enter the analysis.

The review bundle includes the CSV and excludes it from version control. To run without the DataCamp copy, extract `data.csv` from the published supplement, lowercase its headers, and save it as `data/students.csv`. In R, for example:

```r
data <- read.csv("path/to/data.csv", check.names = FALSE, fileEncoding = "UTF-8-BOM")
names(data) <- tolower(names(data))
write.csv(data, "data/students.csv", row.names = FALSE, na = "")
```

The main outcome variables are `todep` (PHQ-9 total) and `dep` (the paper's binary classification). The main predictors are `tosc` (social connectedness), `toas` (acculturative stress), and `stay` (years).
