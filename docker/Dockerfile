# phds-data-pipeline-as-code
# Reproducibility: pinned base, renv.lock, deterministic build order.
# Minimal size: --no-install-recommends, apt clean, .dockerignore.

FROM rocker/r-ver:4.3.0

# System deps: make (for make report), curl (quarto), optional arrow libs
# Arrow: CRAN package can use bundled libs if libarrow-dev unavailable.
# DuckDB: no system deps needed; add libduckdb-dev if using duckdb package.
RUN apt-get update && apt-get install -y --no-install-recommends \
    make \
    curl \
    ca-certificates \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Quarto (pinned for reproducibility)
ARG QUARTO_VERSION=1.4.550
RUN curl -LO "https://github.com/quarto-dev/quarto-cli/releases/download/v${QUARTO_VERSION}/quarto-${QUARTO_VERSION}-linux-amd64.deb" \
    && dpkg -i quarto-*.deb \
    && rm quarto-*.deb

WORKDIR /app

# Copy project (.dockerignore excludes .git, _targets, output, etc.)
COPY . .

# R packages: renv restore preferred; install any missing
RUN Rscript -e " \
  install.packages('renv', repos='https://cloud.r-project.org'); \
  if (file.exists('renv.lock')) renv::restore(); \
  pkgs <- c('targets','yaml','arrow','quarto','testthat','ggplot2'); \
  for (p in pkgs) if (!requireNamespace(p, quietly=TRUE)) install.packages(p, repos='https://cloud.r-project.org'); \
"

# Output dirs (created by pipeline; ensure writable)
RUN mkdir -p /app/output /app/data/synthetic

# Default: run pipeline and report (writes to /app/output, /app/data/synthetic)
CMD ["make", "report"]
