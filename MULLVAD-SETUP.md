# Mullvad VPN Configuration Guide for Transmission

This guide will help you switch from ProtonVPN to Mullvad VPN in your Kubernetes Transmission setup.

## Prerequisites

1. **Mullvad Account**: Sign up at [mullvad.net](https://mullvad.net)
2. **Account Number**: You'll receive a 16-digit account number (e.g., `1234567890123456`)
3. **kubectl access** to your cluster

## Option 1: WireGuard Configuration (Recommended)

### Step 1: Generate WireGuard Keys

1. Log into your Mullvad account
2. Go to "WireGuard configuration"
3. Generate a new key pair
4. Note down:
   - **Private Key**: Your WireGuard private key
   - **IP Address**: Your assigned IP (e.g., `10.x.x.x/32`)

### Step 2: Create Mullvad Secret

```bash
# Encode your values to base64
echo -n "YOUR_PRIVATE_KEY_HERE" | base64
echo -n "10.x.x.x/32" | base64

# Create the secret
kubectl create secret generic mullvad-credentials \
  --from-literal=WIREGUARD_PRIVATE_KEY="YOUR_PRIVATE_KEY_HERE" \
  --from-literal=WIREGUARD_ADDRESSES="10.x.x.x/32" \
  -n transmission
```

### Step 3: Update Deployment

Edit your current `transmission-vpn` deployment:

```bash
kubectl edit deployment transmission-vpn -n transmission
```

Change these environment variables in the `gluetun` container:

```yaml
env:
- name: VPN_SERVICE_PROVIDER
  value: mullvad
- name: VPN_TYPE
  value: wireguard
- name: WIREGUARD_IMPLEMENTATION
  value: kernel
- name: SERVER_COUNTRIES
  value: Netherlands  # or your preferred country
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
```

Update the secret reference:

```yaml
envFrom:
- secretRef:
    name: mullvad-credentials  # Changed from protonvpn-credentials
```

## Option 2: OpenVPN Configuration

### Step 1: Create OpenVPN Secret

For Mullvad, both username and password are your account number:

```bash
# Create the secret using your Mullvad account number
kubectl create secret generic mullvad-credentials \
  --from-literal=OPENVPN_USER="1234567890123456" \
  --from-literal=OPENVPN_PASSWORD="1234567890123456" \
  -n transmission
```

### Step 2: Update Deployment for OpenVPN

```yaml
env:
- name: VPN_SERVICE_PROVIDER
  value: mullvad
- name: VPN_TYPE
  value: openvpn
- name: OPENVPN_PROTOCOL
  value: udp
- name: SERVER_COUNTRIES
  value: Netherlands
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
```

## Step 4: Clean Up Old ProtonVPN Secret (Optional)

```bash
kubectl delete secret protonvpn-credentials -n transmission
```

## Step 5: Verify Connection

1. Check pod status:
```bash
kubectl get pods -n transmission
kubectl logs -f deployment/transmission-vpn -c gluetun -n transmission
```

2. Verify IP address:
```bash
kubectl exec -it deployment/transmission-vpn -c gluetun -n transmission -- wget -qO- https://ipinfo.io
```

3. Check transmission web UI is accessible on your LoadBalancer IP

## Troubleshooting

### Common Issues:

1. **Pod not starting**: Check if the secret is created correctly
2. **VPN not connecting**: Verify your Mullvad account is active and credentials are correct
3. **Can't access web UI**: Ensure firewall ports are configured correctly

### Debug Commands:

```bash
# Check gluetun logs
kubectl logs -f deployment/transmission-vpn -c gluetun -n transmission

# Check transmission logs
kubectl logs -f deployment/transmission-vpn -c transmission -n transmission

# Get pod details
kubectl describe pod -l app=transmission-vpn -n transmission

# Test connectivity from inside the pod
kubectl exec -it deployment/transmission-vpn -c gluetun -n transmission -- wget -qO- https://ipinfo.io
```

## Advanced Configuration

### Port Forwarding (Recommended for better torrent performance)

Add to gluetun container environment:

```yaml
- name: VPN_PORT_FORWARDING
  value: "on"
- name: VPN_PORT_FORWARDING_PROVIDER
  value: mullvad
```

### Specific Server Selection

Instead of `SERVER_COUNTRIES`, you can specify exact servers:

```yaml
- name: SERVER_HOSTNAMES
  value: nl-ams-wg-001.mullvad.net,nl-ams-wg-002.mullvad.net
```

### Health Check Configuration

Monitor VPN status:

```yaml
- name: HEALTH_VPN_DURATION_INITIAL
  value: 60s
- name: HEALTH_VPN_DURATION_ADDITION
  value: 5s
```

## Server Locations

Popular Mullvad server locations:
- **Netherlands**: `Netherlands` or `nl-ams-wg-001.mullvad.net`
- **Switzerland**: `Switzerland` or `ch-zur-wg-001.mullvad.net`
- **Sweden**: `Sweden` or `se-got-wg-001.mullvad.net`
- **Germany**: `Germany` or `de-ber-wg-001.mullvad.net`

## Benefits of Mullvad

- **Privacy**: No email required for signup
- **Anonymous payments**: Supports cryptocurrency
- **No logs**: Independently audited no-logs policy
- **Port forwarding**: Better torrent performance
- **Flat pricing**: €5/month regardless of features
- **Open source**: WireGuard apps are open source

## Performance Tips

1. **Use WireGuard**: Generally faster than OpenVPN
2. **Choose nearby servers**: Lower latency
3. **Enable port forwarding**: Better torrent connectivity
4. **Monitor resource usage**: Adjust CPU/memory limits if needed

Your Transmission setup will now route all traffic through Mullvad VPN, providing better privacy and potentially improved performance for your media downloading workflow.