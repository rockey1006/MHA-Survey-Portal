require "test_helper"

class GradeImportBatchTest < ActiveSupport::TestCase
  setup do
    @admin = users(:admin)
  end

  test "reportable scope includes only explicitly committed completed batches" do
    committed = GradeImportBatch.create!(uploaded_by: @admin, status: "completed", summary: { "dry_run" => false })
    GradeImportBatch.create!(uploaded_by: @admin, status: "completed", summary: { "dry_run" => true })
    GradeImportBatch.create!(uploaded_by: @admin, status: "completed", summary: {})
    GradeImportBatch.create!(uploaded_by: @admin, status: "rolled_back", summary: { "dry_run" => false })
    GradeImportBatch.create!(uploaded_by: @admin, status: "failed", summary: { "dry_run" => false })

    assert_equal [ committed.id ], GradeImportBatch.reportable.pluck(:id)
    assert committed.reportable?
  end
end
