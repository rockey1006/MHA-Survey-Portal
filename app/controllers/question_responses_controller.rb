class QuestionResponsesController < ApplicationController
  before_action :set_question_response, only: %i[ show edit update destroy ]

  # GET /question_responses or /question_responses.json
  def index
    @question_responses = QuestionResponse.all
  end

  # GET /question_responses/1 or /question_responses/1.json
  def show
  end

  # GET /question_responses/new
  def new
    @question_response = QuestionResponse.new
  end

  # GET /question_responses/1/edit
  def edit
  end

  # POST /question_responses or /question_responses.json
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

  # PATCH/PUT /question_responses/1 or /question_responses/1.json
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

  # DELETE /question_responses/1 or /question_responses/1.json
  def destroy
    @question_response.destroy!

    respond_to do |format|
      format.html { redirect_to question_responses_path, notice: "Question response was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_question_response
      @question_response = QuestionResponse.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def question_response_params
      params.require(:question_response).permit(:surveyresponse_id, :question_id, :answer)
    end
end
