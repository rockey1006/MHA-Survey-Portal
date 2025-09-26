Rails.application.routes.draw do
  root to: "dashboards#show"

  # Role-specific dashboard routes
  get "student_dashboard", to: "dashboards#student", as: :student_dashboard
  get "advisor_dashboard", to: "dashboards#advisor", as: :advisor_dashboard
  get "admin_dashboard", to: "dashboards#admin", as: :admin_dashboard

  # Admin-specific management routes
  get "manage_members", to: "dashboards#manage_members", as: :manage_members
  patch "update_roles", to: "dashboards#update_roles", as: :update_roles
  get "debug_users", to: "dashboards#debug_users", as: :debug_users

  devise_for :admins, controllers: { omniauth_callbacks: "admins/omniauth_callbacks" }

  devise_scope :admin do
    get "admins/sign_in", to: "admins/sessions#new", as: :new_admin_session
    get "admins/sign_out", to: "admins/sessions#destroy", as: :destroy_admin_session
  end

  resources :admins
  resources :students
  resources :advisors
  resources :evidence_uploads
  resources :feedbacks
  resources :surveys
  resources :competencies
  resources :questions
  resources :survey_responses
  resources :competency_responses
  resources :question_responses


  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
end
