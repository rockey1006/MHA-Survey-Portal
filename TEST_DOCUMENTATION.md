# Test Suite Documentation

## Overview

This document provides comprehensive information about the test suite for the Health Professions Rails application. The test suite includes unit tests, integration tests, and system tests to ensure the application works correctly across all components.

## Test Structure

```
test/
├── models/                 # Unit tests for model classes
│   ├── admin_test.rb      # Admin model tests (OAuth, roles, permissions)
│   ├── advisor_test.rb    # Advisor model tests (validations, associations)
│   ├── student_test.rb    # Student model tests (enum, associations)
│   ├── survey_test.rb     # Survey model tests (associations, dependencies)
│   ├── competency_test.rb # Competency model tests (associations, validations)
│   ├── question_test.rb   # Question model tests (types, answer options)
│   ├── survey_response_test.rb     # Survey response tests (enum, scopes)
│   ├── question_response_test.rb   # Question response tests (associations)
│   ├── feedback_test.rb            # Feedback model tests
│   └── evidence_upload_test.rb     # Evidence upload tests
├── controllers/           # Controller action tests
│   ├── surveys_controller_test.rb  # CRUD operations, authorization
│   ├── competencies_controller_test.rb # CRUD operations, validation
│   ├── students_controller_test.rb     # Student management
│   └── ...other controller tests
├── integration/          # Integration tests for user workflows
│   ├── survey_workflow_test.rb        # Complete survey lifecycle
│   └── user_authentication_test.rb    # OAuth and permission flows
├── system/              # End-to-end browser tests
│   ├── surveys_test.rb               # UI interactions for surveys
│   ├── complete_survey_workflow_test.rb # Full workflow testing
│   └── ...other system tests
├── fixtures/            # Test data
│   ├── admins.yml      # Admin test data
│   ├── students.yml    # Student test data
│   ├── surveys.yml     # Survey test data
│   └── ...other fixtures
└── test_helper.rb      # Test configuration and utilities
```

## Test Types

### 1. Model Tests (Unit Tests)

Model tests ensure that your ActiveRecord models work correctly in isolation:

- **Validations**: Test required fields, format validations, uniqueness constraints
- **Associations**: Test relationships between models (belongs_to, has_many, etc.)
- **Enums**: Test enum values and prefix methods
- **Custom Methods**: Test any custom model methods
- **Scopes**: Test model scopes and class methods

Example model test structure:
```ruby
class StudentTest < ActiveSupport::TestCase
  def setup
    @student = students(:one)
  end

  test "should be valid with valid attributes" do
    assert @student.valid?
  end

  test "should validate track enum" do
    assert @student.track_residential?
    @student.track = "executive"
    assert @student.track_executive?
  end
end
```

### 2. Controller Tests (Functional Tests)

Controller tests verify that your controllers handle HTTP requests correctly:

- **HTTP Methods**: Test GET, POST, PATCH, DELETE requests
- **Response Codes**: Verify correct HTTP status codes (200, 302, 404, etc.)
- **Authorization**: Test access control and permissions
- **Parameter Handling**: Test valid and invalid parameter combinations
- **Redirects**: Verify correct redirections after actions

Example controller test structure:
```ruby
class SurveysControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = admins(:one)
    sign_in @admin
  end

  test "should create survey with valid params" do
    assert_difference("Survey.count") do
      post surveys_url, params: { survey: valid_survey_params }
    end
    assert_redirected_to survey_url(Survey.last)
  end
end
```

### 3. Integration Tests

Integration tests verify that different parts of your application work together:

- **User Workflows**: Test complete user journeys
- **Multi-Model Interactions**: Test interactions across multiple models
# Test Suite Documentation

## Overview

This document provides comprehensive information about the test suite for the Health Professions Rails application. The test suite includes unit tests, integration tests, and system tests that ensure the application works correctly across components.

## Test structure

The `test/` directory is organized into:

- `models/` — unit tests for ActiveRecord models
- `controllers/` — controller tests (functional / integration style)
- `integration/` — multi-step workflows and higher-level interactions
- `system/` — browser-driven system tests (Capybara)
- `fixtures/` — YAML fixtures used across tests
- `test_helper.rb` — test configuration and shared helpers

## Test types and where to use them

- Model tests: validations, associations, enums, scopes, and custom methods.
- Controller tests: request/response behavior, redirects, parameter handling, and authorization.
- Integration tests: full user workflows that exercise multiple controllers/models.
- System tests: end-to-end browser tests for UI and JavaScript behavior.

## Running tests

Basic commands:

```bash
# Run all tests
rails test

# Run tests by folder
rails test test/models
rails test test/controllers
rails test test/integration
rails test test/system

# Run a specific file or test
rails test test/models/student_test.rb
rails test test/models/student_test.rb:test_should_validate_track_enum
```

Custom test runner:

```bash
# Use the provided helper runner
ruby run_tests.rb

# Run with coverage
ruby run_tests.rb -c

# Run a specific type
ruby run_tests.rb -t controllers
```

Tip: When running tests in Docker, run commands inside the `web` service, e.g. `docker compose run --rm web bin/rails test`.

## Fixtures & test data

Fixtures provide stable records for tests. Key fixture files include:

- `admins.yml`, `students.yml`, `surveys.yml`, `competencies.yml`, `questions.yml`, `survey_responses.yml`.

Ensure fixture associations exist and use consistent primary keys (some models use non-standard PKs like `student_id`).

## Helpers & common patterns

- Include `Devise::Test::IntegrationHelpers` in integration tests to use `sign_in`.
- Use `setup` blocks for common fixtures and `teardown` or cleanup helpers when creating records dynamically.
- Prefer focused tests (one behavior per test) and descriptive test names.

Example model test:

```ruby
class StudentTest < ActiveSupport::TestCase
  setup do
    @student = students(:one)
  end

  test "valid with valid attributes" do
    assert @student.valid?
  end
end
```

## Coverage & CI

- The project supports generating coverage reports via SimpleCov when tests run with the coverage flag (see `run_tests.rb -c`).
- Configure CI to run `bundle exec rails test` and collect coverage artifacts.

## Troubleshooting

- Fixture loading errors: validate YAML syntax and association names.
- Devise auth errors: ensure `sign_in` helper is used in Integration tests and that fixtures create the expected user/advisor records.
- Test data pollution: wrap database-modifying tests in transactions or clean up created records.

## Contributing to tests

1. Add model/controller/integration/system tests for new features.
2. Update or add fixtures where necessary.
3. Run the test suite and include passing tests with your PR.

---
Updated: 2025-10-20
