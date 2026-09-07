class InternalController < ApplicationController
  before_action :require_authentication, except: :database_editor_authorization
  before_action :require_database_editor_authentication, only: :database_editor_authorization
  before_action :prevent_sensitive_caching

  # Caddy accepts only a 2xx response before proxying the original request to
  # Stirling. Any other response (including the sign-in redirect) is returned
  # to the browser instead.
  def database_editor_authorization
    head :no_content
  end

  def pdf_editor_authorization
    audit_security_event("pdf_editor_access")
    head :no_content
  end

  private

  def require_database_editor_authentication
    return if authenticated?

    session[:return_to] = database_tools_path
    redirect_to new_session_path
  end
end
