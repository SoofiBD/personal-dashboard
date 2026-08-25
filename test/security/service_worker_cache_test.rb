require "test_helper"

class ServiceWorkerCacheTest < ActiveSupport::TestCase
  test "service worker does not cache personalized finance html" do
    source = Rails.root.join("public/service-worker.js").read

    assert_no_match(/APP_SHELL\s*=.*\/finance/, source)
    assert_includes source, "/offline.html"
    assert_includes source, "personal-finance-shell-v2"
  end
end
