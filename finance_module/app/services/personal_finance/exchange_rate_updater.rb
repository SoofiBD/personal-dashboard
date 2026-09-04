require "json"
require "net/http"

module PersonalFinance
  class ExchangeRateUpdater
    API_URL = "https://api.frankfurter.dev/v2/rates".freeze

    def initialize(fetcher: nil)
      @fetcher = fetcher || method(:fetch_body)
      @rates = {}
    end

    def call
      User.find_each { |user| update_for(user) }
    end

    private

    def update_for(user)
      quote_currency = user.currency.to_s.upcase
      Account.where(user: user).distinct.pluck(:currency).map(&:upcase).uniq.each do |base_currency|
        next if base_currency == quote_currency

        rate = rate_for(base_currency, quote_currency)
        next unless rate&.positive?

        ExchangeRate.find_or_initialize_by(user: user, base_currency: base_currency, quote_currency: quote_currency).update!(rate: rate)
      rescue => error
        Rails.logger.warn("Exchange rate update skipped for #{user.id} #{base_currency}/#{quote_currency}: #{error.message}")
      end
    end

    def rate_for(base_currency, quote_currency)
      @rates.fetch([base_currency, quote_currency]) do
        body = @fetcher.call(api_uri(base_currency, quote_currency))
        entry = JSON.parse(body).find { |item| item["base"] == base_currency && item["quote"] == quote_currency }
        @rates[[base_currency, quote_currency]] = entry&.fetch("rate", nil)&.to_d
      rescue JSON::ParserError, KeyError
        @rates[[base_currency, quote_currency]] = nil
      end
    end

    def api_uri(base_currency, quote_currency)
      URI("#{API_URL}?#{URI.encode_www_form(base: base_currency, quotes: quote_currency)}")
    end

    def fetch_body(uri)
      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 10) { |http| http.get(uri.request_uri) }
      raise "Frankfurter returned #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      response.body
    end
  end
end
