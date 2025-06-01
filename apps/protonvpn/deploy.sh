#!/bin/bash

# ProtonVPN Deployment Script for PiCluster
# This script deploys ProtonVPN using Gluetun on Kubernetes

set -e

echo "🔐 Deploying ProtonVPN on PiCluster..."

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl not found. Please install kubectl first."
    exit 1
fi

# Check if credentials file exists
if [ ! -f "credentials.env" ]; then
    echo "❌ credentials.env file not found!"
    echo "📝 Please create credentials.env from template:"
    echo "   cp credentials-template.env credentials.env"
    echo "   nano credentials.env"
    echo ""
    echo "🔗 Get your ProtonVPN credentials from:"
    echo "   https://account.protonvpn.com/"
    echo "   Account → OpenVPN/IKEv2 username"
    exit 1
fi

# Validate credentials file has required variables
if ! grep -q "OPENVPN_USER=" credentials.env || ! grep -q "OPENVPN_PASSWORD=" credentials.env; then
    echo "❌ credentials.env missing required variables!"
    echo "📝 Please ensure credentials.env contains:"
    echo "   OPENVPN_USER=your_username"
    echo "   OPENVPN_PASSWORD=your_password"
    exit 1
fi

# Check if values are not placeholder
if grep -q "your_openvpn_username_here" credentials.env || grep -q "your_openvpn_password_here" credentials.env; then
    echo "❌ Please replace placeholder values in credentials.env with your actual ProtonVPN credentials!"
    exit 1
fi

echo "✅ Credentials file validated"

# Deploy namespace
echo "📦 Creating VPN namespace..."
kubectl apply -f 01-namespace.yaml

# Create secret from credentials
echo "🔑 Creating ProtonVPN credentials secret..."
kubectl delete secret protonvpn-credentials -n vpn 2>/dev/null || true
kubectl create secret generic protonvpn-credentials --from-env-file=credentials.env -n vpn

# Deploy ConfigMap
echo "⚙️  Creating ProtonVPN configuration..."
kubectl apply -f 02-configmap.yaml

# Deploy ProtonVPN
echo "🚀 Deploying ProtonVPN..."
kubectl apply -f 03-deployment.yaml

# Deploy Service
echo "🌐 Creating ProtonVPN service..."
kubectl apply -f 04-service.yaml

echo ""
echo "🎉 ProtonVPN deployment complete!"
echo ""
echo "📊 Checking deployment status..."
kubectl get pods -n vpn
echo ""

# Wait for pod to be ready
echo "⏳ Waiting for ProtonVPN to start (this may take 1-2 minutes)..."
kubectl wait --for=condition=ready pod -l app=protonvpn -n vpn --timeout=300s

echo ""
echo "✅ ProtonVPN is ready!"
echo ""
echo "🔍 Useful commands:"
echo "   Check logs:        kubectl logs -f deployment/protonvpn -n vpn"
echo "   Check IP:          kubectl exec -it deployment/protonvpn -n vpn -- curl -s ifconfig.me"
echo "   Check location:    kubectl exec -it deployment/protonvpn -n vpn -- curl -s ipinfo.io"
echo "   Control interface: http://192.168.88.163:30090"
echo ""
echo "🎯 Next steps:"
echo "   1. Test VPN connection with: kubectl exec -it deployment/protonvpn -n vpn -- curl -s ifconfig.me"
echo "   2. Update qBittorrent to use VPN (see README.md)"
echo "   3. Add ProtonVPN to Homer dashboard"
echo ""
echo "📚 For more information, see README.md"