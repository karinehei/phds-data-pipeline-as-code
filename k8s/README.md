# Kubernetes Manifests

**Base** (`k8s/base`): CronJob, ConfigMap, EmptyDir volumes. Daily schedule placeholder.

**Dev overlay** (`k8s/overlays/dev`): Every 6h, image `:dev`, smaller dataset (N_PATIENTS=50, N_VISITS=200).

Build and apply:

```bash
kustomize build k8s/base | kubectl apply -f -
kustomize build k8s/overlays/dev | kubectl apply -f -
```

Or with kubectl:

```bash
kubectl apply -k k8s/overlays/dev
```

**Note:** The pipeline (`_targets.R`) uses hardcoded values. To use ConfigMap env vars (SEED, N_PATIENTS, N_VISITS), wire `Sys.getenv()` in the synthetic_data target.
