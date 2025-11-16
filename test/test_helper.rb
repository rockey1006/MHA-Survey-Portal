ENV["RAILS_ENV"] ||= "test"

require "shellwords"

app_root = File.expand_path("..", __dir__)
tailwind_build = File.join(app_root, "app/assets/builds/tailwind.css")

if ENV["SKIP_TAILWIND_BUILD"].to_s.empty? && !File.exist?(tailwind_build)
  system("cd #{Shellwords.escape(app_root)} && bin/rails tailwindcss:build", exception: true)
end

require_relative "../config/environment"
# Load seeds only when explicitly requested. Some test suites rely on fixtures or
# create their own data; running seeds by default can cause primary key
# collisions (sequences out of sync). Set ENV['LOAD_SEEDS']='true' to enable.
if Rails.env.test? && ENV["LOAD_SEEDS"] == "true"
  Rails.application.load_seed
end
require "rails/test_help"
require "minitest/mock"

class ActiveSupport::TestCase
  parallelize(workers: 1)
  fixtures :admins,
           :advisors,
           :categories,
           :questions,
           :feedbacks,
           :students,
           :surveys,
           :survey_track_assignments,
           :survey_assignments,
           :users,
           :survey_change_logs,
           :notifications
end

class ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include ActiveJob::TestHelper
end

class ActionController::TestCase
  include Devise::Test::ControllerHelpers
end
