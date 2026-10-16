# phds-data-pipeline-as-code Makefile
# Requires: R, Rscript, Quarto (for report)
# Usage: make setup  make data  make test  make report  make clean

.PHONY: setup data test report site clean k8s-validate worklife-acquire worklife-audit worklife worklife-clean

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
	mkdir -p output
	Rscript -e "targets::tar_make()"

# Prepare _site/ for GitHub Pages (copy output/ and create index.html)
site:
	mkdir -p _site && \
	if [ -d output ]; then cp -r output/. _site/; fi && \
	if [ -f _site/report.html ]; then cp _site/report.html _site/index.html; fi

# Remove output, generated data, and targets cache
clean:
	Rscript -e "unlink('output', recursive=TRUE); unlink('_targets', recursive=TRUE); unlink(list.files('data/synthetic', full.names=TRUE, include.dirs=FALSE)); unlink('report.html', force=TRUE)"

# Validate kustomize builds (requires kubectl)
k8s-validate:
	kubectl kustomize k8s/base && kubectl kustomize k8s/overlays/dev

# Download the pinned occupational-disease snapshot and verify it before keeping it
worklife-acquire:
	Rscript scripts/acquire_worklife.R

# Live StatFin 115s comparison. Not part of the offline report build.
worklife-audit:
	Rscript scripts/audit_worklife_denominator.R

# Offline worklife report from the verified snapshot and saved audit
worklife:
	mkdir -p output/worklife
	Rscript scripts/build_worklife.R

# Remove worklife targets cache and report only
worklife-clean:
	Rscript -e "unlink('_targets_worklife', recursive=TRUE); unlink('output/worklife', recursive=TRUE)"
