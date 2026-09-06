class NasController < ApplicationController
  before_action :require_authentication
  before_action :require_owner
  before_action :prevent_sensitive_caching
  rescue_from NasClient::Error, with: :nas_error

  def show
    @current_module = :nas
    @path = params[:path].presence || "/"
    @listing = NasClient.new.browse(path: @path, q: params[:q], sort: params[:sort], page: params[:page]) if NasClient.configured?
  end

  def download
    file = Tempfile.new(["nas-", ".download"], binmode: true)
    NasClient.new.download(params[:path].to_s, file: file)
    send_file file.path, filename: File.basename(params[:path].to_s), type: "application/octet-stream", disposition: "attachment"
    self.response_body = Rack::BodyProxy.new(response.stream) { file.close! }
  rescue
    file&.close!
    raise
  end

  def upload
    NasClient.new.upload(params[:path].to_s, params[:file])
    audit_security_event("nas_upload")
    redirect_to nas_path(path: params[:path]), notice: "Dosya yüklendi.", status: :see_other
  end

  def folder
    NasClient.new.mutate("folder", {path: params[:path], name: params[:name]})
    audit_security_event("nas_create_folder")
    redirect_to nas_path(path: params[:path]), notice: "Klasör oluşturuldu.", status: :see_other
  end

  def destroy
    NasClient.new.mutate("delete", {path: params[:path], confirmation: params[:confirmation]})
    audit_security_event("nas_delete")
    redirect_to nas_path(path: File.dirname(params[:path].to_s)), notice: "Öğe silindi.", status: :see_other
  end

  private

  def require_owner
    head :forbidden unless current_user&.owner?
  end

  def nas_error(error)
    if action_name == "show"
      @current_module = :nas
      @error = error.message
      render :show, status: :service_unavailable
    else
      redirect_to nas_path, alert: error.message, status: :see_other
    end
  end
end
