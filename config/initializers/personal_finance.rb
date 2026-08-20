require Rails.root.join("finance_module/lib/personal_finance")

PersonalFinance.current_user_resolver = ->(_controller) { User.dashboard_owner }
