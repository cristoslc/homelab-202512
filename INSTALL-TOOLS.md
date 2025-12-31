# Install Terraform and Ansible

## Quick Install (Ubuntu/Debian)

### Install Terraform

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

### Install Ansible

```bash
# Install Ansible via apt
sudo apt update
sudo apt install ansible

# Verify installation
ansible --version
```

Expected output: `ansible [core 2.15.x]` or higher

## Alternative: Install Latest Versions

### Terraform (Latest)

```bash
# Download latest version (check https://www.terraform.io/downloads for current version)
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

### Ansible (Latest via pip)

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

## Post-Installation Test

### Test Terraform

```bash
cd ~/git/homelab-202512/terraform
terraform init
```

Expected: Downloads Hetzner and Cloudflare providers successfully

### Test Ansible

```bash
ansible --version
```

Expected: Shows Ansible version and Python interpreter

## Troubleshooting

### "terraform: command not found"
- Check if `/usr/local/bin` is in your PATH
- Try: `which terraform`
- Reinstall or use absolute path: `/usr/local/bin/terraform`

### "ansible: command not found" (pip install)
- Add to PATH: `export PATH="$HOME/.local/bin:$PATH"`
- Add to ~/.bashrc for permanent: `echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc`
- Reload shell: `source ~/.bashrc`

### Terraform provider download fails
- Check internet connection
- Try: `terraform init -upgrade`
- Check firewall allows HTTPS to registry.terraform.io

## Required Versions

- **Terraform**: >= 1.6 (specified in terraform/main.tf)
- **Ansible**: >= 2.15 (recommended for Tasks 2-5)

## Next Steps

Once both are installed:
1. Configure `terraform/terraform.tfvars` with your API keys
2. Run `terraform init` to download providers
3. Proceed with Task 1 deployment
