class SurveysController < ApplicationController
  before_action :set_survey, only: %i[ show edit update destroy submit ]

  # GET /surveys or /surveys.json
  def index
    @surveys = Survey.all
  end

  # GET /surveys/1 or /surveys/1.json
  def show
    # If a student is signed in (via current_admin), collect existing answers so the
    # survey form can pre-fill previously submitted responses for editing/resubmission.
    @existing_answers = {}
    if defined?(current_admin) && current_admin.present?
      student = Student.find_by(email: current_admin.email)
      if student
        # Find the survey_response for this student & survey
        sr = SurveyResponse.find_by(student_id: student.id, survey_id: @survey.id)
        if sr
          # Collect question responses only for this survey_response
          question_ids = @survey.respond_to?(:questions) ? @survey.questions.pluck(:id) : []
          cr_ids = CompetencyResponse.where(surveyresponse_id: sr.id).pluck(:id)
          qrs = QuestionResponse.where(question_id: question_ids, competencyresponse_id: cr_ids)
          qrs.each do |qr|
            @existing_answers[qr.question_id] = qr.answer
          end
        end
      end
    end
  end

  # GET /surveys/new
  def new
    @survey = Survey.new
  end

  # GET /surveys/1/edit
  def edit
  end

  # POST /surveys or /surveys.json
  def create
    @survey = Survey.new(survey_params)

    respond_to do |format|
      if @survey.save
        format.html { redirect_to @survey, notice: "Survey was successfully created." }
        format.json { render :show, status: :created, location: @survey }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @survey.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /surveys/1 or /surveys/1.json
  def update
    respond_to do |format|
      if @survey.update(survey_params)
        format.html { redirect_to @survey, notice: "Survey was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @survey }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @survey.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /surveys/1 or /surveys/1.json
  def destroy
    @survey.destroy!

    respond_to do |format|
      format.html { redirect_to surveys_path, notice: "Survey was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end
  # POST /surveys/1/submit
  def submit
    # identify the acting student: try to match current_admin (Devise) to Student by email
    student = nil
    if defined?(current_admin) && current_admin.present?
      student = Student.find_by(email: current_admin.email)
    end

    unless student
      redirect_to student_dashboard_path, alert: "Student record not found for current user."
      return
    end

    # Find or create survey_response and mark submitted
    survey_response = SurveyResponse.find_or_initialize_by(student_id: student.id, survey_id: @survey.id)
    survey_response.status = SurveyResponse.statuses[:submitted]
    survey_response.advisor_id ||= student.advisor_id
    survey_response.semester ||= params[:semester]
    survey_response.save!

    # Save question responses if provided
    answers = params[:answers] || {}
    answers.each do |question_id_str, answer_value|
      # question ids might be 'sample_text' fallback — skip non-integer keys
      next unless question_id_str.to_s =~ /^\d+$/
      qid = question_id_str.to_i
      q = Question.find_by(id: qid)
      next unless q

      # Find or create the competency_response for this survey_response and question's competency
      comp = Competency.find_by(id: q.competency_id)
      comp_resp = nil
      if comp
        comp_resp = CompetencyResponse.find_or_create_by!(surveyresponse_id: survey_response.id, competency_id: comp.id)
      end

      # normalize checkbox arrays into JSON/string
      response_value = answer_value

      # create or update existing question_response scoped to the competency_response
      qr = if comp_resp
             QuestionResponse.find_or_initialize_by(question_id: qid, competencyresponse_id: comp_resp.id)
      else
             # Fallback: if no competency available, store with nil competencyresponse (legacy behavior)
             QuestionResponse.find_or_initialize_by(question_id: qid, competencyresponse_id: nil)
      end
      qr.answer = response_value
      qr.save!
    end

    redirect_to survey_response_path(survey_response), notice: "Survey submitted successfully!"
  end
  private
    # Use callbacks to share common setup or constraints between actions.
    def set_survey
      @survey = Survey.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def survey_params
      params.expect(survey: [ :survey_id, :assigned_date, :completion_date, :approval_date ])
    end
end
