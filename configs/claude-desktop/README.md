# Claude Desktop Config

Sanitized template for `~/.config/Claude/claude_desktop_config.json`.
Replace all `YOUR_*` placeholders with real values before use.
The live config with tokens is backed up to NFS only and not committed to git.

## MCP Servers

| Server | Package / Binary | Notes |
|--------|-----------------|-------|
| `memory` | `@modelcontextprotocol/server-memory` | Knowledge graph, stored at `~/.config/Claude/memory/memory.db` |
| `netdata-unraid` | `/usr/sbin/nd-mcp` | Netdata MCP for Unraid host — requires Netdata claim token |
| `netdata-claudebox` | `/usr/sbin/nd-mcp` | Netdata MCP for local Claudebox — requires Netdata claim token |
| `basic-memory` | `uvx basic-memory` | Markdown knowledge base, project `claude` |
| `playwright` | `@playwright/mcp` | Browser automation via Firefox |
| `github-personal` | `@modelcontextprotocol/server-github` | Personal GitHub account |
| `github-work` | `@modelcontextprotocol/server-github` | Work GitHub account — separate token |

## Tokens Required

- `YOUR_NETDATA_TOKEN` — Netdata claim token (same value used for both Netdata entries)
- `YOUR_GITHUB_TOKEN` — GitHub personal access token (one per account)

Netdata tokens are generated in the Netdata Cloud UI under Space Settings.
GitHub tokens need `repo` and `read:org` scopes at minimum.

## Additional MCP Servers

Desktop Commander, Grafana, and Microsoft Learn are injected via the Claude.ai
system prompt and do not appear in this config file.
