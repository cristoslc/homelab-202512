# Getting Started

Welcome to the homelab infrastructure project! This guide will help you get from zero to a working deployment.

## Quick Overview

This project uses Infrastructure as Code (Terraform + Ansible) to automate deployment of a WireGuard bastion that provides secure access to home-hosted media services (Plex, Jellyfin, and more).

**What you'll build:**
- Secure WireGuard VPN tunnel
- HTTPS-enabled public access to Plex and Jellyfin
- Zero manual configuration (everything in code)

**Time to first deployment:** ~30 minutes

## Step 1: Prerequisites

Install required tools and set up accounts.

**Tools Required:**
- Terraform >= 1.6
- Ansible >= 2.15
- Git
- SSH client

**See detailed installation instructions:** [prerequisites.md](./prerequisites.md)

**Accounts Required:**
- [Hetzner Cloud](https://console.hetzner.cloud/) - VPS hosting (~€4.51/month)
- [Cloudflare](https://www.cloudflare.com/) - DNS management (free)
- Domain registered and configured in Cloudflare

## Step 2: Clone Repository

```bash
git clone https://github.com/yourusername/homelab-202512.git
cd homelab-202512
```

## Step 3: Configure Secrets

Create your environment configuration:

```bash
# Copy template
cp .env.example .env

# Edit with your values
vi .env
```

**Required values in `.env`:**
- `TF_VAR_hcloud_token` - [Get from Hetzner](https://console.hetzner.cloud/)
- `TF_VAR_cloudflare_api_token` - [Get from Cloudflare](https://dash.cloudflare.com/profile/api-tokens)
- `TF_VAR_cloudflare_zone_id` - Found in Cloudflare dashboard for your domain
- `TF_VAR_domain` - Your domain name (e.g., `example.com`)
- `TF_VAR_ssh_public_key` - Your SSH public key (`cat ~/.ssh/id_ed25519.pub`)
- `ANSIBLE_VAULT_PASSWORD` - Choose a secure password for encrypting secrets

**Don't have an SSH key?**
```bash
ssh-keygen -t ed25519 -C "homelab-bastion"
cat ~/.ssh/id_ed25519.pub  # Copy this value
```

See `.env.example` for complete documentation of all variables.

## Step 4: Deploy Infrastructure

Single command deployment:

```bash
./scripts/deploy.sh
```

This script will:
1. Load environment variables from `.env`
2. Run Terraform to provision VPS and configure DNS
3. Generate Ansible inventory from Terraform outputs
4. Run Ansible playbooks to configure bastion and home server
5. Validate the deployment

**First deployment takes:** ~10-15 minutes
- Terraform: ~2 minutes (VPS provisioning)
- Ansible: ~8-12 minutes (package installation, configuration)

## Step 5: Validate Deployment

The deploy script runs validation automatically, but you can run it manually:

```bash
./scripts/validate-day1.sh
```

**Tests performed:**
- ✅ WireGuard tunnel established
- ✅ Ping across tunnel (bastion ↔ home server)
- ✅ HAProxy listening and forwarding
- ✅ Plex accessible via tunnel
- ✅ DNS resolution correct
- ✅ SSL certificates valid

## Step 6: Access Your Services

Once deployed, access your services:

- **Plex:** `https://plex.yourdomain.com:32400/web`
- **Jellyfin:** `https://plex.yourdomain.com:8920`

**Test from mobile network** (not your home WiFi) to verify external access works!

## What's Next?

You've completed **Day 1** of the 5-day buildout. See the PRDs for next phases:

- **[Day 2: Jellyseerr](./PRD-day2.md)** - Media request management
- **[Day 3: *arr Stack](./PRD-day3.md)** - Sonarr, Radarr, Prowlarr
- **[Day 4: Production Hardening](./PRD-day4.md)** - Monitoring, backups, alerts
- **[Day 5: Documentation & Portability](./PRD-day5.md)** - Final polish

## Common Issues

### "DNS not resolving"
Wait 2-5 minutes for Cloudflare propagation. Check your Zone ID is correct.

### "SSH connection refused"
Wait 1-2 minutes for VPS to boot. Verify your SSH public key is correct in `.env`.

### "Terraform authentication failed"
Check your API tokens have correct permissions:
- Hetzner: Read & Write
- Cloudflare: Zone DNS (Edit)

### "WireGuard tunnel not establishing"
Check systemd service status on both hosts:
```bash
ansible bastion -m shell -a "systemctl status wg-quick@wg0"
ansible homeserver -m shell -a "systemctl status wg-quick@wg0"
```

**Full troubleshooting guide:** See main [README.md](../README.md#troubleshooting)

## Learning Resources

- **Architecture Overview:** [README.md](../README.md)
- **Terraform Module Docs:** [terraform/README.md](../terraform/README.md)
- **Ansible Playbook Docs:** [ansible/README.md](../ansible/README.md)
- **CLAUDE.md:** Instructions for AI coding assistants working on this repo

## Getting Help

- Check the [troubleshooting section](../README.md#troubleshooting)
- Review the [PRDs](./PRD-day1.md) for requirements and validation steps
- Open an issue on GitHub

## Cost Breakdown

| Item | Cost |
|------|------|
| Hetzner CX11 VPS | ~€4.51/month |
| Cloudflare DNS | Free |
| **Total** | **~€4.51/month** |

**Testing?** Hetzner bills hourly (€0.007/hr). Running for 1 day costs ~€0.11.

**Clean up to stop charges:**
```bash
cd terraform
terraform destroy
```
