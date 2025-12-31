#!/bin/bash
# Validation Script for Task 1: Terraform Infrastructure Provisioning
# This script validates that Terraform successfully provisioned the bastion VPS and DNS

set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "========================================="
echo "Task 1 Validation: Terraform Infrastructure"
echo "========================================="
echo ""

# Change to terraform directory
cd "$(dirname "$0")/../terraform" || exit 1

# Test 1: Terraform State Exists
echo -n "Test 1: Checking Terraform state exists... "
if [ -f "terraform.tfstate" ]; then
    echo -e "${GREEN}PASS${NC}"
else
    echo -e "${RED}FAIL${NC}"
    echo "  Error: No terraform.tfstate found. Run 'terraform apply' first."
    exit 1
fi

# Test 2: Get Terraform Outputs
echo -n "Test 2: Retrieving Terraform outputs... "
if terraform output -json > /tmp/tf-outputs.json 2>/dev/null; then
    echo -e "${GREEN}PASS${NC}"
else
    echo -e "${RED}FAIL${NC}"
    echo "  Error: Could not retrieve Terraform outputs"
    exit 1
fi

# Extract values
BASTION_IP=$(terraform output -raw bastion_ip 2>/dev/null)
PLEX_FQDN=$(terraform output -raw plex_fqdn 2>/dev/null)

echo "  Bastion IP: ${BASTION_IP}"
echo "  Plex FQDN: ${PLEX_FQDN}"
echo ""

# Test 3: Validate Bastion IP is valid IPv4
echo -n "Test 3: Validating bastion IP format... "
if echo "$BASTION_IP" | grep -qE '^([0-9]{1,3}\.){3}[0-9]{1,3}$'; then
    echo -e "${GREEN}PASS${NC}"
else
    echo -e "${RED}FAIL${NC}"
    echo "  Error: Invalid IPv4 address: $BASTION_IP"
    exit 1
fi

# Test 4: DNS Resolution
echo -n "Test 4: Testing DNS resolution for ${PLEX_FQDN}... "
DNS_IP=$(dig +short "$PLEX_FQDN" @1.1.1.1 | head -n1)
if [ "$DNS_IP" = "$BASTION_IP" ]; then
    echo -e "${GREEN}PASS${NC}"
    echo "  Resolved to: ${DNS_IP}"
else
    echo -e "${YELLOW}WARNING${NC}"
    echo "  Expected: ${BASTION_IP}"
    echo "  Got: ${DNS_IP}"
    echo "  DNS propagation may still be in progress. Wait a few minutes and try again."
fi
echo ""

# Test 5: SSH Connectivity
echo -n "Test 5: Testing SSH connectivity to bastion... "
if timeout 10 ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 root@"$BASTION_IP" 'echo "SSH_OK"' > /dev/null 2>&1; then
    echo -e "${GREEN}PASS${NC}"
    echo "  SSH connection successful"
else
    echo -e "${YELLOW}WARNING${NC}"
    echo "  Could not connect via SSH. This is expected if:"
    echo "  - Your SSH key is not yet added to ssh-agent"
    echo "  - Server is still booting (wait 1-2 minutes)"
    echo "  - Your IP is not allowed (check firewall rules)"
    echo ""
    echo "  Try manually: ssh root@${BASTION_IP}"
fi
echo ""

# Test 6: Terraform Resource Count
echo -n "Test 6: Verifying Terraform resources created... "
RESOURCE_COUNT=$(terraform state list 2>/dev/null | wc -l)
if [ "$RESOURCE_COUNT" -ge 5 ]; then
    echo -e "${GREEN}PASS${NC}"
    echo "  Created ${RESOURCE_COUNT} resources"
    echo "  Expected: server, firewall, SSH key, DNS record (minimum 4)"
else
    echo -e "${RED}FAIL${NC}"
    echo "  Only ${RESOURCE_COUNT} resources found (expected at least 4)"
    exit 1
fi
echo ""

# Summary
echo "========================================="
echo "Validation Summary"
echo "========================================="
echo ""
echo "Terraform State:      ${GREEN}✓${NC}"
echo "Terraform Outputs:    ${GREEN}✓${NC}"
echo "Bastion IP Valid:     ${GREEN}✓${NC}"
if [ "$DNS_IP" = "$BASTION_IP" ]; then
    echo "DNS Resolution:       ${GREEN}✓${NC}"
else
    echo "DNS Resolution:       ${YELLOW}⚠${NC} (propagating)"
fi
echo ""

echo "Next Steps:"
echo "1. Wait for DNS propagation (if needed): dig ${PLEX_FQDN}"
echo "2. Verify SSH access: ssh root@${BASTION_IP}"
echo "3. Proceed to Task 2: Ansible Repository Structure"
echo ""

echo -e "${GREEN}Task 1 Validation Complete!${NC}"
