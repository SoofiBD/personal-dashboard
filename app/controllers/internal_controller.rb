class InternalController < ApplicationController
  before_action :require_authentication
  before_action :prevent_sensitive_caching

  # Caddy accepts only a 2xx response before proxying the original request to
  # Stirling. Any other response (including the sign-in redirect) is returned
  # to the browser instead.
  def pdf_editor_authorization
    audit_security_event("pdf_editor_access")
    head :no_content
  end
end
