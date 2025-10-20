ENV["RAILS_ENV"] ||= "test"

require "shellwords"

app_root = File.expand_path("..", __dir__)
tailwind_build = File.join(app_root, "app/assets/builds/tailwind.css")

if ENV["SKIP_TAILWIND_BUILD"].blank? && !File.exist?(tailwind_build)
  system("cd #{Shellwords.escape(app_root)} && bin/rails tailwindcss:build", exception: true)
end

require_relative "../config/environment"
# If coverage was requested by the test runner, start SimpleCov inside the test process so
# SimpleCov can correctly detect the test framework (Minitest) and produce accurate metrics.
if ENV["COVERAGE"] == "1"
  require "simplecov"
  SimpleCov.command_name "Unit Tests"
  SimpleCov.start "rails" do
    add_filter "/vendor/"
    add_filter "/test/"
    add_group "Models", "app/models"
    add_group "Controllers", "app/controllers"
    add_group "Helpers", "app/helpers"
    add_group "Jobs", "app/jobs"
    add_group "Mailers", "app/mailers"
  end
end

Rails.application.load_seed if Rails.env.test?
require "rails/test_help"
require "minitest/mock"

class ActiveSupport::TestCase
  parallelize(workers: 1)
  fixtures :admins,
           :advisors,
           :categories,
           :questions,
           :students,
           :surveys,
           :survey_assignments,
           :feedbacks,
           :survey_change_logs,
           :users
end

class ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
end

class ActionController::TestCase
  include Devise::Test::ControllerHelpers
end
