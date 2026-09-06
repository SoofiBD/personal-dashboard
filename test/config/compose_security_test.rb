require "test_helper"
require "yaml"

class ComposeSecurityTest < ActiveSupport::TestCase
  test "compose requires database credentials and keeps postgres internal" do
    source = Rails.root.join("compose.yaml").read
    compose = YAML.safe_load(source, aliases: true)

    assert_nil compose.dig("services", "db", "ports")
    assert_match(/POSTGRES_PASSWORD:\s*"\$\{POSTGRES_PASSWORD:\?/, source)
    assert_no_match(/POSTGRES_PASSWORD:\s*"\$\{POSTGRES_PASSWORD:-/, source)
    assert_no_match(/5432:5432/, source)
  end

  test "production proxy authenticates and bounds PDF editor requests" do
    source = Rails.root.join("config/stirling/Caddyfile.production").read

    assert_match(/forward_auth web:3000/, source)
    assert_match(%r{uri /internal/pdf_editor_authorization}, source)
    assert_match(/max_size 25MB/, source)
    assert_match(/X-Content-Type-Options/, source)
    assert_match(/output stdout/, source)
  end

  test "referrer policy preserves same-origin form request origins" do
    [
      Rails.root.join("config/stirling/Caddyfile"),
      Rails.root.join("config/stirling/Caddyfile.production"),
      Rails.root.join("config/environments/production.rb")
    ].each do |path|
      source = path.read

      assert_includes source, "strict-origin-when-cross-origin", path.to_s
      assert_not_includes source, "no-referrer", path.to_s
    end
  end

  test "production Rails workloads are immutable except for declared mounts" do
    source = Rails.root.join("compose.production.yaml").read

    assert_operator source.scan("read_only: true").length, :>=, 2
    assert_operator source.scan("cap_drop:").length, :>=, 3
  end
end
