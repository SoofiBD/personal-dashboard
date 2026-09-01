require "net/http"

module PersonalFinance
  class PdfToolsController < ApplicationController
    def show
      @stirling_available = stirling_available?
    end

    private

    def stirling_available?
      uri = URI(ENV.fetch("STIRLING_PDF_STATUS_URL", "http://stirling-pdf:8080/pdf-editor/api/v1/info/status"))
      response = Net::HTTP.start(uri.host, uri.port, open_timeout: 1, read_timeout: 1) do |http|
        http.get(uri.request_uri)
      end
      response.is_a?(Net::HTTPSuccess) && response.body.include?("UP")
    rescue URI::InvalidURIError, SocketError, Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNREFUSED
      false
    end
  end
end
