# Task 1 - Ready for Deployment Tomorrow

## What's Been Completed

✅ **Terraform Infrastructure Code** - Complete and tested structure
- Root module with Hetzner and Cloudflare provider configurations
- Hetzner module: VPS provisioning, firewall rules, SSH key management
- Cloudflare module: DNS A record automation
- All outputs configured for Ansible inventory generation

✅ **Task Master Setup**
- PRD parsed into 5 actionable tasks
- Task 1 marked as "in-progress"
- Configured with Anthropic (main), OpenRouter/Perplexity (research), OpenAI (fallback)

✅ **Documentation**
- terraform/README.md: Complete quick-start guide
- terraform.tfvars.example: Template with detailed comments
- Troubleshooting section for common issues

✅ **Validation Scripts**
- scripts/validate-task1.sh: Automated testing suite
- Tests: Terraform state, outputs, DNS resolution, SSH connectivity

✅ **Git Repository**
- All code committed and pushed to GitHub
- .env file gitignored (contains API keys)
- Clean repository structure

## Tomorrow's Deployment Steps

### Step 1: Configure Secrets (5 minutes)

```bash
cd ~/git/homelab-202512/terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your actual values:

**Required Information:**
1. **Hetzner API Token**
   - Get from: https://console.hetzner.cloud/
   - Navigate to: Your Project → Security → API Tokens
   - Create new token with "Read & Write" permissions

2. **Cloudflare API Token**
   - Get from: https://dash.cloudflare.com/profile/api-tokens
   - Create token with "Zone.DNS (Edit)" permission

3. **Cloudflare Zone ID**
   - Find in: Cloudflare Dashboard → Select your domain → Overview (right sidebar)

4. **Domain Name**
   - Your domain managed in Cloudflare (e.g., `example.com`)

5. **SSH Public Key**
   - If you have one: `cat ~/.ssh/id_ed25519.pub`
   - If not, generate: `ssh-keygen -t ed25519 -C "bastion-plex"`

**Example terraform.tfvars:**
```hcl
hcloud_token         = "abc123..."
cloudflare_api_token = "xyz789..."
cloudflare_zone_id   = "def456..."
domain               = "yourdomain.com"
plex_subdomain       = "plex"
ssh_public_key       = "ssh-ed25519 AAAAC3... your-email@example.com"
```

### Step 2: Initialize Terraform (1 minute)

```bash
cd ~/git/homelab-202512/terraform
terraform init
```

This downloads the Hetzner and Cloudflare provider plugins.

### Step 3: Preview Infrastructure (1 minute)

```bash
terraform plan
```

**Expected output:**
- 1 hcloud_server (bastion VPS)
- 1 hcloud_firewall (3 rules: SSH 22/tcp, WireGuard 51820/udp, Plex 32400/tcp)
- 1 hcloud_ssh_key
- 1 cloudflare_record (DNS A record)
- **Total: 4 resources to create**

### Step 4: Deploy Infrastructure (2-3 minutes)

```bash
terraform apply
```

Type `yes` when prompted.

**What happens:**
- Hetzner provisions CX11 VPS (~€4/month) with Ubuntu 24.04 LTS
- Firewall rules configured automatically
- SSH key injected for root access
- Cloudflare creates plex.yourdomain.com → bastion IP
- Server boots in ~30 seconds

### Step 5: Validate Deployment (2 minutes)

```bash
cd ~/git/homelab-202512
./scripts/validate-task1.sh
```

**What it tests:**
1. ✅ Terraform state file exists
2. ✅ Terraform outputs are valid
3. ✅ Bastion IP is valid IPv4 format
4. ✅ DNS resolves correctly (plex.yourdomain.com → bastion IP)
5. ✅ SSH connectivity to bastion
6. ✅ All expected resources created

**Expected result:** All tests PASS (DNS may take 1-5 min to propagate)

### Step 6: Manual Verification (Optional)

```bash
# Get bastion IP
terraform output bastion_ip

# Test SSH access
ssh root@$(terraform output -raw bastion_ip)

# Test DNS resolution
dig $(terraform output -raw plex_fqdn)
```

### Step 7: Mark Task 1 Complete

Once validation passes, update Task Master:

```bash
# Via Claude Code - just ask:
# "Mark Task 1 as done in Task Master"
```

## Troubleshooting

### "Error: Invalid credentials"
- **Hetzner**: Check API token has Read & Write permissions
- **Cloudflare**: Check API token has Zone.DNS (Edit) permission

### "Error: SSH connection refused"
- Wait 1-2 minutes for server to boot
- Verify your SSH key is correct in terraform.tfvars
- Try: `ssh -v root@<bastion-ip>` for verbose output

### "DNS not resolving"
- Wait 2-5 minutes for DNS propagation
- Check Cloudflare Zone ID is correct
- Verify domain name matches your Cloudflare zone

### "Resource already exists"
If you've run Terraform before, clean up first:
```bash
terraform destroy  # Type 'yes' to confirm
terraform apply    # Start fresh
```

## Cost Breakdown

| Resource | Cost |
|----------|------|
| Hetzner CX11 VPS | ~€4.51/month (€0.007/hour) |
| Cloudflare DNS | Free |
| **Total** | **~€4.51/month** |

**Note:** Hetzner bills by the hour. Running for 1 day = ~€0.11

## What Happens After Task 1

Once Task 1 validation passes, you'll have:
- ✅ Live Hetzner VPS with public IP
- ✅ Firewall configured (SSH, WireGuard, Plex ports)
- ✅ DNS pointing plex.yourdomain.com to bastion
- ✅ SSH access to bastion server
- ✅ Terraform outputs ready for Ansible

**Next: Task 2 - Ansible Repository Structure**
- Generate WireGuard keypairs
- Create Ansible roles structure
- Build inventory automation from Terraform outputs

## Quick Reference Commands

```bash
# Change to Terraform directory
cd ~/git/homelab-202512/terraform

# Initialize Terraform
terraform init

# Preview changes
terraform plan

# Deploy infrastructure
terraform apply

# Validate deployment
cd ~/git/homelab-202512
./scripts/validate-task1.sh

# View outputs
terraform output

# Get bastion IP
terraform output -raw bastion_ip

# SSH to bastion
ssh root@$(terraform output -raw bastion_ip)

# Destroy everything (cleanup)
terraform destroy
```

## File Structure Created

```
homelab-202512/
├── .taskmaster/
│   ├── config.json              # Task Master AI configuration
│   ├── docs/prd.txt             # Day 1 Product Requirements Doc
│   └── tasks/tasks.json         # 5 tasks for Day 1
├── terraform/
│   ├── main.tf                  # Root module
│   ├── variables.tf             # Input variables
│   ├── outputs.tf               # Bastion IP, DNS, etc.
│   ├── terraform.tfvars.example # Template (COPY THIS)
│   ├── terraform.tfvars         # Your secrets (CREATE TOMORROW)
│   ├── README.md                # Detailed guide
│   ├── hetzner/
│   │   ├── main.tf              # VPS, firewall, SSH key
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── cloudflare/
│       ├── main.tf              # DNS A record
│       ├── variables.tf
│       └── outputs.tf
├── scripts/
│   └── validate-task1.sh        # Automated validation
├── README.md                    # Day 1 overview
└── .env                         # Task Master API keys (gitignored)
```

## Task Master Status

- **Task 1**: In Progress → Complete after validation
- **Task 2**: Pending (Ansible structure)
- **Task 3**: Pending (Bastion playbook)
- **Task 4**: Pending (Home server playbook)
- **Task 5**: Pending (Deployment & validation)

## Support Links

- **Terraform Hetzner Provider**: https://registry.terraform.io/providers/hetznercloud/hcloud
- **Terraform Cloudflare Provider**: https://registry.terraform.io/providers/cloudflare/cloudflare
- **Hetzner Console**: https://console.hetzner.cloud/
- **Cloudflare Dashboard**: https://dash.cloudflare.com/

---

## Ready to Deploy? ✅

Everything is set up and ready for tomorrow. Just:
1. Copy `terraform.tfvars.example` → `terraform.tfvars`
2. Fill in your API keys
3. Run `terraform init && terraform apply`
4. Run `./scripts/validate-task1.sh`

**Estimated time: 10-15 minutes**

Good luck! 🚀
