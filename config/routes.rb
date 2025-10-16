Rails.application.routes.draw do
  devise_for :users, path: "", controllers: {
    sessions: "sessions",
    omniauth_callbacks: "omniauth_callbacks"
  }, path_names: {
    sign_in: "sign_in",
    sign_out: "sign_out"
  }

  devise_scope :user do
    # Primary landing page shows the admin sign-in screen
    root to: "sessions#new"

    get "sign_in", to: "sessions#new", as: :new_user_session
    post "sign_in", to: "sessions#create", as: :user_session
    delete "sign_out", to: "sessions#destroy", as: :destroy_user_session

    # Accept GET requests to /sign_out safely by redirecting to root
    # This avoids GET requests (from bots or cached links) being treated as
    # Admin resource IDs (e.g. /sign_out -> AdminsController#show with id="sign_out").
    # Devise expects DELETE for sign_out; this GET handler is a harmless redirect.
    get "sign_out", to: "sessions#sign_out_get_fallback"
  end

  # Authenticated dashboard entry point
  get "dashboard", to: "dashboards#show", as: :dashboard

  # Role-specific dashboard routes
  get "student_dashboard", to: "dashboards#student", as: :student_dashboard
  get "advisor_dashboard", to: "dashboards#advisor", as: :advisor_dashboard
  get "admin_dashboard", to: "dashboards#admin", as: :admin_dashboard
  post "switch_role", to: "dashboards#switch_role", as: :switch_role

  get "student_records", to: "student_records#index", as: :student_records

  # Admin-specific management routes
  get "manage_members", to: "dashboards#manage_members", as: :manage_members
  patch "update_roles", to: "dashboards#update_roles", as: :update_roles
  get "debug_users", to: "dashboards#debug_users", as: :debug_users

  namespace :admin do
    resources :surveys do
      collection do
        patch :bulk_update
      end

      member do
        get :preview
      end
    end

    resources :questions, except: :show
  end

  resources :categories
  resources :feedbacks
  resources :questions

  resources :surveys do
    post :submit, on: :member
  end

  resources :survey_responses, only: :show do
    member do
      get :print
      get :download
    end
  end

  namespace :advisors do
    resources :surveys, only: %i[index show] do
      post :assign, on: :member
    end
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
end
