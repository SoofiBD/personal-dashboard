module PersonalGym
  class ApplicationController < ::ApplicationController
    before_action :prevent_sensitive_caching
    before_action :require_authentication
    before_action :require_gym_write_access, unless: -> { request.get? || request.head? }

    helper_method :policy_options_for

    private

    def require_gym_write_access
      return if current_user.can_manage_workspace?

      redirect_to gym_root_path, alert: "Bu işlem için düzenleme yetkiniz yok."
    end

    def policy_options_for(exercise)
      allowed_policies(exercise).map { |policy| [I18n.t("gym.policies.#{policy}", default: policy.humanize), policy] }
    end

    def allowed_policies(exercise)
      if exercise.mode_cardio?
        %w[off]
      elsif exercise.mode_time?
        %w[off time]
      else
        Gym::Progression::POLICIES
      end
    end

    def owned(scope)
      scope.where(user_id: current_user.id)
    end
  end
end
