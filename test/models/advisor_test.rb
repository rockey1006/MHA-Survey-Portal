require "test_helper"

class AdvisorTest < ActiveSupport::TestCase
  test "display_name prefers name and falls back to email" do
    advisor = advisors(:advisor)

    advisor.name = ""
    assert_equal advisor.email, advisor.display_name

    advisor.name = "Dr. Advisor"
    assert_equal "Dr. Advisor", advisor.display_name
  end

  test "role delegates to associated user" do
    advisor = advisors(:advisor)
    assert_equal advisor.user.role, advisor.role
  end

  test "save persists changed user attributes" do
    advisor = advisors(:advisor)

    original_email = advisor.user.email
    advisor.user.email = "changed-#{SecureRandom.hex(4)}@example.com"

    assert advisor.save
    assert_equal advisor.user.email, advisor.reload.user.email
  ensure
    advisor.user.update!(email: original_email)
  end

  test "save! persists changed user attributes" do
    advisor = advisors(:advisor)

    original_name = advisor.user.name
    advisor.user.name = "Changed #{SecureRandom.hex(3)}"

    advisor.save!
    assert_equal advisor.user.name, advisor.reload.user.name
  ensure
    advisor.user.update!(name: original_name)
  end
end
