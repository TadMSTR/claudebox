# Claudebox Backup Configuration

Two-tier backup system targeting the NFS share at `/mnt/atlas/claudebox`
(`10.10.1.9:/mnt/storage/claudebox`, 39TB via 2.5Gbit).

---

## NFS Mount

```
10.10.1.9:/mnt/storage/claudebox  /mnt/atlas/claudebox  nfs  rw,nfsvers=3,rsize=1048576,wsize=1048576,timeo=14,_netdev  0  0
```

`_netdev` ensures the mount waits for network availability at boot. The systemd
mount unit (`mnt-atlas-claudebox.mount`) is auto-generated from fstab and used
as a dependency for the Backrest service.

---

## Backrest / Restic — System Backups

**Backrest** is a WebUI orchestrator for restic, handling scheduling, retention,
and monitoring via a single interface.

| Setting | Value |
|---------|-------|
| Version | 1.12.0 |
| Binary | `/usr/local/bin/backrest` |
| Service | `/etc/systemd/system/backrest.service` |
| Runs as | root |
| WebUI | http://192.168.1.11:9898 |
| Restic repo | `/mnt/atlas/claudebox/restic-repo` |

### Systemd Service

The service is configured with:

```ini
After=network-online.target mnt-atlas-claudebox.mount
Wants=network-online.target
Requires=mnt-atlas-claudebox.mount
```

This ensures Backrest will not start until the NFS share is mounted.

### Backup Plans

All plans run daily at **2:00 AM** with a 90-day retention policy.

| Plan | Source Path | Excludes |
|------|-------------|----------|
| `claudebox-home` | `/home/ted` | `.cache`, `.local/share/Trash`, `.gvfs`, `thinclient_drives` |
| `claudebox-etc` | `/etc` | — |
| `claudebox-opt` | `/opt/Obsidian` | — |

`.gvfs` and `thinclient_drives` are excluded from the home plan because they are
GNOME/RDP virtual mounts that root cannot read.

Backrest downloads and manages the restic binary automatically.

---

## Claude Desktop Backup Script

A custom script handles Claude Desktop data separately, since Backrest runs as
root and Claude's config lives in `~/.config/Claude/`.

| Setting | Value |
|---------|-------|
| Script | `~/scripts/backup-claude.sh` |
| Schedule | Daily at **3:00 AM** (cron) |
| Destination | `/mnt/atlas/claudebox/claude-backup/` |
| Notifications | ntfy → `https://ntfy.glitch42.com/claudebox` |
| Retention | 90 days |

### What Gets Backed Up

- `~/.config/Claude/memory/memory.db` — Memory MCP knowledge graph (JSONL format despite the `.db` extension — plain `cp` is safe)
- `~/.config/Claude/basic-memory/claude/` — Basic Memory markdown knowledge base
- `~/.config/Claude/claude_desktop_config.json` — MCP server config (contains live API tokens, NFS-only)
- `~/.config/Claude/Claude Extensions Settings/` — Extension settings (contains Grafana service account token, NFS-only)

### Directory Structure on NFS

```
/mnt/atlas/claudebox/claude-backup/
├── latest/             # always current, updated via rsync
└── snapshots/
    └── YYYY-MM-DD/     # dated snapshots, kept for 90 days
```

### Notes on Secrets

`claude_desktop_config.json` and the Extensions Settings directory contain live
tokens and are **not committed to git**. A sanitized template of the desktop
config lives in `configs/claude-desktop/claude_desktop_config.json`.

---

## Schedule Summary

| Time | Job |
|------|-----|
| 2:00 AM | Backrest runs home, etc, and opt restic backups |
| 3:00 AM | Claude Desktop data backup script |
