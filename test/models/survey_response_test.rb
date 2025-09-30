require "test_helper"

class SurveyResponseTest < ActiveSupport::TestCase
  def setup
    @survey_response = survey_responses(:one)
  end

  test "should be valid with valid attributes" do
    assert @survey_response.valid?
  end

  test "should have status enum" do
    assert_respond_to @survey_response, :status
    assert_respond_to @survey_response, :status_not_started?
    assert_respond_to @survey_response, :status_in_progress?
    assert_respond_to @survey_response, :status_submitted?
    assert_respond_to @survey_response, :status_under_review?
    assert_respond_to @survey_response, :status_approved?
  end

  test "should accept valid status values" do
    valid_statuses = %w[not_started in_progress submitted under_review approved]

    valid_statuses.each do |status|
      @survey_response.status = status
      assert @survey_response.valid?, "SurveyResponse should be valid with status: #{status}"
    end
  end

  test "should belong to survey optionally" do
    assert_respond_to @survey_response, :survey
    @survey_response.survey = nil
    assert @survey_response.valid?
  end

  test "should belong to student optionally" do
    assert_respond_to @survey_response, :student
    @survey_response.student = nil
    assert @survey_response.valid?
  end

  test "should belong to advisor optionally" do
    assert_respond_to @survey_response, :advisor
    @survey_response.advisor = nil
    assert @survey_response.valid?
  end

  test "status prefix methods should work correctly" do
    @survey_response.update(status: "not_started")
    assert @survey_response.status_not_started?
    assert_not @survey_response.status_in_progress?

    @survey_response.update(status: "submitted")
    assert @survey_response.status_submitted?
    assert_not @survey_response.status_not_started?
  end

  test "should have for_student scope" do
    student = students(:one)
    responses = SurveyResponse.for_student(student.id)
    assert_respond_to SurveyResponse, :for_student
  end

  test "should have pending scope" do
    assert_respond_to SurveyResponse, :pending
    # Test that pending excludes submitted responses
    pending_responses = SurveyResponse.pending
    pending_responses.each do |response|
      assert_not_equal "submitted", response.status
    end
  end

  test "should have completed scope" do
    assert_respond_to SurveyResponse, :completed
    # Test that completed includes only submitted responses
    completed_responses = SurveyResponse.completed
    completed_responses.each do |response|
      assert_equal "submitted", response.status
    end
  end

  test "should have class methods for student-specific queries" do
    student = students(:one)
    assert_respond_to SurveyResponse, :pending_for_student
    assert_respond_to SurveyResponse, :completed_for_student

    pending = SurveyResponse.pending_for_student(student.id)
    completed = SurveyResponse.completed_for_student(student.id)

    assert_kind_of ActiveRecord::Relation, pending
    assert_kind_of ActiveRecord::Relation, completed
  end
end
