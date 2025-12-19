# CRUD controller for survey questions used within categories.
class QuestionsController < ApplicationController
  before_action :set_question, only: %i[ show edit update destroy ]

  # Lists all questions.
  #
  # @return [void]
  def index
    @questions = Question.all
  end

  # Displays the selected question.
  #
  # @return [void]
  def show; end

  # Renders the new-question form.
  #
  # @return [void]
  def new
    @question = Question.new
  end

  # Renders the edit form for an existing question.
  #
  # @return [void]
  def edit; end

  # Creates a question record.
  #
  # @return [void]
  def create
    @question = Question.new(question_params)

    respond_to do |format|
      if @question.save
        format.html { redirect_to @question, notice: "Question was successfully created." }
        format.json { render :show, status: :created, location: @question }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @question.errors, status: :unprocessable_entity }
      end
    end
  end

  # Updates an existing question.
  #
  # @return [void]
  def update
    respond_to do |format|
      if @question.update(question_params)
        format.html { redirect_to @question, notice: "Question was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @question }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @question.errors, status: :unprocessable_entity }
      end
    end
  end

  # Deletes the question and redirects to the index.
  #
  # @return [void]
  def destroy
    @question.destroy!

    respond_to do |format|
      format.html { redirect_to questions_path, notice: "Question was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private
  # Finds the question requested.
  #
  # @return [void]
  def set_question
    @question = Question.find(params[:id])
  end

  # Strong parameters for question creation/update.
  # Supports legacy :text keys by mapping to :question_text.
  #
  # @return [ActionController::Parameters]
  def question_params
    # Support both `question` and `text` keys coming from different callers/tests.
    if params[:question] && params[:question][:text].present?
      params[:question][:question_text] = params[:question].delete(:text)
    end

    params.require(:question).permit(:category_id, :question_order, :question_type, :question_text, :description, :tooltip_text, :answer_options, :is_required, :has_evidence_field, :has_feedback)
  end
end
