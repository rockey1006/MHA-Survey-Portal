require "test_helper"
require "csv"

class Admin::GradeImportBatchesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin)
    @advisor = users(:advisor)
    @student = students(:student)
    sign_in @admin
  end

  test "requires admin role for index" do
    sign_out @admin
    sign_in @advisor

    get admin_grade_import_batches_path

    assert_redirected_to dashboard_path
    assert_match(/access denied/i, flash[:alert].to_s)
  end

  test "commit flips a completed dry run into a reportable batch" do
    batch = GradeImportBatch.create!(
      uploaded_by: @admin,
      status: "completed",
      summary: { "dry_run" => true }
    )

    post commit_admin_grade_import_batch_path(batch)

    assert_redirected_to admin_grade_import_batch_path(batch)
    assert batch.reload.reportable?
    assert_equal false, ActiveModel::Type::Boolean.new.cast(batch.summary["dry_run"])
    assert_equal @admin.email, batch.summary["committed_by"]
  end

  test "rollback hides a committed batch and recommit restores it" do
    batch = GradeImportBatch.create!(
      uploaded_by: @admin,
      status: "completed",
      summary: { "dry_run" => false }
    )
    file = batch.grade_import_files.create!(
      file_name: "sample.xlsx",
      file_checksum: "checksum-1",
      status: "processed"
    )
    batch.grade_competency_evidences.create!(
      grade_import_file: file,
      student: @student,
      assignment_name: "Case Study",
      course_code: "PHPM-700-001",
      competency_title: "Policy Analysis",
      raw_grade: 95,
      mapped_level: 5,
      row_number: 3,
      source_key: "source-1",
      import_fingerprint: "fingerprint-1"
    )

    post rollback_admin_grade_import_batch_path(batch)
    assert_redirected_to admin_grade_import_batch_path(batch)
    assert batch.reload.rolled_back?
    refute batch.reportable?

    post recommit_admin_grade_import_batch_path(batch)
    assert_redirected_to admin_grade_import_batch_path(batch)
    assert_equal "completed", batch.reload.status
    assert batch.reportable?
    assert_equal @admin.email, batch.summary["recommitted_by"]
  end

  test "export ratings returns formatted csv only" do
    batch = GradeImportBatch.create!(
      uploaded_by: @admin,
      status: "completed",
      summary: { "dry_run" => false }
    )
    file = batch.grade_import_files.create!(
      file_name: "sample.xlsx",
      file_checksum: "checksum-csv-format",
      status: "processed"
    )

    evidence = batch.grade_competency_evidences.create!(
      grade_import_file: file,
      student: @student,
      assignment_name: "Case Study",
      course_code: "PHPM-700-001",
      competency_title: "Policy Analysis",
      raw_grade: 95,
      mapped_level: 5,
      row_number: 3,
      source_key: "source-csv-format",
      import_fingerprint: "fingerprint-csv-format"
    )

    batch.grade_competency_ratings.create!(
      student: @student,
      competency_title: "Policy Analysis",
      aggregated_level: 5,
      aggregation_rule: "max",
      evidence_count: 1
    )

    get export_ratings_admin_grade_import_batch_path(batch, format: :csv)

    assert_response :success
    parsed = CSV.parse(response.body, headers: true)
    assert_equal [
      "Student ID",
      "Student Name",
      "Student Email",
      "Competency",
      "Aggregated Level",
      "Aggregation Rule",
      "Contributing Grades",
      "Latest Evidence Updated At",
      "Course Codes",
      "Assignments",
      "Source Files",
      "Provenance Details"
    ], parsed.headers

    first_row = parsed.first
    assert_equal @student.student_id.to_s, first_row["Student ID"]
    assert_equal "Policy Analysis", first_row["Competency"]
    assert_equal "max", first_row["Aggregation Rule"]
    assert_equal "PHPM-700-001", first_row["Course Codes"]
    assert_equal "Case Study", first_row["Assignments"]
    assert_equal "sample.xlsx", first_row["Source Files"]
    assert_includes first_row["Provenance Details"], "raw=95.0"
    assert_equal evidence.updated_at.iso8601, first_row["Latest Evidence Updated At"]

    get export_ratings_admin_grade_import_batch_path(batch, format: :xlsx)
    assert_response :not_acceptable
  end

  test "rollback and recommit toggle matrix visibility for batch-derived ratings" do
    competency_title = Reports::DataAggregator::COMPETENCY_TITLES.first
    batch = GradeImportBatch.create!(
      uploaded_by: @admin,
      status: "completed",
      summary: { "dry_run" => false }
    )

    batch.grade_competency_ratings.create!(
      student: @student,
      competency_title: competency_title,
      aggregated_level: 4.0,
      aggregation_rule: "max",
      evidence_count: 1
    )

    visible_payload = Admin::CompetencyMatrix.new(params: {}, actor_user: @admin).call
    visible_row = visible_payload[:students].find { |row| row[:id] == @student.student_id }
    assert_in_delta 4.0, visible_row.dig(:ratings, competency_title, :course_rating), 0.001

    post rollback_admin_grade_import_batch_path(batch)
    assert_redirected_to admin_grade_import_batch_path(batch)

    hidden_payload = Admin::CompetencyMatrix.new(params: {}, actor_user: @admin).call
    hidden_row = hidden_payload[:students].find { |row| row[:id] == @student.student_id }
    assert_nil hidden_row.dig(:ratings, competency_title, :course_rating)

    post recommit_admin_grade_import_batch_path(batch)
    assert_redirected_to admin_grade_import_batch_path(batch)

    restored_payload = Admin::CompetencyMatrix.new(params: {}, actor_user: @admin).call
    restored_row = restored_payload[:students].find { |row| row[:id] == @student.student_id }
    assert_in_delta 4.0, restored_row.dig(:ratings, competency_title, :course_rating), 0.001
  end
end
