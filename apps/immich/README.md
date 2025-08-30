# Immich Photo Management

Immich is a self-hosted photo and video management solution with AI-powered features, providing a modern alternative to Google Photos. This deployment is optimized for high performance using NVMe storage for database operations and NFS storage for media files.

## Overview

- **Namespace**: `immich`
- **Components**: Server, PostgreSQL, Redis, Machine Learning Service
- **Access**: NodePort 31283 (http://NODE_IP:31283), Ingress (http://immich.home)
- **Storage**: NVMe storage for database/cache (node05), NFS for media files
- **Database**: PostgreSQL 15 with NVMe storage on node05
- **Cache**: Redis with job queue persistence on node05
- **AI Features**: Face recognition, object detection, CLIP embeddings
- **Mobile Apps**: iOS and Android with automatic photo backup

## Architecture

The Immich deployment consists of four main components optimized for performance on the Pi 5 node:

### High-Performance Components (node05 - Pi 5)
All compute-intensive components are colocated on node05 for optimal performance:
- **PostgreSQL Database**: Metadata storage on NVMe for sub-millisecond queries
- **Redis Cache**: Job queue and session management with NVMe persistence
- **Machine Learning Service**: AI processing with model caching on NVMe
- **Performance Benefits**: 60% better CPU, 36% better memory bandwidth, 10-100x faster storage

### Storage Strategy
- **NVMe Storage** (node05): Database, cache, ML models, temp processing
- **NFS Storage** (shared): Photo/video library, uploads, thumbnails, backups

### Component Colocation Benefits
- **Zero network latency** between database, cache, and ML services
- **Shared NVMe storage** for maximum I/O performance
- **Dedicated high-performance CPU** for ML inference and database operations
- **Optimized resource utilization** on the most capable hardware

## Components

### 01-namespace-and-storage.yaml
- Creates `immich` namespace
- Establishes foundation for storage resources

### 02-database.yaml
- PostgreSQL 15 deployment with NVMe storage on node05
- Database initialization and configuration
- Health checks and monitoring

### 03-redis.yaml
- Redis cache deployment with persistence on node05
- Job queue configuration for background processing
- Performance optimization for Pi 5 hardware

### 04-machine-learning.yaml
- AI service deployment for face recognition and object detection
- Model caching on NVMe for fast loading
- CPU and memory optimization for ML workloads

### 05-immich-server.yaml
- Main Immich application server
- Environment configuration for all service connections
- Volume mounts for NFS media storage

### 06-services.yaml
- NodePort service for external web access (port 31283)
- Internal ClusterIP services for component communication
- Session affinity for mobile app reliability



### 09-ingress.yaml
- Ingress configuration for domain-based access
- HTTP routing for web interface and API
- Integration with existing cluster ingress setup



### 10-monitoring.yaml
- Health monitoring and alerting configuration
- Resource usage monitoring
- Integration with cluster monitoring stack

## Configuration

### Configuration Management Strategy
Immich uses a combination of Kubernetes ConfigMaps for non-sensitive configuration and Secrets for sensitive data. All configuration is externalized from the deployment manifests for easy customization and maintenance.

#### Secret Management (Manual Creation Required)
All sensitive configuration is managed through manually created Kubernetes secrets for enhanced security:

**Required Secrets**:
1. **immich-postgres-secret**: Database credentials (username, password)
2. **immich-server-secret**: JWT secret for server authentication

These secrets must be created manually before deployment (see Deployment section for details).

#### Node Affinity Strategy
All high-performance components are colocated on node05 (Pi 5) for optimal performance:
- Zero network latency between database, cache, and ML services
- Shared NVMe storage for maximum I/O performance
- Dedicated high-performance CPU for ML inference and database operations

#### Storage Layout

**NVMe Storage (node05 - /opt/immich/)**
```
/opt/immich/
├── postgres/     # PostgreSQL database files (hostPath)
├── redis/        # Redis persistence and job queue (hostPath)
├── ml-models/    # AI model cache for fast loading (hostPath)
└── temp/         # Processing temporary space (hostPath)
```

**NFS Storage (/mnt/storage/immich/)**
```
/mnt/storage/immich/
├── library/      # Photo and video library (PVC)
│   ├── photos/   # Organized photo storage
│   └── videos/   # Video file storage
├── uploads/      # Temporary upload processing (PVC)
├── thumbs/       # Generated thumbnails and previews (PVC)
└── backups/      # Database backups from node05 (PVC)
```

#### Key Configuration Options

**PostgreSQL Configuration**:
- **Memory Settings**: Optimized for Pi 5 with 1GB container limit
- **Performance**: NVMe-optimized settings with `random_page_cost=1.1`
- **Logging**: Slow query logging for performance monitoring
- **Autovacuum**: Tuned for photo metadata workloads

**Redis Configuration**:
- **Memory Management**: 400MB limit with LRU eviction policy
- **Persistence**: AOF enabled for job queue reliability
- **Performance**: Lazy freeing enabled for better performance

**Machine Learning Configuration**:
- **Models**: Face detection, object detection, CLIP embeddings
- **Performance**: 2 workers optimized for Pi 5 CPU
- **Thresholds**: Configurable accuracy thresholds for AI features

**Server Configuration**:
- **Job Concurrency**: Optimized for Pi hardware limitations
- **FFmpeg Settings**: H.264 codec with ultrafast preset
- **Features**: Face recognition, object detection, duplicate detection enabled

#### Port Configuration
- **Web Interface**: 3001 (internal) → 31283 (NodePort)
- **PostgreSQL**: 5432 (internal cluster access only)
- **Redis**: 6379 (internal cluster access only)
- **Machine Learning**: 3003 (internal API access only)

## Access URLs

### Web Interface

#### Ingress Access (Recommended)
Access Immich through the ingress controller with friendly domain names:
- **Primary**: http://immich.home (HTTP)
- **Alternative**: http://photos.home (HTTP)
- **HTTPS**: https://immich.home or https://photos.home (when TLS certificates are configured)

#### Direct NodePort Access
You can also access Immich directly through any cluster node:
- http://192.168.88.167:31283 (node01)
- http://192.168.88.164:31283 (node02)
- http://192.168.88.163:31283 (node03)
- http://192.168.88.162:31283 (node04)
- http://192.168.88.126:31283 (node05) - **Primary processing node**

#### DNS Configuration
To use the ingress domains, add these entries to your local DNS or hosts file:
```
192.168.88.XXX  immich.home
192.168.88.XXX  photos.home
```
Replace `192.168.88.XXX` with any cluster node IP address.

### Mobile App Configuration

The Immich mobile app provides automatic photo backup, browsing, and management capabilities. The deployment is optimized for reliable mobile connectivity with session affinity and proper timeout configurations.

> **📱 Quick Setup Guide**: Mobile app configuration instructions are included in this README below.

#### Connection Methods

**Method 1: Ingress Access (Recommended)**
- **Server URL**: `http://immich.home` or `http://photos.home`
- **Benefits**: Friendly domain names, load balancing
- **Requirements**: DNS resolution for .home domains

**Method 2: Direct NodePort Access**
- **Server URL**: `http://NODE_IP:31283` (replace NODE_IP with any cluster node)
- **Available Nodes**:
  - `http://192.168.88.167:31283` (node01)
  - `http://192.168.88.164:31283` (node02)
  - `http://192.168.88.163:31283` (node03)
  - `http://192.168.88.162:31283` (node04)
  - `http://192.168.88.126:31283` (node05) - Primary processing node
- **Benefits**: Direct access, no DNS requirements
- **Use Case**: Fallback when ingress is unavailable

#### Mobile App Setup Guide

**Step 1: Download the Immich Mobile App**
- **iOS**: Download from the App Store
- **Android**: Download from Google Play Store or F-Droid
- **GitHub**: Latest releases available at https://github.com/immich-app/immich/releases

**Step 2: Initial Configuration**
1. Open the Immich mobile app
2. Tap "Add Server" or "Connect to Server"
3. Enter your server URL:
   - **Recommended**: `http://immich.home` (if using ingress)
   - **Alternative**: `http://192.168.88.XXX:31283` (replace XXX with node IP)
4. Tap "Connect" to verify server connectivity

**Step 3: User Authentication**
1. **Create Account** (first-time setup):
   - Access the web interface first: `http://immich.home`
   - Create an admin account through the web setup wizard
   - Create additional user accounts as needed
2. **Login** on mobile app:
   - Enter your username/email and password
   - Enable "Remember me" for persistent authentication
   - Authentication tokens are valid for extended periods (configured for 3-hour sessions)

**Step 4: Configure Automatic Backup**
1. After successful login, navigate to "Backup" settings
2. **Enable Auto Backup**: Toggle on automatic photo backup
3. **Select Albums**: Choose which photo albums to backup
   - Camera Roll (recommended)
   - Screenshots (optional)
   - Other albums as desired
4. **Backup Settings**:
   - **Upload Quality**: Original (recommended) or compressed
   - **Background Sync**: Enable for automatic uploads
   - **WiFi Only**: Enable to avoid mobile data usage
   - **Charging Only**: Enable to preserve battery life

#### Mobile App Features and Configuration

**Automatic Photo Backup**
- **Real-time Upload**: Photos are uploaded immediately after capture
- **Background Sync**: Continues uploading when app is in background
- **Duplicate Detection**: Prevents uploading the same photo multiple times
- **Resume Capability**: Interrupted uploads resume automatically
- **Progress Tracking**: Visual progress indicators for upload status

**Photo Browsing and Management**
- **Timeline View**: Chronological photo timeline with fast scrolling
- **Album Organization**: Create and manage photo albums
- **Search Functionality**: Search by date, location, or AI-detected content
- **Sharing**: Share photos and albums with other users
- **Favorites**: Mark photos as favorites for quick access

**Offline Capabilities**
- **Cached Thumbnails**: Recently viewed photos cached for offline viewing
- **Download for Offline**: Download specific photos for offline access
- **Sync Status**: Clear indicators of sync status and pending uploads

#### Network and Performance Optimization

**Session Affinity Configuration**
The NodePort service is configured with session affinity to ensure consistent mobile app performance:
```yaml
sessionAffinity: ClientIP
sessionAffinityConfig:
  clientIP:
    timeoutSeconds: 10800  # 3 hours
```

**Benefits for Mobile Apps**:
- **Consistent Connection**: Mobile app connects to the same backend pod
- **Reduced Authentication**: Less frequent re-authentication required
- **Better Performance**: Cached data and established connections
- **Upload Reliability**: Large photo uploads maintain connection to same pod

**Network Timeout Configuration**
- **Connection Timeout**: 30 seconds for initial connection
- **Upload Timeout**: Extended timeouts for large photo/video uploads
- **Retry Logic**: Automatic retry for failed uploads with exponential backoff
- **Background Sync**: Continues uploads when app is backgrounded

#### Troubleshooting Mobile App Issues

**Connection Issues**
```bash
# Verify NodePort service is accessible
curl -f http://NODE_IP:31283/api/server-info/ping

# Check service status
kubectl get svc immich-server-nodeport -n immich

# Verify pods are running
kubectl get pods -n immich -l app=immich-server
```

**Authentication Problems**
```bash
# Check server logs for authentication errors
kubectl logs -n immich -l app=immich-server | grep -i auth

# Verify JWT secret is configured
kubectl get secret immich-server-secret -n immich

# Check user database
kubectl exec -n immich deployment/immich-postgres -- psql -U immich -d immich -c "SELECT email, created_at FROM users;"
```

**Upload Issues**
```bash
# Check upload storage availability
kubectl exec -n immich deployment/immich-server -- df -h /usr/src/app/upload

# Monitor upload logs
kubectl logs -n immich -l app=immich-server -f | grep -i upload

# Check Redis job queue
kubectl exec -n immich deployment/immich-redis -- redis-cli LLEN immich:jobs:active
```

**Performance Issues**
```bash
# Check resource usage
kubectl top pods -n immich

# Monitor database performance
kubectl exec -n immich deployment/immich-postgres -- psql -U immich -d immich -c "SELECT * FROM pg_stat_activity WHERE state = 'active';"

# Check ML service performance
kubectl logs -n immich -l app=immich-ml --tail=20
```

#### Mobile App Security Considerations

**Network Security**
- **HTTPS Recommended**: Use TLS certificates for encrypted communication
- **VPN Access**: Consider VPN for external access to home network
- **Firewall Rules**: Restrict NodePort access to trusted networks
- **Regular Updates**: Keep mobile app updated for security patches

**Authentication Security**
- **Strong Passwords**: Use strong, unique passwords for user accounts
- **Session Management**: Sessions automatically expire after configured timeout
- **Device Security**: Enable device lock screen for additional protection
- **Account Monitoring**: Monitor user activity through web interface

**Data Protection**
- **Local Storage**: Mobile app stores minimal data locally (thumbnails, cache)
- **Secure Transmission**: All data encrypted in transit (when using HTTPS)
- **Backup Verification**: Verify photos are successfully uploaded before deletion
- **Privacy Settings**: Configure sharing and privacy settings appropriately

#### Advanced Mobile Configuration

**Custom Server Ports**
If you need to change the NodePort:
```bash
# Edit the service to change NodePort
kubectl patch svc immich-server-nodeport -n immich -p '{"spec":{"ports":[{"port":3001,"targetPort":3001,"nodePort":32283,"protocol":"TCP","name":"http"}]}}'

# Update mobile app server URL accordingly
# New URL: http://NODE_IP:32283
```

**Load Balancer Integration**
For external access through load balancer:
```bash
# Check if MetalLB assigns external IP
kubectl get svc immich-server-nodeport -n immich

# If external IP is assigned, use it in mobile app:
# Server URL: http://EXTERNAL_IP:31283
```

**Multiple Server Configuration**
The mobile app supports multiple server configurations:
1. Add primary server: `http://immich.home`
2. Add backup server: `http://192.168.88.126:31283`
3. Switch between servers as needed
4. Each server maintains separate authentication and data

### External Access via Cloudflare Tunnel
For secure external access from outside your home network, use Cloudflare Tunnel instead of exposing ports directly:

#### Benefits of Cloudflare Tunnel
- **Secure HTTPS**: Automatic SSL/TLS termination at Cloudflare edge
- **No Port Forwarding**: No need to open ports on your router
- **DDoS Protection**: Cloudflare's built-in protection
- **Access Control**: Authentication and authorization at the edge
- **Zero Trust**: Secure access without VPN

#### Setup Process
1. **Configure Cloudflare Tunnel**: See `apps/cloudflare-tunnel/` for setup instructions
2. **Add Immich Service**: Configure tunnel to route to `http://immich.home` or `http://NODE_IP:31283`
3. **External Domain**: Access via your configured Cloudflare domain (e.g., `https://photos.yourdomain.com`)
4. **Mobile App**: Use the external Cloudflare domain in mobile app configuration

#### Mobile App with Cloudflare Tunnel
- **External URL**: `https://photos.yourdomain.com` (your configured Cloudflare domain)
- **Internal URL**: `http://immich.home` (when on home network)
- **Automatic Switching**: Mobile app can be configured with both URLs for seamless access

## Features

### Core Features
- **Photo Management**: Upload, organize, and view photos and videos with metadata preservation
- **Album Creation**: Create and share photo albums with other users
- **Mobile App**: iOS and Android apps with automatic photo backup and sync
- **Web Interface**: Modern responsive web application with timeline view
- **Search**: Metadata-based and AI-powered search capabilities
- **User Management**: Multi-user support with sharing and privacy controls

### AI-Powered Features (Machine Learning Service)
- **Face Recognition**: Automatic face detection and grouping with person identification
- **Object Detection**: Identify objects, animals, and scenes in photos using YOLO models
- **CLIP Embeddings**: Semantic search using natural language queries
- **Smart Albums**: Automatically generated albums based on AI-detected content
- **Duplicate Detection**: Find and manage duplicate photos across your library
- **Reverse Geocoding**: Location-based organization and search

### Performance Features
- **Fast Database**: Sub-millisecond queries with NVMe storage on Pi 5
- **Efficient Caching**: Redis-powered caching for quick access and job queue management
- **Optimized ML**: Model caching on NVMe for fast AI processing and inference
- **Thumbnail Generation**: Fast preview generation and caching with multiple sizes
- **Hardware Optimization**: All components optimized for Raspberry Pi 5 performance

### Mobile App Features
- **Automatic Backup**: Real-time photo and video backup from mobile devices
- **Background Sync**: Continues uploading when app is in background
- **Offline Access**: Cached thumbnails and downloaded photos for offline viewing
- **Selective Sync**: Choose which albums and folders to backup
- **Duplicate Prevention**: Intelligent duplicate detection prevents re-uploading

## Deployment

### Prerequisites
- Kubernetes cluster with NFS storage class configured
- Node05 (Pi 5) available for high-performance workloads
- At least 10GB free space on node05 NVMe storage (`/opt/immich/`)
- At least 100GB free space on NFS storage for media files
- OpenSSL installed for secure secret generation

### Step 1: Create Namespace and Storage
```bash
# Deploy namespace and storage foundation
kubectl apply -f apps/immich/01-namespace-and-storage.yaml

# Verify namespace creation
kubectl get namespace immich

# Verify storage is ready (if using dynamic provisioning)
kubectl get pvc -n immich
```

### Step 2: Create Required Secrets
Before deploying the services, create the required secrets with secure credentials. All secrets are created manually for enhanced security and are never stored in version control.

#### PostgreSQL Database Credentials
Create secure database credentials for PostgreSQL:

```bash
# Create PostgreSQL credentials with automatically generated secure password
kubectl create secret generic immich-postgres-secret \
  --from-literal=username=immich \
  --from-literal=password=$(openssl rand -base64 32) \
  --namespace=immich
```

**Alternative: Custom Password**
If you prefer to set a custom password, use a strong password generator:
```bash
# Create with custom secure password (replace with your own strong password)
kubectl create secret generic immich-postgres-secret \
  --from-literal=username=immich \
  --from-literal=password=YOUR_CUSTOM_SECURE_PASSWORD \
  --namespace=immich
```

#### Immich Server JWT Secret
Create a cryptographically secure JWT secret for server authentication:

```bash
# Generate and create JWT secret for server authentication
kubectl create secret generic immich-server-secret \
  --from-literal=jwt-secret=$(openssl rand -base64 32) \
  --namespace=immich
```

#### Verify Secret Creation
Confirm that both secrets have been created successfully:

```bash
# Check that secrets exist
kubectl get secrets -n immich

# Expected output should show both secrets:
# NAME                    TYPE     DATA   AGE
# immich-postgres-secret  Opaque   2      1m
# immich-server-secret    Opaque   1      1m
```

#### Secret Management Best Practices

**Security Requirements:**
- **Never use default passwords**: Always generate unique, strong credentials
- **Use cryptographically secure generation**: OpenSSL rand provides secure randomness
- **Store credentials securely**: Keep a secure backup of credentials outside of Git
- **Rotate regularly**: Plan for periodic credential rotation

**Backup Your Credentials:**
```bash
# Save PostgreSQL password for backup purposes (store securely)
kubectl get secret immich-postgres-secret -n immich -o jsonpath='{.data.password}' | base64 -d > postgres-password.txt

# Save JWT secret for backup purposes (store securely)
kubectl get secret immich-server-secret -n immich -o jsonpath='{.data.jwt-secret}' | base64 -d > jwt-secret.txt

# Store these files in a secure location and remove from the server
# IMPORTANT: Never commit these files to version control
```

**Credential Rotation:**
```bash
# To rotate PostgreSQL password:
kubectl delete secret immich-postgres-secret -n immich
kubectl create secret generic immich-postgres-secret \
  --from-literal=username=immich \
  --from-literal=password=$(openssl rand -base64 32) \
  --namespace=immich
kubectl rollout restart deployment/immich-postgres -n immich
kubectl rollout restart deployment/immich-server -n immich

# To rotate JWT secret:
kubectl delete secret immich-server-secret -n immich
kubectl create secret generic immich-server-secret \
  --from-literal=jwt-secret=$(openssl rand -base64 32) \
  --namespace=immich
kubectl rollout restart deployment/immich-server -n immich
```

**Important Security Notes:**
- All secrets are created manually outside of deployment manifests for enhanced security
- Secrets are never stored in version control or deployment files
- Use OpenSSL for cryptographically secure password generation
- Store backup copies of credentials in a secure password manager or encrypted storage
- Plan for regular credential rotation as part of security maintenance

### Step 3: Deploy Database and Cache
```bash
# Deploy PostgreSQL database with NVMe storage
kubectl apply -f apps/immich/02-database.yaml

# Deploy Redis cache with persistence
kubectl apply -f apps/immich/03-redis.yaml

# Verify database services are running
kubectl get pods,svc -n immich

# Check database connectivity
kubectl exec -n immich deployment/immich-postgres -- pg_isready -U immich
```

### Step 4: Deploy AI and Application Services
```bash
# Deploy machine learning service
kubectl apply -f apps/immich/04-machine-learning.yaml

# Deploy main Immich server
kubectl apply -f apps/immich/05-immich-server.yaml

# Deploy networking services
kubectl apply -f apps/immich/06-services.yaml

# Verify all services are running
kubectl get pods -n immich -o wide
```

### Step 5: Deploy Monitoring (Optional but Recommended)
```bash
# Deploy monitoring configuration
kubectl apply -f apps/immich/10-monitoring.yaml

# Verify monitoring is configured
kubectl get configmap immich-monitoring-config -n immich
```

### Step 6: Deploy Ingress (Optional but Recommended)
```bash
# Deploy ingress configuration for domain-based access
kubectl apply -f apps/immich/09-ingress.yaml

# Verify ingress creation
kubectl get ingress -n immich

# Check ingress status and endpoints
kubectl describe ingress immich-ingress -n immich
```

### Step 7: Verify Complete Deployment
```bash
# Check all resources are running
kubectl get all -n immich

# Verify pod status and node placement
kubectl get pods -n immich -o wide

# Check persistent volumes
kubectl get pv,pvc -n immich

# Test web interface connectivity
curl -f http://immich.home/api/server-info/ping
# Expected response: {"res":"pong"}

# Check application logs
kubectl logs -n immich -l app=immich-server --tail=20
```

### Step 8: Initial Setup
1. **Access Web Interface**: Navigate to `http://immich.home` or `http://NODE_IP:31283`
2. **Create Admin Account**: Follow the setup wizard to create your first admin user
3. **Configure Settings**: Set up your preferences, storage settings, and AI features
4. **Mobile App Setup**: See the Mobile App Configuration section below for detailed setup instructions

## Security

### Secret Management
All sensitive configuration is managed through manually created Kubernetes secrets for enhanced security. This approach ensures that sensitive data never appears in version control and provides better operational security.

#### Required Secrets

**PostgreSQL Database Credentials:**
```bash
# Create PostgreSQL credentials with secure password generation
kubectl create secret generic immich-postgres-secret \
  --from-literal=username=immich \
  --from-literal=password=$(openssl rand -base64 32) \
  --namespace=immich
```

**Immich Server JWT Secret:**
```bash
# Create JWT secret for server authentication
kubectl create secret generic immich-server-secret \
  --from-literal=jwt-secret=$(openssl rand -base64 32) \
  --namespace=immich
```

#### Security Best Practices

**Manual Secret Creation:**
- All secrets are created manually outside of deployment manifests
- Secrets are never stored in version control or deployment files
- Enhanced security through cryptographically secure key generation using OpenSSL
- Secrets can be managed independently of application deployments

**Password Security:**
- Never use default or placeholder passwords
- Generate strong passwords using `openssl rand -base64 32` for cryptographic security
- Use minimum 32-character base64 encoded passwords for maximum entropy
- Store credentials securely in password managers or encrypted storage

**Operational Security:**
- All secrets must be created before deploying application components
- Backup procedures should include secure storage of secret values
- Plan for regular credential rotation as part of security maintenance
- Document secret rotation procedures for operational teams

**Access Control:**
- Secrets are scoped to the immich namespace for isolation
- Follow principle of least privilege for service account access
- Regularly audit secret access and usage patterns
- Monitor for unauthorized secret access attempts

### Data Protection
- **Database Encryption**: PostgreSQL data encrypted at rest on NVMe storage
- **Network Security**: All internal communication over encrypted cluster network
- **File Permissions**: Proper file system permissions on NFS and NVMe storage
- **Backup Security**: Database backups stored securely on NFS with access controls

### Access Control
- **Web Interface**: Authentication required for all access
- **API Security**: JWT-based authentication for mobile apps and API access
- **User Management**: Role-based access control for shared albums and content
- **Session Management**: Secure session handling with configurable timeouts

### Network Security
- **Service Isolation**: Components isolated in dedicated namespace
- **Internal Communication**: Services communicate via internal cluster DNS
- **External Access**: Controlled via NodePort and Ingress with optional TLS
- **Firewall**: Network policies can be applied for additional security

### Best Practices
- **Regular Backups**: Automated database backups to NFS storage
- **Secret Rotation**: Plan for regular credential rotation
- **Monitoring**: Security event monitoring and alerting
- **Updates**: Keep container images updated for security patches
- **Principle of Least Privilege**: Minimal required permissions for all components

## Mobile App Testing and Validation

### Pre-Deployment Testing Checklist

Before configuring mobile apps, verify the deployment is ready:

```bash
# 1. Verify all services are running
kubectl get pods -n immich
# Expected: All pods should be in Running state

# 2. Test web interface connectivity
curl -f http://immich.home/api/server-info/ping
# Expected: {"res":"pong"}

# 3. Verify NodePort accessibility
curl -f http://192.168.88.126:31283/api/server-info/ping
# Expected: {"res":"pong"}

# 4. Check database connectivity
kubectl exec -n immich deployment/immich-postgres -- pg_isready -U immich
# Expected: accepting connections

# 5. Verify Redis connectivity
kubectl exec -n immich deployment/immich-redis -- redis-cli ping
# Expected: PONG

# 6. Test ML service
kubectl exec -n immich deployment/immich-ml -- curl -f http://localhost:3003/ping
# Expected: {"message":"pong"}
```



## Monitoring

> **Note**: Immich monitoring and alerting integrates with the existing cluster monitoring stack (Prometheus, Grafana, AlertManager). See `apps/monitoring/` for cluster-wide monitoring setup.

### Health Checks
All Immich components include comprehensive health checks:

- **Liveness Probes**: HTTP health endpoints for all services
- **Readiness Probes**: Service availability and dependency checks
- **Startup Probes**: Proper initialization verification with extended timeouts

### Built-in Monitoring
```bash
# Check pod resource usage
kubectl top pods -n immich

# Monitor all services status
kubectl get pods,svc -n immich -o wide

# View recent application logs
kubectl logs -n immich -l app=immich-server --tail=50

# Check database performance
kubectl exec -n immich deployment/immich-postgres -- \
  psql -U immich -d immich -c "SELECT * FROM pg_stat_activity WHERE state = 'active';"

# Monitor Redis performance
kubectl exec -n immich deployment/immich-redis -- redis-cli info stats

# Check ML service queue
kubectl exec -n immich deployment/immich-redis -- redis-cli llen immich:jobs:active
```

### Cluster Monitoring Integration
When integrated with the cluster monitoring stack, Immich provides:

#### Prometheus Metrics
- **Resource Monitoring**: CPU, memory, storage utilization for all components
- **Application Metrics**: Photo upload rates, processing times, user activity
- **Database Metrics**: Query performance, connection counts, cache hit rates
- **Storage Metrics**: Disk usage, I/O performance, backup status
- **ML Metrics**: Face detection rates, object recognition performance, model loading times

#### Grafana Dashboards
- **Immich Overview**: High-level service health and performance
- **Database Performance**: PostgreSQL metrics, query analysis, connection monitoring
- **Storage Analytics**: NFS and NVMe usage, I/O patterns, backup status
- **ML Processing**: AI service performance, model accuracy, processing queues
- **User Activity**: Upload patterns, search queries, mobile app usage

#### AlertManager Rules
- **Service Availability**: Alerts for pod failures or service unavailability
- **Resource Exhaustion**: CPU, memory, or storage threshold alerts
- **Database Issues**: Connection failures, slow queries, backup failures
- **Storage Alerts**: Disk space warnings, NFS connectivity issues
- **Performance Degradation**: Response time or throughput alerts

### Custom Monitoring
```bash
# Monitor storage usage trends
kubectl exec -n immich deployment/immich-server -- \
  du -sh /usr/src/app/upload/* | sort -hr

# Database connection monitoring
kubectl exec -n immich deployment/immich-postgres -- \
  psql -U immich -d immich -c "SELECT count(*) as connections FROM pg_stat_activity;"
```

### Performance Monitoring
```bash
# Real-time resource monitoring
watch kubectl top pods -n immich

# Database query performance
kubectl exec -n immich deployment/immich-postgres -- \
  psql -U immich -d immich -c "SELECT query, mean_time, calls FROM pg_stat_statements ORDER BY mean_time DESC LIMIT 10;"

# ML processing performance
kubectl logs -n immich -l app=immich-ml --tail=100 | grep -i "processing\|completed"

# Storage I/O monitoring
kubectl exec -n immich deployment/immich-postgres -- iostat -x 2 5
```

## Troubleshooting

### Common Issues

#### Service Not Starting
```bash
# Check pod status and events
kubectl get pods -n immich
kubectl get events -n immich --sort-by='.lastTimestamp'

# Check specific pod logs
kubectl logs -n immich <pod-name>

# Check pod resource usage
kubectl top pods -n immich

# Describe pod for detailed status
kubectl describe pod -n immich <pod-name>
```

#### Database Connection Issues
```bash
# Check PostgreSQL pod status
kubectl get pods -n immich -l app=immich-postgres

# Test database connectivity
kubectl exec -n immich deployment/immich-postgres -- pg_isready -U immich

# Check database logs
kubectl logs -n immich -l app=immich-postgres --tail=50

# Verify database secret exists
kubectl get secret immich-postgres-secret -n immich

# Test database connection from server pod
kubectl exec -n immich deployment/immich-server -- pg_isready -h immich-postgres -U immich
```

#### Missing Secrets Error
If pods fail to start due to missing credentials:

```bash
# Check if required secrets exist
kubectl get secrets -n immich

# Create PostgreSQL secret if missing
kubectl create secret generic immich-postgres-secret \
  --from-literal=username=immich \
  --from-literal=password=$(openssl rand -base64 32) \
  --namespace=immich

# Create server JWT secret if missing
kubectl create secret generic immich-server-secret \
  --from-literal=jwt-secret=$(openssl rand -base64 32) \
  --namespace=immich

# Restart affected deployments
kubectl rollout restart deployment/immich-postgres -n immich
kubectl rollout restart deployment/immich-server -n immich
```

#### Storage Issues
```bash
# Check persistent volumes and claims
kubectl get pv,pvc -n immich

# Check NFS connectivity from a pod
kubectl exec -n immich deployment/immich-server -- df -h /usr/src/app/upload

# Test NFS mount manually
kubectl run nfs-test --image=busybox --rm -it --restart=Never -- \
  sh -c "mkdir -p /mnt/test && mount -t nfs 192.168.88.126:/mnt/storage/immich/library /mnt/test && ls -la /mnt/test"

# Check node05 NVMe storage space
kubectl exec -n immich deployment/immich-postgres -- df -h /var/lib/postgresql/data
```

#### Machine Learning Service Issues
```bash
# Check ML service status
kubectl get pods -n immich -l app=immich-ml

# Check ML service logs
kubectl logs -n immich -l app=immich-ml --tail=50

# Test ML service connectivity
kubectl exec -n immich deployment/immich-ml -- curl -f http://localhost:3003/ping

# Check ML model downloads
kubectl exec -n immich deployment/immich-ml -- ls -la /cache/

# Monitor ML service resource usage
kubectl top pods -n immich -l app=immich-ml
```

#### Web Interface Not Accessible
```bash
# Check Immich server pod status
kubectl get pods -n immich -l app=immich-server

# Check NodePort service
kubectl get svc immich-server-nodeport -n immich

# Test service connectivity internally
kubectl exec -n immich deployment/immich-server -- curl -f http://localhost:3001/api/server-info/ping

# Check ingress configuration
kubectl get ingress -n immich
kubectl describe ingress immich-ingress -n immich

# Test external connectivity
curl -f http://192.168.88.126:31283/api/server-info/ping
```

#### Mobile App Connection Issues
```bash
# Verify NodePort service is accessible
curl -f http://NODE_IP:31283/api/server-info/ping

# Check session affinity configuration
kubectl get svc immich-server-nodeport -n immich -o yaml | grep -A5 sessionAffinity

# Monitor server logs for mobile app requests
kubectl logs -n immich -l app=immich-server -f | grep -i mobile

# Check authentication logs
kubectl logs -n immich -l app=immich-server | grep -i auth
```

#### Performance Issues
```bash
# Check resource usage across all pods
kubectl top pods -n immich

# Monitor database performance
kubectl exec -n immich deployment/immich-postgres -- \
  psql -U immich -d immich -c "SELECT * FROM pg_stat_activity WHERE state = 'active';"

# Check Redis performance
kubectl exec -n immich deployment/immich-redis -- redis-cli info stats

# Monitor ML processing queue
kubectl exec -n immich deployment/immich-redis -- redis-cli llen immich:jobs:active

# Check storage I/O performance
kubectl exec -n immich deployment/immich-postgres -- iostat -x 1 3
```

### Useful Diagnostic Commands

#### Health Check All Services
```bash
# Quick health check script
echo "=== Pod Status ==="
kubectl get pods -n immich

echo "=== Service Status ==="
kubectl get svc -n immich

echo "=== Database Health ==="
kubectl exec -n immich deployment/immich-postgres -- pg_isready -U immich

echo "=== Redis Health ==="
kubectl exec -n immich deployment/immich-redis -- redis-cli ping

echo "=== ML Service Health ==="
kubectl exec -n immich deployment/immich-ml -- curl -s http://localhost:3003/ping

echo "=== Server Health ==="
kubectl exec -n immich deployment/immich-server -- curl -s http://localhost:3001/api/server-info/ping
```

#### Log Collection
```bash
# Collect logs from all Immich components
kubectl logs -n immich -l app=immich-server --tail=100 > immich-server.log
kubectl logs -n immich -l app=immich-postgres --tail=100 > immich-postgres.log
kubectl logs -n immich -l app=immich-redis --tail=100 > immich-redis.log
kubectl logs -n immich -l app=immich-ml --tail=100 > immich-ml.log

# Check for errors across all logs
grep -i error *.log
grep -i failed *.log
```

#### Resource Monitoring
```bash
# Monitor resource usage over time
watch kubectl top pods -n immich

# Check persistent volume usage
kubectl exec -n immich deployment/immich-server -- df -h

# Monitor network connectivity
kubectl exec -n immich deployment/immich-server -- netstat -tuln
```

### Recovery Procedures

#### Database Recovery
```bash
# If database is corrupted, restore from PostgreSQL backup
# Note: Backup and recovery procedures are not included in this deployment
# but can be implemented as needed for your environment

# Restart database if it's in a bad state
kubectl rollout restart deployment/immich-postgres -n immich
```

#### Complete Service Restart
```bash
# Restart all Immich services in correct order
kubectl rollout restart deployment/immich-postgres -n immich
kubectl rollout restart deployment/immich-redis -n immich
kubectl rollout restart deployment/immich-ml -n immich
kubectl rollout restart deployment/immich-server -n immich

# Wait for all pods to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=immich -n immich --timeout=300s
``` mount status
kubectl describe pvc -n immich

# Check node05 storage space
kubectl exec -n immich deployment/postgres -- df -h /var/lib/postgresql/data
```

#### Configuration Issues
```bash
# Check if ConfigMaps exist
kubectl get configmaps -n immich

# View current configuration
kubectl describe configmap immich-server-config -n immich

# Check configuration syntax in pods
kubectl exec -n immich deployment/immich-server -- cat /config/immich-config.json

# Validate PostgreSQL configuration
kubectl exec -n immich deployment/immich-postgres -- postgres --help --config

# Test Redis configuration
kubectl exec -n immich deployment/immich-redis -- redis-cli CONFIG GET "*"
```

#### Performance Issues
```bash
# Check resource usage
kubectl top pods -n immich

# Check ML service performance
kubectl logs -n immich -l app=immich-ml

# Monitor database performance
kubectl exec -n immich deployment/postgres -- psql -U immich -c "SELECT * FROM pg_stat_activity;"

# Check configuration-related performance issues
kubectl exec -n immich deployment/immich-postgres -- psql -U immich -c "SELECT name, setting FROM pg_settings WHERE name IN ('shared_buffers', 'effective_cache_size', 'work_mem');"
```

#### Configuration Validation
```bash
# Validate all ConfigMaps are properly mounted
kubectl describe pod -n immich -l app=immich-server | grep -A 10 "Mounts:"

# Check for configuration parsing errors in logs
kubectl logs -n immich -l app=immich-server | grep -i "config\|error"

# Verify environment variables from ConfigMaps
kubectl exec -n immich deployment/immich-server -- env | grep -E "(DB_|REDIS_|MACHINE_LEARNING_)"
```

## Data Protection

This deployment focuses on the core Immich application without built-in backup and recovery procedures. Data protection should be implemented at the infrastructure level.

### Recommendations for Data Protection

#### Database Protection
- Implement PostgreSQL backups at the infrastructure level
- Consider using database snapshots if available on your storage system
- Store database credentials securely and maintain access for recovery

#### Media File Protection
- Media files are stored on NFS storage which should have its own backup/redundancy
- Consider implementing regular NFS/storage-level backups
- Monitor storage capacity and performance

#### Configuration Protection
- All configuration is stored in Kubernetes manifests (version controlled)
- Secrets should be backed up securely outside of the cluster
- Document any manual configuration steps for disaster recovery

#### Basic Recovery Procedures
```bash
# If database is corrupted, restore from PostgreSQL backup
# Note: Backup and recovery procedures are not included in this deployment
# but can be implemented as needed for your environment

# Restart database if it's in a bad state
kubectl rollout restart deployment/immich-postgres -n immich

# Restart all services
kubectl rollout restart deployment -n immich
```

## Configuration Management Best Practices

### Configuration Lifecycle Management

#### Initial Configuration
1. **Review default settings**: All ConfigMaps contain optimized defaults for Pi 5 hardware
2. **Customize for your environment**: Adjust memory limits, concurrency, and feature flags
3. **Test configuration changes**: Always test in a non-production environment first
4. **Document customizations**: Keep track of changes from defaults

#### Configuration Updates
```bash
# Safe configuration update process
# 1. Backup current configuration
kubectl get configmap immich-server-config -n immich -o yaml > backup-server-config.yaml

# 2. Create updated configuration file
kubectl get configmap immich-server-config -n immich -o yaml > updated-server-config.yaml
# Edit updated-server-config.yaml with your changes

# 3. Validate configuration syntax (for JSON configs)
cat updated-server-config.yaml | grep -A 1000 "immich-config.json:" | tail -n +2 | head -n -1 | jq .

# 4. Apply changes with rollback capability
kubectl apply -f updated-server-config.yaml

# 5. Monitor application after changes
kubectl rollout status deployment/immich-server -n immich
kubectl logs -n immich -l app=immich-server --tail=20

# 6. Rollback if needed
kubectl apply -f backup-server-config.yaml
kubectl rollout restart deployment/immich-server -n immich
```

#### Configuration Backup and Restore
```bash
# Backup all configurations
mkdir -p immich-config-backup/$(date +%Y%m%d)
kubectl get configmap immich-postgres-config -n immich -o yaml > immich-config-backup/$(date +%Y%m%d)/postgres-config.yaml
kubectl get configmap immich-redis-config -n immich -o yaml > immich-config-backup/$(date +%Y%m%d)/redis-config.yaml
kubectl get configmap immich-ml-config -n immich -o yaml > immich-config-backup/$(date +%Y%m%d)/ml-config.yaml
kubectl get configmap immich-server-config -n immich -o yaml > immich-config-backup/$(date +%Y%m%d)/server-config.yaml

# Restore from backup
kubectl apply -f immich-config-backup/20240101/
kubectl rollout restart deployment -n immich
```

### Configuration Validation and Testing

#### Pre-deployment Validation
```bash
# Validate JSON configuration syntax
kubectl get configmap immich-server-config -n immich -o jsonpath='{.data.immich-config\.json}' | jq .

# Check PostgreSQL configuration syntax
kubectl get configmap immich-postgres-config -n immich -o jsonpath='{.data.postgresql\.conf}' | postgres --help --config

# Validate Redis configuration
kubectl get configmap immich-redis-config -n immich -o jsonpath='{.data.redis\.conf}' | redis-server --test-config -
```

#### Post-deployment Testing
```bash
# Test database configuration
kubectl exec -n immich deployment/immich-postgres -- psql -U immich -c "SHOW ALL;" | grep -E "(shared_buffers|effective_cache_size|work_mem)"

# Test Redis configuration
kubectl exec -n immich deployment/immich-redis -- redis-cli CONFIG GET "*memory*"

# Test server configuration loading
kubectl exec -n immich deployment/immich-server -- curl -s http://localhost:3001/api/server-info/config | jq .
```

### Environment-Specific Customizations

#### Development Environment
```json
{
  "logging": {
    "level": "debug"
  },
  "job": {
    "thumbnailGeneration": {
      "concurrency": 1
    }
  },
  "machineLearning": {
    "enabled": false
  }
}
```

#### Production Environment
```json
{
  "logging": {
    "level": "warn"
  },
  "job": {
    "thumbnailGeneration": {
      "concurrency": 5
    }
  },
  "machineLearning": {
    "enabled": true
  },
  "monitoring": {
    "enabled": true
  }
}
```

#### High-Performance Environment
```bash
# PostgreSQL optimizations
shared_buffers = 512MB
effective_cache_size = 1536MB
work_mem = 8MB
maintenance_work_mem = 128MB

# Redis optimizations
maxmemory 800mb
maxmemory-samples 10
```

## Performance Optimization

### Hardware Utilization
- **Pi 5 Advantages**: Leveraged for all compute-intensive tasks
- **NVMe Performance**: Database and cache on fastest storage
- **Memory Optimization**: Efficient caching strategies configured via ConfigMaps
- **CPU Optimization**: ML processing on most capable hardware with tuned concurrency

### Configuration-Based Performance Tuning
- **Database Performance**: Tuned via immich-postgres-config for NVMe storage
- **Cache Efficiency**: Optimized Redis settings in immich-redis-config
- **Job Processing**: Configurable concurrency limits in immich-server-config
- **ML Performance**: Hardware-specific settings in immich-ml-config

### Scaling Considerations
- Single-node optimization for home lab use
- Horizontal scaling possible with configuration adjustments
- Resource limits prevent resource exhaustion
- Performance monitoring for optimization opportunities

## Integration

### Cluster Integration
- Follows established cluster patterns and conventions
- Compatible with existing monitoring and logging
- Integrates with cluster ingress and load balancing
- Data protection should be implemented at the infrastructure level

### Mobile App Integration
- iOS and Android app support
- Automatic photo backup from mobile devices
- Real-time sync capabilities
- Offline viewing support

### API Integration
- RESTful API for third-party integrations
- Webhook support for automation
- Compatible with existing photo management workflows
- Export capabilities for data portability

---

**Immich provides a comprehensive self-hosted photo management solution with AI-powered features, optimized for high performance on Kubernetes infrastructure.**
