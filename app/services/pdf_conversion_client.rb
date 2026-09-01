require "net/http"
require "json"
require "base64"
require "stringio"

class PdfConversionClient
  class Error < StandardError; end

  MAX_PDF_SIZE = 25.megabytes
  MAX_MARKDOWN_SIZE = 10.megabytes

  def initialize(base_url: ENV.fetch("PDF_WORKER_URL", "http://pdf-worker:8000"))
    @base_uri = URI(base_url)
  end

  def convert(pdf_data:, filename:, custom_notes:, annotation_mode:, conversion_options: {})
    validate_pdf!(pdf_data, filename)
    raise Error, "Geçersiz anotasyon modu." unless %w[section inline both].include?(annotation_mode)

    request = Net::HTTP::Post.new(endpoint("/convert"))
    request.set_form(
      [
        ["file", StringIO.new(pdf_data), {filename: safe_filename(filename), content_type: "application/pdf"}],
        ["custom_notes", custom_notes.to_s],
        ["annotation_mode", annotation_mode],
        *conversion_options.map { |key, value| [key.to_s, value.to_s] }
      ],
      "multipart/form-data"
    )

    response = http.request(request)
    raise Error, "PDF dönüştürme servisi şu anda kullanılamıyor." unless response.is_a?(Net::HTTPSuccess)

    body = JSON.parse(response.body)
    raise Error, "PDF dönüştürme servisi geçersiz bir yanıt verdi." unless body["markdown_content"].is_a?(String)

    {
      markdown_content: body.fetch("markdown_content"),
      processing_stats: body.fetch("stats", {}),
      assets: body.fetch("images", [])
    }
  rescue JSON::ParserError
    raise Error, "PDF dönüştürme servisi geçersiz bir yanıt verdi."
  rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNREFUSED
    raise Error, "PDF dönüştürme servisine bağlanılamadı. Lütfen kısa süre sonra tekrar deneyin."
  end

  def export_zip(markdown_content:, source_filename:, assets:)
    raise Error, "Markdown çıktısı çok büyük." if markdown_content.to_s.bytesize > MAX_MARKDOWN_SIZE

    request = Net::HTTP::Post.new(endpoint("/export-zip"))
    request["Content-Type"] = "application/json"
    request.body = JSON.generate(
      markdown_content: markdown_content,
      source_filename: safe_filename(source_filename),
      images: assets.map { |asset| {filename: asset.filename, data_base64: Base64.strict_encode64(asset.binary_data)} }
    )
    response = http.request(request)
    raise Error, "ZIP dışa aktarma servisi şu anda kullanılamıyor." unless response.is_a?(Net::HTTPSuccess)

    response.body
  rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNREFUSED
    raise Error, "ZIP dışa aktarma servisine bağlanılamadı. Lütfen kısa süre sonra tekrar deneyin."
  end

  def export_html(markdown_content:, source_filename:, assets:)
    raise Error, "Markdown çıktısı çok büyük." if markdown_content.to_s.bytesize > MAX_MARKDOWN_SIZE

    request = Net::HTTP::Post.new(endpoint("/export-html"))
    request["Content-Type"] = "application/json"
    request.body = JSON.generate(
      markdown_content: markdown_content,
      source_filename: safe_filename(source_filename),
      images: assets.map { |asset| {filename: asset.filename, data_base64: Base64.strict_encode64(asset.binary_data)} }
    )
    response = http.request(request)
    raise Error, "HTML dışa aktarma servisi şu anda kullanılamıyor." unless response.is_a?(Net::HTTPSuccess)

    response.body
  rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNREFUSED
    raise Error, "HTML dışa aktarma servisine bağlanılamadı."
  end

  private

  def validate_pdf!(pdf_data, filename)
    raise Error, "Lütfen bir PDF dosyası seçin." if pdf_data.blank?
    raise Error, "PDF dosyası en fazla 25 MB olabilir." if pdf_data.bytesize > MAX_PDF_SIZE
    raise Error, "Yalnızca PDF dosyaları kabul edilir." unless File.extname(filename.to_s).casecmp?(".pdf")
    raise Error, "Yüklenen dosya geçerli bir PDF görünmüyor." unless pdf_data.start_with?("%PDF-")
  end

  def endpoint(path)
    @base_uri + path
  end

  def http
    Net::HTTP.start(@base_uri.host, @base_uri.port, open_timeout: 5, read_timeout: 60)
  end

  def safe_filename(filename)
    File.basename(filename.to_s).presence || "document.pdf"
  end
end
