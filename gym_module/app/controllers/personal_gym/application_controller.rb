module PersonalGym
  class ApplicationController < ::ApplicationController
    before_action :prevent_sensitive_caching
    before_action :require_authentication

    helper_method :policy_options_for

    private

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
