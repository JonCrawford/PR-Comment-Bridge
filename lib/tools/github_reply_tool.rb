# frozen_string_literal: true

require "mcp"
require "net/http"
require "json"
require "uri"

module PRCommentBridge
  class GitHubReplyTool < MCP::Tool
    tool_name "github_reply"
    description "Post a comment on a GitHub pull request or issue. Use this to respond to PR comments, code reviews, or bug reports received through the webhook channel."

    input_schema(
      properties: {
        repo: {
          type: "string",
          description: 'Full repository name, e.g. "owner/repo"',
        },
        number: {
          type: "string",
          description: "The PR or issue number",
        },
        body: {
          type: "string",
          description: "The comment text to post (supports GitHub Markdown)",
        },
        comment_id: {
          type: "string",
          description: "If replying to a specific review comment, the comment ID to reply to. Omit for a top-level comment.",
        },
      },
      required: [:repo, :number, :body],
    )

    def self.call(repo:, number:, body:, comment_id: nil, server_context: nil)
      token = ENV["GITHUB_TOKEN"]
      unless token
        return MCP::Tool::Response.new(
          [{ type: "text", text: "Error: GITHUB_TOKEN environment variable is not set" }],
          error: true,
        )
      end

      begin
        if comment_id && !comment_id.empty?
          result = create_review_comment_reply(token, repo, number, comment_id, body)
        else
          result = create_issue_comment(token, repo, number, body)
        end

        MCP::Tool::Response.new([{ type: "text", text: "Comment posted: #{result["html_url"]}" }])
      rescue => e
        MCP::Tool::Response.new(
          [{ type: "text", text: "Error posting comment: #{e.message}" }],
          error: true,
        )
      end
    end

    class << self
      private

      def create_issue_comment(token, repo, number, body)
        uri = URI("https://api.github.com/repos/#{repo}/issues/#{number}/comments")
        github_post(uri, token, { body: body })
      end

      def create_review_comment_reply(token, repo, number, comment_id, body)
        uri = URI("https://api.github.com/repos/#{repo}/pulls/#{number}/comments/#{comment_id}/replies")
        github_post(uri, token, { body: body })
      end

      def github_post(uri, token, payload)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true

        request = Net::HTTP::Post.new(uri)
        request["Authorization"] = "Bearer #{token}"
        request["Accept"] = "application/vnd.github+json"
        request["X-GitHub-Api-Version"] = "2022-11-28"
        request["Content-Type"] = "application/json"
        request.body = JSON.generate(payload)

        response = http.request(request)

        unless response.is_a?(Net::HTTPSuccess)
          raise "GitHub API returned #{response.code}: #{response.body}"
        end

        JSON.parse(response.body)
      end
    end
  end
end
