#!/bin/bash
# backup-claude.sh
# Backs up Claude Desktop data to NFS share (atlas)
# Covers: memory.db (SQLite), basic-memory markdown, extension settings

# ── Config ────────────────────────────────────────────────────────────────────
CLAUDE_DIR="/home/ted/.config/Claude"
DEST="/mnt/atlas/claudebox/claude-backup"
DATE=$(date +%Y-%m-%d)
LOG="/home/ted/.local/share/logs/claude-backup.log"

NTFY_ENABLED=true
NTFY_URL="https://ntfy.glitch42.com"
NTFY_TOPIC="claudebox"

# ── Helpers ───────────────────────────────────────────────────────────────────
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG"; }

notify() {
    local title="$1" msg="$2" priority="${3:-default}" tags="${4:-backup}"
    [[ "$NTFY_ENABLED" != true ]] && return 0
    curl -s -o /dev/null \
        -H "Title: $title" \
        -H "Priority: $priority" \
        -H "Tags: $tags" \
        -d "$msg" \
        "$NTFY_URL/$NTFY_TOPIC"
}

die() {
    log "ERROR: $*"
    notify "Claude Backup Failed" "$* on claudebox" "high" "warning,backup"
    exit 1
}

# ── Setup ─────────────────────────────────────────────────────────────────────
SNAPSHOT="$DEST/snapshots/$DATE"
mkdir -p "$DEST/latest" "$SNAPSHOT" || die "Failed to create destination dirs"

log "Starting Claude backup"

# ── memory.db (JSONL format despite .db extension - plain copy is safe) ───────
log "Backing up memory.db"
cp "$CLAUDE_DIR/memory/memory.db" "$SNAPSHOT/memory.db" \
    || die "memory.db backup failed"
cp "$SNAPSHOT/memory.db" "$DEST/latest/memory.db" \
    || die "Failed to copy memory.db to latest"
log "memory.db OK"

# ── basic-memory markdown ─────────────────────────────────────────────────────
log "Syncing basic-memory"
rsync -a --delete \
    "$CLAUDE_DIR/basic-memory/claude/" \
    "$DEST/latest/basic-memory/" \
    || die "basic-memory sync failed"
log "basic-memory OK"

# ── claude_desktop_config.json (contains secrets - NFS only) ─────────────────
log "Backing up claude_desktop_config.json"
cp "$CLAUDE_DIR/claude_desktop_config.json" "$SNAPSHOT/claude_desktop_config.json" \
    || die "claude_desktop_config.json backup failed"
cp "$SNAPSHOT/claude_desktop_config.json" "$DEST/latest/claude_desktop_config.json" \
    || die "Failed to copy claude_desktop_config.json to latest"
log "claude_desktop_config.json OK"

# ── Extension settings (contains secrets - NFS only) ─────────────────────────
log "Syncing extension settings"
rsync -a --delete \
    "$CLAUDE_DIR/Claude Extensions Settings/" \
    "$DEST/latest/extension-settings/" \
    || die "Extension settings sync failed"
cp -r "$CLAUDE_DIR/Claude Extensions Settings/." "$SNAPSHOT/extension-settings" \
    || die "Failed to snapshot extension settings"
log "Extension settings OK"

# ── Claude Code settings.json ────────────────────────────────────────────────
log "Backing up claude settings.json"
if [[ -f "/home/ted/.claude/settings.json" ]]; then
    cp "/home/ted/.claude/settings.json" "$SNAPSHOT/claude-settings.json" \
        || die "claude settings.json backup failed"
    cp "$SNAPSHOT/claude-settings.json" "$DEST/latest/claude-settings.json" \
        || die "Failed to copy claude-settings.json to latest"
    log "claude settings.json OK"
else
    log "WARNING: ~/.claude/settings.json not found — skipping"
fi

# ── PM2 ecosystem dump ────────────────────────────────────────────────────────
log "Backing up PM2 dump"
# pm2 save writes to ~/.pm2/dump.pm2 — refresh it before copying
pm2 save --force >> "$LOG" 2>&1 || log "WARNING: pm2 save failed (PM2 may not be running)"
if [[ -f "/home/ted/.pm2/dump.pm2" ]]; then
    cp "/home/ted/.pm2/dump.pm2" "$SNAPSHOT/pm2-dump.pm2" \
        || die "PM2 dump backup failed"
    cp "$SNAPSHOT/pm2-dump.pm2" "$DEST/latest/pm2-dump.pm2" \
        || die "Failed to copy pm2-dump.pm2 to latest"
    log "PM2 dump OK"
else
    log "WARNING: ~/.pm2/dump.pm2 not found — skipping"
fi

# ── Docker secrets (.env files not covered by docker-stack-backup.sh) ─────────
log "Backing up Docker secrets"
DOCKER_SECRETS_DEST="$DEST/latest/docker-secrets"
mkdir -p "$DOCKER_SECRETS_DEST"
if [[ -f "/home/ted/docker/librechat/.env" ]]; then
    cp "/home/ted/docker/librechat/.env" "$DOCKER_SECRETS_DEST/librechat.env"
    chmod 600 "$DOCKER_SECRETS_DEST/librechat.env"
    cp "$DOCKER_SECRETS_DEST/librechat.env" "$SNAPSHOT/librechat.env" 2>/dev/null || true
    log "LibreChat .env OK"
else
    log "WARNING: ~/docker/librechat/.env not found — skipping"
fi
if [[ -f "/opt/appdata/authelia/users_database.yml" ]]; then
    cp "/opt/appdata/authelia/users_database.yml" "$DOCKER_SECRETS_DEST/authelia-users.yml"
    chmod 600 "$DOCKER_SECRETS_DEST/authelia-users.yml"
    cp "$DOCKER_SECRETS_DEST/authelia-users.yml" "$SNAPSHOT/authelia-users.yml" 2>/dev/null || true
    log "Authelia users_database.yml OK"
else
    log "WARNING: Authelia users_database.yml not found — skipping"
fi

# ── Cleanup snapshots older than 90 days ─────────────────────────────────────
log "Cleaning up snapshots older than 90 days"
find "$DEST/snapshots" -maxdepth 1 -type d -mtime +90 -exec rm -rf {} \;
log "Cleanup OK"

# ── Done ──────────────────────────────────────────────────────────────────────
log "Claude backup complete"
notify "Claude Backup OK" "claudebox claude backup completed ($DATE)" "default" "check,backup"
