# CRUD interface for survey categories exposed to admins via the main
# application namespace.
class CategoriesController < ApplicationController
  before_action :set_category, only: %i[ show edit update destroy ]

  # Lists categories grouped by survey.
  #
  # @return [void]
  def index
    @categories = Category.includes(:survey).order(:survey_id, :name)
  end

  # Displays a single category.
  #
  # @return [void]
  def show; end

  # Renders the new-category form.
  #
  # @return [void]
  def new
    @category = Category.new
  end

  # Renders the edit form for an existing category.
  #
  # @return [void]
  def edit; end

  # Persists a new category from submitted parameters.
  #
  # @return [void]
  def create
    @category = Category.new(category_params)

    respond_to do |format|
      if @category.save
        format.html { redirect_to @category, notice: "Category was successfully created." }
        format.json { render :show, status: :created, location: @category }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @category.errors, status: :unprocessable_entity }
      end
    end
  end

  # Updates the selected category with the provided attributes.
  #
  # @return [void]
  def update
    respond_to do |format|
      if @category.update(category_params)
        format.html { redirect_to @category, notice: "Category was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @category }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @category.errors, status: :unprocessable_entity }
      end
    end
  end

  # Deletes a category from the system.
  #
  # @return [void]
  def destroy
    @category.destroy!

    respond_to do |format|
      format.html { redirect_to categories_path, notice: "Category was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private

  # Finds the category matching the request identifier.
  #
  # @return [void]
  def set_category
    @category = Category.find(params[:id])
  end

  # Strong parameters for category creation/update.
  #
  # @return [ActionController::Parameters]
  def category_params
    params.require(:category).permit(:survey_id, :name, :description)
  end
end
