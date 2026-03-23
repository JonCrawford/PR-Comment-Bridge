# Cloud Agent Starter Skill: GitHub Webhook MCP Server

Use this skill when you need to run, debug, or test the webhook bridge quickly in a Cloud Agent session.

## 1) First 5 minutes setup

1. Install gems:
   - `bundle install`
2. Set auth for GitHub reply posting:
   - `export GITHUB_TOKEN="$(gh auth token)"`
3. Optional runtime gates (treat these as feature-flag-like toggles):
   - `export WEBHOOK_PORT=8789` (default is `8789`)
   - `export GITHUB_WEBHOOK_SECRET=...` (unset to disable signature verification in local smoke tests)
   - `export ALLOWED_SENDERS="octocat,another-user"` (unset to allow all senders)
4. Start the app:
   - `bundle exec ruby server.rb`

Health check (new terminal):
- `curl -sS http://127.0.0.1:${WEBHOOK_PORT:-8789}/health`

## 2) Codebase area workflows

### Area A: App bootstrap + webhook HTTP ingress
**Files:** `server.rb`, `lib/webhook_server.rb`

Practical smoke workflow:
1. Start server: `bundle exec ruby server.rb`
2. Verify health endpoint:
   - `curl -i http://127.0.0.1:${WEBHOOK_PORT:-8789}/health`
3. Verify GitHub ping handling:
   - `curl -i -X POST "http://127.0.0.1:${WEBHOOK_PORT:-8789}/" -H "X-GitHub-Event: ping" -H "Content-Type: application/json" -d '{}'`
4. Expected result:
   - HTTP `200` and body containing `"pong"` for ping.

### Area B: Signature verification + sender allowlist guardrails
**Files:** `lib/webhook_server.rb`, `test/verify_signature_test.rb`

Concrete test workflow:
1. Run unit tests:
   - `bundle exec ruby -Itest test/verify_signature_test.rb`
2. Manual signed request check (when `GITHUB_WEBHOOK_SECRET` is set):
   - `BODY='{"action":"opened","sender":{"login":"octocat"},"repository":{"full_name":"o/r"}}'`
   - `SIG=$(ruby -ropenssl -e 'body=ENV.fetch("BODY"); secret=ENV.fetch("GITHUB_WEBHOOK_SECRET"); puts "sha256="+OpenSSL::HMAC.hexdigest("sha256", secret, body)' BODY="$BODY")`
   - `curl -i -X POST "http://127.0.0.1:${WEBHOOK_PORT:-8789}/" -H "X-GitHub-Event: issues" -H "X-Hub-Signature-256: ${SIG}" -H "Content-Type: application/json" -d "$BODY"`
3. Negative check:
   - Send an invalid signature and expect HTTP `403`.

### Area C: Payload parsing and event-to-channel shaping
**File:** `lib/github_payload_parser.rb`

Concrete test workflow:
1. Post representative events (issue comment, PR review, inline review comment):
   - `curl -i -X POST "http://127.0.0.1:${WEBHOOK_PORT:-8789}/" -H "X-GitHub-Event: issue_comment" -H "Content-Type: application/json" -d '{"action":"created","sender":{"login":"octocat"},"repository":{"full_name":"o/r"},"issue":{"number":12,"title":"T","pull_request":{}},"comment":{"id":99,"body":"please fix","html_url":"https://example"}}'`
2. Expected result:
   - HTTP `200` with `{"received":true}`.
3. If behavior looks wrong:
   - Add a narrow parser unit test in `test/` first, then fix parser output.

### Area D: GitHub reply tool behavior
**File:** `lib/tools/github_reply_tool.rb`

Concrete test workflow:
1. Verify auth before posting:
   - `gh auth status`
   - `test -n "$GITHUB_TOKEN" && echo "GITHUB_TOKEN is set"`
2. Token/API sanity check:
   - `curl -sS -H "Authorization: Bearer $GITHUB_TOKEN" -H "Accept: application/vnd.github+json" https://api.github.com/user | ruby -rjson -e 'j=JSON.parse(STDIN.read); puts j["login"]'`
3. Reply behavior check (manual MCP flow):
   - Trigger an inbound webhook event containing `repo` + `number`.
   - Call `github_reply` with required args (`repo`, `number`, `body`; optional `comment_id` for threaded review replies).
4. Expected result:
   - Tool returns `Comment posted: <url>`.

## 3) Common environment toggles (quick reference)

- `GITHUB_TOKEN`: required for outbound GitHub replies.
- `GITHUB_WEBHOOK_SECRET`: enable HMAC signature verification; unset for quick local smoke tests.
- `ALLOWED_SENDERS`: comma-separated sender allowlist; unset to disable filtering.
- `WEBHOOK_PORT`: local bind port for webhook listener.

## 4) Fast debugging checklist

1. `bundle install` completed without errors.
2. Server is up and `/health` returns `200`.
3. Incoming webhook has `X-GitHub-Event` header.
4. If secret is enabled, signature header exactly matches `sha256=<hmac>`.
5. If allowlist is enabled, sender login is present in `ALLOWED_SENDERS`.
6. `GITHUB_TOKEN` is set before using `github_reply`.

## 5) How to keep this skill current

Whenever you discover a new reliable test trick or runbook step:
1. Add it under the most relevant area above (A-D), not in a generic dump.
2. Include four things: **goal**, **exact command(s)**, **expected output**, **failure signal**.
3. Prefer copy-paste-safe commands that work in Cloud Agent terminals.
4. If the trick is temporary or incident-specific, add a short note with when to remove it.
