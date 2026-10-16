# phds-data-pipeline-as-code Makefile
# Requires: R, Rscript, Quarto (for report)
# Usage: make setup  make data  make test  make report  make clean

.PHONY: setup data test report site clean k8s-validate worklife-acquire worklife-audit worklife worklife-clean

# Restore the library pinned in renv.lock. Requires R 4.6.1.
setup:
	Rscript -e "if (!file.exists('renv.lock')) stop('renv.lock is required'); if (!requireNamespace('renv', quietly=TRUE)) install.packages('renv', repos='https://cloud.r-project.org'); renv::restore()"

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

# Stage both reports and the shared front page for GitHub Pages
site:
	mkdir -p _site && \
	if [ -d output ]; then cp -r output/. _site/; fi && \
	cp site/index.html _site/index.html

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
