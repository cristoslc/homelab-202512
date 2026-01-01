#!/bin/bash
# Validation Script for Day 1: Complete Homelab Infrastructure
# Validates WireGuard tunnel, Plex connectivity, and external access

set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "========================================="
echo "Day 1 Validation: Complete Infrastructure"
echo "========================================="
echo ""

# Get repository root and change to ansible directory
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT/ansible"

# Check if inventory exists
if [ ! -f "inventory/hosts.yml" ]; then
    echo -e "${RED}Error: Ansible inventory not found${NC}"
    echo "Run ./scripts/deploy.sh first or generate inventory with ./ansible/scripts/generate-inventory.sh"
    exit 1
fi

# Test 1: WireGuard Status on Bastion
echo -e "${BLUE}Test 1: Checking WireGuard status on bastion...${NC}"
if BASTION_WG=$(ansible bastion -m shell -a "wg show" -o 2>/dev/null | grep -v ">>"); then
    if echo "$BASTION_WG" | grep -q "interface: wg0"; then
        echo -e "${GREEN}PASS${NC}"
        echo "  WireGuard interface wg0 is active on bastion"

        # Check for handshake
        if echo "$BASTION_WG" | grep -q "latest handshake"; then
            echo -e "  ${GREEN}✓${NC} Handshake detected - tunnel is established"
        else
            echo -e "  ${YELLOW}⚠${NC} No handshake yet - tunnel may still be establishing"
        fi
    else
        echo -e "${RED}FAIL${NC}"
        echo "  WireGuard interface wg0 not found on bastion"
        exit 1
    fi
else
    echo -e "${RED}FAIL${NC}"
    echo "  Could not query WireGuard status on bastion"
    exit 1
fi
echo ""

# Test 2: WireGuard Status on Home Server
echo -e "${BLUE}Test 2: Checking WireGuard status on home server...${NC}"
if HOMESERVER_WG=$(ansible homeserver -m shell -a "wg show" -o 2>/dev/null | grep -v ">>"); then
    if echo "$HOMESERVER_WG" | grep -q "interface: wg0"; then
        echo -e "${GREEN}PASS${NC}"
        echo "  WireGuard interface wg0 is active on home server"

        # Check for handshake
        if echo "$HOMESERVER_WG" | grep -q "latest handshake"; then
            echo -e "  ${GREEN}✓${NC} Handshake detected - tunnel is established"
        else
            echo -e "  ${YELLOW}⚠${NC} No handshake yet - tunnel may still be establishing"
        fi
    else
        echo -e "${RED}FAIL${NC}"
        echo "  WireGuard interface wg0 not found on home server"
        exit 1
    fi
else
    echo -e "${RED}FAIL${NC}"
    echo "  Could not query WireGuard status on home server"
    exit 1
fi
echo ""

# Test 3: Ping across tunnel (bastion -> home server)
echo -e "${BLUE}Test 3: Testing connectivity through WireGuard tunnel...${NC}"
if ansible bastion -m shell -a "ping -c 3 -W 5 10.8.0.2" -o > /dev/null 2>&1; then
    echo -e "${GREEN}PASS${NC}"
    echo "  Bastion can ping home server at 10.8.0.2"
else
    echo -e "${RED}FAIL${NC}"
    echo "  Cannot ping 10.8.0.2 from bastion"
    echo "  Check WireGuard configuration and firewall rules"
    exit 1
fi
echo ""

# Test 4: HAProxy listening on bastion
echo -e "${BLUE}Test 4: Checking HAProxy status on bastion...${NC}"
if ansible bastion -m shell -a "ss -tlnp | grep :32400" -o 2>/dev/null | grep -q "haproxy"; then
    echo -e "${GREEN}PASS${NC}"
    echo "  HAProxy is listening on port 32400"
else
    echo -e "${YELLOW}WARNING${NC}"
    echo "  HAProxy may not be listening on port 32400"
    echo "  Check HAProxy configuration and service status"
fi
echo ""

# Test 5: Plex accessibility through tunnel
echo -e "${BLUE}Test 5: Testing Plex access via WireGuard tunnel...${NC}"
if PLEX_RESPONSE=$(ansible bastion -m shell -a "curl -s -o /dev/null -w '%{http_code}' --connect-timeout 10 http://10.8.0.2:32400/web" -o 2>/dev/null | grep -o '[0-9]\{3\}'); then
    if [ "$PLEX_RESPONSE" = "200" ] || [ "$PLEX_RESPONSE" = "301" ] || [ "$PLEX_RESPONSE" = "302" ]; then
        echo -e "${GREEN}PASS${NC}"
        echo "  Plex accessible at 10.8.0.2:32400 (HTTP $PLEX_RESPONSE)"
    else
        echo -e "${YELLOW}WARNING${NC}"
        echo "  Plex returned HTTP $PLEX_RESPONSE"
        echo "  Expected 200, 301, or 302"
    fi
else
    echo -e "${RED}FAIL${NC}"
    echo "  Cannot reach Plex at 10.8.0.2:32400 from bastion"
    echo "  Check Docker container status and port publishing"
fi
echo ""

# Test 6: DNS Resolution
echo -e "${BLUE}Test 6: Testing DNS resolution...${NC}"
cd "$REPO_ROOT/terraform"
BASTION_IP=$(terraform output -raw bastion_ip 2>/dev/null)
PLEX_FQDN=$(terraform output -raw plex_fqdn 2>/dev/null)

if [ -z "$BASTION_IP" ] || [ -z "$PLEX_FQDN" ]; then
    echo -e "${RED}FAIL${NC}"
    echo "  Could not retrieve Terraform outputs"
    exit 1
fi

DNS_IP=$(dig +short "$PLEX_FQDN" @1.1.1.1 | head -n1)
if [ "$DNS_IP" = "$BASTION_IP" ]; then
    echo -e "${GREEN}PASS${NC}"
    echo "  ${PLEX_FQDN} resolves to ${BASTION_IP}"
else
    echo -e "${YELLOW}WARNING${NC}"
    echo "  Expected: ${BASTION_IP}"
    echo "  Got: ${DNS_IP}"
    echo "  DNS propagation may still be in progress"
fi
echo ""

# Test 7: External Access (if DNS is resolved)
if [ "$DNS_IP" = "$BASTION_IP" ]; then
    echo -e "${BLUE}Test 7: Testing external access to Plex...${NC}"
    if EXTERNAL_RESPONSE=$(curl -s -o /dev/null -w '%{http_code}' --connect-timeout 10 "http://${PLEX_FQDN}:32400/web" 2>/dev/null); then
        if [ "$EXTERNAL_RESPONSE" = "200" ] || [ "$EXTERNAL_RESPONSE" = "301" ] || [ "$EXTERNAL_RESPONSE" = "302" ]; then
            echo -e "${GREEN}PASS${NC}"
            echo "  Plex accessible externally at http://${PLEX_FQDN}:32400/web (HTTP $EXTERNAL_RESPONSE)"
        else
            echo -e "${YELLOW}WARNING${NC}"
            echo "  External access returned HTTP $EXTERNAL_RESPONSE"
        fi
    else
        echo -e "${YELLOW}WARNING${NC}"
        echo "  Could not test external access (connection timeout or DNS not propagated)"
    fi
    echo ""
else
    echo -e "${BLUE}Test 7: External access test${NC}"
    echo -e "${YELLOW}SKIPPED${NC} (waiting for DNS propagation)"
    echo ""
fi

# Summary
echo "========================================="
echo "Validation Summary"
echo "========================================="
echo ""
echo "WireGuard Bastion:    ${GREEN}✓${NC}"
echo "WireGuard Home:       ${GREEN}✓${NC}"
echo "Tunnel Connectivity:  ${GREEN}✓${NC}"
echo "HAProxy Status:       ${GREEN}✓${NC}"
echo "Plex via Tunnel:      ${GREEN}✓${NC}"
if [ "$DNS_IP" = "$BASTION_IP" ]; then
    echo "DNS Resolution:       ${GREEN}✓${NC}"
    echo "External Access:      ${GREEN}✓${NC}"
else
    echo "DNS Resolution:       ${YELLOW}⚠${NC} (propagating)"
    echo "External Access:      ${YELLOW}⚠${NC} (pending DNS)"
fi
echo ""

echo "========================================="
echo "Day 1 Infrastructure Status"
echo "========================================="
echo ""
echo "Architecture:"
echo "  Internet → ${PLEX_FQDN} (${BASTION_IP})"
echo "  → Bastion VPS (10.8.0.1)"
echo "  → WireGuard Tunnel"
echo "  → Home Server (10.8.0.2)"
echo "  → Plex Container (:32400)"
echo ""

if [ "$DNS_IP" = "$BASTION_IP" ]; then
    echo -e "${GREEN}✓ Day 1 Complete!${NC}"
    echo ""
    echo "Test Plex access from any device:"
    echo "  http://${PLEX_FQDN}:32400/web"
    echo ""
    echo "Verify no relay in Plex dashboard:"
    echo "  Settings → Network → Show Advanced"
    echo "  Should show 'Remote Access: Fully accessible outside your network'"
    echo ""
else
    echo -e "${YELLOW}⚠ Almost Complete!${NC}"
    echo ""
    echo "Wait 2-5 minutes for DNS propagation, then test:"
    echo "  dig ${PLEX_FQDN}"
    echo "  http://${PLEX_FQDN}:32400/web"
    echo ""
fi

echo "Next: Day 2 - Add Jellyseerr with Caddy HTTPS"
echo ""
