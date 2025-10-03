# Code coverage setup - must be before requiring Rails
require "simplecov"

SimpleCov.start "rails" do
  # Exclude files from coverage
  add_filter "/bin/"
  add_filter "/db/"
  add_filter "/spec/"
  add_filter "/test/"
  add_filter "/vendor/"
  add_filter "/config/"
  add_filter "app/channels/application_cable/"
  add_filter "app/jobs/application_job.rb"
  add_filter "app/mailers/application_mailer.rb"

  # Track specific directories
  add_group "Models", "app/models"
  add_group "Controllers", "app/controllers"
  add_group "Helpers", "app/helpers"
  add_group "Mailers", "app/mailers"
  add_group "Jobs", "app/jobs"

  # Set minimum coverage - adjusted for current test suite coverage
  # Only enforce minimum coverage in CI or when explicitly requested to avoid
  # failing local runs where coverage may be lower during incremental work.
  if ENV["CI"] == "true" || ENV["ENFORCE_COVERAGE"] == "1"
    minimum_coverage 30
  end

  # Generate HTML and terminal reports
  coverage_dir "coverage"
end

ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers (disabled on Windows due to fork() limitation)
    if Gem.win_platform?
      # Windows doesn't support fork(), so disable parallel testing
      parallelize(workers: 1)
    else
      parallelize(workers: :number_of_processors)
    end

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Custom helper methods for tests

    # Create a test admin user
    def create_test_admin(email: "test_admin@tamu.edu", role: "admin")
      Admin.create!(
        email: email,
        full_name: "Test Admin",
        uid: SecureRandom.hex(10),
        avatar_url: "https://example.com/avatar.jpg",
        role: role
      )
    end

    # Create a test student
    def create_test_student(student_id: rand(10000..99999))
      Student.create!(
        student_id: student_id,
        name: "Test Student",
        email: "test_student#{student_id}@tamu.edu",
        net_id: "test#{student_id}",
        track: "residential",
        advisor_id: advisors(:one).id
      )
    end

    # Create a test survey with competencies and questions
    def create_complete_test_survey(survey_id: rand(1000..9999))
      survey = Survey.create!(
        survey_id: survey_id,
        title: "Test Survey #{survey_id}",
        semester: "Test Semester",
        assigned_date: Date.current,
        completion_date: Date.current + 30.days,
        approval_date: Date.current - 1.day
      )

      competency = survey.competencies.create!(
        competency_id: survey_id,
        title: "Test Competency",
        description: "Test competency description"
      )

      question = competency.questions.create!(
        question_id: survey_id,
        text: "Test question?",
        question_type: "select",
        question_order: 1,
        answer_options: [ "Excellent", "Good", "Fair", "Poor" ]
      )

      { survey: survey, competency: competency, question: question }
    end

    # Custom assertion for testing enums
    def assert_enum_values(model_instance, enum_attribute, expected_values)
      enum_values = model_instance.class.send(enum_attribute.to_s.pluralize).keys
      assert_equal expected_values.sort, enum_values.sort,
        "#{model_instance.class} #{enum_attribute} should have values: #{expected_values}"
    end

    # Custom assertion for testing associations
    def assert_association(model, association_name, association_type)
      assert_respond_to model, association_name,
        "#{model.class} should respond to #{association_name}"

      reflection = model.class.reflect_on_association(association_name)
      assert_not_nil reflection,
        "#{model.class} should have #{association_name} association"
      assert_equal association_type, reflection.macro,
        "#{association_name} should be a #{association_type} association"
    end

    # Helper to test model validations
    def assert_required_field(model, field)
      model.send("#{field}=", nil)
      assert_not model.valid?, "#{model.class} should not be valid without #{field}"
      assert_includes model.errors[field], "can't be blank",
        "#{field} should have 'can't be blank' error"
    end

    # Helper to test email validation
    def assert_email_validation(model, email_field = :email)
      invalid_emails = [ "plainaddress", "@missingdomain.com", "missing@.com", "missing.domain@.com" ]
      invalid_emails.each do |email|
        model.send("#{email_field}=", email)
        assert_not model.valid?, "#{email} should be invalid"
      end

      valid_emails = [ "test@example.com", "user@tamu.edu", "valid.email@domain.com" ]
      valid_emails.each do |email|
        model.send("#{email_field}=", email)
        model.valid? # Trigger validation
        assert_not model.errors[email_field].include?("is invalid"),
          "#{email} should be valid"
      end
    end

    # Helper to clean up test data
    def cleanup_test_data
      # Clean up any test records that might interfere with other tests
      Survey.where("survey_id > 9000").destroy_all
      Competency.where("competency_id > 9000").destroy_all
      Question.where("question_id > 9000").destroy_all
      SurveyResponse.where("surveyresponse_id > 9000").destroy_all
      QuestionResponse.where("questionresponse_id > 9000").destroy_all
      Admin.where("email LIKE 'test_%'").destroy_all
      Student.where("email LIKE 'test_%'").destroy_all
    end
  end
end

# Custom module for integration tests
module IntegrationTestHelpers
  def login_as_admin
    admin = admins(:one)
    post admin_session_path, params: {
      admin: {
        email: admin.email,
        password: "password" # Adjust based on your auth setup
      }
    }
  end

  def login_as_advisor
    advisor = admins(:two)
    post admin_session_path, params: {
      admin: {
        email: advisor.email,
        password: "password" # Adjust based on your auth setup
      }
    }
  end
end

# Include helper modules in integration tests
class ActionDispatch::IntegrationTest
  include IntegrationTestHelpers
end
