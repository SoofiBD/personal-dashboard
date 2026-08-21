module PersonalFinance
  class ApplicationController < ::ApplicationController
    before_action :require_panel_user
    before_action :ensure_onboarding_completed
    helper_method :current_panel_user

    private

    def current_panel_user
      @current_panel_user ||= PersonalFinance.current_user_for(self)
    end

    def require_panel_user
      return if current_panel_user

      raise ActionController::RoutingError, "Not Found"
    end

    def ensure_onboarding_completed
      return if controller_name == "onboarding"
      return if current_panel_user&.onboarded?

      redirect_to finance_onboarding_path
    end

    def owned(scope)
      scope.where(user_id: current_panel_user.id)
    end
  end
end
