# Django Web — HTTPS / SSL Setup Guide

Enable HTTPS for `thanappe.infinix-lab.com` using **Let's Encrypt** with two automation approaches.

---

## Prerequisites

- Ubuntu server with Docker & Docker Compose installed
- Domain `thanappe.infinix-lab.com` DNS pointing to your server's public IP
- Ports **80** and **443** open in your firewall
- The Django web app running via `docker compose up -d`

---

## Project Structure

```
devops-django-practice/
├── docker-compose.yml
├── nginx/
│   └── nginx.conf
└── ssl/                                # SSL automation directory
    ├── README.md                       # This file
    ├── setup_https.sh                  # Task 2.1 — Bash automation script
    └── ansible/                        # Task 2.2 — Ansible automation
        ├── inventory.ini
        ├── ssl_playbook.yml
        └── roles/ssl/
            ├── tasks/main.yml
            ├── handlers/main.yml
            └── templates/
                ├── nginx_https.conf.j2
                ├── nginx_http.conf.j2
                └── docker-compose.yml.j2
```

---

## Task 2.1 — Bash Script (`setup_https.sh`)

### First-Time Setup

```bash
cd ~/Desktops/devops-django-practice/ssl

# Make executable (one time)
chmod +x setup_https.sh

# Run full HTTPS setup
sudo ./setup_https.sh obtain
```

This single command will:
1. Install **Certbot** on the host
2. Create required directories (`/var/www/certbot`, `ssl_backups/`)
3. Update `docker-compose.yml` — add port 443, certbot service, shared volumes
4. Configure nginx for the ACME challenge (HTTP)
5. Obtain an SSL certificate from Let's Encrypt
6. Switch nginx to HTTPS with HTTP→HTTPS redirect
7. Set up **auto-renewal** via cron (daily at 3:00 AM)

### Other Commands

```bash
cd ~/Desktops/devops-django-practice/ssl

# Renew existing certificate
sudo ./setup_https.sh renew

# Replace certificate (backup old → revoke → obtain new)
sudo ./setup_https.sh replace

# Check certificate status and expiry date
sudo ./setup_https.sh status
```

---

## Task 2.2 — Ansible Playbook

### Setup

1. Install Ansible on your control machine:
   ```bash
   sudo apt install ansible -y
   ```

2. Edit the inventory if needed:
   ```ini
   # ssl/ansible/inventory.ini
   [webservers]
   thanappe.infinix-lab.com ansible_user=thanaphat_peth ansible_become=yes
   ```

3. Ensure SSH key-based access to the target server.

### Usage

```bash
cd ~/Desktops/devops-django-practice/ssl

# First-time HTTPS setup
ansible-playbook -i ansible/inventory.ini ansible/ssl_playbook.yml --tags obtain

# Replace certificate (backup + revoke + re-obtain)
ansible-playbook -i ansible/inventory.ini ansible/ssl_playbook.yml --tags replace

# Renew certificate
ansible-playbook -i ansible/inventory.ini ansible/ssl_playbook.yml --tags renew

# Only update nginx config
ansible-playbook -i ansible/inventory.ini ansible/ssl_playbook.yml --tags configure

# Only set up auto-renewal cron
ansible-playbook -i ansible/inventory.ini ansible/ssl_playbook.yml --tags cron
```

---

## How It Works

### Architecture

```
Client (Browser)
    │
    ▼
┌──────────────────────┐
│  Nginx (port 80/443) │
│  - HTTP → HTTPS      │
│  - SSL termination   │
│  - Serves /static/   │
│  - ACME challenge    │
└──────────┬───────────┘
           │ proxy_pass :8000
           ▼
┌──────────────────────┐
│  Django (Gunicorn)   │
│  - App logic         │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│  PostgreSQL          │
└──────────────────────┘
```

### SSL Certificate Flow

1. **Obtain**: Certbot requests a certificate from Let's Encrypt using the `webroot` plugin. Nginx serves the ACME challenge file on `/.well-known/acme-challenge/`.
2. **Configure**: Nginx is reconfigured with the certificate paths and modern TLS settings (TLSv1.2/1.3). HTTP traffic is redirected to HTTPS.
3. **Renew**: A cron job runs `certbot renew` daily. If the cert is within 30 days of expiry, it auto-renews and reloads nginx.
4. **Replace**: The old certificate is backed up and revoked, then a fresh certificate is obtained.

### Certificate Locations

| Item | Path |
|------|------|
| Certificate | `/etc/letsencrypt/live/thanappe.infinix-lab.com/fullchain.pem` |
| Private Key | `/etc/letsencrypt/live/thanappe.infinix-lab.com/privkey.pem` |
| Backups | `ssl/ssl_backups/` |
| Logs | `ssl/ssl_setup.log` |

---

## Verification

After running the setup, verify HTTPS is working:

```bash
# Check HTTPS response
curl -I https://thanappe.infinix-lab.com

# Check HTTP redirects to HTTPS
curl -I http://thanappe.infinix-lab.com

# Check certificate details
openssl s_client -connect thanappe.infinix-lab.com:443 -brief

# Check certificate expiry
cd ~/Desktops/devops-django-practice/ssl
sudo ./setup_https.sh status
```

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Certbot fails with "connection refused" | Ensure port 80 is open and nginx is running |
| Certbot fails with "DNS problem" | Verify DNS `A` record points to your server IP |
| Nginx won't start after HTTPS config | Certificate may not exist yet — run `obtain` first |
| Auto-renewal not working | Check cron: `sudo crontab -l` |
| Static files not loading | Run `docker compose exec django poetry run python manage.py collectstatic --noinput` |
