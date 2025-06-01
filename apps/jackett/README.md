# Jackett on PiCluster

This directory contains Kubernetes manifests to deploy Jackett indexer proxy on your PiCluster K3s setup.

## Overview

Jackett is a proxy server that translates queries from apps like Sonarr, Radarr, etc. into tracker-site-specific HTTP queries, parses the HTML response, and then sends results back to the requesting software. This allows you to use many different tracker sites with applications that only support a limited number of indexers.

## Prerequisites

- PiCluster with K3s installed and running
- NFS server configured on master node (node03)
- Sonarr deployed (recommended)
- At least 512MB RAM available for Jackett

## Quick Start

1. **Deploy Jackett:**
   ```bash
   cd apps/jackett
   ./deploy.sh
   ```

2. **Access Jackett:**
   - Web interface: `http://192.168.88.163:30117`

3. **Configure indexers and integrate with Sonarr**

## Manual Deployment

If you prefer manual deployment:

```bash
# Create NFS directories
ssh pi@node03 "sudo mkdir -p /mnt/storage/jackett/config"
ssh pi@node03 "sudo chown -R 1000:1000 /mnt/storage/jackett"

# Deploy manifests
kubectl apply -f 01-namespace-and-storage.yaml
kubectl apply -f 02-deployment.yaml
kubectl apply -f 03-service.yaml
```

## Configuration

### 1. Access Jackett Dashboard

1. **Open browser:** `http://192.168.88.163:30117`
2. **Note the API Key** displayed at the top of the dashboard
3. **Configure admin password** (recommended)

### 2. Add Indexers

1. **Click "Add indexer"**
2. **Search for trackers** you want to use
3. **Popular public indexers:**
   - EZTV (TV shows)
   - YTS (movies)
   - 1337x
   - The Pirate Bay
   - RARBG (if available)

4. **Configure each indexer:**
   - Some require no configuration (public)
   - Others may need credentials or cookies
   - Test each indexer after adding

### 3. Get Torznab URLs

After adding indexers, each will have a unique Torznab URL:
```
http://jackett.jackett.svc.cluster.local:9117/api/v2.0/indexers/INDEXER_ID/results/torznab/
```

## Integration with Sonarr

### 1. Add Jackett Indexers to Sonarr

1. **In Sonarr:** Settings → Indexers → Add Torznab
2. **Configure each indexer:**
   - Name: `Jackett - [IndexerName]`
   - URL: `http://jackett.jackett.svc.cluster.local:9117/api/v2.0/indexers/INDEXER_ID/results/torznab/`
   - API Key: (copy from Jackett dashboard)
   - Categories: `5000,5030,5040` (TV shows)
   - Enable RSS Sync: ✅
   - Enable Automatic Search: ✅

3. **Test the connection** in Sonarr

### 2. Verify Integration

1. **In Sonarr:** Go to a TV show
2. **Manual search** for an episode
3. **You should see results** from your Jackett indexers

## Storage Structure

```
/mnt/storage/jackett/
└── config/          # Jackett configuration and indexer settings
```

## Resource Configuration

- **Memory:** 128Mi request, 512Mi limit
- **CPU:** 50m request, 250m limit
- **Storage:** 2Gi for configuration

## Popular Indexers for TV Shows

### Public Indexers (No registration required):
- **EZTV** - Excellent for TV shows
- **1337x** - General purpose, good TV selection
- **The Pirate Bay** - Large selection but variable quality
- **YTS** - Movies only, high quality
- **Torlock** - Good variety

### Semi-Private/Private (Better quality):
- **TorrentLeech** - Requires invitation
- **IPTorrents** - Requires registration
- **SceneTime** - Requires registration

## Troubleshooting

### Check Jackett Status:
```bash
kubectl get pods -n jackett
kubectl logs -f deployment/jackett -n jackett
kubectl describe pod -n jackett -l app=jackett
```

### Common Issues:

**Jackett not accessible:**
- Verify pod is running: `kubectl get pods -n jackett`
- Check service: `kubectl get svc -n jackett`
- Check logs for errors

**Indexers failing:**
- Test indexer directly in Jackett dashboard
- Check if indexer site is down
- Verify credentials for private trackers
- Some indexers may be blocked in your region

**Sonarr can't connect to Jackett:**
- Verify the internal URL: `http://jackett.jackett.svc.cluster.local:9117`
- Check API key is correct
- Test network connectivity: `kubectl exec -it deployment/sonarr -n sonarr -- ping jackett.jackett.svc.cluster.local`

**No search results:**
- Verify indexers are working in Jackett
- Check category settings (5000 for TV)
- Monitor Jackett logs during searches

### Access Jackett Logs:
```bash
kubectl logs -f deployment/jackett -n jackett
```

### Test Indexer Manually:
```bash
# Test from within the cluster
kubectl exec -it deployment/sonarr -n sonarr -- curl "http://jackett.jackett.svc.cluster.local:9117/api/v2.0/indexers/all/results?apikey=YOUR_API_KEY&Query=test"
```

## Security Considerations

- **Set admin password** in Jackett dashboard
- **Use private indexers** when possible for better content and security
- **Consider VPN** for additional privacy
- **Monitor resource usage** to prevent abuse
- **Regularly update** indexer configurations

## Legal Considerations

⚠️ **Important:** 
- Only use indexers for content you have legal rights to download
- Respect copyright laws in your jurisdiction
- Many indexers provide legal, open-source, and public domain content
- Always verify the legal status of content before downloading

## Performance Tips

1. **Limit Active Indexers:**
   - Don't add too many indexers (5-10 is usually sufficient)
   - Disable underperforming indexers

2. **Monitor Response Times:**
   - Check indexer statistics in Jackett dashboard
   - Remove consistently slow indexers

3. **Category Configuration:**
   - Use specific categories to reduce unnecessary traffic
   - TV: 5000, 5030, 5040
   - Movies: 2000, 2010, 2020, 2030, 2040, 2050, 2060

## Advanced Configuration

### Custom Categories

In Sonarr indexer settings, use specific categories:
```
5000    # TV
5030    # TV/SD
5040    # TV/HD
5045    # TV/UHD
```

### Rate Limiting

If you experience rate limiting:
1. **Increase delays** between requests in Jackett
2. **Reduce concurrent searches** in Sonarr
3. **Use fewer indexers** simultaneously

### Proxy Configuration

For indexers blocked in your region:
1. **Configure proxy** in Jackett settings
2. **Use VPN** at the container level
3. **Consider alternative indexers**

## Monitoring

### Check Indexer Health:
```bash
# Monitor Jackett logs
kubectl logs -f deployment/jackett -n jackett

# Check resource usage
kubectl top pod -n jackett

# Monitor searches in Sonarr
# Activity → History
```

### Performance Metrics:
- Response times per indexer
- Success/failure rates
- Number of results returned

## Upgrading

To upgrade Jackett:
```bash
kubectl set image deployment/jackett jackett=linuxserver/jackett:latest -n jackett
kubectl rollout status deployment/jackett -n jackett
```

## Cleanup

To remove Jackett:
```bash
kubectl delete namespace jackett
# Manually remove NFS directories if desired
ssh pi@node03 "sudo rm -rf /mnt/storage/jackett"
```

## Useful Links

- [Jackett GitHub](https://github.com/Jackett/Jackett)
- [Jackett Wiki](https://github.com/Jackett/Jackett/wiki)
- [Sonarr Integration Guide](https://wiki.servarr.com/sonarr/settings#indexers)
- [Torznab API Documentation](https://github.com/Sonarr/Sonarr/wiki/Implementing-a-Torznab-indexer)