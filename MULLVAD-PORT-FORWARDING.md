# Mullvad Port Forwarding Setup Guide

This guide shows you how to enable port forwarding with Mullvad VPN for better torrent performance.

## Prerequisites

- Mullvad VPN account
- Active Mullvad subscription
- Your current Transmission + Gluetun setup running

## Step 1: Enable Port Forwarding in Mullvad Account

1. **Log into your Mullvad account** at [mullvad.net](https://mullvad.net)
2. **Navigate to "Port forwarding"** in the left sidebar
3. **Click "Add port"** 
4. **Select a city/server** that supports port forwarding
5. **Note the assigned port number** (e.g., 42851)

> **Important**: Not all Mullvad servers support port forwarding. Choose from:
> - Netherlands (Amsterdam)
> - Sweden (Stockholm, Gothenburg, Malmö)
> - Switzerland (Zurich)
> - Germany (Berlin, Frankfurt)
> - Canada (Toronto, Vancouver)
> - US (New York, Los Angeles, Chicago)

## Step 2: Update Your Gluetun Configuration

Edit your existing `transmission-vpn` deployment:

```bash
kubectl edit deployment transmission-vpn -n transmission
```

### Add these environment variables to the `gluetun` container:

```yaml
env:
- name: VPN_SERVICE_PROVIDER
  value: mullvad
- name: VPN_TYPE
  value: wireguard  # or openvpn
- name: VPN_PORT_FORWARDING
  value: "on"
- name: VPN_PORT_FORWARDING_PROVIDER
  value: mullvad
- name: VPN_PORT_FORWARDING_STATUS_FILE
  value: /tmp/gluetun/forwarded_port
- name: SERVER_COUNTRIES
  value: Netherlands  # Choose a country that supports port forwarding
# ... keep your other existing settings
```

### Add a shared volume for port information:

In the `gluetun` container `volumeMounts` section:
```yaml
volumeMounts:
- mountPath: /dev/net/tun
  name: dev-net-tun
- mountPath: /tmp/gluetun
  name: gluetun-tmp
```

In the `transmission` container `volumeMounts` section:
```yaml
volumeMounts:
- mountPath: /config
  name: transmission-config
- mountPath: /downloads
  name: transmission-downloads
- mountPath: /tmp/gluetun
  name: gluetun-tmp
  readOnly: true
```

In the `volumes` section at the bottom:
```yaml
volumes:
- name: dev-net-tun
  hostPath:
    path: /dev/net/tun
    type: CharDevice
- name: transmission-config
  persistentVolumeClaim:
    claimName: transmission-config-pvc
- name: transmission-downloads
  nfs:
    path: /mnt/storage/shared/downloads
    server: 192.168.88.163
- name: gluetun-tmp
  emptyDir: {}
```

## Step 3: Verify Port Forwarding is Working

1. **Check Gluetun logs**:
```bash
kubectl logs -f deployment/transmission-vpn -c gluetun -n transmission
```

Look for messages like:
```
Port forwarded successfully, your forwarded port is 42851
```

2. **Check the forwarded port file**:
```bash
kubectl exec -it deployment/transmission-vpn -c gluetun -n transmission -- cat /tmp/gluetun/forwarded_port
```

3. **Verify in Transmission**:
```bash
kubectl exec -it deployment/transmission-vpn -c transmission -n transmission -- transmission-remote 127.0.0.1:9091 --session-info | grep port
```

## Step 4: Configure Transmission to Use the Forwarded Port

### Option A: Manual Configuration

```bash
# Get the forwarded port
FORWARDED_PORT=$(kubectl exec deployment/transmission-vpn -c gluetun -n transmission -- cat /tmp/gluetun/forwarded_port)

# Update Transmission
kubectl exec -it deployment/transmission-vpn -c transmission -n transmission -- transmission-remote 127.0.0.1:9091 --port $FORWARDED_PORT

# Test the port
kubectl exec -it deployment/transmission-vpn -c transmission -n transmission -- transmission-remote 127.0.0.1:9091 --porttest
```

### Option B: Automatic Configuration (Recommended)

Add this init script to your transmission container:

```yaml
# In the transmission container spec
lifecycle:
  postStart:
    exec:
      command:
      - /bin/bash
      - -c
      - |
        #!/bin/bash
        echo "Waiting for port forwarding to be established..."
        sleep 30
        
        # Wait for the forwarded port file to exist
        while [ ! -f /tmp/gluetun/forwarded_port ]; do
          echo "Waiting for forwarded port..."
          sleep 10
        done
        
        FORWARDED_PORT=$(cat /tmp/gluetun/forwarded_port)
        echo "Configuring Transmission to use port: $FORWARDED_PORT"
        
        # Configure Transmission
        transmission-remote 127.0.0.1:9091 --port $FORWARDED_PORT
        transmission-remote 127.0.0.1:9091 --porttest
        
        echo "Port forwarding configuration complete"
```

## Step 5: Verification and Testing

1. **Check if port forwarding is active**:
```bash
kubectl logs deployment/transmission-vpn -c gluetun -n transmission | grep -i "port"
```

2. **Test connectivity**:
```bash
kubectl exec -it deployment/transmission-vpn -c transmission -n transmission -- transmission-remote 127.0.0.1:9091 --porttest
```

You should see: `Port is open: Yes`

3. **Monitor the forwarded port**:
```bash
# Create a simple monitoring script
kubectl exec -it deployment/transmission-vpn -c gluetun -n transmission -- watch cat /tmp/gluetun/forwarded_port
```

## Troubleshooting

### Common Issues:

1. **Port forwarding not working**:
   - Ensure you're connected to a server that supports port forwarding
   - Check Mullvad account has port forwarding enabled
   - Verify the `VPN_PORT_FORWARDING` environment variable is set to "on"

2. **Transmission not using the forwarded port**:
   - Check if the `/tmp/gluetun/forwarded_port` file exists
   - Manually set the port in Transmission settings
   - Restart the transmission container

3. **Port keeps changing**:
   - This is normal - Mullvad ports can change
   - The automatic configuration should handle this
   - Monitor logs for port change notifications

### Debug Commands:

```bash
# Check gluetun port forwarding status
kubectl exec -it deployment/transmission-vpn -c gluetun -n transmission -- cat /tmp/gluetun/forwarded_port

# Check transmission port configuration
kubectl exec -it deployment/transmission-vpn -c transmission -n transmission -- transmission-remote 127.0.0.1:9091 --session-info

# Test external port connectivity
kubectl exec -it deployment/transmission-vpn -c gluetun -n transmission -- wget -qO- http://portquiz.net:$(cat /tmp/gluetun/forwarded_port)/
```

## Performance Benefits

With port forwarding enabled, you should see:

- **Better connectivity** to other peers
- **Improved download speeds** 
- **More seeders/leechers** can connect to you
- **Better ratio** when seeding torrents
- **Reduced "Unconnectable" warnings** in torrent clients

## Advanced Monitoring

Create a monitoring sidecar container to track port forwarding status:

```yaml
- name: port-monitor
  image: alpine:latest
  command:
  - /bin/sh
  - -c
  - |
    apk add --no-cache curl
    while true; do
      if [ -f /tmp/gluetun/forwarded_port ]; then
        PORT=$(cat /tmp/gluetun/forwarded_port)
        echo "$(date): Current forwarded port: $PORT"
        
        # Test port connectivity
        if curl -s --connect-timeout 5 http://portquiz.net:$PORT/ > /dev/null; then
          echo "$(date): Port $PORT is externally accessible"
        else
          echo "$(date): Warning: Port $PORT may not be accessible"
        fi
      else
        echo "$(date): No forwarded port file found"
      fi
      sleep 300  # Check every 5 minutes
    done
  volumeMounts:
  - mountPath: /tmp/gluetun
    name: gluetun-tmp
    readOnly: true
```

Port forwarding with Mullvad will significantly improve your torrent performance and connectivity!