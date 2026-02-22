# Claudebox Setup

Reference documentation for rebuilding or reconfiguring Claudebox
(GMKTec K11, Debian 13 trixie, 192.168.1.11).

---

## Claude Desktop

Claude Desktop on Linux is installed via the unofficial
[aaddrick/claude-desktop-debian](https://github.com/aaddrick/claude-desktop-debian)
project, which provides a proper apt repository with GPG signing. Updates arrive
automatically via `apt upgrade`.

```bash
# Add GPG key
curl -fsSL https://aaddrick.github.io/claude-desktop-debian/KEY.gpg \
  | sudo gpg --dearmor -o /usr/share/keyrings/claude-desktop.gpg

# Add repository
echo "deb [signed-by=/usr/share/keyrings/claude-desktop.gpg arch=amd64,arm64] \
  https://aaddrick.github.io/claude-desktop-debian stable main" \
  | sudo tee /etc/apt/sources.list.d/claude-desktop.list

# Install
sudo apt update && sudo apt install claude-desktop
```

Config file: `~/.config/Claude/claude_desktop_config.json`

A sanitized template (no secrets) lives in
`configs/claude-desktop/claude_desktop_config.json` in this repo.
The live config with tokens is backed up to NFS only — see
[backups.md](backups.md).

---

## MCP Servers

MCP servers are configured in `~/.config/Claude/claude_desktop_config.json`.
See [backups.md](backups.md) for how this file is backed up.

Locally configured servers (running on Claudebox):

| Server | Notes |
|--------|-------|
| Memory MCP | `@modelcontextprotocol/server-memory`, stores to `~/.config/Claude/memory/memory.db` |
| Netdata (Claudebox) | `ws://localhost:19999/mcp` via `/usr/sbin/nd-mcp` |
| Netdata (Unraid) | `ws://192.168.1.6:19999/mcp` via `/usr/sbin/nd-mcp` |
| Basic Memory | `uvx basic-memory mcp`, project `claude`, stores to `~/.config/Claude/basic-memory/claude/` |

Additional servers are injected via the Claude.ai system prompt (Desktop Commander,
Grafana, GitHub personal/work, Playwright, Microsoft Learn) — these do not require
local configuration.

---

## Remote Access

### RDP

Primary access method on the home network. Connect directly to `192.168.1.11:3389`
from any RDP client. No additional setup required beyond the standard Debian desktop
environment.

### Guacamole

Browser-based remote access for use outside the home network, hosted on Atlas.

**Stack:** Guacamole + guacd + Postgres 15, running via Docker Compose on Atlas.
Authentication via Authentik OIDC (SSO with the rest of the homelab).

The compose file is in `homelab-compose` repo under Atlas stacks. Key details:

- Guacamole web app on port `8189`, proxied via SWAG
- Authentik OIDC for authentication
- Postgres data at `/mnt/datastor/appdata/guacamole/postgres`
- Init SQL in `/mnt/datastor/appdata/guacamole/init` (required on first run to
  create the database schema — generate with the guacamole container's
  `--init-db-sql` flag)
- Connected to the `proxy` external Docker network for SWAG integration

RDP connection to Claudebox is configured within Guacamole's admin UI
(not in the compose file).

---

## Netdata

Netdata is installed directly on Claudebox for local system monitoring and MCP
access. Install via the official script:

```bash
wget -O /tmp/netdata-kickstart.sh https://get.netdata.cloud/kickstart.sh
sh /tmp/netdata-kickstart.sh
```

The MCP endpoint (`/usr/sbin/nd-mcp`) is available after install and is referenced
in the Claude Desktop config for both local (Claudebox) and remote (Unraid) monitoring.

---

## Backups

See [backups.md](backups.md) for full backup configuration including Backrest/Restic,
NFS mount, and the Claude Desktop data backup script.

---

## Cron Jobs

| Schedule | Job |
|----------|-----|
| Daily 3:00 AM | `~/scripts/backup-claude.sh` — Claude Desktop data backup |

Backrest handles its own scheduling internally (configured via WebUI at
`http://192.168.1.11:9898`).
