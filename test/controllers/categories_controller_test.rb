require "test_helper"

class CategoriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @category = categories(:clinical_skills)
    @admin = users(:admin)
    sign_in @admin
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

  test "new renders category form" do
    get new_category_path
    assert_response :success
  end

  test "create category" do
    params = {
      category: {
        survey_id: surveys(:fall_2025).id,
        name: "Wellness",
        description: "Wellness focus"
      }
    }

    assert_difference "Category.count", 1 do
      post categories_path, params: params
    end

    assert_redirected_to category_path(Category.order(:created_at).last)
  end

  test "create with invalid data rerenders form" do
    assert_no_difference "Category.count" do
      post categories_path, params: { category: { survey_id: surveys(:fall_2025).id, name: "" } }
    end

    assert_response :unprocessable_entity
  end

  test "update category" do
    patch category_path(@category), params: { category: { name: "Updated Category" } }
    assert_redirected_to category_path(@category)
    assert_equal "Updated Category", @category.reload.name
  end

  test "destroy category" do
    category = Category.create!(survey: surveys(:spring_2025), name: "Temp", description: "Tmp")

    assert_difference "Category.count", -1 do
      delete category_path(category)
    end

    assert_redirected_to categories_path
  end
end
