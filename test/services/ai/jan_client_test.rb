require "test_helper"

class Ai::JanClientTest < ActiveSupport::TestCase
  test "lists valid model ids from Jan's OpenAI compatible endpoint" do
    response = Net::HTTPOK.new("1.1", "200", "OK")
    response.define_singleton_method(:body) { {data: [{id: "qwen3-4b"}, {id: "gemma-3-4b"}, {name: "ignored"}]}.to_json }
    http = Object.new
    http.define_singleton_method(:get) { |_path| response }

    with_http_start(->(*_args, **_options, &block) { block.call(http) }) do
      assert_equal %w[gemma-3-4b qwen3-4b], Ai::JanClient.new(base_url: "http://jan:1337").models
    end
  end

  test "returns a safe unavailable status when Jan cannot be reached" do
    with_http_start(->(*_args, **_options, &_block) { raise Errno::ECONNREFUSED }) do
      health = Ai::JanClient.new(base_url: "http://jan:1337").health
      refute health[:connected]
      assert_empty health[:models]
      assert_includes health[:error], "Jan'a bağlanılamadı"
    end
  end

  test "rejects invalid configured endpoints before requesting them" do
    error = assert_raises(Ai::JanClient::Error) { Ai::JanClient.new(base_url: "file:///etc/passwd") }
    assert_includes error.message, "HTTP(S)"
  end

  private

  def with_http_start(replacement)
    original = Net::HTTP.method(:start)
    Net::HTTP.define_singleton_method(:start, replacement)
    yield
  ensure
    Net::HTTP.define_singleton_method(:start, original)
  end
end
