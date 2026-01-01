# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Context

This is **Day 1** of a 5-day homelab infrastructure buildout. The goal is to eliminate Plex relay usage by establishing a WireGuard bastion architecture that provides direct connections from the internet to a home Plex server.

**Core Principle**: Zero manual steps - everything is automated via Infrastructure as Code (Terraform + Ansible).

## Architecture Overview

```
Internet → plex.yourdomain.com (Cloudflare DNS)
         → Bastion VPS (Hetzner, 10.8.0.1)
           → WireGuard Tunnel (51820/udp)
             → Home Docker Host (10.8.0.2)
               → Docker Bridge Network
                 → Plex Container (:32400)
```

**Critical Design Decision**: WireGuard runs as a systemd service on the Docker host OS (NOT containerized). This preserves Docker network isolation while avoiding `network_mode: host`. Traffic flows through standard Docker port publishing (`-p 32400:32400`).

## Task Management

This project uses **Task Master AI** (MCP server) to track implementation progress:

- **View all tasks**: Use `mcp__taskmaster-ai__get_tasks` tool
- **View specific task**: Use `mcp__taskmaster-ai__get_task` with task ID
- **Update task status**: Use `mcp__taskmaster-ai__set_task_status` (statuses: pending, in-progress, done, blocked, deferred, cancelled)
- **Task details**: See `.taskmaster/tasks/tasks.json`
- **PRD**: See `.taskmaster/docs/prd.txt` for complete requirements

**5 Day 1 Tasks**:
1. Terraform Infrastructure (VPS + DNS)
2. Ansible Repository Structure
3. Bastion Playbook (WireGuard server, HAProxy, security)
4. Home Server Playbook (WireGuard client, Plex validation)
5. Deployment & Validation

## Common Commands

### Terraform Operations

```bash
# From repository root
cd terraform

# Initialize (first time only)
terraform init

# Preview changes
terraform plan

# Apply infrastructure
terraform apply

# View outputs (used by Ansible)
terraform output
terraform output -json
terraform output -raw bastion_ip

# Destroy infrastructure
terraform destroy

# Validate Task 1 completion
cd ..
./scripts/validate-task1.sh
```

### Ansible Operations (Tasks 2-5)

```bash
# From repository root
cd ansible

# Generate inventory from Terraform outputs
./scripts/generate-inventory.sh

# Run complete deployment
ansible-playbook playbooks/site.yml

# Run bastion configuration only
ansible-playbook playbooks/bastion.yml

# Run home server configuration only
ansible-playbook playbooks/homeserver.yml

# Ad-hoc commands
ansible bastion -m shell -a "wg show"
ansible homeserver -m shell -a "ping -c 3 10.8.0.1"

# Validate Day 1 completion
./scripts/validate-day1.sh
```

## Network Configuration

**WireGuard Network**: 10.8.0.0/24
- Bastion VPS: 10.8.0.1 (WireGuard server, HAProxy, public internet endpoint)
- Home Server: 10.8.0.2 (WireGuard client, Docker host)

**Firewall Ports (Bastion)**:
- 22/tcp: SSH
- 51820/udp: WireGuard
- 32400/tcp: Plex (HAProxy → WireGuard tunnel → home)

**Traffic Flow**: Internet traffic hits HAProxy on bastion:32400 → forwards through WireGuard tunnel to 10.8.0.2:32400 → Docker host routes to published container port → Plex container

## Secrets Management

**Single Source of Truth**: `.env` file (gitignored)

All secrets are centralized in the `.env` file in the project root:

**Terraform Variables** (TF_VAR_* prefix):
- `TF_VAR_hcloud_token` - Hetzner Cloud API token
- `TF_VAR_cloudflare_api_token` - Cloudflare API token (shared with Ansible ddclient)
- `TF_VAR_cloudflare_zone_id` - Cloudflare Zone ID
- `TF_VAR_domain` - Your domain name
- `TF_VAR_ssh_public_key` - SSH public key for bastion access
- Optional: TF_VAR_plex_subdomain, TF_VAR_server_name, TF_VAR_server_type, etc.

**Ansible Variables**:
- `CLOUDFLARE_ZONE` - Domain name for ddclient (should match TF_VAR_domain)
- `ANSIBLE_VAULT_PASSWORD` - Password for encrypting/decrypting WireGuard keys and certificates

**Task Master AI** (optional):
- `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `OPENROUTER_API_KEY`

**Template** (committed to repo):
- `.env.example` - Copy this to `.env` and fill in all values

**Deployment**:
The `./scripts/deploy.sh` script automatically sources `.env` and exports all variables for both Terraform and Ansible.

## Module Structure

**Terraform** (modular design for provider portability):
- `terraform/main.tf` - Root module, provider configs
- `terraform/hetzner/` - VPS, firewall, SSH key resources
- `terraform/cloudflare/` - DNS A record (easily swappable for Route53/etc.)
- `terraform/outputs.tf` - Exports bastion IP, FQDN for Ansible

**Ansible** (host-based playbooks, not service-per-playbook):
- `ansible/playbooks/bastion.yml` - Configures entire bastion VPS (all roles together)
- `ansible/playbooks/homeserver.yml` - Configures entire home Docker host
- `ansible/playbooks/site.yml` - Master orchestrator (runs bastion → homeserver in sequence)
- `ansible/roles/` - Individual service roles (wireguard-server, haproxy, ddclient, base-security, wireguard-client, plex-config)

## Validation Strategy

**Task 1 Validation** (Terraform):
1. Terraform state exists
2. Outputs valid (bastion_ip is IPv4, plex_fqdn resolves)
3. DNS resolution: `dig plex.yourdomain.com` → bastion IP
4. SSH connectivity: `ssh root@<bastion_ip>`
5. Resource count (minimum 4: server, firewall, SSH key, DNS record)

**Day 1 Complete Validation**:
1. WireGuard tunnel established (both sides show handshake)
2. Ping across tunnel (bastion ↔ home server)
3. HAProxy listening on :32400
4. Plex accessible via tunnel from bastion
5. DNS resolves correctly
6. External access test (mobile network → plex.yourdomain.com:32400/web)

## Future Days Context

**Day 2**: Add Jellyseerr with Caddy HTTPS reverse proxy
**Day 3**: Expose *arr stack (Sonarr/Radarr/Prowlarr)
**Day 4**: Production hardening (monitoring, backups, alerting)
**Day 5**: Documentation and portability validation

Day 1 establishes the foundation (bastion + tunnel + Plex). Future days build on this architecture by adding services behind Caddy reverse proxy.

## Important: When Working on Tasks 2-5

- **Inventory automation**: Generate from Terraform outputs via `scripts/generate-inventory.sh` (reads `terraform output -json`)
- **WireGuard keys**: Auto-generate using `wg genkey | tee privatekey | wg pubkey > publickey`
- **Ansible idempotency**: All roles must be safe to re-run (use idempotent modules: systemd, template, apt with state=present)
- **Host-based deployment**: Bastion playbook configures the entire VPS (not individual services), same for home server
- **IP forwarding required**: Home server needs `net.ipv4.ip_forward=1` for wg0 ↔ docker0 traffic
- **Firewall rules**: Use iptables FORWARD rules to allow traffic between wg0 and docker0 interfaces

## Common Issues & Solutions

**"DNS not resolving"**: Wait 2-5 minutes for Cloudflare propagation, check Zone ID is correct

**"SSH connection refused"**: Wait 1-2 minutes for VPS boot, verify SSH key in terraform.tfvars matches your public key

**"WireGuard tunnel not establishing"**: Check firewall allows 51820/udp on both ends, verify peer public keys are correct, check systemd service status

**"Plex not accessible via tunnel"**: Verify HAProxy config points to 10.8.0.2:32400, check Docker container has port 32400 published, ensure IP forwarding enabled on home server
