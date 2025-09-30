require "test_helper"

class SurveyTest < ActiveSupport::TestCase
  def setup
    @survey = surveys(:one)
  end

  test "should be valid with valid attributes" do
    assert @survey.valid?
  end

  test "should have competencies association" do
    assert_respond_to @survey, :competencies
  end

  test "should have questions through competencies" do
    assert_respond_to @survey, :questions
  end

  test "should have survey_responses association" do
    assert_respond_to @survey, :survey_responses
  end

  test "should have students through survey_responses" do
    assert_respond_to @survey, :students
  end

  test "should destroy dependent competencies when survey is destroyed" do
    survey = Survey.create!(title: "Test Survey", semester: "Fall 2024")
    competency = survey.competencies.create!(name: "Test Competency", description: "Test Comp Description")

    assert_difference("Competency.count", -1) do
      survey.destroy
    end
  end

  test "should destroy dependent survey_responses when survey is destroyed" do
    survey = Survey.create!(title: "Test Survey", semester: "Fall 2024")

    initial_count = Survey.count
    survey.destroy
    assert_equal initial_count - 1, Survey.count
  end
end
