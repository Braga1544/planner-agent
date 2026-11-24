# Deployment (home server + Cloudflare)

Goal: nothing from the internet reaches the server, the home network or the containers directly. Only Cloudflare is public, and it only lets you through: the browser after an email-code login, the iOS app with a service token.

```
Internet ──► Cloudflare (WAF, DDoS, rate limit, Access login)
                │  outbound connection from the server only (cloudflared), no port open on the router
                ▼
        cloudflared ──► app (FastAPI :8000, serves web app + API) ──► db (Postgres, internal only)
LAN client ──LAN──► app (port bound to the server's LAN IP only)
```

## 1. Cloudflare Tunnel

1. Create a tunnel under **Zero Trust → Networks → Tunnels** and put its token into `.env` (`CLOUDFLARE_TUNNEL_TOKEN`). `cloudflared` runs as a service in `docker-compose.prod.yml`.
2. Point the public hostname (e.g. `planner.yourdomain.com`) at `http://api:8000`. Web app, `/api/` and `/calendar/` all come from that one container.
3. Don't open any port on the router.

## 2. Cloudflare Access

Create a **self-hosted application** for the hostname with these policies, in this order:

| # | Policy | Action | Rule |
|---|---|---|---|
| 1 | ICS feed | **Bypass** | Separate application for path `/calendar/*`, policy "Everyone". The feed is protected by the secret token in the URL. Skip this if you don't subscribe to the feed. |
| 2 | iOS app | **Service Auth** | Service token created under **Access → Service Auth → Service Tokens**. Client ID and secret go into the app. |
| 3 | Browser | **Allow** | Include: your email, login via one-time PIN. |

Service tokens expire, renew them in time.

## 3. Abuse protection (Security → WAF)

- Rate limit rule on `/api/*`, e.g. 120 requests per minute per IP, block for 10 minutes. The free plan includes one rule.
- Turn on Bot Fight Mode.
- Optional: geo rule blocking other countries.

## 4. Server hardening

- [ ] **Firewall** (`ufw`): deny incoming, allow SSH and the app port from the LAN only.
  ```bash
  sudo ufw default deny incoming
  sudo ufw default allow outgoing
  sudo ufw allow from 192.168.1.0/24 to any port 22 proto tcp
  sudo ufw allow from 192.168.1.0/24 to any port 8080 proto tcp
  sudo ufw enable
  ```
  Docker bypasses `ufw` for published ports, so the next point always applies.
- [ ] **Bind ports to the LAN IP**, never `0.0.0.0`: set `LAN_IP=192.168.1.10` and `APP_PORT=8080` in `.env`. Without `LAN_IP` compose binds to `127.0.0.1`. Postgres publishes no port at all.
- [ ] **SSH**: keys only, no root login, LAN only.
- [ ] **Never mount the Docker socket** into a container and don't expose the Docker API over TCP.
- [ ] **Non-root containers**: the app runs as UID/GID 10001 with `read_only`, `cap_drop: [ALL]` and `no-new-privileges` (see `docker-compose.prod.yml`).
- [ ] **Secrets** (`ANTHROPIC_API_KEY`, `ICS_FEED_TOKEN`, DB password, tunnel token) only in the server's `.env` (`chmod 600`).
- [ ] **Updates**: `unattended-upgrades`, and rebuild regularly with `git pull && docker compose -f docker-compose.prod.yml up -d --build`.
- [ ] **Backups**: the `backup` service dumps daily to `BACKUP_DIR` and keeps `BACKUP_KEEP_DAYS`. Copy that folder off the server too. Restore:
  ```bash
  docker compose -f docker-compose.prod.yml exec -T db pg_restore -U planner -d planner --clean < backups/planner-YYYY-MM-DD_HHMM.dump
  ```
- [ ] **Device tokens**: one per device (`create-token "iPhone"`), revoke a lost one with `revoke-token <id>`.
- [ ] If your router supports it, put the server in its own VLAN.

## 5. Check

- From outside (mobile data): the hostname shows the Cloudflare login, and `curl https://planner.yourdomain.com/api/v1/me` without a service token gets a 403 or a redirect. The backend never sees it.
- Port scan of your public IP: nothing open.
- On the LAN: `http://<server-lan-ip>:8080` works, Postgres on `:5432` does not.
