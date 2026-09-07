require "net/http"

class DatabaseToolsController < ApplicationController
  before_action :require_authentication
  before_action :prevent_sensitive_caching
  # Loaded by a same-origin script tag; authentication still runs for every GET.
  skip_after_action :verify_same_origin_request, only: :configuration

  def show
    @available = begin
      response = Net::HTTP.start("chartdb", 80, open_timeout: 1, read_timeout: 1) { |http| http.get("/health") }
      response.is_a?(Net::HTTPSuccess) && response.body == "OK"
    rescue SocketError, SystemCallError, Timeout::Error, IOError
      false
    end
  end

  def configuration
    response.headers["Cross-Origin-Resource-Policy"] = "same-origin"
    render js: "window.env = {HIDE_CHARTDB_CLOUD: 'true', DISABLE_ANALYTICS: 'true'}; document.documentElement.dataset.dashboardUser = '#{current_user.id}';"
  end
end
