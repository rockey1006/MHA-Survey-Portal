require "test_helper"

class CompetenciesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @competency = competencies(:one)
    @survey = surveys(:one)
    @admin = admins(:one)
    @advisor = admins(:two)
  end

  # Admin access tests
  test "admin should get index" do
    sign_in @admin
    get competencies_url
    assert_response :success
  end

  test "admin should get new" do
    sign_in @admin
    get new_competency_url
    assert_response :success
  end

  test "admin should create competency with valid params" do
    sign_in @admin
    assert_difference("Competency.count") do
      post competencies_url, params: {
        competency: {
          competency_id: 999,
          title: "New Competency",
          description: "New competency description",
          survey_id: @survey.id
        }
      }
    end
    assert_redirected_to competency_url(Competency.last)
  end

  test "admin should not create competency with invalid params" do
    sign_in @admin
    assert_no_difference("Competency.count") do
      post competencies_url, params: {
        competency: {
          competency_id: nil,
          title: "",
          description: "",
          survey_id: nil
        }
      }
    end
    assert_response :unprocessable_entity
  end

  test "admin should show competency" do
    sign_in @admin
    get competency_url(@competency)
    assert_response :success
  end

  test "admin should get edit" do
    sign_in @admin
    get edit_competency_url(@competency)
    assert_response :success
  end

  test "admin should update competency with valid params" do
    sign_in @admin
    new_name = "Updated Competency Name"
    patch competency_url(@competency), params: {
      competency: {
        competency_id: @competency.competency_id,
        name: new_name,
        description: @competency.description,
        survey_id: @competency.survey_id
      }
    }
    assert_redirected_to competency_url(@competency)
    @competency.reload
    assert_equal new_name, @competency.name
  end

  test "admin should not update competency with invalid params" do
    sign_in @admin
    original_name = @competency.name
    patch competency_url(@competency), params: {
      competency: {
        name: "",  # Invalid empty name
        description: @competency.description
      }
    }
    assert_response :unprocessable_entity
    @competency.reload
    assert_equal original_name, @competency.name
  end

  test "admin should destroy competency" do
    sign_in @admin
    assert_difference("Competency.count", -1) do
      delete competency_url(@competency)
    end
    assert_redirected_to competencies_url
  end

  # Authorization tests
  test "should redirect to sign in when not authenticated" do
    get competencies_url
    assert_redirected_to new_admin_session_path
  end

  test "advisor should have appropriate access" do
    sign_in @advisor
    get competencies_url
    # Adjust based on your authorization logic
    assert_response :success # or :forbidden if advisors can't access
  end

  # Edge cases
  test "should handle non-existent competency gracefully" do
    sign_in @admin
    assert_raises(ActiveRecord::RecordNotFound) do
      get competency_url(99999)
    end
  end

  test "should create competency without survey association" do
    sign_in @admin
    assert_difference("Competency.count") do
      post competencies_url, params: {
        competency: {
          competency_id: 998,
          title: "Standalone Competency",
          description: "Competency without survey",
          survey_id: nil
        }
      }
    end
    assert_redirected_to competency_url(Competency.last)
  end

  # Test association handling
  test "should display associated questions in show view" do
    sign_in @admin
    get competency_url(@competency)
    assert_response :success
    # Test that questions are loaded (adjust selector based on your view)
    assert_select "body" # Basic assertion, enhance based on your HTML structure
  end
end
