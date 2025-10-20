require "test_helper"

class CategoriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @category = categories(:clinical_skills)
    @student = users(:student)
    sign_in @student
  end

  test "index shows categories" do
    get categories_path
    assert_response :success
    assert_select "h1", /Categories|Clinical Skills/i
  end

  test "show category" do
    get category_path(@category)
    assert_response :success
    assert_match /#{Regexp.escape(@category.name)}/i, response.body
  end
end
