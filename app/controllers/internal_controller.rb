class InternalController < ApplicationController
  before_action :require_pdf_editor_session
  before_action :prevent_sensitive_caching

  # Caddy accepts only a 2xx response before proxying the original request to
  # Stirling. Any other response (including the sign-in redirect) is returned
  # to the browser instead.
  def pdf_editor_authorization
    audit_security_event("pdf_editor_access")
    head :no_content
  end

  private

  # Like require_authentication, but after sign-in send the user back to the
  # editor page Caddy was asked for (X-Forwarded-Uri), not to this subrequest.
  def require_pdf_editor_session
    return if authenticated?

    original = request.headers["X-Forwarded-Uri"].to_s
    session[:return_to] = (original.start_with?("/pdf-editor") && original.bytesize <= 2048) ? original : "/pdf-editor/"
    redirect_to new_session_path, alert: "Devam etmek için giriş yapın."
  end
end
