CLUSTER_NAME   := gitops-demo
KIND_CONFIG    := kind-config.yaml
ARGOCD_VERSION := v2.13.3

.PHONY: cluster argocd apps port-forward status rollouts clean help

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

cluster: ## Create kind cluster
	kind create cluster --config $(KIND_CONFIG) --name $(CLUSTER_NAME)
	@echo "Waiting for node to be ready..."
	kubectl wait --for=condition=Ready nodes --all --timeout=120s
	@echo "Cluster $(CLUSTER_NAME) is ready."

argocd: ## Install ArgoCD and print admin password
	kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
	kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/$(ARGOCD_VERSION)/manifests/install.yaml
	@echo "Waiting for ArgoCD pods to be ready (this may take a few minutes)..."
	kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s
	@echo ""
	@echo "====================================="
	@echo "ArgoCD admin password:"
	@kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
	@echo ""
	@echo "====================================="

apps: ## Apply ArgoCD Applications
	kubectl apply -f argocd/
	@echo "Applications created. Run 'make status' to check sync state."

port-forward: ## Port-forward ArgoCD UI (8443) and app (8080)
	@echo "ArgoCD UI:  https://localhost:8443  (admin / password from 'make argocd')"
	@echo "App (dev):  http://localhost:8080"
	@echo ""
	@echo "Press Ctrl+C to stop."
	@kubectl port-forward svc/argocd-server -n argocd 8443:443 > /dev/null 2>&1 &
	@sleep 2
	@kubectl port-forward svc/gitops-status-demo -n status-dev 8080:80 2>/dev/null || \
		echo "App not deployed yet. Waiting for ArgoCD to sync..."

status: ## Show ArgoCD application status
	@echo "=== ArgoCD Applications ==="
	@kubectl get applications -n argocd 2>/dev/null || echo "ArgoCD not installed"
	@echo ""
	@echo "=== Pods ==="
	@kubectl get pods -A -l app=gitops-status-demo 2>/dev/null || echo "No pods found"

rollouts: ## Install Argo Rollouts controller
	kubectl create namespace argo-rollouts --dry-run=client -o yaml | kubectl apply -f -
	kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml
	@echo "Waiting for Argo Rollouts to be ready..."
	kubectl wait --for=condition=Ready pods --all -n argo-rollouts --timeout=120s
	@echo "Argo Rollouts installed."

clean: ## Delete the kind cluster
	kind delete cluster --name $(CLUSTER_NAME)
