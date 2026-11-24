require Rails.root.join("lib/personal_finance")

PersonalFinance.current_user_resolver = ->(controller) { controller.current_user }
