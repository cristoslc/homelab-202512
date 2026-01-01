#!/bin/bash
# Complete Day 1 Deployment Script
# Orchestrates Terraform infrastructure provisioning and Ansible configuration
# Usage: ./deploy.sh [--clean] [--auto-approve]

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Parse command line arguments
CLEAN=false
AUTO_APPROVE=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --clean)
      CLEAN=true
      shift
      ;;
    --auto-approve)
      AUTO_APPROVE="-auto-approve"
      shift
      ;;
    *)
      echo -e "${RED}Unknown option: $1${NC}"
      echo "Usage: ./deploy.sh [--clean] [--auto-approve]"
      echo "  --clean          Destroy and rebuild infrastructure from scratch"
      echo "  --auto-approve   Skip Terraform approval prompts"
      exit 1
      ;;
  esac
done

echo "========================================="
echo "  Homelab Day 1 Deployment"
echo "========================================="
echo ""

# Check for required environment variables
if [ -z "$ANSIBLE_VAULT_PASSWORD" ]; then
    echo -e "${YELLOW}Warning: ANSIBLE_VAULT_PASSWORD not set${NC}"
    echo "Certificate backup/restore will be skipped if encryption is needed"
    echo ""
fi

# Get repository root
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

# Step 0: Optional clean deployment
if [ "$CLEAN" = true ]; then
    echo -e "${YELLOW}Step 0: Destroying existing infrastructure...${NC}"
    cd terraform

    if [ ! -f "terraform.tfstate" ]; then
        echo -e "${YELLOW}No existing state found, skipping destroy${NC}"
    else
        terraform destroy $AUTO_APPROVE
        echo -e "${GREEN}✓ Infrastructure destroyed${NC}"
    fi

    cd "$REPO_ROOT"
    echo ""
fi

# Step 1: Terraform Apply
echo -e "${BLUE}Step 1: Provisioning infrastructure with Terraform...${NC}"
cd terraform

if [ ! -f "terraform.tfvars" ]; then
    echo -e "${RED}Error: terraform.tfvars not found${NC}"
    echo "Please create terraform/terraform.tfvars from terraform.tfvars.example"
    exit 1
fi

terraform init -upgrade
terraform apply $AUTO_APPROVE

cd "$REPO_ROOT"
echo -e "${GREEN}✓ Infrastructure provisioned${NC}"
echo ""

# Step 1.5: Prepare for Ansible deployment
echo -e "${BLUE}Step 1.5: Preparing for configuration deployment...${NC}"
cd terraform

BASTION_IP=$(terraform output -raw bastion_ip)
PLEX_FQDN=$(terraform output -raw plex_fqdn)

if [ -z "$BASTION_IP" ]; then
    echo -e "${RED}Error: Could not get bastion_ip from Terraform${NC}"
    exit 1
fi

cd "$REPO_ROOT"

# Clean SSH host key (important when rebuilding VPS)
echo "Removing old SSH host key for $BASTION_IP..."
ssh-keygen -R "$BASTION_IP" 2>/dev/null || true
if [ -n "$PLEX_FQDN" ]; then
    ssh-keygen -R "$PLEX_FQDN" 2>/dev/null || true
fi

# Wait for SSH to become available
echo "Waiting for SSH on new VPS..."
MAX_RETRIES=24  # 2 minutes
RETRY_COUNT=0
until ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=5 \
          root@"$BASTION_IP" exit 2>/dev/null; do
  RETRY_COUNT=$((RETRY_COUNT+1))
  if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
    echo -e "${RED}Error: SSH not available after 2 minutes${NC}"
    exit 1
  fi
  echo "  Attempt $RETRY_COUNT/$MAX_RETRIES..."
  sleep 5
done
echo -e "${GREEN}✓ SSH ready${NC}"

# Wait for cloud-init to complete (prevents apt lock conflicts)
echo "Waiting for cloud-init to complete..."
ssh -o StrictHostKeyChecking=accept-new root@"$BASTION_IP" 'cloud-init status --wait' 2>/dev/null || true
echo -e "${GREEN}✓ Cloud-init complete${NC}"

# Wait for DNS propagation (critical for Let's Encrypt)
if [ -n "$PLEX_FQDN" ]; then
    echo "Waiting for DNS propagation..."
    MAX_DNS_RETRIES=12  # 1 minute
    DNS_RETRY_COUNT=0

    # Check multiple DNS servers for better reliability
    DNS_SERVERS=("1.1.1.1" "8.8.8.8" "9.9.9.9")

    until [ $DNS_RETRY_COUNT -ge $MAX_DNS_RETRIES ]; do
      PROPAGATED=true
      for DNS_SERVER in "${DNS_SERVERS[@]}"; do
        CURRENT_IP=$(dig +short $PLEX_FQDN @$DNS_SERVER | grep -v '\.$' | head -1)
        if [ "$CURRENT_IP" != "$BASTION_IP" ]; then
          PROPAGATED=false
          break
        fi
      done

      if [ "$PROPAGATED" = true ]; then
        echo -e "${GREEN}✓ DNS propagated across all resolvers${NC}"
        break
      fi

      DNS_RETRY_COUNT=$((DNS_RETRY_COUNT+1))
      if [ $DNS_RETRY_COUNT -ge $MAX_DNS_RETRIES ]; then
        echo -e "${YELLOW}Warning: DNS not fully propagated across all resolvers, continuing anyway...${NC}"
        echo -e "${YELLOW}Let's Encrypt certificate acquisition may fail if DNS hasn't propagated${NC}"
        break
      fi

      echo "  Waiting for $PLEX_FQDN to resolve to $BASTION_IP (attempt $DNS_RETRY_COUNT/$MAX_DNS_RETRIES)..."
      sleep 5
    done
fi

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
echo "  3. Test Plex access: curl https://$PLEX_FQDN:32400/web"
echo ""
echo "Optional - Backup Let's Encrypt certificates:"
echo "  ansible-playbook ansible/playbooks/backup-letsencrypt.yml"
echo "  (Enables instant cert restore on future deployments, avoids rate limits)"
echo ""
