module Notes
  class ApplicationController < ::ApplicationController
    before_action :prevent_sensitive_caching
    before_action :require_authentication
    before_action :require_notes_access

    private

    def require_notes_access
      return if request.get? || request.head? || current_user.can_manage_notes?

      redirect_to notes_root_path, alert: "Bu kullanıcı notları değiştiremez."
    end
  end
end
