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

# ── Docker compose files (for deploy script restore) ──────────────────────────
log "Backing up Docker compose files"
DOCKER_COMPOSE_DEST="/mnt/atlas/claudebox/docker-backups"
for stack in swag authelia librechat dockhand open-notebook perplexica grafana graphiti nats n8n plane temporal task-queue-mcp hister ollama-queue-proxy; do
    compose_src="/home/ted/docker/${stack}/docker-compose.yml"
    compose_dest="${DOCKER_COMPOSE_DEST}/${stack}/compose"
    if [[ -f "$compose_src" ]]; then
        mkdir -p "$compose_dest"
        cp "$compose_src" "$compose_dest/docker-compose.yml"
        log "Compose file OK: ${stack}"
    else
        log "WARNING: compose file not found for ${stack} — skipping"
    fi
done
# Graphiti has extra build files (Dockerfile, config.yaml) alongside compose
for extra in Dockerfile config.yaml; do
    extra_src="/home/ted/docker/graphiti/${extra}"
    if [[ -f "$extra_src" ]]; then
        cp "$extra_src" "${DOCKER_COMPOSE_DEST}/graphiti/compose/${extra}"
        log "Graphiti ${extra} OK"
    fi
done
# NATS has nats-server.conf alongside compose
if [[ -f "/home/ted/docker/nats/nats-server.conf" ]]; then
    cp "/home/ted/docker/nats/nats-server.conf" "${DOCKER_COMPOSE_DEST}/nats/compose/nats-server.conf"
    log "NATS nats-server.conf OK"
fi
# n8n has exported workflow JSON files alongside compose
if [[ -d "/home/ted/docker/n8n/workflows" ]]; then
    mkdir -p "${DOCKER_COMPOSE_DEST}/n8n/compose/workflows"
    cp /home/ted/docker/n8n/workflows/*.json "${DOCKER_COMPOSE_DEST}/n8n/compose/workflows/" 2>/dev/null
    log "n8n workflow exports OK"
fi
# Temporal has dynamicconfig/ and scripts/ alongside compose
for extra_dir in dynamicconfig scripts; do
    if [[ -d "/home/ted/docker/temporal/${extra_dir}" ]]; then
        mkdir -p "${DOCKER_COMPOSE_DEST}/temporal/compose/${extra_dir}"
        cp -r "/home/ted/docker/temporal/${extra_dir}/." "${DOCKER_COMPOSE_DEST}/temporal/compose/${extra_dir}/"
        log "Temporal ${extra_dir}/ OK"
    fi
done
# Hister has preview/Dockerfile alongside compose (needed to build hister-preview container)
if [[ -f "/home/ted/docker/hister/preview/Dockerfile" ]]; then
    mkdir -p "${DOCKER_COMPOSE_DEST}/hister/compose/preview"
    cp "/home/ted/docker/hister/preview/Dockerfile" "${DOCKER_COMPOSE_DEST}/hister/compose/preview/Dockerfile"
    log "Hister preview/Dockerfile OK"
fi
# Hister has data/config.yml (contains access token — treat as secret alongside compose)
if [[ -f "/home/ted/docker/hister/data/config.yml" ]]; then
    mkdir -p "${DOCKER_COMPOSE_DEST}/hister/compose/data"
    cp "/home/ted/docker/hister/data/config.yml" "${DOCKER_COMPOSE_DEST}/hister/compose/data/config.yml"
    chmod 600 "${DOCKER_COMPOSE_DEST}/hister/compose/data/config.yml"
    log "Hister data/config.yml OK"
fi
log "Docker compose files OK"

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
if [[ -f "/home/ted/docker/grafana/.env" ]]; then
    cp "/home/ted/docker/grafana/.env" "$DOCKER_SECRETS_DEST/grafana.env"
    chmod 600 "$DOCKER_SECRETS_DEST/grafana.env"
    cp "$DOCKER_SECRETS_DEST/grafana.env" "$SNAPSHOT/grafana.env" 2>/dev/null || true
    log "Grafana .env OK"
else
    log "WARNING: ~/docker/grafana/.env not found — skipping"
fi
if [[ -f "/home/ted/docker/graphiti/.env" ]]; then
    cp "/home/ted/docker/graphiti/.env" "$DOCKER_SECRETS_DEST/graphiti.env"
    chmod 600 "$DOCKER_SECRETS_DEST/graphiti.env"
    cp "$DOCKER_SECRETS_DEST/graphiti.env" "$SNAPSHOT/graphiti.env" 2>/dev/null || true
    log "Graphiti .env OK"
else
    log "WARNING: ~/docker/graphiti/.env not found — skipping"
fi
if [[ -f "/home/ted/docker/n8n/.env" ]]; then
    cp "/home/ted/docker/n8n/.env" "$DOCKER_SECRETS_DEST/n8n.env"
    chmod 600 "$DOCKER_SECRETS_DEST/n8n.env"
    cp "$DOCKER_SECRETS_DEST/n8n.env" "$SNAPSHOT/n8n.env" 2>/dev/null || true
    log "n8n .env OK (contains N8N_ENCRYPTION_KEY — critical for credential restore)"
else
    log "WARNING: ~/docker/n8n/.env not found — skipping"
fi
if [[ -f "/home/ted/docker/plane/.env" ]]; then
    cp "/home/ted/docker/plane/.env" "$DOCKER_SECRETS_DEST/plane.env"
    chmod 600 "$DOCKER_SECRETS_DEST/plane.env"
    cp "$DOCKER_SECRETS_DEST/plane.env" "$SNAPSHOT/plane.env" 2>/dev/null || true
    log "Plane .env OK (contains SECRET_KEY, DB password, RabbitMQ/MinIO creds)"
else
    log "WARNING: ~/docker/plane/.env not found — skipping"
fi
if [[ -f "/home/ted/docker/temporal/.env" ]]; then
    cp "/home/ted/docker/temporal/.env" "$DOCKER_SECRETS_DEST/temporal.env"
    chmod 600 "$DOCKER_SECRETS_DEST/temporal.env"
    cp "$DOCKER_SECRETS_DEST/temporal.env" "$SNAPSHOT/temporal.env" 2>/dev/null || true
    log "Temporal .env OK (contains POSTGRES_PASSWORD)"
else
    log "WARNING: ~/docker/temporal/.env not found — skipping"
fi
if [[ -f "/opt/appdata/ollama-queue-proxy/config.yml" ]]; then
    cp "/opt/appdata/ollama-queue-proxy/config.yml" "$DOCKER_SECRETS_DEST/ollama-queue-proxy-config.yml"
    chmod 600 "$DOCKER_SECRETS_DEST/ollama-queue-proxy-config.yml"
    cp "$DOCKER_SECRETS_DEST/ollama-queue-proxy-config.yml" "$SNAPSHOT/ollama-queue-proxy-config.yml" 2>/dev/null || true
    log "ollama-queue-proxy config.yml OK (contains API keys)"
else
    log "WARNING: /opt/appdata/ollama-queue-proxy/config.yml not found — skipping"
fi

# ── Claude Code Engine (CLAUDE.md, memsearch config, agent memory) ────────────
log "Backing up Claude Code engine files"
CLAUDE_CODE_DEST="$DEST/latest/claude-code"
mkdir -p "$CLAUDE_CODE_DEST"

# Root CLAUDE.md
if [[ -f "/home/ted/.claude/CLAUDE.md" ]]; then
    cp "/home/ted/.claude/CLAUDE.md" "$CLAUDE_CODE_DEST/CLAUDE.md"
    log "Root CLAUDE.md OK"
fi

# Project CLAUDE.md files
if [[ -d "/home/ted/.claude/projects" ]]; then
    rsync -a --delete "/home/ted/.claude/projects/" "$CLAUDE_CODE_DEST/projects/"
    log "CLAUDE.md project files OK"
fi

# Agent memory (shared + per-agent)
if [[ -d "/home/ted/.claude/memory" ]]; then
    rsync -a --delete "/home/ted/.claude/memory/" "$CLAUDE_CODE_DEST/memory/"
    log "Agent memory OK"
fi

# memsearch config (not the DB — it rebuilds from markdown)
if [[ -f "/home/ted/.memsearch/config.toml" ]]; then
    cp "/home/ted/.memsearch/config.toml" "$CLAUDE_CODE_DEST/memsearch-config.toml"
    log "memsearch config.toml OK"
fi

# ── qmd config (collections, context — index rebuilds from source) ────────────
log "Backing up qmd config"
QMD_DEST="$DEST/latest/qmd"
mkdir -p "$QMD_DEST"
if [[ -f "/home/ted/.cache/qmd/index.sqlite" ]]; then
    # Export collection definitions (the sqlite DB has them, but we back up via status dump)
    qmd collection list > "$QMD_DEST/collections.txt" 2>/dev/null
    qmd context list > "$QMD_DEST/contexts.txt" 2>/dev/null
    log "qmd collection/context list OK"
fi

# ── cui config (Claude Code Web UI) ──────────────────────────────────────────
log "Backing up cui config"
CUI_DEST="$DEST/latest/cui"
mkdir -p "$CUI_DEST"
if [[ -f "/home/ted/.cui/config.json" ]]; then
    cp "/home/ted/.cui/config.json" "$CUI_DEST/config.json"
    log "cui config.json OK"
fi
# Also back up the SWAG proxy confs for all custom services
SWAG_PROXY_CONFS_DEST="$DEST/latest/swag-proxy-confs"
mkdir -p "$SWAG_PROXY_CONFS_DEST"
for conf in cui dockhand notebook perplexica librechat authelia grafana nats n8n plane temporal hister ollama-proxy; do
    conf_file="/opt/appdata/swag/nginx/proxy-confs/${conf}.subdomain.conf"
    if [[ -f "$conf_file" ]]; then
        cp "$conf_file" "$SWAG_PROXY_CONFS_DEST/"
        log "SWAG proxy conf OK: ${conf}.subdomain.conf"
    fi
done

# ── agent-bus comms artifacts (build plans, audit requests/reports, diagnose sessions) ───────
log "Backing up comms artifacts"
if [[ -d "/home/ted/.claude/comms/artifacts" ]]; then
    rsync -a --delete \
        "/home/ted/.claude/comms/artifacts/" \
        "$DEST/latest/comms-artifacts/" \
        || die "comms/artifacts sync failed"
    log "comms/artifacts OK"
else
    log "WARNING: ~/.claude/comms/artifacts not found — skipping"
fi
# logs/ is ephemeral JSONL event data — not backed up (regenerates from agent activity)

# ── Claude agent scripts (memory-sync, export-librechat-memory) ───────────────
log "Backing up Claude agent scripts"
if [[ -d "/home/ted/.claude/scripts" ]]; then
    rsync -a --delete "/home/ted/.claude/scripts/" "$DEST/latest/claude-code/scripts/"
    log "~/.claude/scripts/ OK"
fi

# ── Claude agent manifests (~/.claude/agent-manifests/) ──────────────────────
log "Backing up agent manifests"
if [[ -d "/home/ted/.claude/agent-manifests" ]]; then
    rsync -a --delete "/home/ted/.claude/agent-manifests/" "$DEST/latest/claude-code/agent-manifests/"
    log "agent-manifests OK"
else
    log "WARNING: ~/.claude/agent-manifests not found — skipping"
fi

# ── Claude OAuth credentials (~/.claude/.credentials.json) ───────────────────
# Required by trigger-proxy.py to call the Anthropic RemoteTrigger API
log "Backing up Claude OAuth credentials"
if [[ -f "/home/ted/.claude/.credentials.json" ]]; then
    cp "/home/ted/.claude/.credentials.json" "$DEST/latest/claude-code/credentials.json"
    chmod 600 "$DEST/latest/claude-code/credentials.json"
    log "~/.claude/.credentials.json OK"
else
    log "WARNING: ~/.claude/.credentials.json not found — trigger-proxy will not work after deploy until re-authenticated"
fi

# ── Utility scripts (qmd-reindex, check-qmd-issue, etc.) ─────────────────────
log "Backing up utility scripts"
if [[ -d "/home/ted/scripts" ]]; then
    rsync -a --delete "/home/ted/scripts/" "$DEST/latest/scripts/"
    log "~/scripts/ OK"
fi

# ── System cron jobs (/etc/cron.d/) ──────────────────────────────────────────
log "Backing up system cron jobs"
CRON_DEST="$DEST/latest/system-cron"
mkdir -p "$CRON_DEST"
for cron_file in docker-stack-backup; do
    if [[ -f "/etc/cron.d/${cron_file}" ]]; then
        cp "/etc/cron.d/${cron_file}" "$CRON_DEST/"
        log "System cron OK: ${cron_file}"
    else
        log "WARNING: /etc/cron.d/${cron_file} not found — skipping"
    fi
done

# ── Sudoers drop-ins (/etc/sudoers.d/) ────────────────────────────────────────
log "Backing up sudoers drop-ins"
SUDOERS_DEST="$DEST/latest/sudoers.d"
mkdir -p "$SUDOERS_DEST"
for sudoers_file in docker-backup; do
    if [[ -f "/etc/sudoers.d/${sudoers_file}" ]]; then
        cp "/etc/sudoers.d/${sudoers_file}" "$SUDOERS_DEST/"
        chmod 440 "$SUDOERS_DEST/${sudoers_file}"
        log "Sudoers drop-in OK: ${sudoers_file}"
    else
        log "WARNING: /etc/sudoers.d/${sudoers_file} not found — skipping"
    fi
done

# ── Dep-update audit log ──────────────────────────────────────────────────────
log "Backing up dep-update audit log"
AUDIT_SRC="/home/ted/.local/share/logs/update-audit.jsonl"
if [[ -f "$AUDIT_SRC" ]]; then
    cp "$AUDIT_SRC" "$DEST/latest/update-audit.jsonl" \
        || die "update-audit.jsonl backup failed"
    cp "$DEST/latest/update-audit.jsonl" "$SNAPSHOT/update-audit.jsonl" 2>/dev/null || true
    log "update-audit.jsonl OK"
else
    log "update-audit.jsonl not found yet (no updates applied) — skipping"
fi

# ── Cleanup snapshots older than 90 days ─────────────────────────────────────
log "Cleaning up snapshots older than 90 days"
find "$DEST/snapshots" -maxdepth 1 -type d -mtime +90 -exec rm -rf {} \;
log "Cleanup OK"

# ── Done ──────────────────────────────────────────────────────────────────────
log "Claude backup complete"
notify "Claude Backup OK" "claudebox claude backup completed ($DATE)" "default" "check,backup"
