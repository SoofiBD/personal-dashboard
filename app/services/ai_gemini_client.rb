# frozen_string_literal: true

require "net/http"

# One Gemini generateContent request over stdlib HTTP. Failures raise Error with a
# code that AiProviderStatus::MESSAGES turns into a user-facing message.
class AiGeminiClient
  class Error < StandardError
    attr_reader :code

    def initialize(code, detail = code.to_s)
      @code = code
      super(detail)
    end
  end

  MODEL_FORMAT = /\A[a-zA-Z0-9._-]+\z/

  def self.generate(model:, body:, read_timeout: 60)
    key = ENV["GEMINI_API_KEY"].presence
    raise Error.new(:missing) unless key
    raise Error.new(:model_missing) unless model.to_s.match?(MODEL_FORMAT)

    uri = URI("https://generativelanguage.googleapis.com/v1beta/models/#{model}:generateContent")
    request = Net::HTTP::Post.new(uri)
    request["x-goog-api-key"] = key
    request.content_type = "application/json"
    request.body = body.to_json

    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: read_timeout) do |http|
      http.request(request)
    end
    return JSON.parse(response.body) if response.code.to_i == 200

    raise Error.new(error_code(response), "Gemini HTTP #{response.code}: #{response.body.to_s.first(500)}")
  rescue SocketError, IOError, SystemCallError, Timeout::Error, OpenSSL::SSL::SSLError, JSON::ParserError => error
    raise Error.new(:unavailable, error.class.name)
  end

  def self.error_code(response)
    case response.code.to_i
    when 400 then response.body.to_s.include?("API_KEY_INVALID") ? :unauthorized : :bad_request
    when 401 then :unauthorized
    when 403 then :forbidden
    when 404 then :model_missing
    when 429 then :quota
    else :unavailable
    end
  end
  private_class_method :error_code
end
