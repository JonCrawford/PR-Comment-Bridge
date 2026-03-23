# AGENTS.md

## Cursor Cloud specific instructions

### Project overview

PR-Comment-Bridge is a Ruby MCP server that receives GitHub webhooks (PR comments, reviews, issues) via an HTTP server (WEBrick) and forwards them as MCP channel notifications to Claude Code over stdio. It also exposes a `github_reply` tool for posting comments back to GitHub.

### Dependencies

- **Ruby** (3.2+) with `bundler`
- **System package**: `ruby-minitest` (needed to run tests; not in the Gemfile)
- Gems are installed to `vendor/bundle` via `bundle install`

### Running tests

```
ruby -I lib test/verify_signature_test.rb
```

Note: `bundle exec` cannot run the tests because `minitest` is not in the Gemfile — it's a system gem. Use plain `ruby -I lib` instead.

### Running the server

The server is an MCP stdio server; it reads JSON-RPC from stdin and writes to stdout. The webhook HTTP listener starts automatically on a background thread.

```
bundle exec ruby server.rb
```

When running standalone (not connected to an MCP client), keep stdin open to prevent immediate exit:

```
sleep 999 | bundle exec ruby server.rb
```

The webhook HTTP server listens on `127.0.0.1:8789` by default (configurable via `WEBHOOK_PORT` env var).

### Key endpoints

- `GET /health` — returns `{"status":"ok"}`
- `POST /` — receives GitHub webhook payloads (requires `X-GitHub-Event` header)

### Environment variables

- `WEBHOOK_PORT` — HTTP listen port (default: `8789`)
- `GITHUB_TOKEN` — required for the `github_reply` tool to post comments
- `GITHUB_WEBHOOK_SECRET` — optional, for webhook signature verification
- `ALLOWED_SENDERS` — optional, comma-separated GitHub username allowlist
