Rails.application.routes.draw do
  get "up" => "rails/health#show", :as => :rails_health_check

  scope :finance, module: :personal_finance, as: :finance do
    root to: "dashboard#show"
    resource :dashboard, only: :show
    resource :spending_report, only: :show
    resource :cash_flow_forecast, only: :show
    resources :tags, except: :show do
      collection do
        get :report
        patch :merge
      end
    end
    resources :transactions, except: :show do
      collection do
        get :import
        post :import, action: :create_import
        post :preview_import
        post :confirm_import
      end
    end
    resources :recurring_rules, only: %i[index edit update destroy] do
      patch :pause, on: :member
      patch :resume, on: :member
    end
    resources :accounts, except: :show
    resources :categories, except: :show
    get "budget/year/:year", to: "budgets#year", as: :year_budget
    resources :budgets, only: %i[show update], param: :month do
      patch :currency, on: :member
      patch :copy_previous, on: :member
    end
    resource :onboarding, only: %i[show create], controller: :onboarding do
      post :skip, on: :collection
    end
    resources :savings_goals do
      resources :goal_contributions, only: :create
    end
    resources :purchase_plans do
      post :convert, on: :member
    end
  end

  match "locale/:locale", to: "locales#update", via: %i[get post], as: :change_locale

  root to: redirect("/finance")
end
