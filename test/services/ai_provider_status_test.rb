require "test_helper"

class AiProviderStatusTest < ActiveSupport::TestCase
  test "checks the configured model without putting the key in the URL" do
    request = nil
    http = Object.new
    http.define_singleton_method(:request) do |sent_request|
      request = sent_request
      Struct.new(:code, :body).new("200", "{}")
    end

    with_key("test-gemini-key") do
      Net::HTTP.stub(:start, ->(*_args, **_options, &block) { block.call(http) }) do
        assert AiProviderStatus.check(model: "gemini-3.6-flash").available?
      end
    end

    assert_equal "test-gemini-key", request["x-goog-api-key"]
    assert_not_includes request.path, "test-gemini-key"
  end

  test "distinguishes rejected keys, missing models, and quota" do
    with_key("test-gemini-key") do
      {"401" => :unauthorized, "404" => :model_missing, "429" => :quota}.each do |http_code, expected|
        http = Object.new
        http.define_singleton_method(:request) { |_request| Struct.new(:code, :body).new(http_code, "{}") }
        Net::HTTP.stub(:start, ->(*_args, **_options, &block) { block.call(http) }) do
          assert_equal expected, AiProviderStatus.check(model: "gemini-3.6-flash").code
        end
      end
    end
  end

  test "does not call Google with a missing key or unsafe model" do
    with_key(nil) { assert_equal :missing, AiProviderStatus.check(model: "gemini-3.6-flash").code }
    with_key("test-gemini-key") { assert_equal :model_missing, AiProviderStatus.check(model: "../other").code }
  end

  private

  def with_key(value)
    previous = ENV["GEMINI_API_KEY"]
    value.nil? ? ENV.delete("GEMINI_API_KEY") : ENV["GEMINI_API_KEY"] = value
    yield
  ensure
    previous.nil? ? ENV.delete("GEMINI_API_KEY") : ENV["GEMINI_API_KEY"] = previous
  end
end
