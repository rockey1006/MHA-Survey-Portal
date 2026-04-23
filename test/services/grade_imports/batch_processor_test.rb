require "test_helper"
require "tempfile"
require "fileutils"
require "axlsx"
require "rack/test"

class GradeImports::BatchProcessorTest < ActiveSupport::TestCase
  setup do
    @admin = users(:admin)
    @student = students(:student)
    @temp_paths = []
  end

  teardown do
    @temp_paths.each { |path| FileUtils.rm_f(path) }
  end

  test "direct competency xlsx uses mastery points as the imported competency level" do
    path = build_direct_competency_workbook(
      sheet_name: "PHPM_790_001",
      rows: [
        [
          @student.user.name,
          @student.student_id,
          @student.uin,
          88,
          4
        ]
      ]
    )

    batch = create_batch

    assert_difference -> { GradeCompetencyEvidence.count }, 1 do
      GradeImports::BatchProcessor.new(
        batch: batch,
        files: [ uploaded_excel_file(path, "direct_competency.xlsx") ],
        dry_run: true
      ).call
    end

    evidence = batch.reload.grade_competency_evidences.first
    rating = batch.grade_competency_ratings.first

    assert_equal "completed", batch.status
    assert_equal "PHPM-790-001", evidence.course_code
    assert_equal "Legal & Ethical Bases for Health Services and Health Systems", evidence.competency_title
    assert_equal 4, evidence.mapped_level
    assert_in_delta 88.0, evidence.raw_grade.to_f, 0.001
    assert_equal 4, rating.aggregated_level
  end

  test "canvas workbook with mapping sheet creates evidence and ratings" do
    path = build_canvas_workbook(
      grade_sheet_name: "PHPM_791_002",
      course_code: "PHPM-791-002",
      rows: [
        [ @student.user.name, 8001, @student.uin, @student.uin, "PHPM-791-002", 94 ]
      ]
    )

    batch = create_batch

    assert_difference -> { GradeCompetencyEvidence.count }, 1 do
      GradeImports::BatchProcessor.new(
        batch: batch,
        files: [ uploaded_excel_file(path, "canvas_mapping.xlsx") ],
        dry_run: true
      ).call
    end

    evidence = batch.reload.grade_competency_evidences.first

    assert_equal "completed", batch.status
    assert_equal "PHPM-791-002", evidence.course_code
    assert_equal "Policy Analysis", evidence.competency_title
    assert_equal 5, evidence.mapped_level
    assert_equal 1, batch.grade_competency_ratings.count
  end

  test "re-uploading the same direct competency file suppresses duplicates" do
    path = build_direct_competency_workbook(
      sheet_name: "PHPM_792_003",
      rows: [
        [
          @student.user.name,
          @student.student_id,
          @student.uin,
          91,
          5
        ]
      ]
    )

    first_batch = create_batch
    second_batch = create_batch
    upload = uploaded_excel_file(path, "duplicate_direct.xlsx")

    GradeImports::BatchProcessor.new(batch: first_batch, files: [ upload ], dry_run: true).call
    GradeImports::BatchProcessor.new(
      batch: second_batch,
      files: [ uploaded_excel_file(path, "duplicate_direct.xlsx") ],
      dry_run: true
    ).call

    duplicate_count = second_batch.grade_import_files.first.parsed_content.dig("grade_sheet_debug", "duplicate_warning_count")

    assert_equal 1, first_batch.reload.grade_competency_evidences.count
    assert_equal 0, second_batch.reload.grade_competency_evidences.count
    assert_equal 1, duplicate_count
  end

  private

  def create_batch
    GradeImportBatch.create!(uploaded_by: @admin, status: "pending", summary: { "dry_run" => true })
  end

  def uploaded_excel_file(path, filename)
    Rack::Test::UploadedFile.new(
      path,
      "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
      true,
      original_filename: filename
    )
  end

  def build_direct_competency_workbook(sheet_name:, rows:)
    path = temp_xlsx_path("direct_competency")
    package = Axlsx::Package.new
    package.workbook.add_worksheet(name: sheet_name) do |sheet|
      sheet.add_row [
        "Student name",
        "Student ID",
        "Student SIS ID",
        "EMHA competencies > Legal & Ethical Bases for Health Services and Health Systems result",
        "EMHA competencies > Legal & Ethical Bases for Health Services and Health Systems mastery points",
        "HPMC competencies > Ignore Me result",
        "HPMC competencies > Ignore Me mastery points"
      ]

      rows.each do |row|
        sheet.add_row row + [ 100, 5 ]
      end
    end
    package.serialize(path)
    path
  end

  def build_canvas_workbook(grade_sheet_name:, course_code:, rows:)
    path = temp_xlsx_path("canvas_mapping")
    package = Axlsx::Package.new
    package.workbook.add_worksheet(name: grade_sheet_name) do |sheet|
      sheet.add_row [ "Student", "ID", "SIS User ID", "SIS Login ID", "Section", "Discussion Post 1" ]
      sheet.add_row [ "Points Possible", nil, nil, nil, nil, 100 ]
      rows.each { |row| sheet.add_row row }
    end

    package.workbook.add_worksheet(name: "mapping") do |sheet|
      sheet.add_row [ "assignment_name", "competency_title", "score_basis", "min_grade", "max_grade", "competency_level", "course_code" ]
      sheet.add_row [ "Discussion Post 1", "Policy Analysis", "points", 90, 100, 5, course_code ]
      sheet.add_row [ "Discussion Post 1", "Policy Analysis", "points", 80, 89.99, 4, course_code ]
      sheet.add_row [ "Discussion Post 1", "Policy Analysis", "points", 70, 79.99, 3, course_code ]
      sheet.add_row [ "Discussion Post 1", "Policy Analysis", "points", 60, 69.99, 2, course_code ]
      sheet.add_row [ "Discussion Post 1", "Policy Analysis", "points", 0, 59.99, 1, course_code ]
    end

    package.serialize(path)
    path
  end

  def temp_xlsx_path(prefix)
    file = Tempfile.new([ prefix, ".xlsx" ])
    path = file.path
    file.close!
    @temp_paths << path
    path
  end
end
