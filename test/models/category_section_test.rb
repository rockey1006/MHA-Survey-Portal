require "test_helper"

class CategorySectionTest < ActiveSupport::TestCase
  setup do
    @survey = surveys(:fall_2025)
    @other_survey = surveys(:spring_2025)
  end

  test "section must belong to the same survey" do
    category = Category.create!(survey: @survey, name: "Temporary Category")
    section = SurveySection.create!(survey: @other_survey, title: "Other Section")

    category.section = section
    assert_not category.valid?
    assert_includes category.errors[:section], "must belong to the same survey"
  end
end
