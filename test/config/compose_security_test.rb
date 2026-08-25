require "test_helper"
require "yaml"

class ComposeSecurityTest < ActiveSupport::TestCase
  test "compose requires database credentials and keeps postgres internal" do
    source = Rails.root.join("compose.yaml").read
    compose = YAML.safe_load(source, aliases: true)

    assert_nil compose.dig("services", "db", "ports")
    assert_match(/POSTGRES_PASSWORD:\s*\"\$\{POSTGRES_PASSWORD:\?/, source)
    assert_no_match(/POSTGRES_PASSWORD:\s*\"\$\{POSTGRES_PASSWORD:-/, source)
    assert_no_match(/5432:5432/, source)
  end
end
