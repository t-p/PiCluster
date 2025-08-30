# Database Services

This directory contains shared database services that can be used by multiple applications across the PiCluster. The database namespace provides centralized PostgreSQL and Redis instances optimized for high performance on node05.

## Overview

- **Namespace**: `database`
- **Components**: PostgreSQL 15, Redis 7
- **Storage**: NVMe storage on node05 for optimal performance
- **Architecture**: Shared services for multiple applications
- **Security**: Cluster-internal access only

## Components

### PostgreSQL 15
- **Image**: `postgres:15-alpine`
- **Purpose**: Primary relational database for applications
- **Storage**: 100GB NVMe storage on node05
- **Features**:
  - Optimized for NVMe SSD performance
  - Multiple database support
  - Connection pooling ready
  - Monitoring and health checks enabled
  - Data checksums for integrity

### Redis 7
- **Image**: `redis:7-alpine`
- **Purpose**: Caching, session storage, and job queues
- **Storage**: 10GB NVMe storage on node05
- **Features**:
  - AOF persistence enabled
  - Memory optimization for shared workloads
  - Keyspace notifications enabled
  - Multiple database namespaces (0-15)

## Configuration

### Required Secrets

Before deployment, create the PostgreSQL secret:

```bash
# Create PostgreSQL credentials
kubectl create secret generic postgres-secret \
  --from-literal=username=postgres \
  --from-literal=password=$(openssl rand -base64 32) \
  --namespace=database
```

### Storage Requirements

Ensure the following directories exist on node05:
```bash
sudo mkdir -p /opt/postgres/data
sudo mkdir -p /opt/redis/data
sudo chown -R 999:999 /opt/postgres/data /opt/redis/data
```

## Deployment

Deploy in the following order:

```bash
# Step 1: Create namespace and storage
kubectl apply -f 01-namespace-and-storage.yaml

# Step 2: Create secrets (see Configuration section above)

# Step 3: Deploy PostgreSQL
kubectl apply -f 02-postgresql.yaml

# Step 4: Deploy Redis
kubectl apply -f 03-redis.yaml

# Step 5: Verify deployment
kubectl get pods -n database
```

## Usage by Applications

Applications can connect to these shared database services using the following connection details:

### PostgreSQL Connection
- **Host**: `postgres.database.svc.cluster.local`
- **Port**: `5432`
- **Username**: From `postgres-secret`
- **Password**: From `postgres-secret`
- **Default Database**: `postgres`

Example application configuration:
```yaml
env:
- name: DB_HOSTNAME
  value: "postgres.database.svc.cluster.local"
- name: DB_PORT
  value: "5432"
- name: DB_USERNAME
  valueFrom:
    secretKeyRef:
      name: postgres-secret
      namespace: database
      key: username
- name: DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: postgres-secret
      namespace: database
      key: password
```

### Redis Connection
- **Host**: `redis.database.svc.cluster.local`
- **Port**: `6379`
- **Database**: 0-15 (use different databases for different apps)
- **Authentication**: None (cluster-internal only)

Example application configuration:
```yaml
env:
- name: REDIS_HOSTNAME
  value: "redis.database.svc.cluster.local"
- name: REDIS_PORT
  value: "6379"
- name: REDIS_DATABASE
  value: "1"  # Use different numbers for each app
```

## Database Management

### Creating Application-Specific Databases

Connect to PostgreSQL and create databases for applications:

```bash
# Connect to PostgreSQL
kubectl exec -it deployment/postgres -n database -- psql -U postgres

# Create database for an application
CREATE DATABASE immich;
CREATE USER immich WITH ENCRYPTED PASSWORD 'secure_password';
GRANT ALL PRIVILEGES ON DATABASE immich TO immich;

# Exit
\q
```

### Redis Database Allocation

Use different Redis database numbers for each application:
- Database 0: General purpose / default
- Database 1: Immich
- Database 2: Future application
- Database 3: Future application
- ... (up to 15)

## Monitoring

### Health Checks

```bash
# Check PostgreSQL status
kubectl exec -n database deployment/postgres -- pg_isready -U postgres

# Check Redis status
kubectl exec -n database deployment/redis -- redis-cli ping

# View logs
kubectl logs -n database deployment/postgres
kubectl logs -n database deployment/redis
```

### Resource Usage

```bash
# Check resource usage
kubectl top pods -n database

# Check storage usage
kubectl exec -n database deployment/postgres -- df -h /var/lib/postgresql/data
kubectl exec -n database deployment/redis -- df -h /data
```

## Performance Optimization

### PostgreSQL Tuning
- Optimized for NVMe SSD performance (`random_page_cost = 1.1`)
- Connection pooling support (200 max connections)
- Shared buffers and cache sizing for Pi 5 hardware
- WAL optimization for write performance

### Redis Tuning
- Memory limit: 1GB with LRU eviction
- AOF persistence for durability
- Optimized for both caching and queue workloads
- Multiple databases for application isolation

## Security

### Network Security
- Services are only accessible within the Kubernetes cluster
- No external exposure
- Applications must be in the cluster to connect

### Authentication
- PostgreSQL uses username/password authentication
- Redis has no authentication (cluster-internal only)
- All credentials stored in Kubernetes secrets

### Data Protection
- PostgreSQL data checksums enabled
- Redis AOF persistence for durability
- Regular backups recommended at the infrastructure level

## Backup Recommendations

Since these are shared services, implement backup strategies:

1. **PostgreSQL**: Use `pg_dump` for logical backups
2. **Redis**: RDB snapshots are automatically created
3. **Storage**: Consider NVMe-level backups
4. **Secrets**: Backup credentials securely

## Troubleshooting

### Common Issues

#### PostgreSQL Connection Issues
```bash
# Check if PostgreSQL is running
kubectl get pods -n database -l app=postgres

# Check PostgreSQL logs
kubectl logs -n database deployment/postgres

# Test connection
kubectl exec -n database deployment/postgres -- pg_isready
```

#### Redis Connection Issues
```bash
# Check if Redis is running
kubectl get pods -n database -l app=redis

# Check Redis logs
kubectl logs -n database deployment/redis

# Test Redis connection
kubectl exec -n database deployment/redis -- redis-cli ping
```

#### Storage Issues
```bash
# Check PVC status
kubectl get pvc -n database

# Check PV status
kubectl get pv | grep database
```

## Migration from Application-Specific Databases

When migrating existing applications to use shared database services:

1. **Backup existing data** from application-specific databases
2. **Create application database** in shared PostgreSQL instance
3. **Restore data** to new database
4. **Update application configuration** to use shared services
5. **Test thoroughly** before removing old database resources
6. **Update ArgoCD applications** to exclude old database configs

## Future Enhancements

Potential improvements for the database services:
- PostgreSQL connection pooling (PgBouncer)
- Redis clustering for high availability
- Automated backup solutions
- Monitoring with Prometheus metrics
- Database migration tools
