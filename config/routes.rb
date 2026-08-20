Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  scope :finance, module: :personal_finance, as: :finance do
    root to: "dashboard#show"
    resource :dashboard, only: :show
    resources :transactions, except: :show
    resources :accounts, except: :show
    resources :categories, except: :show
    resources :budgets, only: %i[show update], param: :month
    resources :savings_goals, except: :show do
      resources :goal_contributions, only: :create
    end
    resources :purchase_plans, except: :show
  end

  root to: redirect("/finance")
end
