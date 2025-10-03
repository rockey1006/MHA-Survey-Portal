class CompetencyResponsesController < ApplicationController
  before_action :set_competency_response, only: %i[ show edit update destroy ]

  # GET /competency_responses or /competency_responses.json
  def index
    @competency_responses = CompetencyResponse.all
  end

  # GET /competency_responses/1 or /competency_responses/1.json
  def show
  end

  # GET /competency_responses/new
  def new
    @competency_response = CompetencyResponse.new
  end

  # GET /competency_responses/1/edit
  def edit
  end

  # POST /competency_responses or /competency_responses.json
  def create
    @competency_response = CompetencyResponse.new(competency_response_params)

    respond_to do |format|
      if @competency_response.save
        format.html { redirect_to @competency_response, notice: "Competency response was successfully created." }
        format.json { render :show, status: :created, location: @competency_response }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @competency_response.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /competency_responses/1 or /competency_responses/1.json
  def update
    respond_to do |format|
      if @competency_response.update(competency_response_params)
        format.html { redirect_to @competency_response, notice: "Competency response was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @competency_response }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @competency_response.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /competency_responses/1 or /competency_responses/1.json
  def destroy
    @competency_response.destroy!

    respond_to do |format|
      format.html { redirect_to competency_responses_path, notice: "Competency response was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_competency_response
      @competency_response = CompetencyResponse.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def competency_response_params
      params.require(:competency_response).permit(:competencyresponse_id, :surveyresponse_id, :competency_id)
    end
end
