require "net/http"
require "json"
require "base64"
require "stringio"

# HTTP client for pdf_worker. The contract is documented in pdf_worker/README.md;
# the worker validates every input itself, so this client only transports.
class PdfConversionClient
  class Error < StandardError; end

  UNAVAILABLE = "PDF servisine bağlanılamadı. Lütfen kısa süre sonra tekrar deneyin."

  def initialize(base_url: ENV.fetch("PDF_WORKER_URL", "http://pdf-worker:8000"), api_key: worker_api_key)
    @base_uri = URI(base_url)
    @api_key = api_key
  end

  def convert(pdf_data:, filename:, custom_notes:, annotation_mode:, conversion_options: {})
    request = Net::HTTP::Post.new(@base_uri + "/convert")
    request.set_form(
      [
        ["file", StringIO.new(pdf_data), {filename: File.basename(filename.to_s), content_type: "application/pdf"}],
        ["custom_notes", custom_notes.to_s],
        ["annotation_mode", annotation_mode],
        *conversion_options.map { |key, value| [key.to_s, value.to_s] }
      ],
      "multipart/form-data"
    )
    body = JSON.parse(perform(request))
    raise Error, "PDF dönüştürme servisi geçersiz bir yanıt verdi." unless body["markdown_content"].is_a?(String)

    {markdown_content: body["markdown_content"], processing_stats: body.fetch("stats", {}), assets: body.fetch("images", [])}
  rescue JSON::ParserError
    raise Error, "PDF dönüştürme servisi geçersiz bir yanıt verdi."
  end

  # format: :zip or :html
  def export(format, markdown_content:, source_filename:, assets:)
    request = Net::HTTP::Post.new(@base_uri + "/export-#{format}")
    request["Content-Type"] = "application/json"
    request.body = JSON.generate(
      markdown_content: markdown_content.to_s,
      source_filename: File.basename(source_filename.to_s),
      images: assets.map { |asset| {filename: asset.filename, data_base64: Base64.strict_encode64(asset.binary_data)} }
    )
    perform(request)
  end

  def crop_image(asset:, bounds:)
    request = Net::HTTP::Post.new(@base_uri + "/crop-image")
    request.set_form([
      ["file", StringIO.new(asset.file.download), {filename: asset.filename, content_type: asset.content_type}],
      *bounds.map { |key, value| [key.to_s, value.to_s] }
    ], "multipart/form-data")
    perform(request)
  end

  private

  # Returns the response body. 413/422 details from the worker are
  # user-facing Turkish strings; anything else gets a generic message.
  def perform(request)
    request["Authorization"] = "Bearer #{@api_key}" if @api_key
    response = Net::HTTP.start(@base_uri.host, @base_uri.port, open_timeout: 5, read_timeout: 180) { |http| http.request(request) }
    return response.body if response.is_a?(Net::HTTPSuccess)

    detail = begin
      JSON.parse(response.body.to_s)["detail"]
    rescue JSON::ParserError
      nil
    end
    raise Error, (detail.is_a?(String) && %w[413 422].include?(response.code)) ? detail.truncate(300) : UNAVAILABLE
  rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, SystemCallError, IOError
    raise Error, UNAVAILABLE
  end

  # Docker secrets are mounted as files in production.  Keep the environment
  # variable as the first choice so local development remains straightforward.
  def worker_api_key
    ENV["PDF_WORKER_API_KEY"].presence || read_secret_file(ENV["PDF_WORKER_API_KEY_FILE"])
  end

  def read_secret_file(path)
    return if path.blank? || !File.file?(path)

    File.read(path).strip.presence
  end
end
