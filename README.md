# Claudebox

A dedicated AI workstation running Claude Desktop on Debian Linux, serving as a homelab AI companion and assistant.

## What is Claudebox?

Claudebox is a GMKTec K11 mini PC running Debian 13 (trixie) with Claude Desktop installed. It provides persistent, always-on access to Claude with a suite of MCP (Model Context Protocol) servers that give it real awareness of and control over the homelab environment.

The result is an AI assistant that actually knows your infrastructure — it can query live metrics, manage dashboards, read and write files, and remember context across sessions.

## Remote Access

**RDP** - Primary access method at home. Connect directly to the Claudebox desktop via any RDP client.

**Guacamole** - Browser-based remote access for use outside the home network. Hosted on the homelab, accessible from anywhere without a VPN or RDP client.

## MCP Servers

| Server | Purpose |
|---|---|
| Desktop Commander | File operations, terminal process execution, system commands on the Claudebox host |
| Netdata (Claudebox) | Live system metrics and alerts for the local Claudebox machine |
| Netdata (Unraid) | Live metrics and alerts for the Unraid server |
| Grafana | Dashboard management, alert rules, metrics querying via Prometheus/Loki |
| Memory MCP | Persistent knowledge graph shared across all chats (infrastructure IPs, conventions, facts) |
| Basic Memory | Persistent markdown knowledge base for Claudebox-specific context, Obsidian-compatible |
| Microsoft Learn | Search and fetch Microsoft/Azure documentation |

## Hardware

- **Device:** GMKTec K11 mini PC
- **CPU:** AMD Ryzen 9 8945HS (8 cores / 16 threads)
- **RAM:** 28GB
- **OS:** Debian 13 (trixie)
- **IP:** 192.168.1.178

## Use Cases

- Homelab monitoring and management
- Grafana dashboard creation and maintenance
- Infrastructure documentation
- PowerShell and scripting assistance
- General AI assistant tasks scoped to the homelab context
