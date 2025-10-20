# Manages the question library that admins can attach to surveys.
#
# Provides CRUD actions for `Question` records along with helper methods used
# by the admin forms.
class Admin::QuestionsController < Admin::BaseController
  before_action :set_question, only: %i[edit update destroy]
  before_action :load_categories, only: %i[new create edit update]

  # Lists all questions with their associated categories for quick reference.
  #
  # @return [void]
  def index
  @questions = Question.includes(category: :survey).ordered
  end

  # Presents a form for creating a new question, pre-populating sensible
  # defaults so the admin can start editing immediately.
  #
  # @return [void]
  def new
    @question = Question.new(question_type: Question.question_types.keys.first, question_order: next_question_order)
  end

  # Persists a newly created question using the submitted form data.
  #
  # @return [void]
  def create
    @question = Question.new(question_params)

    if @question.save
      redirect_to admin_questions_path, notice: "Question created successfully."
    else
      load_categories
      render :new, status: :unprocessable_entity
    end
  end

  # Renders the edit form for the selected question.
  #
  # @return [void]
  def edit; end

  # Updates an existing question with the provided parameters.
  #
  # @return [void]
  def update
    if @question.update(question_params)
      redirect_to admin_questions_path, notice: "Question updated successfully."
    else
      load_categories
      render :edit, status: :unprocessable_entity
    end
  end

  # Deletes a question and redirects back to the listing page.
  #
  # @return [void]
  def destroy
    @question.destroy!
    redirect_to admin_questions_path, notice: "Question deleted successfully."
  end

  private

  # Loads the requested question for mutation-focused actions.
  #
  # @return [void]
  def set_question
    @question = Question.find(params[:id])
  end

  # Fetches categories used to populate select inputs in the form.
  #
  # @return [void]
  def load_categories
    @categories = Category.order(:name)
  end

  # Whitelists question parameters accepted from the admin form.
  #
  # @return [ActionController::Parameters] the permitted parameter hash
  def question_params
    permitted = params.require(:question).permit(
      :question,
      :question_type,
      :question_order,
      :answer_options,
      :category_id,
      category_ids: []
    )

    # Support legacy multi-select params by coalescing the first selected value
    # into the single category_id attribute used by the model.
    permitted[:category_id] = permitted[:category_id].presence

    if permitted[:category_id].blank? && permitted.key?(:category_ids)
      first_selected_id = Array(permitted.delete(:category_ids)).map(&:presence).compact.first
      permitted[:category_id] = first_selected_id if first_selected_id.present?
    else
      permitted.delete(:category_ids)
    end

    permitted.compact
  end

  # @return [Integer] the order value that will place a question at the end
  def next_question_order
    Question.maximum(:question_order).to_i + 1
  end
end
