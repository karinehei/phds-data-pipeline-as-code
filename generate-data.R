#!/usr/bin/env Rscript
# Generate synthetic data. Run from project root: Rscript generate-data.R

root <- if (file.exists("R")) "." else {
  if (file.exists("../R")) ".." else stop("Run from project root")
}
setwd(root)

for (f in list.files("R", pattern = "\\.R$", full.names = TRUE)) {
  source(f)
}
generate_demo_data()
