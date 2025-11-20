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

  get "manage_students", to: "dashboards#manage_students", as: :manage_students
  patch "manage_students", to: "dashboards#update_student_advisors", as: :update_student_advisors

  # Reporting hub shared by admins and advisors
  get "reports", to: "reports#show", as: :reports
  get "reports/export_excel", to: "reports#export_excel", as: :export_reports_excel
  get "reports/:section/export_pdf", to: "reports#export_pdf", as: :export_reports_pdf

  # Admin-specific management routes
  get "manage_members", to: "dashboards#manage_members", as: :manage_members
  patch "update_roles", to: "dashboards#update_roles", as: :update_roles
  get "debug_users", to: "dashboards#debug_users", as: :debug_users

  namespace :admin do
    resources :surveys do
      member do
        get :preview
        patch :archive
        patch :activate
      end
    end
    resources :questions
    resources :survey_change_logs, only: :index
    resources :program_semesters, only: %i[create destroy] do
      member do
        patch :make_current
      end
    end
  end

  resources :categories
  resources :feedbacks
  resources :questions
  resources :question_responses

  resources :students, only: %i[index update]
  patch "students/:id/update_advisor", to: "dashboards#update_student_advisor", as: :update_student_advisor

  # Student profile management
  resource :student_profile, only: %i[show edit update]

  # Account settings (all roles share this page)
  resource :account, only: %i[edit update]

  resources :surveys do
    post :submit, on: :member
    post :save_progress, on: :member
  end

  # Accept GET requests to /surveys/:id/submit and redirect to the survey show page.
  # This avoids a noisy RoutingError if a user or external crawler follows a cached/old GET link.
  get 'surveys/:id/submit', to: redirect('/surveys/%{id}')

  resources :notifications, only: %i[index show update] do
    collection do
      patch :mark_all_read
    end
  end

  resources :survey_responses, only: :show do
    member do
      get :download
      get :composite_report
    end
  end

  # Evidence helpers
  get "evidence/check_access", to: "evidence#check_access", as: :evidence_check_access, defaults: { format: :json }

  namespace :advisors do
    resources :surveys, only: %i[index show] do
      post   :assign,     on: :member
      post   :assign_all, on: :member
      delete :unassign,   on: :member
    end
    resources :students, only: %i[show update]
  end

  namespace :api do
    get "reports/filters", to: "reports#filters"
    get "reports/competency-summary", to: "reports#competency_summary"
    get "reports/competency-detail", to: "reports#competency_detail"
    get "reports/course-summary", to: "reports#course_summary"
    get "reports/benchmark", to: "reports#benchmark"
  end

  get "about", to: "pages#about", as: :about
  get "faq",   to: "pages#faq",   as: :faq

  

  # User settings page (accessible to any authenticated user)
  get "settings", to: "settings#edit", as: :settings
  patch "settings", to: "settings#update"

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
end
