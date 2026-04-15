# frozen_string_literal: true

require "test_helper"
require "securerandom"
require "base64"
require "digest"
require "ruby_coded/auth/pkce"

class TestPKCE < Minitest::Test
  def setup
    @result = RubyCoded::Auth::PKCE.generate
  end

  def test_generate_returns_a_hash
    assert_instance_of Hash, @result
  end

  def test_generate_includes_verifier_key
    assert_includes @result.keys, :verifier
  end

  def test_generate_includes_challenge_key
    assert_includes @result.keys, :challenge
  end

  def test_verifier_is_a_string
    assert_instance_of String, @result[:verifier]
  end

  def test_challenge_is_a_string
    assert_instance_of String, @result[:challenge]
  end

  def test_verifier_is_not_empty
    refute_empty @result[:verifier]
  end

  def test_challenge_is_not_empty
    refute_empty @result[:challenge]
  end

  def test_challenge_matches_sha256_of_verifier
    expected = Base64.urlsafe_encode64(
      Digest::SHA256.digest(@result[:verifier]),
      padding: false
    )
    assert_equal expected, @result[:challenge]
  end

  def test_challenge_is_base64url_without_padding
    refute_includes @result[:challenge], "="
    assert_match(/\A[A-Za-z0-9_-]+\z/, @result[:challenge])
  end

  def test_verifier_is_url_safe
    assert_match(/\A[A-Za-z0-9_-]+={0,2}\z/, @result[:verifier])
  end

  def test_each_call_generates_unique_values
    other = RubyCoded::Auth::PKCE.generate
    refute_equal @result[:verifier], other[:verifier]
    refute_equal @result[:challenge], other[:challenge]
  end
end
