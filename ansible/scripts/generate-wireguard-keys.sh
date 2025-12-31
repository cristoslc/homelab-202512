#!/bin/bash
set -euo pipefail

# Generate WireGuard keys and store in ansible-vault encrypted file
# Run from ansible/ directory

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANSIBLE_DIR="$(dirname "$SCRIPT_DIR")"
VAULT_FILE="$ANSIBLE_DIR/group_vars/all/wireguard_vault.yml"

echo "Generating WireGuard keys for ansible-vault..."

# Create group_vars/all directory if it doesn't exist
mkdir -p "$ANSIBLE_DIR/group_vars/all"

# Generate keys
WG_SERVER_PRIVATE=$(wg genkey)
WG_SERVER_PUBLIC=$(echo "$WG_SERVER_PRIVATE" | wg pubkey)
WG_CLIENT_PRIVATE=$(wg genkey)
WG_CLIENT_PUBLIC=$(echo "$WG_CLIENT_PRIVATE" | wg pubkey)

# Create temporary unencrypted file
TEMP_FILE=$(mktemp)
cat > "$TEMP_FILE" <<EOF
---
# WireGuard Keys - Encrypted with ansible-vault
# To view: ansible-vault view group_vars/all/wireguard_vault.yml
# To edit: ansible-vault edit group_vars/all/wireguard_vault.yml

wg_server_private_key: $WG_SERVER_PRIVATE
wg_server_public_key: $WG_SERVER_PUBLIC
wg_client_private_key: $WG_CLIENT_PRIVATE
wg_client_public_key: $WG_CLIENT_PUBLIC
EOF

echo ""
echo "Keys generated. Now encrypting with ansible-vault..."
echo "You will be prompted to create a vault password."
echo ""
echo "IMPORTANT: Use the same password you added to .env as ANSIBLE_VAULT_PASSWORD"
echo "This allows Ansible to automatically decrypt the vault when running playbooks."
echo ""

# Encrypt the file
ansible-vault encrypt "$TEMP_FILE" --output="$VAULT_FILE"

# Clean up
rm -f "$TEMP_FILE"

echo ""
echo "Encrypted keys saved to: $VAULT_FILE"
echo ""
echo "Ansible will automatically decrypt this file using ANSIBLE_VAULT_PASSWORD from .env"
echo "You can now run playbooks with: ansible-playbook playbooks/site.yml"
echo ""
echo "Public keys (safe to view):"
echo "  Server Public: $WG_SERVER_PUBLIC"
echo "  Client Public: $WG_CLIENT_PUBLIC"
