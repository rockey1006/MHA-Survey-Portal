require "test_helper"

class Admin::SurveysControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin_user = users(:admin)
    @advisor_user = users(:advisor)
    @survey = surveys(:fall_2025)
    sign_in @admin_user
  end

  test "requires admin role" do
    sign_out @admin_user
    sign_in @advisor_user

    get admin_surveys_path
    assert_redirected_to dashboard_path
  end

  test "creates survey with tracks and logs change" do
    params = {
      survey: {
        title: "Capstone Survey",
        description: "Capstone overview",
        semester: "Fall 2026",
        is_active: true,
        track_list: [ "Residential" ],
        categories_attributes: {
          "0" => {
            name: "Leadership",
            description: "Leadership competencies",
            questions_attributes: {
              "0" => {
                question_text: "Describe your leadership style",
                question_type: "short_answer",
                question_order: 1,
                is_required: true,
                has_evidence_field: false,
                answer_options: ""
              }
            }
          }
        }
      }
    }

  assert_difference [ "Survey.count", "SurveyTrackAssignment.count", "SurveyChangeLog.count" ] do
      post admin_surveys_path, params: params
    end

    assert_redirected_to admin_surveys_path

    survey = Survey.order(:created_at).last
    assert_equal "Capstone Survey", survey.title
    assert_equal [ "Residential" ], survey.track_list
    assert_equal 1, survey.categories.count
    assert_equal 1, survey.questions.count

    log = SurveyChangeLog.order(:created_at).last
    assert_equal "create", log.action
    assert_equal survey, log.survey
    assert_equal @admin_user, log.admin
    assert_equal "Survey created with 1 track(s)", log.description
  end

  test "updates survey and records change summary" do
    survey = surveys(:fall_2025)

    assert_difference "SurveyChangeLog.count" do
      patch admin_survey_path(survey), params: {
        survey: {
          title: "Updated Survey Title",
          description: "Updated details",
          track_list: [ "Executive" ]
        }
      }
    end

    assert_redirected_to admin_surveys_path

    survey.reload
    assert_equal "Updated Survey Title", survey.title
    assert_equal [ "Executive" ], survey.track_list

    log = SurveyChangeLog.order(:created_at).last
    assert_equal "update", log.action
    assert_equal survey, log.survey
    assert_equal @admin_user, log.admin
    assert_includes log.description, "Tracks updated to Executive"
    assert_includes log.description, "Title changed from"
  end

  test "archives survey and removes track assignments" do
    assert @survey.is_active?
    assert @survey.track_list.any?

  prior_assignment_count = SurveyTrackAssignment.count
  prior_tracks = @survey.track_list.size

    assert_difference "SurveyChangeLog.count" do
      patch archive_admin_survey_path(@survey)
    end

    assert_redirected_to admin_surveys_path

    @survey.reload
    refute @survey.is_active?
    assert_empty @survey.track_list
  assert_equal prior_assignment_count - prior_tracks, SurveyTrackAssignment.count
  assert_empty SurveyTrackAssignment.where(survey: @survey)

    log = SurveyChangeLog.order(:created_at).last
    assert_equal "archive", log.action
    assert_equal @survey, log.survey
  end

  test "activates survey and logs change" do
    survey = surveys(:fall_2025)
    survey.update!(is_active: false)

    assert_difference "SurveyChangeLog.count" do
      patch activate_admin_survey_path(survey)
    end

    assert_redirected_to admin_surveys_path

    survey.reload
    assert survey.is_active?

    log = SurveyChangeLog.order(:created_at).last
    assert_equal "activate", log.action
    assert_equal survey, log.survey
  end

  test "preview renders successfully and logs preview" do
    assert_difference "SurveyChangeLog.count" do
      get preview_admin_survey_path(@survey)
    end

    assert_response :success

    log = SurveyChangeLog.order(:created_at).last
    assert_equal "preview", log.action
    assert_equal @survey, log.survey
  end
end
