ENV["RAILS_ENV"] ||= "test"

require "shellwords"

app_root = File.expand_path("..", __dir__)
tailwind_build = File.join(app_root, "app/assets/builds/tailwind.css")

if ENV["SKIP_TAILWIND_BUILD"].blank? && !File.exist?(tailwind_build)
  system("cd #{Shellwords.escape(app_root)} && bin/rails tailwindcss:build", exception: true)
end

require_relative "../config/environment"
require "rails/test_help"
require "minitest/mock"

class ActiveSupport::TestCase
  parallelize(workers: 1)
  fixtures :all
end

class ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
end

class ActionController::TestCase
  include Devise::Test::ControllerHelpers
end
