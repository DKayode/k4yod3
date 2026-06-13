# k4yod3

Small VPS infrastructure repo: bash scripts + nginx site configs for hosting per-app Docker containers behind a TLS-terminating host nginx. No application code; no package manager.

## Stack

- Host nginx terminates TLS via Let's Encrypt / certbot.
- Each app runs in its own Docker container bound to a loopback port; nginx reverse-proxies to it.
- Two helper scripts in `scripts/` glue it together.

## Layout

- `nginx/sites-available/` — per-site nginx config (currently `nook.k4yod3.com.conf`).
- `scripts/bootstrap-vps.sh` — one-time VPS setup.
- `scripts/enable-site.sh` — per-app cert issuance + symlink into `sites-enabled` + nginx reload. Uses the ACME stub trick so cert issuance works before the real config is enabled.

## Workflows

- Validate nginx config: `sudo nginx -t`
- Lint scripts: `shellcheck scripts/*.sh`
- Test cert renewal: `sudo certbot renew --dry-run`
- Deploy on the VPS: `git pull` then re-run `enable-site.sh` for any affected site.

## Conventions

- Upstreams are loopback-only (`127.0.0.1:<port>`). Never expose app containers directly.
- Each site uses the two-server-block pattern (port 80 redirect → port 443 TLS).
- Scripts are idempotent — safe to re-run.
- TLS settings follow the Mozilla intermediate profile.

## Current apps

| Host | Upstream |
| --- | --- |
| nook.k4yod3.com | loopback Docker container (see site conf) |
| stride.k4yod3.com | `127.0.0.1:3002` — static PWA (Vite build) in Docker container |
