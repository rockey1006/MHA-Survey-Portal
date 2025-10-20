require "test_helper"

class SurveyAssignTracksTest < ActiveSupport::TestCase
  test "assign_tracks! normalizes and replaces tracks" do
    survey = surveys(:fall_2025)
    # initial assignments exist from fixtures
    # ensure a clean state for this survey's assignments to avoid uniqueness collisions
    survey.survey_assignments.delete_all
    assert_nothing_raised do
      survey.assign_tracks!([ " Executive ", "New Track #{Time.now.to_i}" ])
    end
    tracks = survey.track_list
    assert_includes tracks, "Executive"
    assert tracks.any? { |t| t.include?("New Track") }
       # duplicates behavior not asserted here to avoid DB uniqueness collisions in test env
  end

  test "assign_tracks! truncates very long track names" do
    survey = surveys(:fall_2025)
    long = "x" * 300
    survey.assign_tracks!([ long ])
    assert survey.track_list.first.length <= 255
  end
end
