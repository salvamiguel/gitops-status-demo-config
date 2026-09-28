# gitops-status-demo-config

Kubernetes manifests and ArgoCD configuration for [gitops-status-demo-app](https://github.com/salvamiguel/gitops-status-demo-app). Uses Kustomize base+overlays for multi-environment management.

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/)
- [kind](https://kind.sigs.k8s.io/docs/user/quick-start/#installation)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- (Optional) [argocd CLI](https://argo-cd.readthedocs.io/en/stable/cli_installation/)
- (Optional) [kubectl-argo-rollouts](https://argo-rollouts.readthedocs.io/en/stable/installation/#kubectl-plugin-installation) (for strategy branches)

## Quick start

```bash
make cluster    # Create kind cluster
make argocd     # Install Argo CD v3.5.3 (prints admin password)
make apps       # Create ArgoCD Applications (dev, staging, prod)
make port-forward  # Access ArgoCD UI (localhost:8443) and app (localhost:8080)
```

### Installing Argo CD by hand

The Makefile pins Argo CD `v3.5.3`. Argo CD 3 must be installed with server-side apply, because some of its CRDs are too large for the `last-applied-configuration` annotation used by a plain `kubectl apply`:

```bash
kubectl create namespace argocd
kubectl apply -n argocd --server-side --force-conflicts \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/v3.5.3/manifests/install.yaml
argocd admin initial-password -n argocd   # admin password
```

## Environments

| Environment | Namespace | Replicas | Sync | Color |
|-------------|-----------|----------|------|-------|
| dev | `status-dev` | 1 | Auto | green |
| staging | `status-staging` | 2 | Auto | yellow |
| prod | `status-prod` | 4 | Manual | blue |

## Kustomize structure

```
k8s/
├── base/           # Shared deployment + service
└── overlays/
    ├── dev/        # 1 replica, auto-sync
    ├── staging/    # 2 replicas, auto-sync
    └── prod/       # 4 replicas, manual sync
```

Preview rendered manifests:
```bash
kubectl kustomize k8s/overlays/dev
kubectl kustomize k8s/overlays/prod
diff <(kubectl kustomize k8s/overlays/dev) <(kubectl kustomize k8s/overlays/prod)
```

## Deployment strategy branches

| Branch | Strategy | Requires |
|--------|----------|----------|
| `main` | Rolling Update | Nothing extra |
| `strategy/blue-green` | Blue-Green | `make rollouts` |
| `strategy/canary` | Canary | `make rollouts` |

To switch strategies:
```bash
git checkout strategy/blue-green
make rollouts       # Install Argo Rollouts
kubectl apply -f argocd/  # Re-apply Applications
```

## Makefile targets

```
make help          # Show all targets
make cluster       # Create kind cluster
make argocd        # Install ArgoCD
make apps          # Apply ArgoCD Applications
make port-forward  # Port-forward UI + app
make status        # Show app status
make rollouts      # Install Argo Rollouts
make clean         # Delete kind cluster
```

## Cleanup

```bash
make clean
```
