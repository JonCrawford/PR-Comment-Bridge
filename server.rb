#!/usr/bin/env ruby
# frozen_string_literal: true

require "mcp"
require_relative "lib/webhook_server"
require_relative "lib/tools/github_reply_tool"

module PRCommentBridge
  INSTRUCTIONS = <<~PROMPT
    Events from the github-webhook channel arrive as <channel source="github-webhook" ...>.
    Each event represents a GitHub webhook delivery: PR comments, code reviews, pull request updates, or issues.

    The meta attributes on the <channel> tag include:
    - event: the GitHub event type (issue_comment, pull_request_review, pull_request_review_comment, pull_request, issues)
    - action: the webhook action (created, submitted, opened, edited, etc.)
    - repo: the full repository name (owner/repo)
    - number: the PR or issue number
    - sender: the GitHub username who triggered the event
    - comment_id: the comment ID (for reply threading)
    - review_state: the review state (approved, changes_requested, commented) for review events
    - path: the file path for inline review comments
    - html_url: link to the comment/PR/review on GitHub

    When you receive a PR comment or review requesting changes:
    1. Read the comment carefully to understand what is being requested
    2. Look at the relevant code in the repository
    3. Make the requested changes
    4. Use the github_reply tool to post a response summarizing what you did

    When you receive a bug report:
    1. Analyze the issue description
    2. Investigate the codebase for the root cause
    3. Implement a fix
    4. Use the github_reply tool to post your findings and fix summary

    Reply using the github_reply tool, passing the repo and number from the tag attributes.
    For inline review comment replies, also pass the comment_id to thread the reply correctly.
  PROMPT

  def self.run
    port = Integer(ENV.fetch("WEBHOOK_PORT", "8789"))
    webhook_secret = ENV["GITHUB_WEBHOOK_SECRET"]
    webhook_secret = nil if webhook_secret&.empty?
    allowed_senders = ENV["ALLOWED_SENDERS"]&.split(",")&.map(&:strip)

    server = MCP::Server.new(
      name: "github-webhook",
      version: "0.1.0",
      instructions: INSTRUCTIONS,
      tools: [GitHubReplyTool],
      capabilities: {
        experimental: { "claude/channel" => {} },
        tools: { listChanged: true },
        logging: {},
      },
    )

    webhook = WebhookServer.new(
      server,
      port: port,
      webhook_secret: webhook_secret,
      allowed_senders: allowed_senders,
    )

    # Run the HTTP webhook server in a background thread
    webhook_thread = Thread.new do
      webhook.start
    rescue => e
      $stderr.puts "[PR-Comment-Bridge] Webhook server error: #{e.message}"
      $stderr.puts e.backtrace.first(5).join("\n")
    end

    # Handle graceful shutdown
    trap("INT") do
      webhook.shutdown
      exit(130)
    end
    trap("TERM") do
      webhook.shutdown
      exit(143)
    end

    # Connect to Claude Code over stdio (blocks reading from stdin)
    transport = MCP::Server::Transports::StdioTransport.new(server)
    server.transport = transport
    transport.open
  ensure
    webhook&.shutdown
    webhook_thread&.join(2)
  end
end

PRCommentBridge.run
