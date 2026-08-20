module PersonalFinance
  mattr_accessor :current_user_resolver, default: ->(_controller) { nil }

  def self.current_user_for(controller)
    current_user_resolver.call(controller)
  end
end
