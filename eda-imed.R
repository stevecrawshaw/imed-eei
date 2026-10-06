pacman::p_load(tidyverse, janitor, glue, duckdb)

con <- duckdb::dbConnect(duckdb("data/imed_eei.duckdb"))

imed_eei_tbl <- con |>
  tbl("imed_eei_tbl") |>
  head(100) |>
  collect()

imed_eei_tbl |> glimpse()

view(imed_eei_tbl)

imed_eei_tbl |>
  ggplot(aes(x = easting)) +
  geom_histogram() +
  theme_minimal()

con |> dbDisconnect()
con |> close()
