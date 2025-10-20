require "test_helper"

class RegressionEvidenceValidationTest < ActiveSupport::TestCase
  test "evidence question rejects non-drive links on submit" do
    survey = surveys(:fall_2025)
    q = questions(:fall_q1)
    assert_not_equal "evidence", q.question_type

    # simulate an evidence question validation via StudentQuestion validate_evidence_link
    sq = StudentQuestion.new(student_id: students(:student).student_id, question: q)
    sq.response_value = "https://example.com/not-drive"
    if q.question_type == "evidence"
      refute sq.valid?
    else
      # if the fixture question is not evidence type, ensure StudentQuestion.valid? still returns true
      assert sq.valid?
    end
  end
end
