# frozen_string_literal: true

Rails.application.routes.draw do
  get 'up' => 'rails/health#show', :as => :rails_health_check
  get 'internal/pdf_editor_authorization' => 'internal#pdf_editor_authorization'
  resource :database_tools, only: :show
  get 'internal/database_editor_authorization' => 'internal#database_editor_authorization'
  get 'database-editor/config.js' => 'database_tools#configuration'
  resource :session, only: %i[new create destroy]
  resource :signup, controller: 'signups', only: %i[new create]
  resource :mfa, controller: 'mfa', only: %i[show destroy] do
    post :verify
  end
  resource :profile, only: %i[show update]
  resource :ai_settings, only: %i[show update] do
    get :health
  end
  post 'ai_chat', to: 'ai_chats#create'
  delete 'ai_chat/history', to: 'ai_chats#destroy'
  resources :users, only: %i[index new create edit update]

  resource :password, controller: 'passwords', only: %i[new create edit update] do
    get :confirm, on: :collection
  end

  resource :nas, controller: 'nas', only: %i[show destroy] do
    get :download
    post :upload
    post :folder
  end

  root to: 'home#show'

  scope :notes, module: :notes, as: :notes do
    root to: 'notes#index'
    resources :notes do
      get :graph, on: :collection
    end
  end

  scope :learning, module: :learning, as: :learning do
    root to: 'workspace#index'
    get 'library', to: 'workspace#library'
    get 'resource/:id', to: 'workspace#resource', as: :resource
    get 'export', to: 'workspace#export', as: :export
    resources :items, controller: :workspace, only: %i[new create show update destroy] do
      post :practice, on: :member
    end
  end

  scope :finance, module: :personal_finance, as: :finance do
    root to: 'dashboard#show'
    resource :dashboard, only: :show
    resource :spending_report, only: :show
    resource :cash_flow_forecast, only: :show
    resource :pdf_tools, only: :show
    resources :notifications, only: :index do
      post :mark_all_read, on: :collection
    end
    resource :notification_settings, only: :update
    resource :theme_preference, only: :update
    resource :data, only: :show do
      get :export
      post :import
    end
    resources :document_conversions, only: %i[index create show update destroy] do
      get :source_pdf, on: :member
      post :export_zip, on: :member
      post :export_html, on: :member
      post :reprocess, on: :member
      resources :assets, only: %i[show update destroy], controller: :document_assets
    end
    resources :subscriptions, except: :show
    resources :debts, except: :show do
      post :pay, on: :member
    end
    resources :tags, except: :show do
      collection do
        get :report
        patch :merge
      end
    end
    resources :exchange_rates, only: %i[index create edit update destroy]
    resources :transactions, except: :show do
      collection do
        get :category_suggestion
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
    get 'budget/year/:year', to: 'budgets#year', as: :year_budget
    resources :budgets, only: %i[show update], param: :month do
      patch :currency, on: :member
      patch :copy_previous, on: :member
      post :apply_template, on: :member
      post :save_as_template, on: :member
    end
    resources :budget_templates, only: %i[index update destroy] do
      patch :refresh, on: :member
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

  scope :gym, module: :personal_gym, as: :gym do
    root to: 'dashboard#show'
    post :seed_catalog, to: 'exercises#seed'
    resources :exercises, only: %i[index show new create]
    resources :routines, except: :show do
      post :seed_templates, on: :collection
      resources :days, controller: :routine_days, only: %i[create destroy]
      resources :plans, controller: :routine_exercises, only: %i[create update destroy]
    end
    resources :workouts, only: %i[index show create destroy] do
      patch :finish, on: :member
      resources :sets, controller: :workout_sets, only: %i[create update destroy]
    end
    resource :stats, only: :show
  end

  match 'locale/:locale', to: 'locales#update', via: %i[get post], as: :change_locale
end
