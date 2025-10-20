# CRUD controller for individual responses to survey questions.
class QuestionResponsesController < ApplicationController
  before_action :set_question_response, only: %i[ show edit update destroy ]

  # Lists all recorded question responses.
  #
  # @return [void]
  def index
    @question_responses = QuestionResponse.all
  end

  # Displays a single question response.
  #
  # @return [void]
  def show; end

  # Renders the form for creating a new response.
  #
  # @return [void]
  def new
    @question_response = QuestionResponse.new
  end

  # Renders the edit form for an existing response.
  #
  # @return [void]
  def edit; end

  # Persists a newly submitted response.
  #
  # @return [void]
  def create
    @question_response = QuestionResponse.new(question_response_params)

    respond_to do |format|
      if @question_response.save
        format.html { redirect_to @question_response, notice: "Question response was successfully created." }
        format.json { render :show, status: :created, location: @question_response }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @question_response.errors, status: :unprocessable_entity }
      end
    end
  end

  # Updates a stored response.
  #
  # @return [void]
  def update
    respond_to do |format|
      if @question_response.update(question_response_params)
        format.html { redirect_to @question_response, notice: "Question response was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @question_response }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @question_response.errors, status: :unprocessable_entity }
      end
    end
  end

  # Removes a response from the system.
  #
  # @return [void]
  def destroy
    @question_response.destroy!

    respond_to do |format|
      format.html { redirect_to question_responses_path, notice: "Question response was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private
  # Finds the question response referenced by params.
  #
  # @return [void]
  def set_question_response
    @question_response = QuestionResponse.find(params[:id])
  end

  # Strong parameters for response creation/update.
  #
  # @return [ActionController::Parameters]
  def question_response_params
    params.require(:question_response).permit(:student_id, :advisor_id, :question_id, :answer)
  end
end
