# AGENTS.md

## Cursor Cloud specific instructions

This is a **GitHub Webhook MCP Channel Server** (`PRCommentBridge`) written in Ruby. It receives GitHub webhooks via a WEBrick HTTP server and bridges them to Claude Code over MCP stdio transport.

**Ruby version:** 4.0.2 (compiled from source at `/usr/local/bin/ruby`).

### Running tests

```
ruby test/verify_signature_test.rb
```

`minitest` is used. In Ruby 4.0+, minitest is a bundled gem and must be installed separately (`sudo /usr/local/bin/gem install minitest`). Tests run with plain `ruby` (not `bundle exec`) since minitest isn't in the Gemfile.

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

- Ruby 4.0.2 is compiled from source at `/usr/local`. Gems install to `/usr/local/lib/ruby/gems/4.0.0` (use `sudo` for `bundle install` and `gem install`).
- In Ruby 4.0+, `minitest` is a bundled gem (not auto-available). Install it separately: `sudo /usr/local/bin/gem install minitest --no-document`.
- The server process exits immediately if stdin closes (no MCP client connected). Use the `tail -f /dev/null |` pipe trick for standalone HTTP testing.
- The update script compiles Ruby from source if `/usr/local/bin/ruby` is missing. This takes ~90 seconds but only runs once per fresh VM.
