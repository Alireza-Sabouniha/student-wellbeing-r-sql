library(readr)
library(dplyr)
library(ggplot2)

if (!file.exists("data/students.csv")) {
  stop("Place students.csv in data/ and run from the project root.")
}

students <- read_csv(
  "data/students.csv",
  col_select = c(inter_dom, stay, dep, todep, tosc, toas, gender, age,
                 english, japanese, intimate, religion),
  col_types = cols(
    inter_dom = col_character(), stay = col_integer(), dep = col_character(),
    todep = col_double(), tosc = col_double(), toas = col_double(),
    gender = col_character(), age = col_integer(), english = col_integer(),
    japanese = col_integer(), intimate = col_character(), religion = col_character()
  )
)
stop_for_problems(students)

sample <- students |>
  filter(!is.na(inter_dom)) |>
  mutate(
    group = factor(inter_dom, levels = c("Inter", "Dom"),
                   labels = c("International", "Domestic")),
    depression_flag = as.integer(dep == "Yes"),
    stay_group = factor(pmin(stay, 4), levels = 1:4,
                        labels = c("1 year", "2 years", "3 years", "4+ years"))
  )
stopifnot(identical(as.integer(table(sample$group)), c(201L, 67L)),
          all(sample$dep %in% c("Yes", "No")),
          all(sample$todep %in% 0:27))
international <- filter(sample, inter_dom == "Inter")
domestic <- filter(sample, inter_dom == "Dom")

group_summary <- sample |>
  group_by(group) |>
  summarise(n = n(), classified = sum(depression_flag),
            rate = 100 * mean(depression_flag), phq_mean = mean(todep),
            .groups = "drop")

stay_summary <- international |>
  group_by(stay_group) |>
  summarise(n = n(), rate = mean(depression_flag), .groups = "drop")

# Keep the original DataCamp aggregation as a reproducible SQL cross-check.
r_summary <- international |>
  group_by(stay) |>
  summarise(count_int = n(), average_phq = round(mean(todep), 2),
            average_scs = round(mean(tosc), 2), average_as = round(mean(toas), 2),
            .groups = "drop") |>
  arrange(desc(stay))

run_sql <- function(students) {
  connection <- DBI::dbConnect(RSQLite::SQLite())
  on.exit(DBI::dbDisconnect(connection))
  DBI::dbWriteTable(connection, "students", students)
  DBI::dbGetQuery(connection, paste(readLines("sql/stay_summary.sql"), collapse = "\n"))
}

stopifnot(isTRUE(all.equal(as.data.frame(r_summary), run_sql(students), tolerance = 1e-8)))

# Tables 4–5 and 6 of the paper. Table 6 transforms domestic PHQ-9.
correlations <- bind_rows(
  tibble(group = "International", connectedness = cor(international$todep, international$tosc),
         stress = cor(international$todep, international$toas),
         scales = cor(international$tosc, international$toas)),
  tibble(group = "Domestic", connectedness = cor(domestic$todep, domestic$tosc),
         stress = cor(domestic$todep, domestic$toas),
         scales = cor(domestic$tosc, domestic$toas))
)

paper_int <- lm(todep ~ tosc + toas, data = international)
paper_dom <- lm(sqrt(todep) ~ tosc + toas, data = domestic)
paper_ols <- tibble(
  group = rep(c("International", "Domestic"), each = 2),
  term = rep(c("Social connectedness", "Acculturative stress"), 2),
  published = c(-0.241, 0.033, -0.044, 0.014),
  reproduced = c(coef(paper_int)[2:3], coef(paper_dom)[2:3]),
  p_value = c(coef(summary(paper_int))[2:3, 4], coef(summary(paper_dom))[2:3, 4])
)

# Table 3 reconstruction for international students, with year 3 kept separate.
# The single respondent at Japanese level 5 perfectly predicts their outcome.
# Removing that separated level reproduces the finite Table 3 coefficients.
logit_sample <- international |>
  filter(japanese < 5) |>
  mutate(
    gender = factor(gender, levels = c("Male", "Female")),
    age_group = factor(case_when(age < 20 ~ "17–19", age == 20 ~ "20", TRUE ~ ">20"),
                       levels = c("17–19", "20", ">20")),
    english_group = factor(case_when(english <= 2 ~ "Low", english == 3 ~ "Average",
                                     english == 4 ~ "High", TRUE ~ "Native"),
                           levels = c("Low", "Average", "High", "Native")),
    japanese_group = factor(case_when(japanese <= 2 ~ "Low", japanese == 3 ~ "Average",
                                       TRUE ~ "High"),
                            levels = c("Low", "Average", "High"))
  )
paper_logit <- glm(
  depression_flag ~ gender + age_group + stay_group + english_group +
    japanese_group + intimate + religion,
  family = binomial(), data = logit_sample
)

# Use HC0 robust standard errors for the logit replication.
logit_vcov <- sandwich::vcovHC(paper_logit, type = "HC0")
logit_results <- lmtest::coeftest(paper_logit, vcov. = logit_vcov, df = Inf)
stay_terms <- grep("^stay_group", rownames(logit_results), value = TRUE)

# Test all stay groups together on the same estimation sample.
logit_without_stay <- update(paper_logit, . ~ . - stay_group,
                             data = model.frame(paper_logit))
stay_test <- lmtest::waldtest(logit_without_stay, paper_logit,
                              vcov = logit_vcov, test = "Chisq")
logit_stay_joint_p <- stay_test[2, "Pr(>Chisq)"]

logit_check <- tibble(
  comparison = c("2 years", "3 years", "4+ years"),
  published = c(0.80, 1.08, 1.04),
  published_p = c(0.103, 0.032, 0.106),
  reproduced = unname(logit_results[stay_terms, "Estimate"]),
  p_value = unname(logit_results[stay_terms, "Pr(>|z|)"])
)

# HC3 accounts for leverage when calculating robust intervals for OLS.
hc3_confint <- function(model) {
  robust_vcov <- sandwich::vcovHC(model, type = "HC3")
  lmtest::coefci(model, vcov. = robust_vcov, df = df.residual(model))
}

# Extension: do the Table 6 estimates survive adjustment for duration?
extended <- lm(todep ~ tosc + toas + stay_group, data = international)
adjusted_ci <- 10 * hc3_confint(extended)[c("tosc", "toas"), ]
extension_check <- tibble(
  term = c("Social connectedness", "Acculturative stress"),
  baseline = unname(10 * coef(paper_int)[2:3]),
  adjusted = unname(10 * coef(extended)[2:3]),
  lower = unname(adjusted_ci[, 1]),
  upper = unname(adjusted_ci[, 2])
)

ink <- "#182747"
blue <- "#3855bc"
orange <- "#a44c29"
paper <- "#ffffff"
group_legend <- setNames(paste(group_summary$group, group_summary$n, sep = " · "),
                         group_summary$group)
report_theme <- theme_minimal(base_size = 15) +
  theme(text = element_text(colour = ink),
        axis.text = element_text(colour = "#4e5a72"),
        panel.grid.minor = element_blank(),
        panel.grid.major = element_line(colour = "#e6ebf5", linewidth = 0.4),
        plot.background = element_rect(fill = paper, colour = NA),
        legend.position = "bottom")

# Step curves show the full distribution without choosing histogram bins.
distribution_plot <- ggplot(sample, aes(todep, colour = group)) +
  stat_ecdf(geom = "step", linewidth = 1.25, pad = FALSE) +
  scale_colour_manual(values = c(International = blue, Domestic = orange),
                      labels = group_legend) +
  scale_x_continuous(breaks = c(0, 5, 10, 15, 20, 25)) +
  scale_y_continuous(labels = scales::label_percent(), breaks = seq(0, 1, 0.25)) +
  labs(x = "PHQ-9 score", y = "Share scoring at or below", colour = NULL) +
  report_theme

stay_labels <- setNames(paste0(stay_summary$stay_group, "\n", stay_summary$n, " students"),
                        stay_summary$stay_group)
stay_plot <- ggplot(stay_summary, aes(stay_group, rate)) +
  geom_col(aes(fill = stay_group == "3 years"), width = 0.58) +
  geom_text(aes(label = scales::percent(rate, accuracy = 0.1)),
            colour = ink, vjust = -0.65, size = 4.5, fontface = "bold") +
  scale_fill_manual(values = c("FALSE" = "#c6d2f4", "TRUE" = blue), guide = "none") +
  scale_x_discrete(labels = stay_labels) +
  scale_y_continuous(labels = scales::label_percent(), limits = c(0, 0.61),
                     breaks = seq(0, 0.6, 0.2)) +
  labs(x = NULL, y = "Share classified positive") +
  report_theme + theme(panel.grid.major.x = element_blank())

baseline_ci <- 10 * hc3_confint(paper_int)[c("tosc", "toas"), ]
extension_plot_data <- bind_rows(
  extension_check |>
    transmute(term, estimate = baseline, lower = baseline_ci[, 1],
              upper = baseline_ci[, 2], model = "Paper model reproduced"),
  extension_check |>
    transmute(term, estimate = adjusted, lower, upper, model = "With stay groups")
) |>
  mutate(term = factor(term, levels = rev(extension_check$term)))
extension_plot <- ggplot(extension_plot_data, aes(estimate, term, colour = model)) +
  geom_vline(xintercept = 0, colour = "#667590", linetype = "dashed") +
  geom_pointrange(aes(xmin = lower, xmax = upper),
                  position = position_dodge(width = 0.45), orientation = "y",
                  linewidth = 0.85) +
  scale_colour_manual(values = c("Paper model reproduced" = orange,
                                 "With stay groups" = blue)) +
  labs(x = "Estimated difference in PHQ-9 points", y = NULL, colour = NULL) +
  report_theme + theme(panel.grid.major.y = element_blank())
