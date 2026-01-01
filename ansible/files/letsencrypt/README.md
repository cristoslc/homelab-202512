# Let's Encrypt Certificate Backups

This directory contains encrypted backups of Let's Encrypt SSL certificates, allowing for instant certificate restoration when rebuilding infrastructure.

## Why Backup Certificates?

**Problem**: Let's Encrypt has rate limits (5 duplicate certificates per week). When testing infrastructure migrations or rebuilds, you can quickly hit these limits.

**Solution**: Backup certificates after initial acquisition, restore from backup on subsequent deployments. This:
- Avoids Let's Encrypt rate limits
- Eliminates DNS propagation wait times
- Provides instant HTTPS on new VPS instances
- Makes deployments faster and more reliable

## Security

Certificates are encrypted with `ansible-vault` before being committed to git. The vault password is stored in the `ANSIBLE_VAULT_PASSWORD` environment variable (never committed to git).

**Encrypted files are safe to commit** because:
- ansible-vault uses AES256 encryption
- Only those with the vault password can decrypt
- Same pattern used for WireGuard keys

## Backup Process

After your first successful deployment with a valid certificate:

```bash
# Set vault password (add to your shell profile or .env file)
export ANSIBLE_VAULT_PASSWORD='your-secure-password-here'

# Backup certificates
ansible-playbook ansible/playbooks/backup-letsencrypt.yml

# Commit encrypted backup
git add ansible/files/letsencrypt/
git commit -m "Add encrypted Let's Encrypt certificate backup"
git push
```

## Restore Process (Automatic)

The `certbot` role automatically checks for encrypted backups before requesting new certificates:

1. Checks for `ansible/files/letsencrypt/plex.yourdomain.com_backup.tar.gz.vault`
2. If found: Decrypts and restores to `/etc/letsencrypt/` on bastion
3. If not found or restore fails: Requests new certificate from Let's Encrypt

No manual intervention required - just run `./scripts/deploy.sh` as normal.

## Files in This Directory

- `README.md` - This file
- `*.tar.gz.vault` - Encrypted certificate backups (safe to commit)
  - Example: `plex.theblueroost.me_backup.tar.gz.vault`

## Certificate Renewal

Let's Encrypt certificates expire after 90 days. The bastion has automatic renewal configured via `certbot.timer`.

**After renewal, re-backup:**

```bash
ansible-playbook ansible/playbooks/backup-letsencrypt.yml
git add ansible/files/letsencrypt/
git commit -m "Update Let's Encrypt certificate backup (renewed)"
git push
```

This ensures future deployments get the latest valid certificate.

## Troubleshooting

**Restore fails:**
- Check `ANSIBLE_VAULT_PASSWORD` is set correctly
- Verify `.vault-pass.sh` is executable: `chmod +x ansible/.vault-pass.sh`
- Try manual decrypt: `ansible-vault view ansible/files/letsencrypt/*.vault`

**Rate limit hit:**
- Wait 7 days for limit reset
- OR use Let's Encrypt staging environment for testing
- Backup certificates immediately after successful acquisition

**Certificates expired:**
- Cannot restore expired certificates
- Must request new certificate from Let's Encrypt
- Backup the new certificate after acquisition
