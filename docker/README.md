# Docker

Build from project root:

```bash
docker build -f docker/Dockerfile -t phds-pipeline .
```

Run (writes to `/app/output`, `/app/data/synthetic`):

```bash
docker run --rm -v $(pwd)/output:/app/output -v $(pwd)/data/synthetic:/app/data/synthetic phds-pipeline
```

Or run without volume mounts (outputs stay in container):

```bash
docker run --rm phds-pipeline
```

**Reproducibility:** Base image and Quarto version are pinned. Use `renv.lock` for R package versions.

**Minimal size:** `.dockerignore` excludes `.git`, `_targets`, `output`, etc. Use `--no-install-recommends` for apt.
