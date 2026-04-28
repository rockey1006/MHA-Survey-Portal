require "test_helper"

class StudentCompetenciesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @student_user = users(:student)
    @student = students(:student)
    @admin = users(:admin)
    @survey = surveys(:fall_2025)
    @competency_title = Reports::DataAggregator::COMPETENCY_TITLES.first
  end

  test "student can view competency dashboard" do
    sign_in @student_user

    get student_competencies_path

    assert_response :success
    assert_includes response.body, "My Competencies"
    assert_includes response.body, @competency_title
  end

  test "student can export competencies as csv" do
    sign_in @student_user

    get student_competencies_path(format: :csv)

    assert_response :success
    assert_includes response.media_type, "text/csv"
    assert_includes response.body, "Competency"
    assert_includes response.body, @competency_title
  end

  test "future release date hides course ratings from student dashboard" do
    batch = GradeImportBatch.create!(
      uploaded_by: @admin,
      status: "completed",
      summary: { "dry_run" => false }
    )
    batch.grade_competency_ratings.create!(
      student: @student,
      competency_title: @competency_title,
      aggregated_level: 4,
      aggregation_rule: "max",
      evidence_count: 1
    )
    @survey.create_course_grade_release_date!(release_at: 2.days.from_now)

    sign_in @student_user

    get student_competencies_path(semester: @survey.semester)

    assert_response :success
    assert_includes response.body, "Embargoed"
    refute_match(/<td>4\.0<\/td>/, response.body)
  end

  test "student dashboard shows course competency sources and levels" do
    batch = GradeImportBatch.create!(
      uploaded_by: @admin,
      program_semester: @survey.program_semester,
      status: "completed",
      summary: { "dry_run" => false }
    )
    file = batch.grade_import_files.create!(
      file_name: "PHPM-601.xlsx",
      file_checksum: "sources-checksum-1",
      status: "processed"
    )
    batch.grade_competency_ratings.create!(
      student: @student,
      competency_title: @competency_title,
      aggregated_level: 5,
      aggregation_rule: "max",
      evidence_count: 2
    )
    batch.grade_competency_evidences.create!(
      grade_import_file: file,
      student: @student,
      assignment_name: "Community Assessment",
      course_code: "PHPM-601-700",
      competency_title: @competency_title,
      raw_grade: 71,
      mapped_level: 1,
      row_number: 2,
      source_key: "source-community-assessment",
      import_fingerprint: "fingerprint-community-assessment"
    )
    batch.grade_competency_evidences.create!(
      grade_import_file: file,
      student: @student,
      assignment_name: "Population Final",
      course_code: "PHPM-633-700",
      competency_title: @competency_title,
      raw_grade: 98,
      mapped_level: 5,
      row_number: 3,
      source_key: "source-population-final",
      import_fingerprint: "fingerprint-population-final"
    )

    sign_in @student_user

    get student_competencies_path(semester: @survey.semester)

    assert_response :success
    assert_includes response.body, "2 sources"
    assert_includes response.body, "PHPM-601-700"
    assert_includes response.body, "Competency level 1"
    assert_includes response.body, "PHPM-633-700"
    assert_includes response.body, "Competency level 5"
    refute_includes response.body, "Community Assessment"
    refute_includes response.body, "Raw 71.0"
    refute_includes response.body, "PHPM-601.xlsx"
  end

  test "student dashboard hides sources from other semesters" do
    other_survey = surveys(:spring_2025)
    batch = GradeImportBatch.create!(
      uploaded_by: @admin,
      program_semester: other_survey.program_semester,
      status: "completed",
      summary: { "dry_run" => false }
    )
    file = batch.grade_import_files.create!(
      file_name: "PHPM-999.xlsx",
      file_checksum: "sources-checksum-other-semester",
      status: "processed"
    )
    batch.grade_competency_ratings.create!(
      student: @student,
      competency_title: @competency_title,
      aggregated_level: 5,
      aggregation_rule: "max",
      evidence_count: 1
    )
    batch.grade_competency_evidences.create!(
      grade_import_file: file,
      student: @student,
      assignment_name: "Other Semester Assignment",
      course_code: "PHPM-999-700",
      competency_title: @competency_title,
      raw_grade: 99,
      mapped_level: 5,
      row_number: 4,
      source_key: "source-other-semester",
      import_fingerprint: "fingerprint-other-semester"
    )

    sign_in @student_user

    get student_competencies_path(semester: @survey.semester)

    assert_response :success
    refute_includes response.body, "PHPM-999-700"
  end

  test "admin cannot view student competency dashboard" do
    sign_in @admin

    get student_competencies_path

    assert_redirected_to dashboard_path
  end
end
