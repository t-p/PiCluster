# Argo CD on PiCluster

This directory contains Kubernetes manifests and Argo CD Application definitions to enable GitOps-based continuous delivery for your PiCluster K3s setup.

## Overview

Argo CD is a declarative GitOps continuous delivery tool for Kubernetes. It watches your Git repository and automatically synchronizes Kubernetes manifests to your cluster, providing a visual dashboard and advanced deployment management features.

## Prerequisites

- PiCluster with K3s installed and running
- `argocd` namespace created (handled by manifests)
- NodePort or Ingress configured for Argo CD UI access
- Your applications defined as manifests in the `apps/` directory

## Quick Start

1. **Deploy Argo CD:**
   ```bash
   cd apps/argocd
   kubectl apply -f 01-ingress.yaml
   kubectl apply -f 02-nodeport-service.yaml
   # (Add Argo CD core manifests if not already installed)
   ```

2. **Deploy Applications via Argo CD:**
   ```bash
   # Apply any Application manifests (e.g., jellyfin, monitoring, etc.)
   kubectl apply -f jellyfin-application.yaml -n argocd
   kubectl apply -f monitoring-application.yaml -n argocd
   # ...and so on for other apps
   ```

3. **Access Argo CD UI:**
   - **NodePort:** [http://192.168.88.163:30080](http://192.168.88.163:30080)
   - **Ingress (if configured):** Use your configured domain

4. **Login:**
   - Default username: `admin`
   - Initial password: Run `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d`

## Application Structure

- `01-ingress.yaml` – Ingress and middleware for Argo CD UI (Traefik example)
- `02-nodeport-service.yaml` – NodePort service for Argo CD UI
- `*-application.yaml` – Argo CD Application manifests for managed apps (Jellyfin, Monitoring, etc.)

## Example: Add a New Application

To add a new app to Argo CD, create an Application manifest (see `jellyfin-application.yaml` for an example) and apply it:
```bash
kubectl apply -f myapp-application.yaml -n argocd
```
Argo CD will automatically detect and manage the app.

## Troubleshooting

- **Check Argo CD app status:**
  ```bash
  kubectl get applications -n argocd
  ```
- **Sync or refresh apps from the UI or CLI:**
  ```bash
  argocd app sync <app-name>
  ```
- **View logs:**
  ```bash
  kubectl logs -n argocd deployment/argocd-server
  ```

## Security Notes

- Change the default admin password after first login.
- Limit Argo CD UI exposure to trusted networks or use authentication.
- Review RBAC and restrict permissions as needed.

## Documentation

- [Argo CD Documentation](https://argo-cd.readthedocs.io/)
- [PiCluster Main README](../../README.md)
