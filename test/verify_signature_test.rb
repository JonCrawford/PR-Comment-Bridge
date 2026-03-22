# frozen_string_literal: true

require "minitest/autorun"
require "openssl"
require_relative "../lib/webhook_server"

class VerifySignatureTest < Minitest::Test
  SECRET = "test_secret_key"

  def setup
    @server = PRCommentBridge::WebhookServer.new(
      nil,
      port: 0,
      webhook_secret: SECRET,
    )
  end

  def test_valid_signature
    body = '{"action":"opened"}'
    signature = sign(body)

    assert @server.send(:verify_signature, body, signature)
  end

  def test_wrong_signature
    body = '{"action":"opened"}'
    signature = "sha256=deadbeef" + "0" * 56

    refute @server.send(:verify_signature, body, signature)
  end

  def test_nil_signature_header
    refute @server.send(:verify_signature, '{"action":"opened"}', nil)
  end

  def test_tampered_body
    body = '{"action":"opened"}'
    signature = sign(body)

    refute @server.send(:verify_signature, '{"action":"closed"}', signature)
  end

  def test_empty_body
    body = ""
    signature = sign(body)

    assert @server.send(:verify_signature, body, signature)
  end

  private

  def sign(body)
    "sha256=" + OpenSSL::HMAC.hexdigest("sha256", SECRET, body)
  end
end
