# IMAP Server

Self-hosted IMAP email server with automated S3 email sync, running on Kubernetes. Remote access is via the Cloudflare Zero Trust Private Network Route (see `apps/cloudflare-tunnel/README.md`), not a per-app VPN sidecar.

## Overview

The IMAP server provides secure email access via IMAP protocol, automatically syncing emails from AWS S3 storage to local Maildir format.

## Architecture

- **IMAP Server**: Dovecot running on Alpine Linux
- **Email Sync**: Automated S3 to Maildir sync via CronJob (every 5 minutes)
- **Remote Access**: Cloudflare WARP client + Private Network Route to the cluster Service CIDR
- **Storage**: NFS persistent storage for email data
- **Deployment**: GitOps managed via ArgoCD

## Components

### Core Services
- **Dovecot IMAP**: Port 143, Alpine Linux with Dovecot
- **Email Sync CronJob**: AWS CLI 2.15.30 (ARM compatible - pinned version)

### Configuration
- **Namespace**: `email`
- **Storage**: 10Gi NFS PVC (`email-data-pvc`)
- **Secrets**: IMAP credentials, AWS credentials, SSL certificates
- **Schedule**: Email sync every 5 minutes

## Access

- **IMAP**: Port 143 (plaintext), reachable only via ClusterIP — not exposed on the LAN
- **Remote access**: WARP client enrolled in Zero Trust, routed via the Private Network Route directly to the ClusterIP `10.43.95.132` (`*.svc.cluster.local` DNS does not resolve from client devices — `.local` is a reserved mDNS TLD, intercepted before any configured DNS server)
- **Management**: ArgoCD application for GitOps deployment

## Deployment

### Prerequisites
- Kubernetes cluster with NFS storage
- AWS S3 bucket for email storage
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
- **SSL**: Disabled (Cloudflare tunnel provides transport encryption for remote access; internal ClusterIP traffic is not exposed outside the cluster)
- **Users**: Static UID/GID 5000

### Remote Access
- **Route**: Cloudflare Zero Trust Private Network Route to the cluster Service CIDR (`10.43.0.0/16`)
- **Name/address**: `10.43.95.132:143` (ClusterIP, used directly — not by name)
- **Access**: WARP client, OTP-email enrollment

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
- Verify the WARP client's Private Network Route (`10.43.0.0/16`) is active and the client is in "Traffic and DNS mode" (not "Traffic only")
- Ensure dovecot-config ConfigMap is properly mounted

**No new emails syncing:**
- Check CronJob schedule and recent job status
- Verify AWS credentials and S3 bucket access
- Check email sync job logs for errors

### Resource Limits
- **Dovecot**: 100m CPU / 128Mi RAM (requests), 500m CPU / 512Mi RAM (limits)
- **Email Sync**: 100m CPU / 128Mi RAM (requests), 500m CPU / 512Mi RAM (limits)

## Security

- **Network**: `ClusterIP` only; the Cloudflare tunnel's Private Network Route is the only path in
- **Authentication**: Password-based IMAP auth via dovecot-users secret
- **Encryption**: Cloudflare tunnel provides transport encryption
- **Isolation**: Dedicated namespace
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
