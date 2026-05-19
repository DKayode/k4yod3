#!/usr/bin/env bash
# Enable an nginx site backed by Let's Encrypt + this repo's config.
#
# Usage: enable-site.sh <subdomain> [--email <addr>] [--domain <root>]
#   <subdomain>   e.g. "nook" → nook.k4yod3.com
#   --email       required on first issuance for Let's Encrypt
#   --domain      override root domain (default: k4yod3.com)
#
# Idempotent — re-running after the cert exists just refreshes the symlink and reloads.

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  exec sudo -E bash "$0" "$@"
fi

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
ROOT_DOMAIN="k4yod3.com"
EMAIL=""

usage() { echo "usage: $0 <subdomain> [--email <addr>] [--domain <root>]" >&2; exit 64; }

(( $# >= 1 )) || usage
SUBDOMAIN="$1"; shift
while (( $# > 0 )); do
  case "$1" in
    --email)  EMAIL="${2:-}"; shift 2 ;;
    --domain) ROOT_DOMAIN="${2:-}"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "unknown arg: $1" >&2; usage ;;
  esac
done

FQDN="${SUBDOMAIN}.${ROOT_DOMAIN}"
SITE_CONF="${REPO_DIR}/nginx/sites-available/${FQDN}.conf"
ENABLED_LINK="/etc/nginx/sites-enabled/${FQDN}.conf"
CERT_DIR="/etc/letsencrypt/live/${FQDN}"

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }

[[ -f "$SITE_CONF" ]] || { echo "missing config: $SITE_CONF" >&2; exit 1; }

if [[ ! -s "${CERT_DIR}/fullchain.pem" ]]; then
  [[ -n "$EMAIL" ]] || { echo "first-time issuance for ${FQDN} needs --email <addr>" >&2; exit 64; }

  log "Issuing Let's Encrypt cert for ${FQDN}"
  mkdir -p /var/www/certbot

  # Temporary HTTP-only stub so nginx can serve the ACME challenge while the
  # real config (which references not-yet-existing cert files) stays disabled.
  STUB="/etc/nginx/sites-enabled/${FQDN}-acme.conf"
  cat > "$STUB" <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name ${FQDN};
    location /.well-known/acme-challenge/ { root /var/www/certbot; }
    location / { return 404; }
}
EOF
  nginx -t
  systemctl reload nginx

  certbot certonly --webroot -w /var/www/certbot \
    -d "$FQDN" --email "$EMAIL" --agree-tos --non-interactive --no-eff-email

  rm -f "$STUB"
fi

log "Linking ${SITE_CONF} → ${ENABLED_LINK}"
ln -sfn "$SITE_CONF" "$ENABLED_LINK"

log "Validating nginx config"
nginx -t

log "Reloading nginx"
systemctl reload nginx

log "Done. https://${FQDN} is live (assuming upstream is up and DNS resolves)."
