class SurveysController < ApplicationController
  before_action :set_survey, only: %i[ show edit update destroy submit ]

  # GET /surveys or /surveys.json
  def index
    # 只显示当前学生 track 对应的 survey
    if current_student && current_student.track.present?
      if current_student.track == 'Executive'
        @surveys = Survey.where(title: 'Executive Survey')
      elsif current_student.track == 'Residential'
        @surveys = Survey.where(title: 'Residential Survey')
      else
        @surveys = Survey.none
      end
    else
      @surveys = Survey.none
    end
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

    # Validate all required questions are answered
    answers = params[:answers] || {}
    evidence_links = params[:evidence_links] || {}

    missing_required = []
    @survey.competencies.each do |comp|
      comp.questions.each do |q|
        # Make all non-conditional free_response questions required
        is_required = q.required
        if q.question_type == 'free_response' && q.depends_on_question_id.blank? && q.depends_on_value.blank?
          is_required = true
        end
        next unless is_required
        # Conditional required: only check if dependency is met
        if q.depends_on_question_id.present? && q.depends_on_value.present?
          dep_val = answers[q.depends_on_question_id.to_s]
          next unless dep_val.to_s == q.depends_on_value.to_s
        end
        val = if q.question_type == 'evidence'
          evidence_links[comp.id.to_s]
        else
          answers[q.id.to_s]
        end
        if val.blank?
          missing_required << q
        end
      end
    end

    if missing_required.any?
      # Pass missing required question IDs to the view for highlighting
      flash[:alert] = "Please answer all required questions (marked with *)."
      flash[:missing_required_ids] = missing_required.map(&:id)
      redirect_to survey_path(@survey, missing: missing_required.map(&:id).join(',')) and return
    end

    # Save question responses if provided
    # Save normal answers
    answers.each do |question_id_str, answer_value|
      next unless question_id_str.to_s =~ /^\d+$/
      qid = question_id_str.to_i
      q = Question.find_by(id: qid)
      next unless q
      comp = q.competency
      comp_resp = nil
      if comp
        comp_resp = CompetencyResponse.find_or_create_by!(surveyresponse_id: survey_response.id, competency_id: comp.id)
      end
      qr = if comp_resp
             QuestionResponse.find_or_initialize_by(question_id: qid, competencyresponse_id: comp_resp.id)
           else
             QuestionResponse.find_or_initialize_by(question_id: qid, competencyresponse_id: nil)
           end
      qr.answer = answer_value
      qr.save!
    end

    # Save evidence links as answers to 'evidence' questions
    evidence_links.each do |comp_id_str, link|
      next if link.blank?
      comp_id = comp_id_str.to_i
      comp = Competency.find_by(id: comp_id)
      next unless comp
      evidence_q = comp.questions.find_by(question_type: 'evidence')
      next unless evidence_q
      comp_resp = CompetencyResponse.find_or_create_by!(surveyresponse_id: survey_response.id, competency_id: comp.id)
      qr = QuestionResponse.find_or_initialize_by(question_id: evidence_q.id, competencyresponse_id: comp_resp.id)
      qr.answer = link
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
      params.require(:survey).permit(:survey_id, :assigned_date, :completion_date, :approval_date, :title, :semester)
    end
end
