#!/bin/bash
# =============================================================================
# setup_https.sh - SSL Certificate Replacement Automation Script
# Task 2.1: Automate the process of replacing SSL certificates on a web server
#
# Usage:
#   ./setup_https.sh [obtain|renew|replace|status]
#
# Commands:
#   obtain   - First-time SSL certificate setup (install certbot + get cert)
#   renew    - Renew existing certificates
#   replace  - Replace certificate with a new one (revoke old + obtain new)
#   status   - Show current certificate status
#
# Domain: thanappe.infinix-lab.com
# =============================================================================

set -euo pipefail

# ---- Configuration ----
DOMAIN="thanappe.infinix-lab.com"
EMAIL="admin@infinix-lab.com"
WEBROOT_PATH="/var/www/certbot"
CERT_PATH="/etc/letsencrypt/live/${DOMAIN}"
NGINX_CONTAINER="nginx-webserver"
SSL_DIR="$(cd "$(dirname "$0")" && pwd)"
COMPOSE_DIR="$(cd "${SSL_DIR}/.." && pwd)"
NGINX_CONF="${COMPOSE_DIR}/nginx/nginx.conf"
BACKUP_DIR="${SSL_DIR}/ssl_backups"
LOG_FILE="${SSL_DIR}/ssl_setup.log"

# ---- Colors ----
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ---- Helper Functions ----
log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo -e "${GREEN}${msg}${NC}"
    echo "$msg" >> "$LOG_FILE"
}

warn() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $1"
    echo -e "${YELLOW}${msg}${NC}"
    echo "$msg" >> "$LOG_FILE"
}

error() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1"
    echo -e "${RED}${msg}${NC}" >&2
    echo "$msg" >> "$LOG_FILE"
    exit 1
}

info() {
    echo -e "${BLUE}$1${NC}"
}

# ---- Pre-flight Checks ----
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root (use sudo)"
    fi
}

check_docker() {
    if ! command -v docker &> /dev/null; then
        error "Docker is not installed"
    fi
    if ! command -v docker compose &> /dev/null; then
        error "Docker Compose is not installed"
    fi
}

# ---- Step 1: Install Certbot ----
install_certbot() {
    log "Step 1: Installing Certbot..."
    if command -v certbot &> /dev/null; then
        log "Certbot is already installed: $(certbot --version 2>&1)"
        return 0
    fi

    apt-get update -qq
    apt-get install -y -qq certbot python3-certbot-nginx
    log "Certbot installed successfully: $(certbot --version 2>&1)"
}

# ---- Step 2: Prepare directories ----
prepare_directories() {
    log "Step 2: Preparing directories..."
    mkdir -p "$WEBROOT_PATH"
    mkdir -p "$BACKUP_DIR"
    log "Directories ready: ${WEBROOT_PATH}, ${BACKUP_DIR}"
}

# ---- Step 3: Update nginx for ACME challenge (HTTP-only, pre-cert) ----
configure_nginx_http() {
    log "Step 3: Configuring nginx for ACME challenge..."

    cat > "$NGINX_CONF" << 'NGINX_HTTP'
events {
    worker_connections 1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    server {
        listen 80;
        server_name thanappe.infinix-lab.com;

        # ACME challenge for Let's Encrypt
        location /.well-known/acme-challenge/ {
            root /var/www/certbot;
        }

        location / {
            proxy_pass http://django:8000;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }

        location /static/ {
            alias /usr/share/nginx/html/static/;
        }
    }
}
NGINX_HTTP
    log "Nginx HTTP config updated for ACME challenge"
}

# ---- Step 4: Update docker-compose for SSL ----
update_docker_compose() {
    log "Step 4: Updating docker-compose.yml for SSL support..."

    # Backup original
    cp "${COMPOSE_DIR}/docker-compose.yml" "${BACKUP_DIR}/docker-compose.yml.bak.$(date +%s)"

    cat > "${COMPOSE_DIR}/docker-compose.yml" << 'COMPOSE'
services:
  django:
      container_name: django-webserver
      build: .
      command: ["sh", "./run_server.sh"]
      volumes:
        - static_volume:/app/static
      expose:
        - "8000"
      env_file:
        - .env
      restart: always
      depends_on:
        - postgres
      networks:
        - dj

  postgres:
    image: postgres:14
    container_name: postgres-db
    environment:
      POSTGRES_DB: dj-jrd
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: 123456
    restart: always
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - dj

  nginx:
    build: ./nginx
    container_name: nginx-webserver
    ports:
      - "80:80"
      - "443:443"
    restart: always
    volumes:
      - static_volume:/usr/share/nginx/html/static
      - certbot_www:/var/www/certbot:ro
      - certbot_conf:/etc/letsencrypt:ro
    depends_on:
      - django
    networks:
      - dj

  certbot:
    image: certbot/certbot:latest
    container_name: certbot
    volumes:
      - certbot_www:/var/www/certbot:rw
      - certbot_conf:/etc/letsencrypt:rw
    networks:
      - dj

  pgadmin:
    image: dpage/pgadmin4:latest
    container_name: PGadmin
    environment:
      PGADMIN_DEFAULT_EMAIL: admin@junraider.com
      PGADMIN_DEFAULT_PASSWORD: 123456789
    ports:
      - "5050:80"
    depends_on:
      - postgres
    volumes:
      - pgadmin_data:/var/lib/pgadmin
    networks:
      - dj

volumes:
  postgres_data:
  static_volume:
  pgadmin_data:
  certbot_www:
  certbot_conf:
networks:
  dj:
COMPOSE
    log "docker-compose.yml updated with SSL support"
}

# ---- Step 5: Restart nginx with HTTP config and obtain certificate ----
obtain_certificate() {
    log "Step 5: Obtaining SSL certificate for ${DOMAIN}..."

    # Restart services with updated compose + HTTP nginx config
    cd "$COMPOSE_DIR"
    docker compose up -d --build nginx

    # Wait for nginx to be ready
    sleep 5

    # Obtain certificate using certbot via docker
    docker compose run --rm certbot certonly \
        --webroot \
        --webroot-path=/var/www/certbot \
        --email "$EMAIL" \
        --agree-tos \
        --no-eff-email \
        --force-renewal \
        -d "$DOMAIN"

    log "SSL certificate obtained for ${DOMAIN}"
}

# ---- Step 6: Configure nginx for HTTPS ----
configure_nginx_https() {
    log "Step 6: Configuring nginx for HTTPS..."

    cat > "$NGINX_CONF" << 'NGINX_HTTPS'
events {
    worker_connections 1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    # HTTP -> HTTPS redirect
    server {
        listen 80;
        server_name thanappe.infinix-lab.com;

        # ACME challenge (for renewals)
        location /.well-known/acme-challenge/ {
            root /var/www/certbot;
        }

        # Redirect all other HTTP traffic to HTTPS
        location / {
            return 301 https://$host$request_uri;
        }
    }

    # HTTPS server
    server {
        listen 443 ssl;
        server_name thanappe.infinix-lab.com;

        # SSL certificate paths
        ssl_certificate     /etc/letsencrypt/live/thanappe.infinix-lab.com/fullchain.pem;
        ssl_certificate_key /etc/letsencrypt/live/thanappe.infinix-lab.com/privkey.pem;

        # Modern TLS settings
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
        ssl_prefer_server_ciphers off;
        ssl_session_cache shared:SSL:10m;
        ssl_session_timeout 1d;

        # Security headers
        add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
        add_header X-Content-Type-Options nosniff;
        add_header X-Frame-Options DENY;

        location / {
            proxy_pass http://django:8000;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }

        location /static/ {
            alias /usr/share/nginx/html/static/;
        }
    }
}
NGINX_HTTPS
    log "Nginx HTTPS config written"
}

# ---- Step 7: Reload nginx with HTTPS config ----
reload_nginx() {
    log "Step 7: Reloading nginx with HTTPS..."
    cd "$COMPOSE_DIR"
    docker compose up -d --build nginx
    sleep 3
    log "Nginx reloaded with HTTPS configuration"
}

# ---- Step 8: Set up auto-renewal cron ----
setup_auto_renewal() {
    log "Step 8: Setting up automatic certificate renewal..."

    local CRON_CMD="0 3 * * * cd ${COMPOSE_DIR} && docker compose run --rm certbot renew --quiet && docker compose exec nginx nginx -s reload"

    # Remove existing cron entry if any
    crontab -l 2>/dev/null | grep -v "certbot renew" | crontab - 2>/dev/null || true

    # Add new cron entry
    (crontab -l 2>/dev/null; echo "$CRON_CMD") | crontab -

    log "Auto-renewal cron job set (daily at 3:00 AM)"
    info "Cron entry: ${CRON_CMD}"
}

# ---- Command: obtain (first-time setup) ----
cmd_obtain() {
    info "=========================================="
    info "  SSL Certificate Setup"
    info "  Domain: ${DOMAIN}"
    info "=========================================="

    check_root
    check_docker
    install_certbot
    prepare_directories
    update_docker_compose
    configure_nginx_http
    obtain_certificate
    configure_nginx_https
    reload_nginx
    setup_auto_renewal

    echo ""
    log "✅ HTTPS setup complete for ${DOMAIN}"
    info "  - HTTP  → https://${DOMAIN} (auto-redirect)"
    info "  - HTTPS → https://${DOMAIN} (secured)"
    info "  - Auto-renewal: daily at 3:00 AM via cron"
    info ""
    info "Test: curl -I https://${DOMAIN}"
}

# ---- Command: renew ----
cmd_renew() {
    info "=========================================="
    info "  SSL Certificate Renewal"
    info "  Domain: ${DOMAIN}"
    info "=========================================="

    check_root
    check_docker

    log "Renewing certificate for ${DOMAIN}..."
    cd "$COMPOSE_DIR"
    docker compose run --rm certbot renew

    # Reload nginx to pick up new cert
    docker compose exec nginx nginx -s reload
    log "✅ Certificate renewed and nginx reloaded"
}

# ---- Command: replace (revoke old + obtain new) ----
cmd_replace() {
    info "=========================================="
    info "  SSL Certificate Replacement"
    info "  Domain: ${DOMAIN}"
    info "=========================================="

    check_root
    check_docker

    # Backup current certificate
    if [ -d "$CERT_PATH" ]; then
        local backup_name="cert_backup_$(date +%Y%m%d_%H%M%S)"
        log "Backing up current certificate to ${BACKUP_DIR}/${backup_name}/"
        mkdir -p "${BACKUP_DIR}/${backup_name}"
        cp -rL "$CERT_PATH"/* "${BACKUP_DIR}/${backup_name}/" 2>/dev/null || true
        log "Backup complete"

        # Revoke existing certificate
        log "Revoking existing certificate..."
        docker compose run --rm certbot revoke \
            --cert-path "/etc/letsencrypt/live/${DOMAIN}/cert.pem" \
            --non-interactive || warn "Revocation failed or cert already revoked"
    fi

    # Obtain new certificate
    log "Obtaining new certificate..."
    cd "$COMPOSE_DIR"
    docker compose run --rm certbot certonly \
        --webroot \
        --webroot-path=/var/www/certbot \
        --email "$EMAIL" \
        --agree-tos \
        --no-eff-email \
        --force-renewal \
        -d "$DOMAIN"

    # Reload nginx
    docker compose exec nginx nginx -s reload

    log "✅ Certificate replaced successfully"
    info "Old certificate backed up to: ${BACKUP_DIR}/"
}

# ---- Command: status ----
cmd_status() {
    info "=========================================="
    info "  SSL Certificate Status"
    info "  Domain: ${DOMAIN}"
    info "=========================================="

    if [ -f "${CERT_PATH}/cert.pem" ]; then
        echo ""
        info "Certificate details:"
        openssl x509 -in "${CERT_PATH}/cert.pem" -noout \
            -subject -issuer -dates -serial 2>/dev/null || \
            warn "Could not read certificate (try running with sudo)"
        echo ""

        # Check expiry
        local expiry
        expiry=$(openssl x509 -in "${CERT_PATH}/cert.pem" -noout -enddate 2>/dev/null | cut -d= -f2)
        local expiry_epoch
        expiry_epoch=$(date -d "$expiry" +%s 2>/dev/null)
        local now_epoch
        now_epoch=$(date +%s)
        local days_left=$(( (expiry_epoch - now_epoch) / 86400 ))

        if [ "$days_left" -le 30 ]; then
            warn "Certificate expires in ${days_left} days — consider renewing soon!"
        else
            log "Certificate valid for ${days_left} more days"
        fi
    else
        warn "No certificate found at ${CERT_PATH}"
        info "Run: sudo ./setup_https.sh obtain"
    fi

    echo ""
    info "Nginx container status:"
    docker ps --filter "name=${NGINX_CONTAINER}" --format "  {{.Names}}: {{.Status}}"

    echo ""
    info "Auto-renewal cron:"
    crontab -l 2>/dev/null | grep certbot || warn "No auto-renewal cron found"
}

# ---- Main ----
main() {
    case "${1:-}" in
        obtain)
            cmd_obtain
            ;;
        renew)
            cmd_renew
            ;;
        replace)
            cmd_replace
            ;;
        status)
            cmd_status
            ;;
        *)
            echo "Usage: sudo $0 {obtain|renew|replace|status}"
            echo ""
            echo "Commands:"
            echo "  obtain   - First-time setup: install certbot, get cert, configure HTTPS"
            echo "  renew    - Renew existing certificate"
            echo "  replace  - Replace certificate (backup old, revoke, get new)"
            echo "  status   - Show certificate info and expiry"
            exit 1
            ;;
    esac
}

main "$@"
