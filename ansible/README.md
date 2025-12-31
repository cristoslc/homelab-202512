# Ansible Configuration for Homelab

This directory contains Ansible playbooks and roles for configuring the homelab infrastructure.

## Initial Setup

### 1. Generate Inventory from Terraform

After running `terraform apply`, generate the Ansible inventory:

```bash
cd ansible
./scripts/generate-inventory.sh
```

This creates `inventory/hosts.yml` with bastion and homeserver configurations.

### 2. Configure Vault Password in .env

Add your Ansible Vault password to the `.env` file in the repository root:

```bash
# In /home/cristos/git/homelab-202512/.env
ANSIBLE_VAULT_PASSWORD=your-secure-vault-password
```

The `.env` file is gitignored and centralizes all secrets (Task Master API keys, vault password, etc.).

### 3. Generate WireGuard Keys

Generate and encrypt WireGuard keys using ansible-vault:

```bash
cd ansible
./scripts/generate-wireguard-keys.sh
```

You'll be prompted to create a vault password. **Use the same password you added to .env in step 2.**

### 4. Add Additional Secrets

You'll need to add Cloudflare API credentials to the vault file:

```bash
ansible-vault edit group_vars/all/wireguard_vault.yml
```

Add these variables:
```yaml
cloudflare_api_token: your-cloudflare-api-token
cloudflare_zone: yourdomain.com
```

## Running Playbooks

### Deploy Everything
```bash
ansible-playbook playbooks/site.yml
```

### Deploy Bastion Only
```bash
ansible-playbook playbooks/bastion.yml
```

### Deploy Home Server Only
```bash
ansible-playbook playbooks/homeserver.yml
```

## Secrets Management

- **Encrypted secrets**: `group_vars/all/wireguard_vault.yml` (ansible-vault encrypted)
- **Non-sensitive config**: `group_vars/all/wireguard.yml` (plain text)
- **Vault password**: Stored in `.env` as `ANSIBLE_VAULT_PASSWORD` (gitignored)
- **Password retrieval**: `ansible/.vault-pass.sh` script reads from `.env` automatically

### Vault Commands

View encrypted file:
```bash
ansible-vault view group_vars/all/wireguard_vault.yml
```

Edit encrypted file:
```bash
ansible-vault edit group_vars/all/wireguard_vault.yml
```

Rekey (change password):
```bash
ansible-vault rekey group_vars/all/wireguard_vault.yml
```

## Directory Structure

```
ansible/
├── ansible.cfg              # Ansible configuration
├── group_vars/
│   └── all/
│       ├── wireguard.yml    # Non-sensitive WireGuard config
│       └── wireguard_vault.yml  # Encrypted secrets (WG keys, API tokens)
├── inventory/
│   └── hosts.yml            # Generated from Terraform (gitignored)
├── playbooks/
│   ├── site.yml             # Master playbook (bastion + homeserver)
│   ├── bastion.yml          # Bastion VPS configuration
│   └── homeserver.yml       # Home Docker host configuration
├── roles/
│   ├── base-security/       # UFW, fail2ban, SSH hardening
│   ├── wireguard-server/    # WG server on bastion
│   ├── wireguard-client/    # WG client on home server
│   ├── haproxy/             # HAProxy for Plex forwarding
│   ├── ddclient/            # Dynamic DNS updates
│   └── plex-config/         # Plex container validation
└── scripts/
    ├── generate-inventory.sh        # Create inventory from Terraform
    └── generate-wireguard-keys.sh   # Generate and encrypt WG keys
```

## Validation

Test inventory:
```bash
ansible-inventory --list
```

Test connectivity:
```bash
ansible all -m ping
```

Syntax check:
```bash
ansible-playbook --syntax-check playbooks/site.yml
```
