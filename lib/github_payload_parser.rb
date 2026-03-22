# frozen_string_literal: true

module PRCommentBridge
  module GitHubPayloadParser
    module_function

    def parse(event_type, payload)
      case event_type
      when "issue_comment"
        parse_issue_comment(payload)
      when "pull_request_review"
        parse_pull_request_review(payload)
      when "pull_request_review_comment"
        parse_review_comment(payload)
      when "pull_request"
        parse_pull_request(payload)
      when "issues"
        parse_issue(payload)
      else
        parse_generic(event_type, payload)
      end
    end

    def common_attributes(payload)
      {
        repo: payload.dig("repository", "full_name") || "unknown",
        sender: payload.dig("sender", "login") || "unknown",
        action: payload["action"],
      }
    end

    def parse_issue_comment(payload)
      repo, sender, action = common_attributes(payload).values_at(:repo, :sender, :action)
      comment = payload["comment"] || {}
      issue = payload["issue"] || {}
      is_pr = issue.key?("pull_request")

      content = <<~MSG.strip
        #{is_pr ? "PR" : "Issue"} comment #{action} by #{sender} on #{repo}##{issue["number"]}
        Title: #{issue["title"]}
        Comment: #{comment["body"]}
      MSG

      meta = {
        "event" => "issue_comment",
        "action" => action,
        "repo" => repo,
        "number" => issue["number"].to_s,
        "sender" => sender,
        "comment_id" => comment["id"].to_s,
        "is_pull_request" => is_pr.to_s,
        "html_url" => comment["html_url"].to_s,
      }

      [content, meta]
    end

    def parse_pull_request_review(payload)
      repo, sender, action = common_attributes(payload).values_at(:repo, :sender, :action)
      review = payload["review"] || {}
      pr = payload["pull_request"] || {}
      state = review["state"] || "unknown"

      content = <<~MSG.strip
        PR review #{action} by #{sender} on #{repo}##{pr["number"]}
        Title: #{pr["title"]}
        Review state: #{state}
        Review body: #{review["body"]}
      MSG

      meta = {
        "event" => "pull_request_review",
        "action" => action,
        "repo" => repo,
        "number" => pr["number"].to_s,
        "sender" => sender,
        "review_id" => review["id"].to_s,
        "review_state" => state,
        "html_url" => review["html_url"].to_s,
      }

      [content, meta]
    end

    def parse_review_comment(payload)
      repo, sender, action = common_attributes(payload).values_at(:repo, :sender, :action)
      comment = payload["comment"] || {}
      pr = payload["pull_request"] || {}

      content = <<~MSG.strip
        PR inline review comment #{action} by #{sender} on #{repo}##{pr["number"]}
        Title: #{pr["title"]}
        File: #{comment["path"]}#{comment["line"] ? " line #{comment["line"]}" : ""}
        Diff hunk:
        #{comment["diff_hunk"]}
        Comment: #{comment["body"]}
      MSG

      meta = {
        "event" => "pull_request_review_comment",
        "action" => action,
        "repo" => repo,
        "number" => pr["number"].to_s,
        "sender" => sender,
        "comment_id" => comment["id"].to_s,
        "path" => comment["path"].to_s,
        "html_url" => comment["html_url"].to_s,
      }

      [content, meta]
    end

    def parse_pull_request(payload)
      repo, sender, action = common_attributes(payload).values_at(:repo, :sender, :action)
      pr = payload["pull_request"] || {}

      content = <<~MSG.strip
        Pull request #{action} by #{sender} on #{repo}##{pr["number"]}
        Title: #{pr["title"]}
        Body: #{pr["body"]}
        Head: #{pr.dig("head", "ref")} Base: #{pr.dig("base", "ref")}
      MSG

      meta = {
        "event" => "pull_request",
        "action" => action,
        "repo" => repo,
        "number" => pr["number"].to_s,
        "sender" => sender,
        "html_url" => pr["html_url"].to_s,
      }

      [content, meta]
    end

    def parse_issue(payload)
      repo, sender, action = common_attributes(payload).values_at(:repo, :sender, :action)
      issue = payload["issue"] || {}

      content = <<~MSG.strip
        Issue #{action} by #{sender} on #{repo}##{issue["number"]}
        Title: #{issue["title"]}
        Body: #{issue["body"]}
      MSG

      meta = {
        "event" => "issues",
        "action" => action,
        "repo" => repo,
        "number" => issue["number"].to_s,
        "sender" => sender,
        "html_url" => issue["html_url"].to_s,
      }

      [content, meta]
    end

    def parse_generic(event_type, payload)
      repo, sender, action = common_attributes(payload).values_at(:repo, :sender, :action)
      action ||= "triggered"

      content = <<~MSG.strip
        GitHub event "#{event_type}" #{action} by #{sender} on #{repo}
        Payload keys: #{payload.keys.join(", ")}
      MSG

      meta = {
        "event" => event_type,
        "action" => action,
        "repo" => repo,
        "sender" => sender,
      }

      [content, meta]
    end
  end
end
