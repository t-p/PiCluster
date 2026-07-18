# Pathfinder

Self-hosted Starknet full node. Provides a local JSON-RPC endpoint for self-custody Starknet operations, syncing state from Ethereum L1.

- **Image**: `eqlabs/pathfinder:v0.22.7`
- **Namespace**: `pathfinder`
- **Node**: `node02` (CM4, Turing Pi slot 2)
- **Docs**: https://github.com/eqlabs/pathfinder

## Access

Internal ClusterIP only — not exposed outside the cluster.

- `http://pathfinder.pathfinder.svc.cluster.local:9545` (JSON-RPC)

Port-forward for local access:
```bash
kubectl port-forward -n pathfinder deployment/pathfinder 9545:9545
```

## Ports

| Port | Protocol | Purpose |
|------|----------|---------|
| 9545 | HTTP | Starknet JSON-RPC API |

## Storage

| Name | Type | Server | Path | Size |
|------|------|--------|------|------|
| `pathfinder-data-pvc` | NFS | 192.168.88.163 | `/mnt/storage/pathfinder/data` | 100Gi (provisioned) |

> **Note**: Full Starknet mainnet state grows to ~2TB at sync tip. An mSATA SSD upgrade on node02 is recommended for improved I/O vs NFS.

## Secrets

```bash
kubectl create secret generic pathfinder-secrets -n pathfinder \
  --from-literal=ethereum-url="https://mainnet.infura.io/v3/YOUR_KEY"
```

## Configuration

| Env Var | Value | Purpose |
|---------|-------|---------|
| `PATHFINDER_ETHEREUM_API_URL` | Secret | Ethereum L1 RPC endpoint |
| `PATHFINDER_DATA_DIRECTORY` | `/data` | State database path |
| `PATHFINDER_RPC_COMPILER_CONCURRENCY_LIMIT` | `4` | Parallel Sierra→CASM compilation |

## Sync Status

Check current sync progress:
```bash
kubectl port-forward -n pathfinder deployment/pathfinder 9545:9545 &
curl -s -X POST http://localhost:9545 \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","method":"starknet_syncing","params":[],"id":1}' | jq .
```

## Files

| File | Purpose |
|------|---------|
| `01-namespace-and-storage.yaml` | Namespace and PVC |
| `02-deployment.yaml` | Deployment |
| `03-service.yaml` | ClusterIP service |
