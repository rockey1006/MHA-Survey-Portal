require "test_helper"

class Admin::TargetLevelsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin)
    @student = users(:student)
    @semester = program_semesters(:fall_2025)
    @track_value = Student.tracks.values.first
    @competency_title = Reports::DataAggregator::COMPETENCY_TITLES.first
  end

  test "admin can view the editor" do
    sign_in @admin

    get admin_target_levels_path(program_semester_id: @semester.id, track: @track_value)
    assert_response :success
    assert_match "Target Levels", response.body
    assert_match @competency_title, response.body
    assert_match(/data-controller=\"confirm-submit\"/, response.body)
    assert_match(/submit-(&gt;|>?)confirm-submit#confirm/, response.body)
  end

  test "non-admin is redirected" do
    sign_in @student

    get admin_target_levels_path(program_semester_id: @semester.id, track: @track_value)
    assert_redirected_to dashboard_path
  end

  test "admin can update a target level" do
    sign_in @admin

    assert_difference "CompetencyTargetLevel.count", 1 do
      patch admin_target_levels_path, params: {
        program_semester_id: @semester.id,
        track: @track_value,
        program_year: "",
        targets: {
          "0" => {
            competency_title: @competency_title,
            target_level: "4"
          }
        }
      }
    end

    record = CompetencyTargetLevel.last
    assert_equal @semester.id, record.program_semester_id
    assert_equal @track_value, record.track
    assert_nil record.program_year
    assert_equal @competency_title, record.competency_title
    assert_equal 4, record.target_level
  end

  test "warns when updating target levels after students submitted surveys" do
    sign_in @admin

    survey_assignments(:completed_residential_assignment)

    patch admin_target_levels_path, params: {
      program_semester_id: @semester.id,
      track: "Residential",
      program_year: "",
      targets: {
        "0" => {
          competency_title: @competency_title,
          target_level: "4"
        }
      }
    }

    assert_redirected_to admin_target_levels_path(program_semester_id: @semester.id, track: "Residential")

    follow_redirect!
    assert_response :success
    assert_match(/Warning:/i, response.body)
    assert_match(/Target levels changed/i, response.body)
  end

  test "does not warn when updating target levels and no one has submitted" do
    sign_in @admin

    patch admin_target_levels_path, params: {
      program_semester_id: @semester.id,
      track: "Executive",
      program_year: "",
      targets: {
        "0" => {
          competency_title: @competency_title,
          target_level: "4"
        }
      }
    }

    assert_redirected_to admin_target_levels_path(program_semester_id: @semester.id, track: "Executive")

    follow_redirect!
    assert_response :success
    assert_no_match(/Target levels changed/i, response.body)
  end

  test "editor renders previously saved target levels" do
    sign_in @admin

    CompetencyTargetLevel.create!(
      program_semester: @semester,
      track: @track_value,
      program_year: nil,
      competency_title: @competency_title,
      target_level: 5
    )

    get admin_target_levels_path(program_semester_id: @semester.id, track: @track_value, program_year: "")
    assert_response :success
    assert_match @competency_title, response.body
    assert_match(/<option[^>]*value="5"[^>]*selected="selected"[^>]*>[^<]*5[^<]*<\/option>|<option[^>]*selected="selected"[^>]*value="5"[^>]*>[^<]*5[^<]*<\/option>/, response.body)
  end
end
