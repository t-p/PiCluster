#!/bin/bash

echo "=== Media Stack Configuration Validator ==="
echo

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to check service connectivity
check_service() {
    local service_name=$1
    local namespace=$2
    local port=$3
    local path=$4
    
    echo -n "Checking $service_name connectivity... "
    
    if kubectl exec -n sonarr deployment/sonarr -- wget -qO- --timeout=10 "http://$service_name.$namespace:$port$path" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ PASS${NC}"
        return 0
    else
        echo -e "${RED}❌ FAIL${NC}"
        return 1
    fi
}

# Function to check VPN status
check_vpn_status() {
    echo -n "Checking VPN connection status... "
    
    local vpn_logs=$(kubectl logs -n transmission deployment/transmission-vpn -c gluetun --tail=10 2>/dev/null)
    
    if echo "$vpn_logs" | grep -q "healthy!"; then
        echo -e "${GREEN}✅ VPN HEALTHY${NC}"
        
        # Get VPN IP
        local vpn_ip=$(kubectl exec -n transmission deployment/transmission-vpn -c transmission -- wget -qO- --timeout=5 ifconfig.me/ip 2>/dev/null)
        if [ ! -z "$vpn_ip" ]; then
            echo -e "   ${BLUE}VPN IP: $vpn_ip${NC}"
        fi
        return 0
    else
        echo -e "${RED}❌ VPN UNHEALTHY${NC}"
        return 1
    fi
}

# Function to check download paths
check_download_paths() {
    echo -n "Checking shared download paths... "
    
    local transmission_pod=$(kubectl get pods -n transmission -l app=transmission-vpn -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    
    if [ ! -z "$transmission_pod" ]; then
        if kubectl exec -n transmission "$transmission_pod" -c transmission -- ls /downloads >/dev/null 2>&1; then
            echo -e "${GREEN}✅ ACCESSIBLE${NC}"
            return 0
        fi
    fi
    
    echo -e "${RED}❌ NOT ACCESSIBLE${NC}"
    return 1
}

# Function to validate configuration
validate_transmission_config() {
    echo -e "\n${YELLOW}=== Transmission Configuration Validation ===${NC}"
    
    echo "Recommended settings for Sonarr/Radarr:"
    echo -e "${BLUE}Host:${NC} transmission-vpn.transmission"
    echo -e "${BLUE}Port:${NC} 9091"
    echo -e "${BLUE}URL Base:${NC} /transmission/"
    echo -e "${BLUE}Username:${NC} (leave empty)"
    echo -e "${BLUE}Password:${NC} (leave empty)"
    echo -e "${BLUE}Category:${NC} tv (for Sonarr), movies (for Radarr)"
    echo
}

# Main validation
echo "1. Checking Kubernetes cluster connectivity..."
if ! kubectl cluster-info >/dev/null 2>&1; then
    echo -e "${RED}❌ Cannot connect to Kubernetes cluster${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Kubernetes cluster accessible${NC}"

echo
echo "2. Checking VPN-protected Transmission..."
check_vpn_status

echo
echo "3. Checking service connectivity..."
check_service "transmission-vpn" "transmission" "9091" "/transmission/web/"
check_service "sonarr" "sonarr" "8989" "/"
check_service "radarr" "radarr" "7878" "/"
check_service "jackett" "jackett" "9117" "/"

echo
echo "4. Checking storage accessibility..."
check_download_paths

echo
echo "5. Checking pod status..."
echo -n "Transmission pod: "
if kubectl get pods -n transmission -l app=transmission-vpn --no-headers 2>/dev/null | grep -q "2/2.*Running"; then
    echo -e "${GREEN}✅ RUNNING${NC}"
else
    echo -e "${RED}❌ NOT READY${NC}"
fi

echo -n "Sonarr pod: "
if kubectl get pods -n sonarr -l app=sonarr --no-headers 2>/dev/null | grep -q "1/1.*Running"; then
    echo -e "${GREEN}✅ RUNNING${NC}"
else
    echo -e "${RED}❌ NOT READY${NC}"
fi

echo -n "Radarr pod: "
if kubectl get pods -n radarr -l app=radarr --no-headers 2>/dev/null | grep -q "1/1.*Running"; then
    echo -e "${GREEN}✅ RUNNING${NC}"
else
    echo -e "${RED}❌ NOT READY${NC}"
fi

echo -n "Jackett pod: "
if kubectl get pods -n jackett -l app=jackett --no-headers 2>/dev/null | grep -q "1/1.*Running"; then
    echo -e "${GREEN}✅ RUNNING${NC}"
else
    echo -e "${RED}❌ NOT READY${NC}"
fi

validate_transmission_config

echo
echo "6. Access URLs:"
echo -e "${BLUE}Sonarr:${NC} http://192.168.88.163:8989"
echo -e "${BLUE}Radarr:${NC} http://192.168.88.163:7878"
echo -e "${BLUE}Transmission:${NC} http://192.168.88.163:9091"
echo -e "${BLUE}Jackett:${NC} http://192.168.88.163:9117"

echo
echo "=== Configuration Steps ==="
echo "1. Open Sonarr: http://192.168.88.163:8989"
echo "2. Go to Settings → Download Clients"
echo "3. Add/Edit Transmission with host: transmission-vpn.transmission"
echo "4. Repeat for Radarr: http://192.168.88.163:7878"
echo "5. Test connections in both applications"

echo
echo "=== Validation Complete ==="