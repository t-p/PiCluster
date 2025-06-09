# Mullvad VPN Quick Setup Guide

Based on official Gluetun documentation for switching your Transmission setup from ProtonVPN to Mullvad.

## Prerequisites

- Mullvad VPN account
- Your existing Transmission + Gluetun setup

## Step 1: Get WireGuard Configuration from Mullvad

1. **Login** to [mullvad.net/en/account/](https://mullvad.net/en/account/)
2. **Navigate** to "WireGuard configuration" 
3. **Generate** a new WireGuard key (if needed)
4. **Download** configuration files as ZIP
5. **Extract** and open any `.json` file

From the JSON file, you need:
- `PrivateKey`: Your WireGuard private key
- `Address`: IPv4 address (first in list, e.g., `10.64.222.21/32`)

## Step 2: Create Mullvad Secret

Replace the values with your actual WireGuard configuration:

```bash
kubectl create secret generic mullvad-credentials \
  --from-literal=WIREGUARD_PRIVATE_KEY="wOEI9rqqbDwnN8/Bpp22sVz48T71vJ4fYmFWujulwUU=" \
  --from-literal=WIREGUARD_ADDRESSES="10.64.222.21/32" \
  -n transmission
```

## Step 3: Update Deployment

```bash
kubectl edit deployment transmission-vpn -n transmission
```

In the `gluetun` container, replace the environment variables:

```yaml
env:
- name: VPN_SERVICE_PROVIDER
  value: mullvad
- name: VPN_TYPE
  value: wireguard
- name: SERVER_CITIES
  value: Amsterdam
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

envFrom:
- secretRef:
    name: mullvad-credentials  # Changed from protonvpn-credentials
```

## Step 4: Add Port Forwarding (Optional)

Add these environment variables to enable port forwarding:

```yaml
- name: VPN_PORT_FORWARDING
  value: "on"
- name: VPN_PORT_FORWARDING_PROVIDER
  value: mullvad
```

**Note**: Port forwarding requires:
1. Setting it up in your Mullvad account at [mullvad.net/en/account/#/ports](https://mullvad.net/en/account/#/ports)
2. Using servers that support it (Netherlands, Sweden, Switzerland, Germany, Canada, select US cities)

## Step 5: Verify Connection

```bash
# Check logs
kubectl logs -f deployment/transmission-vpn -c gluetun -n transmission

# Verify Mullvad connection
kubectl exec -it deployment/transmission-vpn -c gluetun -n transmission -- wget -qO- https://am.i.mullvad.net/connected
```

You should see: `You are connected to Mullvad (server xx-xxx-xx-xxx). Your IP address is x.x.x.x`

## Server Selection Options

Choose your preferred location:

```yaml
# By city (recommended)
- name: SERVER_CITIES
  value: Amsterdam,Stockholm,Zurich

# By country
- name: SERVER_COUNTRIES  
  value: Netherlands,Sweden,Switzerland

# By specific hostname
- name: SERVER_HOSTNAMES
  value: nl-ams-wg-001.mullvad.net

# Mullvad-owned servers only
- name: OWNED_ONLY
  value: "yes"
```

## Cleanup

Remove the old ProtonVPN secret:

```bash
kubectl delete secret protonvpn-credentials -n transmission
```

## Troubleshooting

- **Wrong key error**: Use `PrivateKey` from downloaded config, not the web interface key
- **Address format**: Must include `/32` (e.g., `10.64.222.21/32`)
- **Connection issues**: Check gluetun logs for specific errors

## Important Notes

⚠️ **OpenVPN Deprecation**: Mullvad removes OpenVPN support January 15, 2026. WireGuard is recommended.

✅ **Benefits**: Better performance, stronger privacy, port forwarding support, future-proof.

Your setup is now using Mullvad VPN with WireGuard!