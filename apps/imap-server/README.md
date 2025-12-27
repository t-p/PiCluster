# IMAP Server

Self-hosted IMAP email server with automated S3 email sync, running on Kubernetes with Tailscale VPN access.

## Overview

The IMAP server provides secure email access via IMAP protocol, automatically syncing emails from AWS S3 storage to local Maildir format. It includes VPN access via Tailscale for secure remote connections.

## Architecture

- **IMAP Server**: Dovecot running on Alpine Linux
- **Email Sync**: Automated S3 to Maildir sync via CronJob (every 5 minutes)
- **VPN Access**: Tailscale sidecar for secure remote access
- **Storage**: NFS persistent storage for email data
- **Deployment**: GitOps managed via ArgoCD

## Components

### Core Services
- **Dovecot IMAP**: Port 143, Alpine Linux with Dovecot
- **Email Sync CronJob**: AWS CLI 2.15.30 (ARM compatible - pinned version)
- **Tailscale VPN**: Sidecar container

### Configuration
- **Namespace**: `email`
- **Storage**: 10Gi NFS PVC (`email-data-pvc`)
- **Secrets**: IMAP credentials, AWS credentials, Tailscale auth, SSL certificates
- **Schedule**: Email sync every 5 minutes

## Access

- **IMAP**: Port 143 (plaintext, internal network only)
- **VPN**: Accessible via Tailscale network as `picluster-email`
- **Management**: ArgoCD application for GitOps deployment

## Deployment

### Prerequisites
- Kubernetes cluster with NFS storage
- AWS S3 bucket for email storage
- Tailscale account and auth key
- Required secrets (see below)

### Required Secrets
```bash
# IMAP credentials
kubectl create secret generic imap-credentials -n email \
  --from-literal=username=<email-address>

# AWS credentials  
kubectl create secret generic aws-credentials -n email \
  --from-literal=access-key-id=<aws-key> \
  --from-literal=secret-access-key=<aws-secret> \
  --from-literal=s3-bucket=<bucket-name>

# Tailscale auth
kubectl create secret generic tailscale-auth -n email \
  --from-literal=TS_AUTHKEY=<tailscale-key>

# Dovecot users (passwd-file format)
kubectl create secret generic dovecot-users -n email \
  --from-literal=users=<username>:<password-hash>

# SSL certificates
kubectl create secret tls dovecot-ssl -n email \
  --cert=<cert-file> --key=<key-file>
```

### Deploy via ArgoCD
```bash
kubectl apply -f apps/argocd/imap-server-application.yaml
```

### Manual Deployment
```bash
kubectl apply -f apps/imap-server/01-namespace-and-storage.yaml
kubectl apply -f apps/imap-server/02-configmap.yaml
kubectl apply -f apps/imap-server/06-tailscale-rbac.yaml
kubectl apply -f apps/imap-server/03-deployment.yaml
kubectl apply -f apps/imap-server/04-service.yaml
kubectl apply -f apps/imap-server/05-email-sync-cronjob.yaml
```

## Configuration

### Email Sync
- **Source**: AWS S3 bucket with SES incoming emails
- **Target**: Maildir format in `/var/mail/vmail/<email>/`
- **State Tracking**: Prevents duplicate downloads using ETags
- **Schedule**: Every 5 minutes via CronJob
- **Concurrency**: Forbid (prevents overlapping jobs)

### Dovecot IMAP
- **Protocol**: IMAP only (port 143)
- **Authentication**: passwd-file based
- **Mail Location**: Maildir format
- **SSL**: Disabled (VPN provides encryption)
- **Users**: Static UID/GID 5000

### Tailscale VPN
- **Hostname**: `picluster-email`
- **Routes**: Advertises `192.168.88.0/24` cluster network
- **Access**: Secure remote IMAP access via Tailscale network

## Monitoring

### Health Checks
- **Liveness Probe**: TCP check on port 143 (30s delay, 30s interval)
- **Readiness Probe**: TCP check on port 143 (10s delay, 10s interval)

### Logs
```bash
# IMAP server logs
kubectl logs -n email deployment/imap-server -c dovecot

# Email sync logs
kubectl logs -n email job/<job-name> -c aws-email-sync

# Tailscale VPN logs
kubectl logs -n email deployment/imap-server -c tailscale
```

### Status
```bash
# Check deployment
kubectl get deployment -n email imap-server

# Check email sync jobs
kubectl get cronjob,job -n email

# Check pods
kubectl get pods -n email
```

## Troubleshooting

### Common Issues

**Email sync failing with ARM error:**
- Ensure AWS CLI version is 2.15.30 (ARM 8.1-a compatible)
- Newer versions require ARM 8.2-a+ (Graviton 2+)

**IMAP connection refused:**
- Check Dovecot container logs for configuration errors
- Verify port 143 is accessible via Tailscale network
- Ensure dovecot-config ConfigMap is properly mounted

**No new emails syncing:**
- Check CronJob schedule and recent job status
- Verify AWS credentials and S3 bucket access
- Check email sync job logs for errors

**Tailscale connection issues:**
- Verify TS_AUTHKEY secret is valid
- Check Tailscale container logs for auth errors
- Ensure proper RBAC permissions for Tailscale service account

### Resource Limits
- **Dovecot**: 100m CPU / 128Mi RAM (requests), 500m CPU / 512Mi RAM (limits)
- **Tailscale**: 50m CPU / 64Mi RAM (requests), 200m CPU / 256Mi RAM (limits)
- **Email Sync**: 100m CPU / 128Mi RAM (requests), 500m CPU / 512Mi RAM (limits)

## Security

- **Network**: Internal IMAP access only, VPN for remote access
- **Authentication**: Password-based IMAP auth via dovecot-users secret
- **Encryption**: Tailscale provides transport encryption
- **Isolation**: Dedicated namespace with RBAC permissions
- **Storage**: NFS with proper file permissions (UID/GID 5000)

## Maintenance

### Updates
- **Dependabot**: Monitors container images (AWS CLI pinned to 2.15.30)
- **ArgoCD**: Automatic deployment of configuration changes
- **Revision History**: Keeps last 3 deployment revisions

### Backup
- **Email Data**: Backup NFS storage at `/mnt/storage/email/`
- **Configuration**: All config stored in Git repository
- **Secrets**: Backup secret values securely (not in Git)
