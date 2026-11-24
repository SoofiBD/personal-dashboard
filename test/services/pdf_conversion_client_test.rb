require "test_helper"
require "minitest/mock"

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

  test "surfaces worker validation messages and hides other failures" do
    client = PdfConversionClient.new(base_url: "http://pdf-worker.test:8000", api_key: "k" * 32)
    unprocessable = Net::HTTPUnprocessableEntity.new("1.1", "422", "Unprocessable")
    unprocessable.instance_variable_set(:@read, true)
    unprocessable.body = {detail: "PDF dönüştürülemedi."}.to_json

    Net::HTTP.stub(:start, ->(*, **) { unprocessable }) do
      error = assert_raises(PdfConversionClient::Error) { client.export(:zip, markdown_content: "# A", source_filename: "a.pdf", assets: []) }
      assert_equal "PDF dönüştürülemedi.", error.message
    end

    Net::HTTP.stub(:start, ->(*) { raise Errno::ECONNREFUSED }) do
      error = assert_raises(PdfConversionClient::Error) { client.export(:html, markdown_content: "# A", source_filename: "a.pdf", assets: []) }
      assert_equal PdfConversionClient::UNAVAILABLE, error.message
    end
  end
end
