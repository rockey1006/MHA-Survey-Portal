class Admin::QuestionsController < Admin::BaseController
  before_action :set_question, only: %i[edit update destroy]
  before_action :load_categories, only: %i[new create edit update]

  def index
    @questions = Question.includes(:categories).ordered
  end

  def new
    @question = Question.new(question_type: Question.question_types.keys.first, question_order: next_question_order)
  end

  def create
    @question = Question.new(question_params)

    if @question.save
      redirect_to admin_questions_path, notice: "Question created successfully."
    else
      load_categories
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @question.update(question_params)
      redirect_to admin_questions_path, notice: "Question updated successfully."
    else
      load_categories
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @question.destroy!
    redirect_to admin_questions_path, notice: "Question deleted successfully."
  end

  private

  def set_question
    @question = Question.find(params[:id])
  end

  def load_categories
    @categories = Category.order(:name)
  end

  def question_params
    params.require(:question).permit(
      :question,
      :question_type,
      :question_order,
      :answer_options,
      category_ids: []
    )
  end

  def next_question_order
    Question.maximum(:question_order).to_i + 1
  end
end
