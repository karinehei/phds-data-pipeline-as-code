# phds-data-pipeline-as-code Makefile
# Requires: R, Rscript, Quarto (for report)
# Usage: make setup  make data  make test  make report  make clean

.PHONY: setup data test report clean k8s-validate

# Install R dependencies: renv restore if lock has packages, else install minimal set
setup:
	Rscript -e "pkgs <- c('targets','yaml','arrow','quarto','testthat','ggplot2'); if (file.exists('renv.lock')) { install.packages('renv', repos='https://cloud.r-project.org'); renv::restore() }; for (p in pkgs) if (!requireNamespace(p, quietly=TRUE)) install.packages(p, repos='https://cloud.r-project.org')"

# Generate synthetic data to data/synthetic/visits.parquet
data:
	Rscript generate-data.R

# Run testthat unit tests
test:
	Rscript run-tests.R

# Run targets pipeline (includes report render to output/report.html)
report:
	Rscript -e "targets::tar_make()"

# Remove output, generated data, and targets cache
clean:
	Rscript -e "unlink('output', recursive=TRUE); unlink('_targets', recursive=TRUE); unlink(list.files('data/synthetic', full.names=TRUE, include.dirs=FALSE)); unlink('report.html', force=TRUE)"

# Validate kustomize builds (requires kubectl)
k8s-validate:
	kubectl kustomize k8s/base && kubectl kustomize k8s/overlays/dev
