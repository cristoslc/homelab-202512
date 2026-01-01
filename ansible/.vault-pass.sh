#!/bin/bash
# Ansible Vault password helper
# Reads vault password from ANSIBLE_VAULT_PASSWORD environment variable

if [ -z "$ANSIBLE_VAULT_PASSWORD" ]; then
    echo "Error: ANSIBLE_VAULT_PASSWORD environment variable not set" >&2
    exit 1
fi

echo "$ANSIBLE_VAULT_PASSWORD"
