class Admin::SurveysController < Admin::BaseController
  before_action :set_survey, only: %i[edit update destroy preview]
  before_action :load_bulk_support, only: %i[index bulk_update]
  before_action :load_form_data, only: %i[new create edit update]
  before_action :set_sorting, only: :index

  def index
    @group_by = permitted_grouping
    @query = params[:q].to_s.strip
    @selected_track = params[:track].presence
    @selected_semester = params[:semester].presence

    scope = Survey.includes(:categories, assigned_advisors: :user, tagged_categories: :category)
    scope = scope.where(track: @selected_track) if @selected_track
    scope = scope.where(semester: @selected_semester) if @selected_semester

    if @query.present?
      pattern = "%#{ActiveRecord::Base.sanitize_sql_like(@query)}%"
      scope = scope.where(Survey.arel_table[:title].matches(pattern))
    end

    @surveys = sorted_surveys(scope)
    @total_surveys = @surveys.size
    @grouped_surveys = group_surveys(@surveys, @group_by)
    @semester_options = Survey.distinct.order(:semester).pluck(:semester).compact
    @audit_logs = SurveyAuditLog.includes(admin: :user, survey: []).recent_first.limit(10)
  end

    def new
      @survey = Survey.new
    end

    def create
      @survey = Survey.new(survey_params)

      if @survey.save
        @survey.reload
        log_survey_action("create", @survey, metadata: audit_metadata_for(@survey))
        redirect_to admin_surveys_path, notice: "Survey created successfully."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      before_snapshot = association_snapshot(@survey)

      if @survey.update(survey_params)
        attribute_changes = extract_attribute_changes(@survey.saved_changes)
        @survey.reload
        after_snapshot = association_snapshot(@survey)

        metadata = {}
        metadata[:attributes] = attribute_changes if attribute_changes.present?

        association_changes = association_differences(before_snapshot, after_snapshot)
        metadata[:associations] = association_changes if association_changes.present?
        metadata[:note] = "Update saved with no detected changes" if metadata.blank?

        log_survey_action("update", @survey, metadata: metadata)
        redirect_to admin_surveys_path, notice: "Survey updated successfully."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      survey_id = @survey.id
      metadata = audit_metadata_for(@survey, before_snapshot: survey_snapshot(@survey), after_snapshot: {})
      metadata[:note] = "Survey deleted"
      @survey.destroy!
      log_survey_action("delete", nil, survey_id: survey_id, metadata: metadata)
      redirect_to admin_surveys_path, notice: "Survey deleted successfully."
    end

    def preview
      @questions = @survey.questions.includes(:categories).order(:question_order)
      @advisor_names = names_for_advisors(@survey.assigned_advisor_ids)
      @category_names = names_for_categories(@survey.tagged_category_ids)

      log_survey_action("preview", @survey, metadata: { via: "admin_dashboard" })
    end

    def bulk_update
      permitted = params.permit(:track, survey_ids: [], assigned_advisor_ids: [], tagged_category_ids: [])
      survey_ids = Array(permitted[:survey_ids]).map(&:presence).compact.map(&:to_i).uniq

      if survey_ids.empty?
        redirect_to admin_surveys_path, alert: "Select at least one survey to update." and return
      end

      track = permitted[:track].to_s.strip
      track = nil if track.blank?

      advisor_ids = normalize_id_list(permitted[:assigned_advisor_ids])
      category_ids = normalize_id_list(permitted[:tagged_category_ids])

      if track.nil? && advisor_ids.nil? && category_ids.nil?
        redirect_to admin_surveys_path, alert: "Choose at least one grouping option to apply." and return
      end

      surveys = Survey.where(id: survey_ids)
      advisor_lookup_hash = advisor_lookup
      category_lookup_hash = category_lookup

      Survey.transaction do
        surveys.each do |survey|
          changes = {}

          if !track.nil? && survey.track != track
            changes[:track] = { before: survey.track, after: track }
            survey.track = track
          end

          if advisor_ids
            before_ids = survey.assigned_advisor_ids.sort
            survey.assigned_advisor_ids = advisor_ids
            after_ids = survey.assigned_advisor_ids.sort
            if before_ids != after_ids
              changes[:advisors] = {
                before: names_for_advisors(before_ids, advisor_lookup_hash),
                after: names_for_advisors(after_ids, advisor_lookup_hash)
              }
            end
          end

          if category_ids
            before_ids = survey.tagged_category_ids.sort
            survey.tagged_category_ids = category_ids
            after_ids = survey.tagged_category_ids.sort
            if before_ids != after_ids
              changes[:categories] = {
                before: names_for_categories(before_ids, category_lookup_hash),
                after: names_for_categories(after_ids, category_lookup_hash)
              }
            end
          end

          survey.save! if survey.changed?
          log_survey_action("group_update", survey, metadata: changes) if changes.present?
        end
      end

      redirect_to admin_surveys_path, notice: "Updated #{surveys.size} survey#{'s' if surveys.size != 1}."
    end

    private

    def set_survey
      @survey = Survey.find(params[:id])
    end

    def survey_params
      permitted = params.require(:survey).permit(
        :title,
        :semester,
        :track,
        question_ids: [],
        assigned_advisor_ids: [],
        tagged_category_ids: []
      )

      permitted[:question_ids] = normalize_id_list(permitted[:question_ids]) || []
      permitted[:assigned_advisor_ids] = normalize_id_list(permitted[:assigned_advisor_ids]) || []
      permitted[:tagged_category_ids] = normalize_id_list(permitted[:tagged_category_ids]) || []

      permitted
    end

    def permitted_grouping
      requested = params[:group_by].to_s
      return requested if %w[track advisor category semester].include?(requested)

      "track"
    end

  def group_surveys(surveys, group_by)
    grouped = Hash.new { |hash, key| hash[key] = [] }

    surveys.each do |survey|
      case group_by
      when "advisor"
        advisors = survey.assigned_advisors
        if advisors.any?
          advisors.each do |advisor|
            grouped[advisor.display_name] << survey
          end
        else
          grouped["Unassigned Advisors"] << survey
        end
      when "category"
        categories = survey.tagged_categories.presence || survey.categories
        if categories.any?
          categories.each do |category|
            grouped[category.name] << survey
          end
        else
          grouped["Uncategorized"] << survey
        end
      when "semester"
        grouped[survey.semester.presence || "Unscheduled Semester"] << survey
      else
        grouped[survey.track.presence || "Unassigned Track"] << survey
      end
    end

    grouped.map do |group_name, list|
      [group_name, deduplicate_preserving_order(list)]
    end.sort_by { |group_name, _| group_name.to_s.downcase }
  end

    def load_bulk_support
      @advisors = Advisor.includes(:user).references(:users).order(Arel.sql("LOWER(users.name) ASC"))
      @categories = Category.order(:name)
      @track_options = (
        Survey::TRACK_OPTIONS +
        Student.distinct.pluck(:track).compact +
        Survey.distinct.pluck(:track).compact
      ).map(&:to_s).reject(&:blank?).uniq.sort
    end

    def load_form_data
      load_bulk_support
      @questions = Question.includes(:categories).order(:question_order)
    end

    def association_snapshot(survey)
      {
        advisor_ids: survey.assigned_advisor_ids.sort,
        category_ids: survey.tagged_category_ids.sort,
        question_ids: survey.question_ids.sort
      }
    end

    def association_differences(before_snapshot, after_snapshot)
      diff = {}

      if before_snapshot[:advisor_ids] != after_snapshot[:advisor_ids]
        diff[:advisors] = {
          before: names_for_advisors(before_snapshot[:advisor_ids]),
          after: names_for_advisors(after_snapshot[:advisor_ids])
        }
      end

      if before_snapshot[:category_ids] != after_snapshot[:category_ids]
        diff[:categories] = {
          before: names_for_categories(before_snapshot[:category_ids]),
          after: names_for_categories(after_snapshot[:category_ids])
        }
      end

      if before_snapshot[:question_ids] != after_snapshot[:question_ids]
        diff[:questions] = {
          before: names_for_questions(before_snapshot[:question_ids]),
          after: names_for_questions(after_snapshot[:question_ids])
        }
      end

      diff
    end

    def extract_attribute_changes(changes)
      return {} unless changes

      changes.except("updated_at", "created_at").each_with_object({}) do |(attribute, values), hash|
        before_value, after_value = values
        next if before_value == after_value

        hash[attribute] = { before: before_value, after: after_value }
      end
    end

    def audit_metadata_for(survey, before_snapshot: nil, after_snapshot: nil)
      before_snapshot ||= {}
      after_snapshot ||= survey_snapshot(survey)
      metadata = {}

      attributes_diff = diff_snapshot_section(before_snapshot[:attributes], after_snapshot[:attributes])
      metadata[:attributes] = attributes_diff if attributes_diff.present?

      associations_diff = diff_snapshot_section(before_snapshot[:associations], after_snapshot[:associations])
      metadata[:associations] = associations_diff if associations_diff.present?

      metadata
    end

    def normalize_id_list(values)
      normalized = Array(values).map(&:presence).compact.map(&:to_i).uniq
      normalized.empty? ? nil : normalized
    end

    def survey_snapshot(survey)
      {
        attributes: {
          "title" => survey.title,
          "semester" => survey.semester,
          "track" => survey.track
        },
        associations: {
          "advisors" => names_for_advisors(survey.assigned_advisor_ids),
          "categories" => names_for_categories(survey.tagged_category_ids.presence || survey.category_ids),
          "questions" => names_for_questions(survey.question_ids)
        }
      }
    end

    def diff_snapshot_section(before_section, after_section)
      before_section = (before_section || {}).transform_keys(&:to_s)
      after_section = (after_section || {}).transform_keys(&:to_s)
      keys = (before_section.keys + after_section.keys).uniq

      diffs = keys.each_with_object({}) do |key, result|
        before_value = before_section[key]
        after_value = after_section[key]
        next if before_value == after_value

        result[key] = { before: before_value, after: after_value }
      end

      diffs.presence
    end

    def advisor_lookup
      return @advisor_lookup if defined?(@advisor_lookup) && @advisor_lookup

      records = (@advisors || Advisor.includes(:user)).to_a
      @advisor_lookup = records.index_by(&:advisor_id)
    end

    def category_lookup
      return @category_lookup if defined?(@category_lookup) && @category_lookup

      records = (@categories || Category.all).to_a
      @category_lookup = records.index_by(&:id)
    end

    def names_for_advisors(ids, lookup = advisor_lookup)
      Array(ids).map { |advisor_id| lookup[advisor_id]&.display_name || "Advisor ##{advisor_id}" }
    end

    def names_for_categories(ids, lookup = category_lookup)
      Array(ids).map { |category_id| lookup[category_id]&.name || "Category ##{category_id}" }
    end

    def names_for_questions(ids)
      return [] if ids.blank?

      @question_lookup ||= {}
      missing_ids = Array(ids).map(&:to_i) - @question_lookup.keys
      if missing_ids.any?
        Question.where(id: missing_ids).pluck(:id, :question).each do |id, question|
          @question_lookup[id] = question
        end
      end

      Array(ids).map { |question_id| @question_lookup[question_id.to_i] || "Question ##{question_id}" }
    end

  def log_survey_action(action, survey, survey_id: nil, metadata: {})
    admin_profile = current_admin_profile || current_user&.create_admin_profile
    return unless admin_profile

    SurveyAuditLog.create!(
      admin: admin_profile,
      survey: survey,
      survey_id: survey_id || survey&.id,
      action: action,
      metadata: metadata.merge(
        performed_by: current_user.email,
        performed_at: Time.current
      )
    )
  end

  SORTABLE_COLUMNS = {
    "title" => { mode: :sql, expression: "LOWER(surveys.title)" },
    "semester" => { mode: :sql, expression: "LOWER(surveys.semester)" },
    "track" => { mode: :sql, expression: "LOWER(surveys.track)" },
    "created_at" => { mode: :sql, expression: "surveys.created_at" },
    "categories" => { mode: :ruby, accessor: :survey_category_sort_key },
    "advisors" => { mode: :ruby, accessor: :survey_advisor_sort_key }
  }.freeze

  def set_sorting
    requested_sort = params[:sort].to_s
    @sort_column = SORTABLE_COLUMNS.key?(requested_sort) ? requested_sort : "title"

    requested_direction = params[:direction].to_s.downcase
    @sort_direction = %w[asc desc].include?(requested_direction) ? requested_direction : "asc"
  end

  def sort_order_clause
    strategy = SORTABLE_COLUMNS[@sort_column]
    return unless strategy && strategy[:mode] == :sql

    "#{strategy[:expression]} #{@sort_direction.upcase}, surveys.id ASC"
  end

  def deduplicate_preserving_order(list)
    seen = {}
    ordered = []

    list.each do |survey|
      next if seen[survey.id]

      ordered << survey
      seen[survey.id] = true
    end

    ordered
  end

  def sorted_surveys(scope)
    strategy = SORTABLE_COLUMNS[@sort_column]
    return scope.order(Arel.sql("LOWER(surveys.title) #{@sort_direction.upcase}, surveys.id ASC")).to_a unless strategy

    case strategy[:mode]
    when :sql
      clause = sort_order_clause
      clause ? scope.order(Arel.sql(clause)).to_a : scope.to_a
    when :ruby
      records = scope.to_a
      accessor = method(strategy[:accessor])
      records.sort_by! { |survey| normalize_sort_value(accessor.call(survey)) }
      records.reverse! if @sort_direction == "desc"
      records
    else
      scope.to_a
    end
  end

  def normalize_sort_value(value)
    Array(value).flatten.compact.map { |item| item.to_s.downcase }.join("|")
  end

  def survey_category_sort_key(survey)
    categories = survey.tagged_categories.presence || survey.categories
    categories.map(&:name).map(&:to_s).sort
  end

  def survey_advisor_sort_key(survey)
    survey.assigned_advisors.map(&:display_name).map(&:to_s).sort
  end
end
