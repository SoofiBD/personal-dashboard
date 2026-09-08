require "json"
require "net/http"

module Ai
  class JanClient
    class Error < StandardError; end

    DEFAULT_BASE_URL = "http://127.0.0.1:1337"

    def initialize(base_url: ENV.fetch("JAN_API_BASE_URL", DEFAULT_BASE_URL))
      @base_uri = URI.parse(base_url)
      validate_base_uri!
    rescue URI::InvalidURIError
      raise Error, "JAN_API_BASE_URL geçerli bir HTTP(S) adresi olmalıdır."
    end

    def models
      response = request("/v1/models")
      payload = JSON.parse(response.body)
      entries = payload.fetch("data")
      raise Error, "Jan model listesi geçersiz bir yanıt verdi." unless entries.is_a?(Array)

      entries.filter_map { |entry| entry["id"] if entry.is_a?(Hash) && entry["id"].is_a?(String) }.sort
    rescue JSON::ParserError, KeyError
      raise Error, "Jan model listesi geçersiz bir yanıt verdi."
    end

    def health
      model_ids = models
      {connected: true, models: model_ids}
    rescue Error => e
      {connected: false, models: [], error: e.message}
    end

    def base_url
      @base_uri.to_s.delete_suffix("/")
    end

    private

    def request(path)
      uri = @base_uri + path
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 2, read_timeout: 4) do |http|
        http.get(uri.request_uri)
      end
      raise Error, "Jan şu anda yanıt vermiyor." unless response.is_a?(Net::HTTPSuccess)

      response
    rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNREFUSED, Errno::EHOSTUNREACH
      raise Error, "Jan'a bağlanılamadı. Uygulamanın açık olduğunu ve yerel API sunucusunun çalıştığını kontrol edin."
    end

    def validate_base_uri!
      unless @base_uri.is_a?(URI::HTTP) && @base_uri.host.present? && @base_uri.userinfo.nil?
        raise Error, "JAN_API_BASE_URL geçerli bir HTTP(S) adresi olmalıdır."
      end
    end
  end
end
