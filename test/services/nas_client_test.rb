require "test_helper"
require "minitest/mock"

class NasClientTest < ActiveSupport::TestCase
  setup do
    @old_url = ENV["NAS_WORKER_URL"]
    @old_token = ENV["NAS_API_TOKEN"]
    ENV["NAS_WORKER_URL"] = "http://nas-worker:8000"
    ENV["NAS_API_TOKEN"] = "t" * 40
  end

  teardown do
    ENV["NAS_WORKER_URL"] = @old_url
    ENV["NAS_API_TOKEN"] = @old_token
  end

  test "download writes chunks to temporary file and sends service auth" do
    response = Net::HTTPOK.new("1.1", "200", "OK")
    response.define_singleton_method(:read_body) { |&block|
      block.call("abc")
      block.call("def")
    }
    http = Object.new
    captured = []
    http.define_singleton_method(:request) { |request, &block|
      captured << request
      block.call(response)
    }
    Net::HTTP.stub :start, ->(*args, **options, &block) { block.call(http) } do
      file = NasClient.new.download("/backup.txt")
      begin
        assert_equal "abcdef", file.read
        assert_equal "Bearer #{ENV.fetch("NAS_API_TOKEN")}", captured.first["Authorization"]
        assert_equal "/download?path=%2Fbackup.txt", captured.first.path
      ensure
        file.close!
      end
    end
  end

  test "upstream failure cannot disclose response credentials" do
    response = Net::HTTPForbidden.new("1.1", "403", "secret-details")
    http = Object.new
    http.define_singleton_method(:request) { |request, &block| block.call(response) }
    Net::HTTP.stub :start, ->(*args, **options, &block) { block.call(http) } do
      error = assert_raises(NasClient::Error) { NasClient.new.browse(path: "/") }
      refute_includes error.message, "secret-details"
    end
  end

  test "unconfigured adapter fails before network access" do
    ENV.delete("NAS_API_TOKEN")
    assert_raises(NasClient::Error) { NasClient.new.browse(path: "/") }
  end
end
