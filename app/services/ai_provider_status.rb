# frozen_string_literal: true

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
    bad_request: "Gemini isteği reddetti. Model ayarını kontrol edip tekrar deneyin.",
    unavailable: "Gemini bağlantısı şu anda doğrulanamadı. Biraz sonra tekrar deneyin."
  }.freeze

  def self.check(model:)
    AiGeminiClient.generate(
      model: model,
      body: {contents: [{role: "user", parts: [{text: "Reply with OK."}]}], generationConfig: {maxOutputTokens: 8}},
      read_timeout: 10
    )
    result(:ok)
  rescue AiGeminiClient::Error => error
    Rails.logger.warn(event: "ai_provider_check_failed", code: error.code, detail: error.message) unless error.code == :missing
    result(error.code)
  end

  def self.result(code)
    Result.new(code: code, message: MESSAGES.fetch(code))
  end
  private_class_method :result
end
