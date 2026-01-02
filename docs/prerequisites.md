# Prerequisites

Before deploying the homelab infrastructure, you'll need to install required tools and set up necessary accounts.

## Required Tools

### Terraform >= 1.6

Terraform is used for infrastructure provisioning (VPS, DNS, firewalls).

#### Install on Ubuntu/Debian

```bash
# Add HashiCorp GPG key
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg

# Add HashiCorp repository
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list

# Update and install
sudo apt update
sudo apt install terraform

# Verify installation
terraform version
```

Expected output: `Terraform v1.6.x` or higher

#### Install Latest Version (Alternative)

```bash
# Download latest version (check https://www.terraform.io/downloads)
TERRAFORM_VERSION="1.7.0"
wget https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip

# Unzip and install
unzip terraform_${TERRAFORM_VERSION}_linux_amd64.zip
sudo mv terraform /usr/local/bin/

# Verify
terraform version

# Cleanup
rm terraform_${TERRAFORM_VERSION}_linux_amd64.zip
```

#### Install on macOS

```bash
# Using Homebrew
brew install terraform

# Verify
terraform version
```

### Ansible >= 2.15

Ansible is used for configuration management (services, security, networking).

#### Install on Ubuntu/Debian

```bash
# Install Ansible via apt
sudo apt update
sudo apt install ansible

# Verify installation
ansible --version
```

Expected output: `ansible [core 2.15.x]` or higher

#### Install Latest via pip

```bash
# Install pip if needed
sudo apt install python3-pip

# Install Ansible via pip (gets latest version)
pip3 install --user ansible

# Add to PATH (add to ~/.bashrc for persistence)
export PATH="$HOME/.local/bin:$PATH"

# Verify
ansible --version
```

#### Install on macOS

```bash
# Using Homebrew
brew install ansible

# Verify
ansible --version
```

### Git

Required for repository management and Beads issue tracking.

```bash
# Ubuntu/Debian
sudo apt install git

# macOS (usually pre-installed)
git --version
```

### SSH Client

Required for connecting to the bastion VPS.

```bash
# Ubuntu/Debian (usually pre-installed)
ssh -V

# Generate SSH key if you don't have one
ssh-keygen -t ed25519 -C "homelab-bastion"
```

## Required Accounts

### Hetzner Cloud

**Purpose:** VPS hosting for the bastion server

**Cost:** ~€4.51/month for CX11 instance (€0.007/hour)

**Setup Steps:**
1. Sign up at [https://console.hetzner.cloud/](https://console.hetzner.cloud/)
2. Create a new project (e.g., "Homelab")
3. Navigate to: Your Project → Security → API Tokens
4. Create new token with "Read & Write" permissions
5. Copy token to `.env` file as `TF_VAR_hcloud_token`

### Cloudflare

**Purpose:** DNS management (free tier is sufficient)

**Cost:** Free

**Setup Steps:**
1. Sign up at [https://www.cloudflare.com/](https://www.cloudflare.com/)
2. Add your domain to Cloudflare
3. Update your domain registrar's nameservers to Cloudflare's
4. Wait for DNS propagation (~24 hours max, often much faster)

**Get API Token:**
1. Go to [https://dash.cloudflare.com/profile/api-tokens](https://dash.cloudflare.com/profile/api-tokens)
2. Click "Create Token"
3. Use template: "Edit zone DNS" or create custom with these permissions:
   - Zone → DNS → Edit
   - Zone → Zone → Read
4. Select your specific zone
5. Copy token to `.env` file as `TF_VAR_cloudflare_api_token`

**Get Zone ID:**
1. Go to Cloudflare Dashboard
2. Select your domain
3. Scroll down in Overview tab
4. Copy "Zone ID" from the right sidebar
5. Add to `.env` file as `TF_VAR_cloudflare_zone_id`

### Domain Name

**Purpose:** Public domain for accessing services

**Requirements:**
- Must be registered with any registrar
- Must be configured in Cloudflare (nameservers updated)
- Can be a subdomain if you prefer (e.g., `home.example.com`)

**Recommendations:**
- Namecheap, Porkbun, or Cloudflare Registrar for affordability
- Keep domain registration separate from DNS (easier to migrate)

## Existing Infrastructure

### Docker Host

**Requirements:**
- Docker installed and running
- Accessible from your local network
- Static IP on local network (or DHCP reservation)
- SSH access configured

### Media Services (Optional for Day 1)

**Plex:**
- Container running and accessible on port 32400
- Example: `docker run -p 32400:32400 plexinc/pms-docker`

**Jellyfin:**
- Container running and accessible on port 8096
- Example: `docker run -p 8096:8096 jellyfin/jellyfin`

**Note:** Services can be deployed later; Day 1 will still configure the tunnel and proxy.

## Verify Installation

### Test Terraform

```bash
# Should show version >= 1.6
terraform version

# Initialize in project directory
cd ~/git/homelab-202512/terraform
terraform init
```

Expected: Downloads Hetzner and Cloudflare providers successfully

### Test Ansible

```bash
# Should show version >= 2.15
ansible --version

# Test Python dependencies
ansible localhost -m ping
```

Expected: `localhost | SUCCESS | ...`

### Test SSH Key

```bash
# Check if key exists
ls -la ~/.ssh/id_ed25519*

# If not, generate one
ssh-keygen -t ed25519 -C "homelab-bastion"

# Display public key (copy this to .env)
cat ~/.ssh/id_ed25519.pub
```

## Troubleshooting

### "terraform: command not found"

**Solution 1:** Check PATH
```bash
echo $PATH | grep -o "/usr/local/bin"
which terraform
```

**Solution 2:** Reinstall or use absolute path
```bash
/usr/local/bin/terraform version
```

### "ansible: command not found" (pip install)

**Solution:** Add to PATH permanently
```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
ansible --version
```

### Terraform provider download fails

**Possible causes:**
- No internet connection
- Firewall blocking registry.terraform.io
- Proxy configuration needed

**Solution:**
```bash
terraform init -upgrade
```

### Ansible SSH connection fails

**Check SSH config:**
```bash
ssh -v root@<bastion-ip>
```

Look for:
- "Permission denied" → Wrong SSH key
- "Connection refused" → Server not ready or firewall
- "Connection timed out" → Network issue or wrong IP

## Next Steps

Once all prerequisites are met, proceed to:
- [Getting Started Guide](./getting-started.md)
- [Day 1 PRD](./PRD-day1.md)

## Version Requirements Summary

| Tool | Minimum Version | Recommended |
|------|----------------|-------------|
| Terraform | 1.6.0 | Latest 1.x |
| Ansible | 2.15.0 | Latest 2.x |
| Git | 2.x | Latest |
| Python | 3.8+ | 3.10+ |
| SSH | OpenSSH 7.x+ | Latest |
