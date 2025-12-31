require "test_helper"

class Advisors::SurveysControllerTest < ActionDispatch::IntegrationTest
  setup do
    @survey = surveys(:fall_2025)
    sign_in users(:advisor)
  end

  test "index renders successfully" do
    get advisors_surveys_path
    assert_response :success
    assert_includes response.body, @survey.title
  end

  test "show filters students by survey track" do
    @survey.update!(track: "Residential")

    get advisors_survey_path(@survey)
    assert_response :success
    assert_includes response.body, users(:student).name
    refute_includes response.body, users(:other_student).name
  end

  test "show infers track from title when track attribute is blank" do
    sign_in users(:admin)

    @survey.update!(track: nil, title: "Executive Something")

    get advisors_survey_path(@survey)
    assert_response :success

    # Executive students should be included; residential should be excluded.
    assert_includes response.body, users(:other_student).name
    refute_includes response.body, users(:student).name
  end

  test "assign creates student questions and enqueues notification" do
    StudentQuestion.delete_all
    SurveyAssignment.delete_all

    assert_enqueued_jobs 1, only: SurveyNotificationJob do
      assert_difference "StudentQuestion.count", @survey.questions.count do
        assert_difference "SurveyAssignment.count", 1 do
          post assign_advisors_survey_path(@survey), params: { student_id: students(:student).student_id }
        end
      end
    end

    assert_redirected_to advisors_surveys_path
  end

  test "assign parses due_date and falls back when I18n timestamp formatting fails" do
    StudentQuestion.delete_all
    SurveyAssignment.delete_all

    I18n.stub(:l, ->(*) { raise I18n::InvalidLocale.new(:xx) }) do
      post assign_advisors_survey_path(@survey), params: {
        student_id: students(:student).student_id,
        due_date: "2030-01-01"
      }
    end

    assert_redirected_to advisors_surveys_path
    assignment = SurveyAssignment.find_by!(survey_id: @survey.id, student_id: students(:student).student_id)
    assert_equal Date.new(2030, 1, 1), assignment.due_date.to_date
    assert_match "Assigned", flash[:notice]
  end

  test "assign_all handles eligible students" do
    StudentQuestion.delete_all
    SurveyAssignment.delete_all
    @survey.update!(track: "Residential")

    assert_enqueued_jobs 1, only: SurveyNotificationJob do
      assert_difference "StudentQuestion.count", @survey.questions.count do
        assert_difference "SurveyAssignment.count", 1 do
          post assign_all_advisors_survey_path(@survey)
        end
      end
    end

    assert_redirected_to advisors_surveys_path
    assert_match "Assigned", flash[:notice]
  end

  test "assign_all alerts when no students match" do
    @survey.update!(track: "Executive")
    post assign_all_advisors_survey_path(@survey)

    assert_redirected_to advisors_survey_path(@survey)
    assert_match "No students available", flash[:alert]
  end

  test "unassign removes assignments and notifies" do
    StudentQuestion.delete_all
    Notification.delete_all

    student = students(:student)
    StudentQuestion.create!(
      student: student,
      question: questions(:fall_q1),
      advisor_id: advisors(:advisor).advisor_id
    )
    SurveyAssignment.where(survey: @survey, student: student).delete_all
    SurveyAssignment.create!(
      survey: @survey,
      student: student,
      advisor: advisors(:advisor),
      assigned_at: Time.current
    )

    assert_difference "StudentQuestion.count", -@survey.questions.count do
      assert_difference "Notification.count", 1 do
        delete unassign_advisors_survey_path(@survey), params: { student_id: student.student_id }
      end
    end

    assert_redirected_to advisors_survey_path(@survey)
    assert_match "Unassigned", flash[:notice]
  end
end
