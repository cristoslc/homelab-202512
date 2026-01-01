#!/bin/bash
# Complete Day 1 Deployment Script
# Orchestrates Terraform infrastructure provisioning and Ansible configuration

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo "========================================="
echo "  Homelab Day 1 Deployment"
echo "========================================="
echo ""

# Get repository root
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

# Step 1: Terraform Apply
echo -e "${BLUE}Step 1: Provisioning infrastructure with Terraform...${NC}"
cd terraform

if [ ! -f "terraform.tfvars" ]; then
    echo -e "${RED}Error: terraform.tfvars not found${NC}"
    echo "Please create terraform/terraform.tfvars from terraform.tfvars.example"
    exit 1
fi

terraform init -upgrade
terraform apply

cd "$REPO_ROOT"
echo -e "${GREEN}✓ Infrastructure provisioned${NC}"
echo ""

# Step 2: Generate Ansible Inventory
echo -e "${BLUE}Step 2: Generating Ansible inventory from Terraform outputs...${NC}"
cd ansible

if [ ! -f "scripts/generate-inventory.sh" ]; then
    echo -e "${RED}Error: generate-inventory.sh not found${NC}"
    exit 1
fi

./scripts/generate-inventory.sh

echo -e "${GREEN}✓ Inventory generated${NC}"
echo ""

# Step 3: Run Ansible Playbook
echo -e "${BLUE}Step 3: Configuring infrastructure with Ansible...${NC}"

if [ ! -f "playbooks/site.yml" ]; then
    echo -e "${RED}Error: playbooks/site.yml not found${NC}"
    exit 1
fi

ansible-playbook playbooks/site.yml

cd "$REPO_ROOT"
echo -e "${GREEN}✓ Configuration complete${NC}"
echo ""

# Summary
echo "========================================="
echo "  Deployment Complete!"
echo "========================================="
echo ""
echo "Next steps:"
echo "  1. Verify deployment: ./scripts/validate-day1.sh"
echo "  2. Check WireGuard tunnel: ansible bastion -m shell -a 'wg show'"
echo "  3. Test Plex access: curl http://plex.yourdomain.com:32400/web"
echo ""
