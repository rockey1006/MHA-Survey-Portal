class Admin::SurveysController < Admin::BaseController
  before_action :set_survey, only: %i[edit update destroy preview archive activate]
  before_action :prepare_supporting_data, only: %i[new create edit update]

  def index
    scope = Survey.includes(:categories, :survey_assignments, :creator)
    @active_surveys = scope.active.order(updated_at: :desc)
    @archived_surveys = scope.archived.order(updated_at: :desc)
    @recent_logs = SurveyChangeLog.recent.includes(:survey, :admin).limit(12)
  end

  def new
    @survey = Survey.new(created_by: current_user, semester: default_semester)
    build_default_structure(@survey)
  end

  def create
    @survey = Survey.new(survey_params)
    @survey.created_by ||= current_user
    @survey.semester ||= default_semester

    tracks = selected_tracks

    if @survey.save
      @survey.assign_tracks!(tracks)
      @survey.log_change!(admin: current_user, action: "create", description: "Survey created with #{tracks.size} track(s)")
      redirect_to admin_surveys_path, notice: "Survey created successfully."
    else
      build_default_structure(@survey)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    build_default_structure(@survey)
  end

  def update
    tracks = selected_tracks
    before_snapshot = survey_snapshot(@survey)

    if @survey.update(survey_params)
      @survey.assign_tracks!(tracks)
      description = change_summary(before_snapshot, survey_snapshot(@survey), tracks)
      @survey.log_change!(admin: current_user, action: "update", description: description)
      redirect_to admin_surveys_path, notice: "Survey updated successfully."
    else
      build_default_structure(@survey)
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    summary = "Survey deleted (#{@survey.title})"
    @survey.log_change!(admin: current_user, action: "delete", description: summary)
    @survey.destroy!
    redirect_to admin_surveys_path, notice: "Survey deleted successfully."
  end

  def archive
    if @survey.update(is_active: false)
      @survey.assign_tracks!([])
      @survey.log_change!(admin: current_user, action: "archive", description: "Survey archived and unassigned from all tracks")
      redirect_to admin_surveys_path, notice: "Survey archived."
    else
      redirect_to edit_admin_survey_path(@survey), alert: @survey.errors.full_messages.to_sentence
    end
  end

  def activate
    if @survey.update(is_active: true)
      @survey.log_change!(admin: current_user, action: "activate", description: "Survey reactivated")
      redirect_to admin_surveys_path, notice: "Survey activated."
    else
      redirect_to edit_admin_survey_path(@survey), alert: @survey.errors.full_messages.to_sentence
    end
  end

  def preview
    @categories = @survey.categories.includes(:questions).order(:id)
    @questions = @survey.questions.includes(:category).order(:question_order)
    @category_names = @categories.map(&:name)
    @track_list = @survey.track_list
    @survey.log_change!(admin: current_user, action: "preview", description: "Previewed from admin panel")
  end

  private

  def set_survey
    @survey = Survey.find(params[:id])
  end

  def survey_params
    params.require(:survey).permit(
      :title,
      :description,
      :semester,
      :is_active,
      categories_attributes: [
        :id,
        :name,
        :description,
        :_destroy,
        questions_attributes: [
          :id,
          :question_text,
          :question_type,
          :question_order,
          :answer_options,
          :is_required,
          :has_evidence_field,
          :_destroy
        ]
      ]
    )
  end

  def selected_tracks
    permitted = params.fetch(:survey, {}).permit(track_list: [], additional_track_names: "")
    base = Array(permitted[:track_list]).map(&:to_s)
    extras = permitted[:additional_track_names].to_s.split(/[,\n;]/)
    (base + extras).map(&:strip).reject(&:blank?).uniq
  end

  def prepare_supporting_data
    @available_tracks = (
      Survey::TRACK_OPTIONS +
      Student.distinct.pluck(:track).compact +
      SurveyAssignment.distinct.pluck(:track).compact
    ).map(&:to_s).reject(&:blank?).uniq.sort
    @question_types = Question.question_types.keys
  end

  def build_default_structure(survey)
    if survey.categories.empty?
      category = survey.categories.build(name: "New Category")
      build_default_question(category)
    else
      survey.categories.each do |category|
        build_default_question(category) if category.questions.empty?
      end
    end
  end

  def build_default_question(category)
    category.questions.build(
      question_text: "New question",
      question_type: Question.question_types.keys.first,
      question_order: (category.questions.maximum(:question_order) || 0) + 1,
      is_required: false,
      has_evidence_field: false
    )
  end

  def default_semester
    current = Time.zone.today
    year = current.year
    season = case current.month
             when 1..4 then "Spring"
             when 5..7 then "Summer"
             else "Fall"
             end
    "#{season} #{year}"
  end

  def survey_snapshot(survey)
    {
      title: survey.title,
      semester: survey.semester,
      description: survey.description,
      is_active: survey.is_active,
      tracks: survey.track_list,
      categories: survey.categories.map do |category|
        {
          name: category.name,
          question_count: category.questions.size
        }
      end
    }
  end

  def change_summary(before, after, tracks)
    diffs = []
    %i[title semester description is_active].each do |attribute|
      before_value = before[attribute]
      after_value = after[attribute]
      next if before_value == after_value

      diffs << "#{attribute.to_s.humanize} changed from '#{before_value}' to '#{after_value}'"
    end

    if before[:tracks].sort != tracks.sort
      diffs << "Tracks updated to #{tracks.join(', ')}"
    end

    before_counts = before[:categories].map { |c| c[:question_count] }
    after_counts = after[:categories].map { |c| c[:question_count] }
    diffs << "Category/question structure updated" if before_counts != after_counts

    diffs.present? ? diffs.join("; ") : "No structural changes detected"
  end
end
