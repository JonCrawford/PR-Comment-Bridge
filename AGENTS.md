# AGENTS.md

## Cursor Cloud specific instructions

This is a **GitHub Webhook MCP Channel Server** (`PRCommentBridge`) written in Ruby. It receives GitHub webhooks via a WEBrick HTTP server and bridges them to Claude Code over MCP stdio transport.

### Running tests

```
ruby test/verify_signature_test.rb
```

`minitest` is used (Ruby stdlib in 3.2). Tests do not require `bundle exec` since they only depend on stdlib + project files.

### Running the server

The server blocks on stdin (MCP stdio transport). To run it for local HTTP endpoint testing, keep stdin open:

```
tail -f /dev/null | WEBHOOK_PORT=8789 bundle exec ruby server.rb
```

The WEBrick webhook listener runs on `127.0.0.1:8789` by default (configurable via `WEBHOOK_PORT`).

### Key endpoints

- `GET /health` — returns `{"status":"ok"}`
- `POST /` — accepts GitHub webhook payloads (requires `X-GitHub-Event` header)

### Environment variables

| Variable | Required | Purpose |
|---|---|---|
| `GITHUB_TOKEN` | For reply tool | GitHub API token for posting comments |
| `WEBHOOK_PORT` | No (default `8789`) | HTTP server listen port |
| `GITHUB_WEBHOOK_SECRET` | No | HMAC secret for webhook signature verification |
| `ALLOWED_SENDERS` | No | Comma-separated GitHub username allowlist |

### Gotchas

- Gems install to `vendor/bundle` (configured via `.bundle/config`) to avoid system permission issues.
- `minitest` is a Ruby stdlib gem but may need `sudo gem install minitest` if not present in the system Ruby installation.
- The server process exits immediately if stdin closes (no MCP client connected). Use the `tail -f /dev/null |` pipe trick for standalone HTTP testing.
