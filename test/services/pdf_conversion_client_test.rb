require "test_helper"

class PdfConversionClientTest < ActiveSupport::TestCase
  test "reads the worker key from a Docker secret file when no environment key is set" do
    secret = Tempfile.new("pdf-worker-key")
    secret.write("#{"a" * 32}\n")
    secret.close

    ENV.stub(:[], ->(name) { {"PDF_WORKER_API_KEY" => nil, "PDF_WORKER_API_KEY_FILE" => secret.path}[name] }) do
      client = PdfConversionClient.new
      assert_equal "a" * 32, client.instance_variable_get(:@api_key)
    end
  ensure
    secret&.unlink
  end

  test "prefers the environment key over the Docker secret file" do
    ENV.stub(:[], ->(name) { {"PDF_WORKER_API_KEY" => "environment-key", "PDF_WORKER_API_KEY_FILE" => "/not-used"}[name] }) do
      client = PdfConversionClient.new
      assert_equal "environment-key", client.instance_variable_get(:@api_key)
    end
  end
end
