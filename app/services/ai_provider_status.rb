# frozen_string_literal: true

require "net/http"

class AiProviderStatus
  Result = Data.define(:code, :message) do
    def available?
      code == :ok
    end
  end

  MESSAGES = {
    ok: "Gemini bağlantısı çalışıyor.",
    missing: "Gemini API anahtarı sunucuda yapılandırılmamış.",
    unauthorized: "Gemini API anahtarı Google tarafından reddedildi. AI Studio'da anahtarı kontrol edin.",
    forbidden: "Gemini erişimi bu anahtar veya proje için kapalı. AI Studio'daki izinleri kontrol edin.",
    model_missing: "Seçilen Gemini modeli bulunamadı. Sağlayıcı ve model ayarını kontrol edin.",
    quota: "Gemini kullanım sınırına ulaşıldı. Google AI Studio'da kotayı kontrol edin.",
    unavailable: "Gemini bağlantısı şu anda doğrulanamadı. Biraz sonra tekrar deneyin."
  }.freeze

  def self.check(model:)
    key = ENV["GEMINI_API_KEY"].presence
    return result(:missing) unless key
    return result(:model_missing) unless model.to_s.match?(/\A[a-zA-Z0-9._-]+\z/)

    uri = URI("https://generativelanguage.googleapis.com/v1beta/models/#{model}:generateContent")
    request = Net::HTTP::Post.new(uri)
    request["x-goog-api-key"] = key
    request.content_type = "application/json"
    request.body = {contents: [{parts: [{text: "Reply with OK."}]}], generationConfig: {maxOutputTokens: 8}}.to_json

    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 3, read_timeout: 10) do |http|
      http.request(request)
    end

    case response.code.to_i
    when 200 then result(:ok)
    when 401 then result(:unauthorized)
    when 400 then response.body.to_s.include?("API_KEY_INVALID") ? result(:unauthorized) : result(:unavailable)
    when 403 then result(:forbidden)
    when 404 then result(:model_missing)
    when 429 then result(:quota)
    else
      Rails.logger.warn(event: "ai_provider_check_failed", status: response.code.to_i)
      result(:unavailable)
    end
  rescue SocketError, IOError, SystemCallError, Timeout::Error, OpenSSL::SSL::SSLError => error
    Rails.logger.warn(event: "ai_provider_check_failed", error_class: error.class.name)
    result(:unavailable)
  end

  def self.result(code)
    Result.new(code: code, message: MESSAGES.fetch(code))
  end
  private_class_method :result
end
