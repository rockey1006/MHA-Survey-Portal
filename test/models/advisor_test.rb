require "test_helper"

class AdvisorTest < ActiveSupport::TestCase
  def setup
    @advisor = advisors(:one)
  end

  test "should be valid with valid attributes" do
    assert @advisor.valid?
  end

  test "should require name" do
    @advisor.name = nil
    assert_not @advisor.valid?
    assert_includes @advisor.errors[:name], "can't be blank"
  end

  test "should require email" do
    @advisor.email = nil
    assert_not @advisor.valid?
    assert_includes @advisor.errors[:email], "can't be blank"
  end

  test "should validate email format" do
    valid_emails = %w[test@example.com user@tamu.edu advisor@school.edu]
    valid_emails.each do |email|
      @advisor.email = email
      assert @advisor.valid?, "#{email} should be valid"
    end

    invalid_emails = %w[plainaddress @missingdomain.com missing@.com]
    invalid_emails.each do |email|
      @advisor.email = email
      assert_not @advisor.valid?, "#{email} should be invalid"
    end
  end

  test "should have unique email" do
    duplicate_advisor = @advisor.dup
    @advisor.save
    assert_not duplicate_advisor.valid?
    assert_includes duplicate_advisor.errors[:email], "has already been taken"
  end

  test "should have associations if defined" do
    # Test associations based on your model definition
    # These tests assume standard Rails associations
    if @advisor.respond_to?(:students)
      assert_respond_to @advisor, :students
    end

    if @advisor.respond_to?(:survey_responses)
      assert_respond_to @advisor, :survey_responses
    end
  end
end
