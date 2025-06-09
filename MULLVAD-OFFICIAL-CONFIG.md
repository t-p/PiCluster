# Mullvad VPN Configuration for Transmission (Official Gluetun Guide)

This guide is based on the official Gluetun documentation for Mullvad VPN configuration.

## Important Notes

⚠️ **OpenVPN Deprecation**: Mullvad will remove OpenVPN support on January 15th, 2026. WireGuard is the recommended and future-proof option.

## Prerequisites

1. Active Mullvad VPN account
2. Mullvad account number (16-digit ID)
3. Generated WireGuard configuration from Mullvad

## Step 1: Generate WireGuard Configuration

1. **Log into your Mullvad account** at [mullvad.net](https://mullvad.net/en/account/)
2. **Navigate to WireGuard configuration** section
3. **Generate a new WireGuard key** (if you don't have one)
4. **Download the configuration files** as a ZIP
5. **Extract and open any `.json` file** from the ZIP

You'll need two values from the configuration:
- **PrivateKey**: Your WireGuard private key (same for all servers)
- **Address**: Your WireGuard IP address (IPv4, usually first in comma-separated list)

## Step 2: Create Mullvad Secret

### Get Your Values
From the downloaded configuration file:
```json
{
  "PrivateKey": "wOEI9rqqbDwnN8/Bpp22sVz48T71vJ4fYmFWujulwUU=",
  "Address": ["10.64.222.21/32", "fc00:bbbb:bbbb:bb01::4:de14/128"]
}
```

Use the IPv4 address (first one): `10.64.222.21/32`

### Create the Secret
```bash
kubectl create secret generic mullvad-credentials \
  --from-literal=WIREGUARD_PRIVATE_KEY="wOEI9rqqbDwnN8/Bpp22sVz48T71vJ4fYmFWujulwUU=" \
  --from-literal=WIREGUARD_ADDRESSES="10.64.222.21/32" \
  -n transmission
```

## Step 3: Update Your Deployment

Edit your existing transmission-vpn deployment:

```bash
kubectl edit deployment transmission-vpn -n transmission
```

### Update the Gluetun Container Environment

Replace the ProtonVPN configuration with:

```yaml
env:
# Required for Mullvad
- name: VPN_SERVICE_PROVIDER
  value: mullvad
- name: VPN_TYPE
  value: wireguard

# Server Selection (optional)
- name: SERVER_CITIES
  value: Amsterdam  # or your preferred city
# Alternative options:
# - name: SERVER_COUNTRIES
#   value: Netherlands,Sweden
# - name: SERVER_HOSTNAMES
#   value: nl-ams-wg-001.mullvad.net
# - name: OWNED_ONLY
#   value: "yes"  # Only Mullvad-owned servers

# WireGuard Configuration (optional)
- name: WIREGUARD_ENDPOINT_PORT
  value: "51820"  # Default port, can be any value

# Standard Gluetun Settings
- name: TZ
  value: UTC
- name: FIREWALL
  value: "on"
- name: FIREWALL_VPN_INPUT_PORTS
  value: "9091,51413"
- name: FIREWALL_INPUT_PORTS
  value: "9091,51413"
- name: DOT
  value: "off"
- name: HEALTH_SERVER_ADDRESS
  value: ":9999"

# Port Forwarding (if needed)
- name: VPN_PORT_FORWARDING
  value: "on"
- name: VPN_PORT_FORWARDING_PROVIDER
  value: mullvad

envFrom:
- secretRef:
    name: mullvad-credentials  # Changed from protonvpn-credentials
```

## Step 4: Complete Updated Deployment YAML

Here's a complete deployment configuration:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: transmission-vpn
  namespace: transmission
  labels:
    app: transmission-vpn
spec:
  replicas: 1
  selector:
    matchLabels:
      app: transmission-vpn
  template:
    metadata:
      labels:
        app: transmission-vpn
    spec:
      nodeSelector:
        node-role.kubernetes.io/worker: worker
      tolerations:
      - effect: NoSchedule
        key: arm
        operator: Equal
        value: "true"
      securityContext:
        fsGroup: 1000
      containers:
      # Gluetun VPN Container
      - name: gluetun
        image: qmcgaw/gluetun:latest
        imagePullPolicy: Always
        securityContext:
          capabilities:
            add:
            - NET_ADMIN
            - SYS_MODULE
          privileged: true
          runAsNonRoot: false
          runAsUser: 0
        env:
        - name: VPN_SERVICE_PROVIDER
          value: mullvad
        - name: VPN_TYPE
          value: wireguard
        - name: SERVER_CITIES
          value: Amsterdam
        - name: WIREGUARD_ENDPOINT_PORT
          value: "51820"
        - name: TZ
          value: UTC
        - name: FIREWALL
          value: "on"
        - name: FIREWALL_VPN_INPUT_PORTS
          value: "9091,51413"
        - name: FIREWALL_INPUT_PORTS
          value: "9091,51413"
        - name: DOT
          value: "off"
        - name: HEALTH_SERVER_ADDRESS
          value: ":9999"
        # Optional: Port Forwarding
        - name: VPN_PORT_FORWARDING
          value: "on"
        - name: VPN_PORT_FORWARDING_PROVIDER
          value: mullvad
        envFrom:
        - secretRef:
            name: mullvad-credentials
        ports:
        - containerPort: 9091
          name: webui
          protocol: TCP
        - containerPort: 51413
          name: torrent-tcp
          protocol: TCP
        - containerPort: 51413
          name: torrent-udp
          protocol: UDP
        - containerPort: 9999
          name: health
          protocol: TCP
        volumeMounts:
        - mountPath: /dev/net/tun
          name: dev-net-tun
        livenessProbe:
          httpGet:
            path: /
            port: 9999
          initialDelaySeconds: 60
          periodSeconds: 60
          timeoutSeconds: 10
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /
            port: 9999
          initialDelaySeconds: 30
          periodSeconds: 30
          timeoutSeconds: 5
          failureThreshold: 3

      # Transmission Container
      - name: transmission
        image: linuxserver/transmission:latest
        imagePullPolicy: Always
        securityContext:
          runAsUser: 1000
          runAsGroup: 1000
        env:
        - name: PUID
          value: "1000"
        - name: PGID
          value: "1000"
        - name: TZ
          value: UTC
        volumeMounts:
        - mountPath: /config
          name: transmission-config
        - mountPath: /downloads
          name: transmission-downloads
        resources:
          requests:
            cpu: 100m
            memory: 256Mi
          limits:
            cpu: 500m
            memory: 1Gi
        livenessProbe:
          httpGet:
            path: /transmission/web/
            port: 9091
          initialDelaySeconds: 120
          periodSeconds: 30
          timeoutSeconds: 10
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /transmission/web/
            port: 9091
          initialDelaySeconds: 90
          periodSeconds: 15
          timeoutSeconds: 5
          failureThreshold: 3

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
```

## Step 5: Verification

### Check Connection Status
```bash
# Check Gluetun logs
kubectl logs -f deployment/transmission-vpn -c gluetun -n transmission

# Verify IP address
kubectl exec -it deployment/transmission-vpn -c gluetun -n transmission -- wget -qO- https://am.i.mullvad.net/connected
```

### Check Port Forwarding (if enabled)
```bash
# Check if port forwarding is working
kubectl logs deployment/transmission-vpn -c gluetun -n transmission | grep -i "port forwarding"

# Check forwarded port (if port forwarding is enabled)
kubectl exec deployment/transmission-vpn -c gluetun -n transmission -- cat /tmp/gluetun/forwarded_port
```

## Server Selection Options

### By City
```yaml
- name: SERVER_CITIES
  value: Amsterdam,Stockholm,Zurich
```

### By Country
```yaml
- name: SERVER_COUNTRIES
  value: Netherlands,Sweden,Switzerland
```

### By Hostname (most specific)
```yaml
- name: SERVER_HOSTNAMES
  value: nl-ams-wg-001.mullvad.net,se-sto-wg-001.mullvad.net
```

### Mullvad-Owned Only
```yaml
- name: OWNED_ONLY
  value: "yes"
```

## Port Forwarding Setup

### Enable in Mullvad Account
1. Log into [mullvad.net](https://mullvad.net/en/account/#/ports)
2. Go to "Manage devices and ports"
3. Add a port forward for your device
4. Note: Not all servers support port forwarding

### Servers Supporting Port Forwarding
- Netherlands (Amsterdam)
- Sweden (Stockholm, Gothenburg, Malmö)
- Switzerland (Zurich)
- Germany (Berlin, Frankfurt)
- Canada (Toronto, Vancouver)
- US (selected cities)

## Troubleshooting

### Common Issues

1. **Wrong Private Key**: Ensure you're using the `PrivateKey` from the downloaded configuration, not the key shown in the web interface

2. **Wrong Address Format**: Use the IPv4 address with CIDR notation (e.g., `10.64.222.21/32`)

3. **Connection Issues**: Check Gluetun logs for specific error messages

### Debug Commands

```bash
# Check secret contents
kubectl get secret mullvad-credentials -n transmission -o yaml

# View Gluetun logs
kubectl logs deployment/transmission-vpn -c gluetun -n transmission

# Test Mullvad connection
kubectl exec -it deployment/transmission-vpn -c gluetun -n transmission -- wget -qO- https://am.i.mullvad.net/connected
```

## Migration from ProtonVPN

If migrating from ProtonVPN:

1. Create the new Mullvad secret
2. Update the deployment configuration
3. Delete the old ProtonVPN secret:
```bash
kubectl delete secret protonvpn-credentials -n transmission
```

## Benefits of Mullvad + WireGuard

- **Performance**: WireGuard is faster than OpenVPN
- **Privacy**: Strong no-logs policy, anonymous signup
- **Reliability**: Modern, efficient protocol
- **Future-proof**: OpenVPN being deprecated in 2026
- **Port forwarding**: Available on select servers
- **Flat pricing**: €5/month for all features

Your Transmission setup will now use Mullvad VPN with WireGuard for optimal performance and privacy!
