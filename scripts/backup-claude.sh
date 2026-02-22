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

# ── Cleanup snapshots older than 90 days ─────────────────────────────────────
log "Cleaning up snapshots older than 90 days"
find "$DEST/snapshots" -maxdepth 1 -type d -mtime +90 -exec rm -rf {} \;
log "Cleanup OK"

# ── Done ──────────────────────────────────────────────────────────────────────
log "Claude backup complete"
notify "Claude Backup OK" "claudebox claude backup completed ($DATE)" "default" "check,backup"
