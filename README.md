# PiCluster

PiCluster is a fully automated, self-hosted Kubernetes media server stack designed for Raspberry Pi clusters. Built on a Turing Pi 2.5 carrier board with four Raspberry Pi Compute Module 4 nodes, plus an additional standalone Raspberry Pi 5 as the control plane.

This project provides manifests and configuration for running Jellyfin, Sonarr, Radarr, Transmission (with VPN), Prowlarr, Pi-hole DNS, Cloudflare Tunnel, and a modern dashboard—all orchestrated by K3s with GitOps via ArgoCD and backed by shared NFS storage. The hybrid architecture uses Compute Module 4s for worker nodes and a Raspberry Pi 5 for the control plane, providing optimal performance and reliability. PiCluster is ideal for homelab enthusiasts, edge computing, and anyone seeking a robust, private alternative to cloud-based media solutions.

---

<p align="center">
  <img src="images/pi-cluster-v2.jpeg" alt="Raspberry Pi Cluster" width="600"/>
</p>

## 📑 Index

- [Hardware Setup](#hardware-setup)
- [Kubernetes Installation (K3s)](#kubernetes-installation-k3s)
- [Storage Configuration (NFS)](#storage-configuration-nfs)
- [Remote Access Setup](#remote-access-setup)
- [Media Server Applications](#media-server-applications)
  - [Application Stack Overview](#application-stack-overview)
  - [Detailed Application Information](#detailed-application-information)
  - [Storage Architecture](#storage-architecture)
  - [Network Configuration](#network-configuration)
  - [Deployment and Management](#deployment-and-management)
  - [Security Features](#security-features)
  - [Integration Workflow](#integration-workflow)

---

## Hardware Setup

### Architecture Overview

This cluster uses a **hybrid architecture** combining two different Raspberry Pi platforms:

- **Turing Pi 2.5 Carrier Board**: Houses 4x Raspberry Pi Compute Module 4 nodes as workers
- **Standalone Raspberry Pi 5**: Serves as the dedicated control plane node

**Benefits of this setup:**
- **Enhanced Performance**: Pi 5 provides superior CPU/memory for Kubernetes control plane
- **Improved Reliability**: Separate control plane reduces worker node impact on cluster management
- **Better Resource Allocation**: Workers focus purely on application workloads
- **Easier Maintenance**: Control plane can be maintained independently
- **Future Expansion**: Easy to add more worker nodes to the Turing Pi board

### Requirements
- Turing Pi 2.5 carrier board
- 4x Raspberry Pi Compute Module 4 (with eMMC)
- 1x Raspberry Pi 5 (standalone, for control plane)
- Micro SD card (for OS images and Pi 5)
- Network connection to your LAN

### Node Configuration
| Node | Hardware | Role | IP Address | Hostname |
|------|----------|------|------------|----------|
| Node 1 | CM4 (Turing Pi) | Worker | 192.168.88.167 | node01 |
| Node 2 | CM4 (Turing Pi) | Worker | 192.168.88.164 | node02 |
| Node 3 | CM4 (Turing Pi) | Worker | 192.168.88.163 | node03 |
| Node 4 | CM4 (Turing Pi) | Worker | 192.168.88.162 | node04 |
| Node 5 | **Pi 5 (Standalone)** | **Control Plane** | 192.168.88.126 | node05 |

## Hardware Setup and Configuration

### Turing Pi 2.5 Setup (Nodes 1-4)

#### Flash the eMMC on the Raspberry Pi Compute Module 4 and Configure the Nodes
### Step 1: Prepare the OS Image
1. Download the latest Raspberry Pi OS Lite (64-bit) image from the [official website](https://www.raspberrypi.com/software/operating-systems/#raspberry-pi-os-64-bit)
2. Copy the image to the `images/` folder on your micro SD card
3. Insert the micro SD card into the slot on the back of your Turing Pi carrier board

### Step 2: Access the Turing Pi Management Interface
Log into your Turing Pi carrier board (default password is `turing`):
```bash
ssh root@turingpi.local
```
### Step 3: Flash Each Compute Module
Flash the OS image to the eMMC on each Raspberry Pi Compute Module 4 (repeat for nodes 1-4):
```bash
tpi flash -n 1 -l -i /mnt/sdcard/images/2024-11-19-raspios-bookworm-arm64-lite.img
```
### Step 4: Configure Boot Settings
Mount the eMMC to modify boot configuration:
```bash
tpi advanced msd --node 1
mount /dev/sda1 /mnt/bootfs
```
Enable UART logging for boot diagnostics:
```bash
echo "enable_uart=1" >> /mnt/bootfs/config.txt
```

Enable SSH server:
```bash
touch /mnt/bootfs/ssh
```

Create default user account (username: `pi`, password: `raspberry`):
```bash
echo 'pi:$6$c70VpvPsVNCG0YR5$l5vWWLsLko9Kj65gcQ8qvMkuOoRkEagI90qi3F/Y7rm8eNYZHW8CY6BOIKwMH7a3YYzZYL90zf304cAHLFaZE0' > /mnt/bootfs/userconf
```

Enable memory cgroups for Kubernetes (append to existing cmdline.txt):
```bash
sed -i '$ s/$/ cgroup_memory=1 cgroup_enable=memory/' /mnt/bootfs/cmdline.txt
```

Unmount and restart the node:
```bash
umount /mnt/bootfs
tpi power -n 1 off
tpi power -n 1 on
```

Monitor boot process:
```bash
tpi uart get -n 1
```

**Repeat steps 3-4 for all four Compute Module nodes (node01-node04).**

### Raspberry Pi 5 Setup (Node 5 - Control Plane)

#### Step 6: Setup Standalone Raspberry Pi 5
The control plane runs on a separate Raspberry Pi 5 for enhanced performance and reliability.

**Flash Raspberry Pi OS:**
1. Use Raspberry Pi Imager to flash Raspberry Pi OS Lite (64-bit) to a microSD card
2. Enable SSH and configure user account during imaging
3. Set hostname to `node05`
4. Configure WiFi if desired (optional - ethernet recommended)

**Initial Configuration:**
```bash
# SSH into the Pi 5
ssh pi@192.168.88.126

# Update system
sudo apt update && sudo apt upgrade -y

# Install essential tools
sudo apt install -y curl wget vim htop iptables iptables-persistent

# Enable memory cgroups for Kubernetes
sudo sed -i '$ s/$/ cgroup_memory=1 cgroup_enable=memory/' /boot/firmware/cmdline.txt

# Reboot to apply changes
sudo reboot
```

### Step 7: Configure Network and Hostnames
After all nodes have booted (CM4 nodes + Pi 5), SSH into each node and configure networking.

Add all node IP addresses to `/etc/hosts` on each Compute Module:
```
127.0.0.1      localhost
192.168.88.167 node01 node01.local
192.168.88.164 node02 node02.local
192.168.88.163 node03 node03.local
192.168.88.162 node04 node04.local
192.168.88.126 node05 node05.local
```

Set the appropriate hostname on each node:
```bash
# On node01 (192.168.88.167)
hostnamectl set-hostname node01

# On node02 (192.168.88.164)
hostnamectl set-hostname node02

# On node03 (192.168.88.163)
hostnamectl set-hostname node03

# On node04 (192.168.88.162)
hostnamectl set-hostname node04

# On node05 (192.168.88.126) - Control Plane
hostnamectl set-hostname node05
```

Update package lists and install essential tools:
```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl wget vim htop iptables iptables-persistent
```
## Kubernetes Installation (K3s)

### Overview
This cluster uses K3s, a lightweight Kubernetes distribution optimized for edge computing and IoT devices.

**Technology Stack:**
- **K3s**: https://docs.k3s.io/
- **Kube-VIP**: https://kube-vip.io/ (for load balancing)
- **k3sup**: https://github.com/alexellis/k3sup (optional deployment tool)

### Step 1: Initialize the Control Plane Node
On the control plane node (node05 - Raspberry Pi 5 - 192.168.88.126):
```bash
curl -sfL https://get.k3s.io | sh -s - \
  --write-kubeconfig-mode 644 \
  --node-ip 192.168.88.126 \
  --disable local-storage
```

**Installation Options Explained:**
- `--write-kubeconfig-mode 644`: Makes kubeconfig readable by non-root users
- `--node-ip`: Specifies the node's IP address for cluster communication
- `--disable local-storage`: Disables default local storage (we'll use NFS)

Retrieve the cluster join token:
```bash
sudo cat /var/lib/rancher/k3s/server/node-token
```

Verify control plane is running:
```bash
kubectl get nodes
kubectl get pods --all-namespaces
```

### Step 2: Join Worker Nodes to the Cluster
On each worker node (node01, node02, node03, node04), run:
```bash
curl -sfL https://get.k3s.io | K3S_URL=https://192.168.88.126:6443 K3S_TOKEN=<TOKEN_FROM_STEP_1> sh -
```

### Step 3: Label Worker Nodes
From the control plane node, label all worker nodes:
```bash
kubectl label node node01 node-role.kubernetes.io/worker=worker
kubectl label node node02 node-role.kubernetes.io/worker=worker
kubectl label node node03 node-role.kubernetes.io/worker=worker
kubectl label node node04 node-role.kubernetes.io/worker=worker
```

Verify cluster status:
```bash
kubectl get nodes -o wide
```

Expected output:
```
NAME     STATUS   ROLES                  AGE   VERSION        INTERNAL-IP      EXTERNAL-IP   OS-IMAGE
node01   Ready    worker                 1m    v1.32.6+k3s1   192.168.88.167   <none>        Debian GNU/Linux 12 (bookworm)  [CM4]
node02   Ready    worker                 1m    v1.32.6+k3s1   192.168.88.164   <none>        Debian GNU/Linux 12 (bookworm)  [CM4]
node03   Ready    worker                 1m    v1.32.6+k3s1   192.168.88.163   <none>        Debian GNU/Linux 12 (bookworm)  [CM4]
node04   Ready    worker                 1m    v1.32.6+k3s1   192.168.88.162   <none>        Debian GNU/Linux 12 (bookworm)  [CM4]
node05   Ready    control-plane,master   5m    v1.32.6+k3s1   192.168.88.126   <none>        Debian GNU/Linux 12 (bookworm)  [Pi5]
```
## Storage Configuration (NFS)

### Overview
The cluster uses NFS for shared persistent storage across all nodes. Node03 (192.168.88.163) serves as the NFS server, and the NFS Subdir External Provisioner automatically creates PersistentVolumes from PersistentVolumeClaims.

**Storage Components:**
- **NFS Server**: node03 (192.168.88.163) at `/mnt/storage`
- **NFS Provisioner**: Deployed on node01 via Helm (managed by ArgoCD)
- **Storage Class**: `nfs` (default for dynamic provisioning)

### Step 1: Install NFS Server
On node03 (192.168.88.163), install and configure NFS:
```bash
sudo apt install nfs-kernel-server -y
```

### Step 2: Create Storage Directory Structure
Create the directory structure for media server data:
```bash
sudo mkdir -p /mnt/storage/{jellyfin,transmission,sonarr,radarr,jackett}/{config,data}
sudo mkdir -p /mnt/storage/{downloads,media/{movies,tv,music}}
sudo mkdir -p /mnt/storage/monitoring/{prometheus,grafana}
sudo chown -R 1000:1000 /mnt/storage
sudo chown 65534:65534 /mnt/storage/monitoring/prometheus
sudo chown 472:472 /mnt/storage/monitoring/grafana
sudo chmod -R 755 /mnt/storage
```

### Step 3: Configure NFS Exports
Add the following line to `/etc/exports`:
```bash
echo "/mnt/storage       192.168.88.0/24(rw,sync,no_subtree_check,no_root_squash)" | sudo tee -a /etc/exports
```

Apply the NFS configuration:
```bash
sudo exportfs -ra
sudo systemctl enable nfs-kernel-server
sudo systemctl restart nfs-kernel-server
```

### Step 4: Install NFS Client on All Nodes
On all nodes (including control plane), install NFS client utilities:
```bash
sudo apt install nfs-common -y
```

Test NFS mount from a worker node:
```bash
sudo mkdir -p /tmp/nfs-test
sudo mount -t nfs 192.168.88.163:/mnt/storage /tmp/nfs-test
ls -la /tmp/nfs-test
sudo umount /tmp/nfs-test
```

### Step 5: Deploy NFS Provisioner
The NFS Subdir External Provisioner is deployed via ArgoCD and creates PersistentVolumes automatically:

```bash
# The provisioner is deployed as part of the shared-storage application
kubectl apply -f apps/argocd/shared-storage-application.yaml
```

**Configuration** (in `apps/shared-storage/00-nfs-provisioner.yaml`):
- **NFS Server**: 192.168.88.163 (node03)
- **NFS Path**: `/mnt/storage`
- **Storage Class**: `nfs`
- **Node Selector**: Runs on node01

**Usage**: Applications can request storage by creating PVCs with `storageClassName: nfs`:
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-app-data
spec:
  accessModes:
    - ReadWriteOnce  # or ReadWriteMany for shared access
  storageClassName: nfs
  resources:
    requests:
      storage: 10Gi
```

The provisioner will automatically create a subdirectory under `/mnt/storage` and bind it to the PVC.

## Remote Access Setup

### Copy Kubernetes Configuration
To manage the cluster from your local machine, copy the kubeconfig:

```bash
# From your local machine (copy from Pi 5 control plane)
scp pi@192.168.88.126:/etc/rancher/k3s/k3s.yaml ~/.kube/config-picluster

# Update server endpoint in the config
sed -i 's/127.0.0.1/192.168.88.126/g' ~/.kube/config-picluster

# Set KUBECONFIG environment variable
export KUBECONFIG=~/.kube/config-picluster

# Test connectivity
kubectl get nodes
```

## Media Server Applications

This K3s cluster hosts a complete media server stack with automated content management and VPN-protected downloads. All applications are deployed using Kubernetes manifests located in the `apps/` directory.

### Application Stack Overview

| Application | Purpose | Access URL | Service Type | Docs |
|-------------|---------|------------|--------------|------|
| **Homarr** | Modern Dashboard & Service Management | `http://192.168.88.126:31880` | NodePort | [Homarr README](apps/homarr/README.md) |
| **Jellyfin** | Media Server & Streaming | `http://192.168.88.126:8096` | LoadBalancer | [Jellyfin README](apps/jellyfin/README.md) |
| **Immich** | Self-hosted Photo & Video Management | `http://192.168.88.126:31283` | NodePort | [Immich README](apps/immich/README.md) |
| **Database** | Shared PostgreSQL & Redis Services | Internal Only | ClusterIP | [Database README](apps/database/README.md) |
| **Transmission** | BitTorrent Client (VPN Protected) | `http://192.168.88.162:9091` | LoadBalancer | [Transmission README](apps/transmission/README.md) |
| **Sonarr** | TV Series Management | `http://192.168.88.162:8989` | LoadBalancer | [Sonarr README](apps/sonarr/README.md) |
| **Radarr** | Movie Management | `http://192.168.88.162:7878` | LoadBalancer | [Radarr README](apps/radarr/README.md) |
| **Prowlarr** | Indexer Manager (Jackett Replacement) | `http://192.168.88.162:9117` | LoadBalancer | - |
| **Pi-hole** | Network-wide DNS Ad Blocker | `http://192.168.88.167:31080/admin/` | NodePort | [Pi-hole README](apps/pihole/README.md) |
| **Cloudflare Tunnel** | Secure Remote Access | External via Cloudflare | Tunnel | [Cloudflare Tunnel README](apps/cloudflare-tunnel/README.md) |
| **Argo CD** | GitOps Kubernetes Management | `http://192.168.88.163:30080` | NodePort | [Argo CD README](apps/argocd/README.md) |
| **Grafana** | Monitoring Dashboards (PostgreSQL Backend) | `http://192.168.88.126:30300` | NodePort | [Monitoring README](apps/monitoring/README.md) |
| **Prometheus** | Metrics Collection | `http://192.168.88.126:30900` | NodePort | [Monitoring README](apps/monitoring/README.md) |
| **n8n** | Workflow Automation & Integration | `http://192.168.88.126:32000` | NodePort | - |

### Detailed Application Information


#### 🎬 Jellyfin - Media Server
- **Namespace**: `jellyfin`
- **Description**: Open-source media server for streaming movies, TV shows, and music
- **Features**:
  - Hardware transcoding support
  - Multiple client support (web, mobile, TV apps)
  - User management and content libraries
  - DLNA/UPnP support for local network streaming
- **Storage**:
  - Config: `/mnt/storage/jellyfin/config`
  - Media: `/mnt/storage/media` (shared with other apps)
- **Ports**: 8096 (HTTP), 8920 (HTTPS), 1900 (DLNA), 7359 (Discovery)
- **More info**: [apps/jellyfin/README.md](apps/jellyfin/README.md)

#### 📸 Immich - Self-hosted Photo & Video Management
- **Namespace**: `immich`
- **Description**: Modern self-hosted photo and video management solution with AI-powered features
- **Features**:
  - Automatic photo backup from mobile devices
  - AI-powered face recognition and object detection
  - Advanced search with CLIP embeddings
  - Timeline view and album organization
  - RAW photo support and thumbnail generation
  - Video transcoding and streaming
- **Storage**:
  - Database: NVMe storage on node05 (PostgreSQL)
  - Cache: Redis with persistence on node05
  - Media: `/mnt/storage/immich/` (photos, videos, thumbnails)
  - ML Models: Cached on node05 NVMe for fast inference
- **Ports**: 31283 (HTTP Web Interface)
- **Mobile Apps**: iOS and Android with automatic backup
- **More info**: [apps/immich/README.md](apps/immich/README.md)

#### 🗄️ Database - Shared Database Services
- **Namespace**: `database`
- **Description**: Centralized PostgreSQL and Redis instances for shared use across applications
- **Features**:
  - PostgreSQL 15 with pgvector extension for AI/ML workloads
  - Multi-database support (immich, n8n, grafana)
  - Redis 7 with multiple database namespaces
  - NVMe storage optimization on node05
  - Prometheus metrics via postgres_exporter
  - Connection pooling ready
  - Automated health checks and monitoring
- **Storage**:
  - PostgreSQL: 100GB NVMe storage on node05
  - Redis: 10GB NVMe storage on node05
- **Usage**: Internal cluster services only
- **Applications**: Used by Immich, n8n, Grafana
- **Monitoring**: Exposed metrics on port 9187 for Prometheus
- **More info**: [apps/database/README.md](apps/database/README.md)

#### 🔒 Transmission - Torrent Client (VPN Protected)
- **Namespace**: `downloads`
- **Description**: BitTorrent client with integrated VPN protection via Gluetun
- **Features**:
  - WireGuard integration with kill-switch
  - Automatic VPN health monitoring
  - Firewall protection (only VPN traffic allowed)
  - Custom DNS server for enhanced privacy
  - Public IP verification and logging
- **VPN Status**: Automatically monitored with health checks
- **Storage**:
  - Config: `/mnt/storage/transmission/config`
  - Downloads: `/mnt/storage/shared/downloads` (shared with *arr apps)
- **More info**: [apps/transmission/README.md](apps/transmission/README.md)

#### 📺 Sonarr - TV Series Management
- **Namespace**: `downloads`
- **Description**: Automated TV series collection and management
- **Features**:
  - Automatic episode monitoring and downloading
  - Integration with Transmission and Jackett
  - Metadata and artwork management
  - Episode renaming and organization
- **Storage**:
  - Config: `/mnt/storage/sonarr/config`
  - TV Shows: `/mnt/storage/jellyfin/media/tv-shows`
  - Downloads: `/mnt/storage/shared/downloads` (shared)
- **More info**: [apps/sonarr/README.md](apps/sonarr/README.md)

#### 🎭 Radarr - Movie Management
- **Namespace**: `downloads`
- **Description**: Automated movie collection and management
- **Features**:
  - Automatic movie monitoring and downloading
  - Integration with Transmission and Jackett
  - Quality profiles and release management
  - Movie metadata and artwork
- **Storage**:
  - Config: `/mnt/storage/radarr/config`
  - Movies: `/mnt/storage/jellyfin/media/movies`
  - Downloads: `/mnt/storage/shared/downloads` (shared)
- **More info**: [apps/radarr/README.md](apps/radarr/README.md)

#### 🔍 Prowlarr - Indexer Manager
- **Namespace**: `prowlarr`
- **Description**: Modern indexer manager and proxy for torrent trackers (Jackett replacement)
- **Features**:
  - Support for 500+ torrent trackers
  - Unified search API for *arr applications
  - Automatic tracker health monitoring
  - Built-in sync with Sonarr/Radarr
  - Modern web interface with statistics
- **Storage**: Config: `/mnt/storage/prowlarr/config`
- **More info**: [apps/prowlarr/README.md](apps/prowlarr/README.md)

#### 🛡️ Pi-hole - DNS Ad Blocker
- **Namespace**: `dns`
- **Description**: Network-wide DNS ad blocking and filtering service
- **Features**:
  - Network-wide ad blocking at DNS level
  - Custom blocklists with automatic updates
  - DNS filtering for malicious domains
  - Web interface for management and statistics
  - High availability via LoadBalancer
  - DNSSEC support
- **Storage**: Config and logs: `/mnt/storage/pihole/`
- **DNS Servers**: Available on all cluster node IPs (port 53)
- **More info**: [apps/pihole/README.md](apps/pihole/README.md)

#### 🌐 Cloudflare Tunnel
- **Namespace**: `cloudflare-tunnel`
- **Description**: Secure remote access to cluster services via Cloudflare
- **Features**:
  - Secure tunneling without port forwarding
  - SSL/TLS termination at Cloudflare edge
  - Access control and authentication
  - Multiple service routing
  - Zero-trust network access
- **Access**: External via configured Cloudflare domains
- **More info**: [apps/cloudflare-tunnel/README.md](apps/cloudflare-tunnel/README.md)

#### 🔄 n8n - Workflow Automation
- **Namespace**: `automation`
- **Description**: Self-hosted workflow automation platform for connecting apps and services
- **Features**:
  - Visual workflow builder with 400+ integrations
  - PostgreSQL backend for workflow storage
  - Redis queue for reliable execution
  - Webhook support for external triggers
  - AWS integration for cloud services
  - Custom JavaScript/Python code execution
- **Storage**:
  - Database: PostgreSQL (shared database service)
  - Queue: Redis database 2
  - Workflows: `/mnt/storage/n8n/` (persistent data)
- **Access**: `http://192.168.88.126:32000`
- **More info**: [apps/n8n/README.md](apps/n8n/README.md)



#### 🚀 Argo CD - GitOps Kubernetes Management
- **Namespace**: `argocd`
- **Description**: Declarative GitOps continuous delivery tool for Kubernetes. Manages application deployments via Git.
- **Features**:
  - Visual dashboard for application sync/status
  - Automated sync and self-healing
  - Rollbacks, history, and audit trails
  - SSO and RBAC support
- **Access**: [http://192.168.88.163:30080](http://192.168.88.163:30080)
- **Docs**: [Argo CD Documentation](https://argo-cd.readthedocs.io/)

#### 📊 Monitoring Stack
- **Namespace**: `monitoring`
- **Description**: Complete monitoring solution for cluster and application metrics
- **Components**:
  - **Prometheus**: Time-series database collecting metrics from all cluster nodes and applications
  - **Grafana**: Visualization platform with PostgreSQL backend for dashboards and alerting
  - **Node Exporter**: System metrics collector running on all nodes (CPU, memory, disk, network)
  - **postgres_exporter**: PostgreSQL metrics exporter for database monitoring
- **Features**:
  - Real-time cluster and application monitoring
  - Persistent storage for historical data (15-day retention)
  - Auto-discovery of Kubernetes services via annotations
  - Pre-configured Prometheus datasource in Grafana
  - PostgreSQL database monitoring with detailed metrics
  - Grafana uses PostgreSQL for improved reliability (no SQLite locking issues)
- **Storage**:
  - Prometheus data: `/mnt/storage/monitoring/prometheus` (20Gi)
  - Grafana config: `/mnt/storage/monitoring/grafana` (1Gi)
  - Grafana database: PostgreSQL (shared database service)
- **Access**:
  - Grafana: `http://192.168.88.126:30300`
  - Prometheus: `http://192.168.88.126:30900`
- **More info**: [apps/monitoring/README.md](apps/monitoring/README.md)

### Storage Architecture

The media server uses NFS-based persistent storage with the following structure:

```
/mnt/storage/

├── jellyfin/config/       # Jellyfin server settings and database
├── transmission/config/   # Transmission and VPN configuration
├── sonarr/config/         # Sonarr application data
├── radarr/config/         # Radarr application data
├── jackett/config/        # Jackett indexer configurations
├── monitoring/            # Monitoring stack persistent storage
│   ├── prometheus/        # Prometheus metrics data (20Gi, 15-day retention)
│   └── grafana/           # Grafana dashboards and configuration (1Gi)
├── shared/downloads/      # Shared download directory (Transmission, Sonarr, Radarr)
└── jellyfin/media/
    ├── movies/            # Organized movie library (Radarr → Jellyfin)
    ├── tv-shows/          # Organized TV show library (Sonarr → Jellyfin)
    └── music/             # Music library (manual/future automation)
```

For details on NFS setup, the provisioner, and how to create PVCs, see the [Storage Configuration (NFS)](#storage-configuration-nfs) section.

### Network Configuration

- **Load Balancer**: Uses K3s built-in load balancer with VIP spanning all nodes
- **VPN Protection**: Transmission pod routes all traffic through WireGuard tunnel
- **NodePort Services**: Direct node access for core services (Homarr, Jellyfin, Dashboard)
- **Internal Communication**: Apps communicate via Kubernetes service discovery

### Deployment and Management

#### Deploy All Applications

**Option 1: Manual Deployment**
```bash
# Deploy core infrastructure
kubectl apply -f apps/shared-storage/

# Deploy database services first (required by other apps)
kubectl apply -f apps/database/

# Deploy applications (order matters for dependencies)
kubectl apply -f apps/jellyfin/
kubectl apply -f apps/immich/
kubectl apply -f apps/prowlarr/
kubectl apply -f apps/transmission/
kubectl apply -f apps/sonarr/
kubectl apply -f apps/radarr/
kubectl apply -f apps/homarr/
kubectl apply -f apps/pihole/
kubectl apply -f apps/cloudflare-tunnel/
kubectl apply -f apps/n8n/

# Deploy monitoring and management
kubectl apply -f apps/monitoring/
kubectl apply -f apps/argocd/
```

**Option 2: GitOps with ArgoCD (Recommended)**
```bash
# Deploy ArgoCD first
kubectl apply -f apps/argocd/

# Apply all application manifests to ArgoCD
kubectl apply -f apps/argocd/*-application.yaml

# ArgoCD will automatically sync and manage all applications
```



#### Check Application Status
```bash
# View all application pods
kubectl get pods --all-namespaces | grep -E "(homarr|jellyfin|transmission|sonarr|radarr|prowlarr|pihole|cloudflare)"

# Check ArgoCD applications
kubectl get applications -n argocd

# Check persistent volumes
kubectl get pv
```

#### Access Logs
```bash
# Transmission VPN logs
kubectl logs -n transmission deployment/transmission-vpn -c gluetun

# Application logs
kubectl logs -n jellyfin deployment/jellyfin
kubectl logs -n sonarr deployment/sonarr
kubectl logs -n radarr deployment/radarr
```

### Security Features

1. **VPN Protection**: All torrent traffic routed through encrypted WireGuard tunnel
2. **Network Isolation**: Applications isolated in separate namespaces
3. **Firewall Rules**: Gluetun enforces strict firewall allowing only VPN traffic
4. **Private Networking**: Internal service communication over cluster network
5. **Health Monitoring**: Automatic VPN health checks with connection recovery

### Integration Workflow

The applications work together in an automated content acquisition pipeline:

1. **Content Request**: User adds movie/show to Radarr/Sonarr
2. **Search**: Radarr/Sonarr queries Prowlarr for available releases
3. **Download**: Best release sent to Transmission (via VPN) for download
4. **Processing**: Completed downloads moved and renamed by Radarr/Sonarr
5. **Library Update**: Jellyfin automatically detects new content
6. **Streaming**: Content available for streaming through Jellyfin

**Additional Services:**
- **Pi-hole**: Provides network-wide ad blocking for all cluster traffic
- **Cloudflare Tunnel**: Enables secure remote access to services
- **ArgoCD**: Manages application deployments via GitOps
- **Homarr**: Provides unified dashboard for all services

This setup provides a fully automated, secure, and scalable media server solution running on Kubernetes with modern DevOps practices.

---
