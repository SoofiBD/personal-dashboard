require "net/http"
require "json"
require "tempfile"

class NasClient
  class Error < StandardError; end
  MAX_BYTES = 256 * 1024 * 1024

  def self.configured?
    ENV["NAS_WORKER_URL"].present? && ENV["NAS_API_TOKEN"].to_s.length >= 32
  end

  def browse(path:, q: nil, sort: nil, page: nil)
    JSON.parse(perform("browse", query: {path: path, q: q, sort: sort, page: page}.compact))
  end

  def mutate(action, data)
    perform(action, data: data)
  end

  def upload(path, file)
    raise Error, "Dosya seçin (en fazla 256 MiB)." unless file.respond_to?(:tempfile) && file.size <= MAX_BYTES
    perform("upload", form: [["path", path], ["file", file.tempfile, {filename: file.original_filename}]])
  end

  def download(path, file: Tempfile.new(["nas-", ".download"], binmode: true))
    perform("download", query: {path: path}, output: file)
    file.rewind
    file
  rescue
    file.close!
    raise
  end

  private

  def perform(action, query: {}, data: nil, form: nil, output: nil)
    raise Error, "NAS bağlantısı henüz yapılandırılmadı." unless self.class.configured?
    uri = URI.parse(ENV.fetch("NAS_WORKER_URL"))
    raise Error, "NAS servis adresi geçersiz." unless %w[http https].include?(uri.scheme) && uri.host && !uri.userinfo
    uri.path = "/#{action}"
    uri.query = query.present? ? URI.encode_www_form(query) : nil
    req = (data || form) ? Net::HTTP::Post.new(uri) : Net::HTTP::Get.new(uri)
    req["Authorization"] = "Bearer #{ENV.fetch("NAS_API_TOKEN")}"
    if form
      req.set_form(form, "multipart/form-data")
    elsif data
      req["Content-Type"] = "application/json"
      req.body = JSON.generate(data)
    end
    body = +""
    bytes = 0
    Net::HTTP.start(uri.host, uri.port, nil, use_ssl: uri.scheme == "https", open_timeout: 3, read_timeout: 75, write_timeout: 75) do |http|
      http.request(req) do |response|
        unless response.is_a?(Net::HTTPSuccess)
          raise Error, case response.code
          when "400", "413" then "İstek geçersiz. Dosya yolunu, boyutunu ve silme onayını kontrol edin."
          when "409" then "Bu ad zaten var. Farklı bir dosya adı kullanın."
          else "NAS erişilemiyor. Bağlantıyı ve paylaşım izinlerini kontrol edin."
          end
        end
        response.read_body do |chunk|
          bytes += chunk.bytesize
          raise Error, "NAS yanıtı boyut sınırını aşıyor." if bytes > (output ? MAX_BYTES : 2 * 1024 * 1024)
          output ? output.write(chunk) : body << chunk
        end
      end
    end
    body
  rescue Error
    raise
  rescue => e
    Rails.logger.warn("NAS request failed (#{e.class.name})")
    raise Error, "NAS erişilemiyor. Bağlantıyı kontrol edip yeniden deneyin."
  end
end
