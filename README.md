# k4yod3

VPS configuration for apps served under `*.k4yod3.com`.

**Model.** Host-installed nginx terminates TLS (Let's Encrypt via certbot) and reverse-proxies each `<sub>.k4yod3.com` to a per-app container bound to a loopback port. Each app's repo owns its own compose overlay that publishes its upstream port; this repo owns the nginx site config and the scripts to install it.

## Layout

```
nginx/sites-available/   one .conf per subdomain
scripts/
  bootstrap-vps.sh       one-time per VPS — install nginx, certbot, docker, ufw rules
  enable-site.sh         per-app — issue cert (first run) + symlink + reload
```

## First-time VPS setup

```sh
sudo mkdir -p /srv && sudo git clone git@github.com:DKayode/k4yod3.git /srv/k4yod3
sudo /srv/k4yod3/scripts/bootstrap-vps.sh
```

Tested on Debian/Ubuntu. Re-running is safe.

## Adding an app

1. Add the site config at `nginx/sites-available/<sub>.k4yod3.com.conf` (model it on `nook.k4yod3.com.conf`).
2. Point DNS `<sub>.k4yod3.com` at the VPS and wait for it to resolve.
3. Start the app stack on the VPS so its loopback upstream is live (see per-app section below).
4. Enable the nginx site:
   ```sh
   sudo /srv/k4yod3/scripts/enable-site.sh <sub> --email you@example.com
   ```
   `--email` is required only on first issuance. Subsequent runs skip certbot and just refresh the symlink + reload.

## Apps

| Subdomain | Upstream | Source repo | Compose overlay |
|---|---|---|---|
| `nook.k4yod3.com` | `127.0.0.1:3001` (Next.js, `web` container) | [DKayode/Nook](https://github.com/DKayode/Nook) | `deploy/docker-compose.host-nginx.yml` |

### nook deploy (host-nginx mode)

Use the `host-nginx` overlay *instead of* `prod.yml` so the bundled Caddy service is skipped and `web` is republished on `127.0.0.1:3001`:

```sh
cd /srv/nook
docker compose -f docker-compose.yml -f deploy/docker-compose.host-nginx.yml pull
docker compose -f docker-compose.yml -f deploy/docker-compose.host-nginx.yml up -d
sudo /srv/k4yod3/scripts/enable-site.sh nook --email you@example.com
```

`.env` must set `NEXTAUTH_URL=https://nook.k4yod3.com` and `AUTH_TRUST_HOST=true` — nginx terminates TLS, so Next sees plain HTTP from the proxy and Auth.js otherwise rejects the cookie.

## Renewal

certbot installs a systemd timer (`certbot.timer`) that runs `renew` twice daily. Verify with `sudo systemctl list-timers | grep certbot`; dry-run with `sudo certbot renew --dry-run`. Renewed certs are picked up by nginx automatically via certbot's deploy hook.
