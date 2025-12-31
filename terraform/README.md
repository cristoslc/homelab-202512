# Terraform Infrastructure - Task 1

## Quick Start

### 1. Configure Secrets

Copy the example file and fill in your API keys:

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your actual values:
- **Hetzner API Token**: Get from https://console.hetzner.cloud/
- **Cloudflare API Token**: Get from https://dash.cloudflare.com/profile/api-tokens
- **Cloudflare Zone ID**: Find in Cloudflare dashboard for your domain
- **Domain**: Your domain name (e.g., `example.com`)
- **SSH Public Key**: Contents of `~/.ssh/id_ed25519.pub` (or generate new key)

### 2. Generate SSH Key (if needed)

```bash
ssh-keygen -t ed25519 -C "bastion-plex" -f ~/.ssh/bastion-plex
cat ~/.ssh/bastion-plex.pub  # Copy this to terraform.tfvars
```

### 3. Initialize Terraform

```bash
terraform init
```

This downloads the Hetzner and Cloudflare providers.

### 4. Preview Changes

```bash
terraform plan
```

Expected resources:
- 1 Hetzner server (bastion-plex, default: CPX11 in Ashburn, VA)
- 1 Hetzner firewall (3 rules: SSH, WireGuard, Plex)
- 1 Hetzner SSH key
- 1 Cloudflare DNS A record (plex.yourdomain.com)

### 5. Apply Configuration

```bash
terraform apply
```

Type `yes` to confirm. This will:
- Provision a Hetzner CPX11 VPS (~€4-5/month)
- Configure firewall rules (22/tcp, 51820/udp, 32400/tcp)
- Create DNS A record pointing to bastion IP

### 6. Validate Deployment

```bash
cd ..
./scripts/validate-task1.sh
```

This script tests:
- Terraform state exists
- Outputs are valid (bastion IP, Plex FQDN)
- IPv4 address format
- DNS resolution (plex.yourdomain.com → bastion IP)
- SSH connectivity
- Resource count

### 7. Verify Outputs

```bash
terraform output
```

Expected outputs:
- `bastion_ip`: Public IPv4 of your VPS
- `plex_fqdn`: Full domain (e.g., plex.example.com)
- `wireguard_port`: 51820
- `ansible_inventory`: Ready for Ansible (Task 2)

### 8. Test SSH Access

```bash
ssh root@$(terraform output -raw bastion_ip)
```

Should connect successfully with your SSH key.

### 9. Test DNS Resolution

```bash
dig $(terraform output -raw plex_fqdn)
```

Should return your bastion IP. Note: DNS propagation may take 1-5 minutes.

## Troubleshooting

### "No valid credential sources found"

**Hetzner**: Check `hcloud_token` in `terraform.tfvars` is correct.

**Cloudflare**: Check `cloudflare_api_token` in `terraform.tfvars` has DNS edit permissions.

### "SSH connection refused"

- Wait 1-2 minutes for server to finish booting
- Check your SSH key path matches the public key in `terraform.tfvars`
- Verify firewall allows SSH (22/tcp) from your IP

### "DNS not resolving"

- Wait 2-5 minutes for DNS propagation
- Check Cloudflare Zone ID is correct
- Verify domain name in `terraform.tfvars` matches your Cloudflare zone

### "Resource already exists"

If you've run Terraform before:
```bash
terraform destroy  # Remove old infrastructure
terraform apply    # Create fresh
```

## Cost Estimate

- **Hetzner CPX11**: ~€4.51/month (€0.007/hour)
- **Cloudflare DNS**: Free
- **Total**: ~€4.51/month

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

Type `yes` to confirm. This removes:
- VPS (stops billing)
- Firewall
- SSH key
- DNS record

**Note**: Always destroy when not in use to avoid unnecessary charges.

## Next Steps

Once Task 1 validation passes:
- **Task 2**: Ansible repository structure and inventory automation
- **Task 3**: Bastion playbook (WireGuard, HAProxy, security)
- **Task 4**: Home server playbook (WireGuard client, Plex)
- **Task 5**: Deployment orchestration and validation

## File Structure

```
terraform/
├── main.tf                      # Root module
├── variables.tf                 # Input variables
├── outputs.tf                   # Exported values for Ansible
├── terraform.tfvars.example     # Template for secrets
├── terraform.tfvars             # Your secrets (gitignored)
├── hetzner/
│   ├── main.tf                  # VPS, firewall, SSH key
│   ├── variables.tf
│   └── outputs.tf
└── cloudflare/
    ├── main.tf                  # DNS A record
    ├── variables.tf
    └── outputs.tf
```

## Resources Created

| Type | Name | Purpose |
|------|------|---------|
| `hcloud_server` | bastion-plex | Ubuntu 24.04 LTS VPS |
| `hcloud_firewall` | bastion-plex-firewall | SSH, WireGuard, Plex ports |
| `hcloud_ssh_key` | bastion-plex-key | SSH authentication |
| `cloudflare_record` | plex.yourdomain.com | DNS A record |

## Provider Documentation

- **Hetzner Cloud**: https://registry.terraform.io/providers/hetznercloud/hcloud
- **Cloudflare**: https://registry.terraform.io/providers/cloudflare/cloudflare
