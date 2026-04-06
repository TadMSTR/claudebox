# Claudebox

A dedicated AI workstation running Claude Desktop on Debian Linux, serving as a homelab AI companion and assistant.

## What is Claudebox?

Claudebox is a GMKTec K11 mini PC running Debian 13 (trixie) with Claude Desktop installed. It provides persistent, always-on access to Claude with a suite of MCP (Model Context Protocol) servers that give it real awareness of and control over the homelab environment.

The result is an AI assistant that actually knows your infrastructure — it can query live metrics, manage dashboards, read and write files, and remember context across sessions.

## Persistent Context

Claudebox uses a three-tier memory system with two semantic search engines and a knowledge graph:

**Session tier** — Raw session notes auto-captured by the memsearch plugin, per-project. Indexed in real-time by `memsearch-watch` (Milvus standalone + bge-m3 embeddings via forge GPU). 30-day retention.

**Working tier** — Agent-curated knowledge at `~/.claude/memory/`. Promoted from session nightly by `memory-promote-daily` (Haiku) or written by agents during work. 90-day expiry. Injected at session start via hooks.

**Distilled tier** — Permanent notes in `claude-prime-directive/memory/distilled/`, git-backed. Promoted from working weekly by `memory-sync-weekly` (Opus) when notes pass the "would this matter in 3 months?" test.

**Knowledge graph** — Graphiti + Neo4j for relational/topology queries. Fed by memory-flush (real-time) and nightly batch ingestion.

**Search surfaces:** memsearch (automatic, per-prompt), qmd (on-demand, hybrid BM25+vector across all repos), Graphiti (relational). See [homelab-agent docs](https://github.com/TadMSTR/homelab-agent/tree/main/docs/components) for full architecture.

## Remote Access

**RDP** - Primary access method at home. Connect directly to the Claudebox desktop via any RDP client.

**Guacamole** - Browser-based remote access for use outside the home network. Hosted on the homelab, accessible from anywhere without a VPN or RDP client.

## MCP Servers

| Server | Purpose |
|---|---|
| Desktop Commander | File operations, terminal process execution, system commands on the Claudebox host |
| Netdata (Claudebox) | Live system metrics and alerts for the local Claudebox machine |
| Netdata (Unraid) | Live metrics and alerts for the Unraid server |
| Netdata (Atlas) | Live metrics and alerts for the TrueNAS Scale server |
| InfluxDB | Query and write time-series data in InfluxDB v2.7 on TrueNAS. Telegraf ships metrics from all hosts into per-host buckets. |
| Grafana | Dashboard management, alert rules, and querying across Netdata, InfluxDB, and Loki datasources. Also covers OnCall schedules and incident management. |
| Unraid | Array status, disk health, parity, Docker containers, shares, notifications via GraphQL API |
| TrueNAS | Pool/dataset management, SMB/NFS shares, snapshots via REST API (see note below) |
| Bluesky | Post, search, notifications, and social graph management |
| GitHub (Personal) | Repo management, issues, PRs for TadMSTR account |
| GitHub (Work) | Repo management, issues, PRs for work account |
| memsearch | Semantic memory search — auto-injects relevant context from past sessions via Claude Code plugin |
| qmd | Hybrid semantic search (BM25 + vector) over repos, docs, and agent memory — HTTP + stdio MCP |
| Playwright | Browser automation via Firefox |
| Microsoft Learn | Search and fetch Microsoft/Azure documentation |

### TrueNAS MCP Note

The TrueNAS MCP (`vespo92/TrueNasCoreMCP`) required a patch to `http_client.py` in the uv cache to fix SSL handling with the self-signed cert. The upstream bug: a custom `ssl_context` was passed to `httpx.AsyncClient` but a separate `AsyncHTTPTransport` was also created, which took precedence and ignored the ssl_context. Fix was to remove the transport block entirely.

**Caveat:** The patch is applied to the uv package cache. If `uvx` updates the package, the patch will be lost and will need to be reapplied.

## Hardware

- **Device:** GMKTec K11 mini PC
- **CPU:** AMD Ryzen 9 8945HS (8 cores / 16 threads)
- **RAM:** 28GB (32GB total, shared between CPU/GPU)
- **OS:** Debian 13 (trixie)

## Use Cases

- Homelab monitoring and management
- Grafana dashboard creation and maintenance
- Infrastructure documentation
- Bash and PowerShell scripting assistance
- General AI assistant tasks scoped to the homelab context
