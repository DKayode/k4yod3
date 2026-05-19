#!/usr/bin/env bash
# One-time VPS bootstrap: nginx + certbot + Docker + firewall.
# Idempotent — safe to re-run. Tested on Debian/Ubuntu.

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  exec sudo -E bash "$0" "$@"
fi

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }

log "Updating apt index"
apt-get update -qq

install_if_missing() {
  local pkgs=()
  for pkg in "$@"; do
    dpkg -s "$pkg" >/dev/null 2>&1 || pkgs+=("$pkg")
  done
  if (( ${#pkgs[@]} > 0 )); then
    log "Installing: ${pkgs[*]}"
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "${pkgs[@]}"
  fi
}

install_if_missing nginx certbot python3-certbot-nginx ca-certificates curl gnupg

if ! command -v docker >/dev/null 2>&1; then
  log "Installing Docker CE"
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/debian/gpg \
    | gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg
  . /etc/os-release
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/${ID} ${VERSION_CODENAME} stable" \
    > /etc/apt/sources.list.d/docker.list
  apt-get update -qq
  install_if_missing docker-ce docker-ce-cli containerd.io \
                     docker-buildx-plugin docker-compose-plugin
fi

log "Ensuring webroot for ACME challenges"
mkdir -p /var/www/certbot
chown -R www-data:www-data /var/www/certbot

if command -v ufw >/dev/null 2>&1 && ufw status 2>/dev/null | grep -q "Status: active"; then
  log "Allowing Nginx Full through ufw"
  ufw allow 'Nginx Full' >/dev/null
fi

log "Enabling nginx"
systemctl enable --now nginx >/dev/null

if [[ -e /etc/nginx/sites-enabled/default ]]; then
  log "Removing default nginx site"
  rm -f /etc/nginx/sites-enabled/default
  nginx -t && systemctl reload nginx
fi

log "Bootstrap complete"
cat <<'EOF'

Next steps:
  1. Point DNS for the subdomain at this VPS (A/AAAA).
  2. Start the app stack so its upstream loopback port is live.
  3. Enable the site:
       sudo /srv/k4yod3/scripts/enable-site.sh <subdomain> --email you@example.com
EOF
