#!/bin/bash
# Read Ansible Vault password from .env file
# This script is called by Ansible when vault_password_file is set

set -euo pipefail

# Path to .env file (one level up from ansible/)
ENV_FILE="$(dirname "$0")/../.env"

if [ ! -f "$ENV_FILE" ]; then
    echo "Error: .env file not found at $ENV_FILE" >&2
    exit 1
fi

# Source .env and extract ANSIBLE_VAULT_PASSWORD
if grep -q "^ANSIBLE_VAULT_PASSWORD=" "$ENV_FILE"; then
    # Extract the value after ANSIBLE_VAULT_PASSWORD=
    # This handles quotes and special characters properly
    VAULT_PASSWORD=$(grep "^ANSIBLE_VAULT_PASSWORD=" "$ENV_FILE" | cut -d '=' -f 2- | tr -d '"' | tr -d "'")

    if [ -z "$VAULT_PASSWORD" ]; then
        echo "Error: ANSIBLE_VAULT_PASSWORD is empty in .env" >&2
        exit 1
    fi

    # Output password to stdout (Ansible captures this)
    echo "$VAULT_PASSWORD"
else
    echo "Error: ANSIBLE_VAULT_PASSWORD not found in .env" >&2
    echo "Add this line to your .env file: ANSIBLE_VAULT_PASSWORD=your-password" >&2
    exit 1
fi
