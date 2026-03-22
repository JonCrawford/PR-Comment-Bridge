# frozen_string_literal: true

require "webrick"
require "json"
require "openssl"
require_relative "github_payload_parser"

module PRCommentBridge
  class WebhookServer
    CHANNEL_NOTIFICATION_METHOD = "notifications/claude/channel"

    def initialize(mcp_server, port:, webhook_secret: nil, allowed_senders: nil)
      @mcp_server = mcp_server
      @port = port
      @webhook_secret = webhook_secret
      @allowed_senders = allowed_senders
    end

    def start
      @http_server = WEBrick::HTTPServer.new(
        Port: @port,
        BindAddress: "127.0.0.1",
        Logger: WEBrick::Log.new($stderr, WEBrick::Log::WARN),
        AccessLog: [],
      )

      @http_server.mount_proc("/") do |req, res|
        handle_request(req, res)
      end

      @http_server.mount_proc("/health") do |_req, res|
        res.status = 200
        res.content_type = "application/json"
        res.body = JSON.generate({ status: "ok" })
      end

      $stderr.puts "[PR-Comment-Bridge] Webhook server listening on 127.0.0.1:#{@port}"
      @http_server.start
    end

    def shutdown
      @http_server&.shutdown
    end

    private

    def handle_request(req, res)
      unless req.request_method == "POST"
        res.status = 405
        res.body = "Method not allowed"
        return
      end

      body = req.body || ""

      if @webhook_secret && !verify_signature(body, req["X-Hub-Signature-256"])
        $stderr.puts "[PR-Comment-Bridge] Invalid webhook signature, rejecting request"
        res.status = 403
        res.body = "Invalid signature"
        return
      end

      event_type = req["X-GitHub-Event"]
      unless event_type
        res.status = 400
        res.body = "Missing X-GitHub-Event header"
        return
      end

      if event_type == "ping"
        res.status = 200
        res.content_type = "application/json"
        res.body = JSON.generate({ message: "pong" })
        return
      end

      begin
        payload = JSON.parse(body)
      rescue JSON::ParserError => e
        res.status = 400
        res.body = "Invalid JSON: #{e.message}"
        return
      end

      sender = payload.dig("sender", "login")
      if @allowed_senders && !@allowed_senders.include?(sender)
        $stderr.puts "[PR-Comment-Bridge] Sender '#{sender}' not in allowlist, dropping event"
        res.status = 403
        res.body = "Sender not allowed"
        return
      end

      content, meta = GitHubPayloadParser.parse(event_type, payload)
      send_channel_notification(content, meta)

      res.status = 200
      res.content_type = "application/json"
      res.body = JSON.generate({ received: true })
    rescue => e
      $stderr.puts "[PR-Comment-Bridge] Error handling webhook: #{e.message}"
      res.status = 500
      res.body = "Internal server error"
    end

    def send_channel_notification(content, meta)
      return unless @mcp_server.transport

      params = { "content" => content }
      params["meta"] = meta if meta && !meta.empty?

      @mcp_server.transport.send_notification(CHANNEL_NOTIFICATION_METHOD, params)
    end

    def verify_signature(body, signature_header)
      return false unless signature_header

      expected = "sha256=" + OpenSSL::HMAC.hexdigest("sha256", @webhook_secret, body)

      return false unless expected.bytesize == signature_header.bytesize

      left = expected.unpack("C*")
      right = signature_header.unpack("C*")
      left.zip(right).reduce(0) { |acc, (a, b)| acc | (a ^ b) }.zero?
    end
  end
end
