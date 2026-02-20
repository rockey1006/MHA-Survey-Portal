require "test_helper"

class SurveyTest < ActiveSupport::TestCase
  test "active scope returns active surveys" do
    active = Survey.where(is_active: true).to_a
    assert active.present?
    assert_equal active.sort_by(&:id), Survey.active.order(:id).to_a
  end

  test "survey has questions association and questions can be ordered" do
    survey = surveys(:fall_2025)
    assert_respond_to survey, :questions
    ordered = survey.questions.ordered.to_a
    assert_kind_of Array, ordered
  end
  test "valid fixture" do
    assert surveys(:fall_2025).valid?
  end

  test "requires title" do
    survey = Survey.new(semester: "Fall 2025")
    assert_not survey.valid?
    assert_includes survey.errors[:title], "can't be blank"
  end

  test "requires semester" do
    survey = Survey.new(title: "Test Survey")
    assert_not survey.valid?
    assert_includes survey.errors[:program_semester], "must exist"
  end

  test "rejects duplicate title within the same semester" do
    existing = surveys(:fall_2025)
    survey = build_survey(
      title: "  #{existing.title.upcase}  ",
      semester: "  #{existing.semester.downcase}  "
    )

    assert_not survey.valid?
    assert_includes survey.errors[:title], "already exists for this semester"
  end

  test "allows same title across different semesters" do
    existing = surveys(:fall_2025)
    survey = build_survey(title: existing.title, semester: "Spring 2035")

    assert survey.valid?
  end

  test "strips surrounding whitespace before validation" do
    survey = build_survey(title: "  Sample Survey  ", semester: "  Fall 2035  ")

    assert survey.valid?
    assert_equal "Sample Survey", survey.title
    assert_equal "Fall 2035", survey.semester
  end

  test "changing survey due date updates inherited assignment deadlines but preserves custom ones" do
    survey = build_survey(title: "Due Sync Survey", semester: "Fall 2036")
    survey.available_until = Time.zone.local(2036, 10, 1, 12, 0)
    survey.save!

    inherited_assignment = SurveyAssignment.create!(
      survey: survey,
      student: students(:student),
      advisor: advisors(:advisor),
      assigned_at: Time.current,
      available_until: survey.available_until
    )

    blank_assignment = SurveyAssignment.create!(
      survey: survey,
      student: students(:completed_student),
      advisor: advisors(:other_advisor),
      assigned_at: Time.current,
      available_until: nil
    )

    custom_deadline = Time.zone.local(2036, 10, 20, 17, 0)
    custom_assignment = SurveyAssignment.create!(
      survey: survey,
      student: students(:other_student),
      advisor: advisors(:other_advisor),
      assigned_at: Time.current,
      available_until: custom_deadline
    )

    new_survey_deadline = Time.zone.local(2036, 11, 15, 9, 30)
    survey.update!(available_until: new_survey_deadline)

    assert_equal new_survey_deadline.to_i, inherited_assignment.reload.available_until.to_i
    assert_equal new_survey_deadline.to_i, blank_assignment.reload.available_until.to_i
    assert_equal custom_deadline.to_i, custom_assignment.reload.available_until.to_i
  end

  test "removing survey due date clears inherited assignment deadlines" do
    survey = build_survey(title: "Due Removal Survey", semester: "Spring 2037")
    survey.available_until = Time.zone.local(2037, 3, 20, 8, 0)
    survey.save!

    inherited_assignment = SurveyAssignment.create!(
      survey: survey,
      student: students(:student),
      advisor: advisors(:advisor),
      assigned_at: Time.current,
      available_until: survey.available_until
    )

    custom_deadline = Time.zone.local(2037, 4, 10, 8, 0)
    custom_assignment = SurveyAssignment.create!(
      survey: survey,
      student: students(:other_student),
      advisor: advisors(:other_advisor),
      assigned_at: Time.current,
      available_until: custom_deadline
    )

    survey.update!(available_until: nil)

    assert_nil inherited_assignment.reload.available_until
    assert_equal custom_deadline.to_i, custom_assignment.reload.available_until.to_i
  end

  private

  def build_survey(attrs = {})
    Survey.new({ title: "Unique", semester: "Fall 2099", is_active: true }.merge(attrs)).tap do |survey|
      category = survey.categories.build(name: "Basics")
      category.questions.build(
        question_text: "Describe your progress",
        question_type: "short_answer",
        question_order: 1
      )
    end
  end
end
