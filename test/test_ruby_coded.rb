# frozen_string_literal: true

require "test_helper"
require "ruby_coded/version"

class TestRubyCoded < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::RubyCoded::VERSION
  end

  def test_version_is_a_string
    assert_instance_of String, RubyCoded::VERSION
  end

  def test_version_follows_semver_format
    assert_match(/\A\d+\.\d+\.\d+\z/, RubyCoded::VERSION)
  end

  def test_gem_version_returns_gem_version_object
    assert_instance_of Gem::Version, RubyCoded.gem_version
  end

  def test_gem_version_matches_version_constant
    assert_equal Gem::Version.new(RubyCoded::VERSION), RubyCoded.gem_version
  end
end
