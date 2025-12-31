#!/bin/bash
set -euo pipefail

# Generate Ansible inventory from Terraform outputs
# Run from ansible/ directory

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANSIBLE_DIR="$(dirname "$SCRIPT_DIR")"
TERRAFORM_DIR="$ANSIBLE_DIR/../terraform"
INVENTORY_FILE="$ANSIBLE_DIR/inventory/hosts.yml"

echo "Generating Ansible inventory from Terraform outputs..."

# Check if terraform directory exists
if [ ! -d "$TERRAFORM_DIR" ]; then
    echo "Error: Terraform directory not found at $TERRAFORM_DIR"
    exit 1
fi

# Get Terraform outputs
cd "$TERRAFORM_DIR"

# Check if Terraform state exists
if [ ! -f "terraform.tfstate" ]; then
    echo "Error: terraform.tfstate not found. Run 'terraform apply' first."
    exit 1
fi

# Extract outputs using terraform output
BASTION_IP=$(terraform output -raw bastion_ip 2>/dev/null || echo "")
PLEX_FQDN=$(terraform output -raw plex_fqdn 2>/dev/null || echo "")

if [ -z "$BASTION_IP" ]; then
    echo "Error: Could not get bastion_ip from Terraform outputs"
    exit 1
fi

if [ -z "$PLEX_FQDN" ]; then
    echo "Error: Could not get plex_fqdn from Terraform outputs"
    exit 1
fi

echo "Bastion IP: $BASTION_IP"
echo "Plex FQDN: $PLEX_FQDN"

# Create inventory directory if it doesn't exist
mkdir -p "$ANSIBLE_DIR/inventory"

# Generate inventory file
cat > "$INVENTORY_FILE" <<EOF
---
all:
  vars:
    ansible_user: root
    ansible_python_interpreter: /usr/bin/python3
    plex_domain: $PLEX_FQDN

bastion:
  hosts:
    bastion_vps:
      ansible_host: $BASTION_IP

homeserver:
  hosts:
    home_docker:
      ansible_connection: local
EOF

echo "Inventory file generated at: $INVENTORY_FILE"
echo ""
echo "Verify with: ansible-inventory --list -i $INVENTORY_FILE"
