#!/bin/bash
# backup-claude.sh
# Backs up Claude Desktop data to NFS share (atlas)
# Covers: memory.db, basic-memory markdown, extension settings

# ── Config ────────────────────────────────────────────────────────────────────
CLAUDE_DIR="/home/ted/.config/Claude"
DEST="/mnt/atlas/claudebox/claude-backup"
DATE=$(date +%Y-%m-%d)
LOG="/home/ted/.local/share/logs/claude-backup.log"

NTFY_ENABLED=true
NTFY_URL="https://ntfy.example.com"   # set your ntfy URL
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

# ── Extension settings (contains secrets - NFS only, not committed) ───────────
log "Syncing extension settings"
rsync -a --delete \
    "$CLAUDE_DIR/Claude Extensions Settings/" \
    "$DEST/latest/extension-settings/" \
    || die "Extension settings sync failed"
cp -r "$CLAUDE_DIR/Claude Extensions Settings/." "$SNAPSHOT/extension-settings" \
    || die "Failed to snapshot extension settings"
log "Extension settings OK"

# ── Done ──────────────────────────────────────────────────────────────────────
log "Claude backup complete"
notify "Claude Backup OK" "claudebox claude backup completed ($DATE)" "default" "check,backup"
