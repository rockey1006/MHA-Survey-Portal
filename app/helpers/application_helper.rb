# Helpers shared across views for formatting flash messages, buttons, and audit
# metadata.
module ApplicationHelper
  DEFAULT_SCALE_LABELS = %w[1 2 3 4 5].freeze

  # Base CSS class applied to all flash notifications.
  FLASH_BASE_CLASSES = "flash".freeze
  # Query string keys that should be preserved when building sortable headers.
  SURVEY_SORTABLE_KEYS = %w[q track semester].freeze

  # Computes alert styling classes based on the flash key.
  #
  # @param key [Symbol, String]
  # @return [String]
  def flash_classes(key)
    tone = key.to_sym

    case tone
    when :notice, :info
      "#{FLASH_BASE_CLASSES} flash__notice"
    when :success
      "#{FLASH_BASE_CLASSES} flash__success"
    when :alert, :error
      "#{FLASH_BASE_CLASSES} flash__alert"
    when :warning
      "#{FLASH_BASE_CLASSES} flash__warning"
    else
      FLASH_BASE_CLASSES
    end
  end

  # Provides a human-friendly heading for a flash message key.
  #
  # @param key [Symbol, String]
  # @return [String]
  def flash_title(key)
    {
      notice: "Heads up",
      info: "Heads up",
      success: "Success",
      alert: "Attention",
      error: "Something went wrong",
      warning: "Warning"
    }.fetch(key.to_sym, key.to_s.titleize)
  end

  # Emits a stylesheet tag for Tailwind, with a fallback if the asset pipeline
  # is unavailable (e.g., during development).
  #
  # @return [String, nil]
  def tailwind_stylesheet_tag
    stylesheet_link_tag("tailwind", "data-turbo-track": "reload")
  rescue StandardError => e
    if (asset = Rails.application.assets&.load_path&.find("tailwind.css"))
      prefix = Rails.application.config.assets.prefix.presence || "/assets"
      href = File.join(prefix, asset.digested_path)

      return tag.link(rel: "stylesheet", href:, "data-turbo-track": "reload")
    end

    Rails.logger.warn("tailwind.css could not be loaded: #{e.message}")
    nil
  end

  # Builds Tailwind button classes for the provided variant.
  #
  # @param variant [Symbol]
  # @param extra_classes [String]
  # @return [String]
  def tailwind_button_classes(variant = :primary, extra_classes: "")
    base = "btn"

    variant_class = case variant.to_sym
    when :primary
      "btn-primary"
    when :secondary
      "btn-secondary"
    when :ghost
      "btn-ghost"
    when :subtle
      "btn-subtle"
    when :danger
      "btn-danger"
    else
      "btn-secondary"
    end

    [ base, variant_class, extra_classes.presence ].compact.join(" ")
  end

  # Returns CSS classes for a survey status pill.
  #
  # @param status [String, Symbol]
  # @return [String]
  def survey_status_badge_classes(status)
    base = "inline-flex items-center rounded-full border px-3 py-1 text-xs font-semibold uppercase tracking-wide"

    variant = case status.to_s.downcase
    when "completed"
      "border-emerald-200 bg-emerald-50 text-emerald-700"
    when "pending"
      "border-amber-200 bg-amber-50 text-amber-700"
    else
      "border-slate-200 bg-slate-100 text-slate-600"
    end

    "#{base} #{variant}"
  end

  # Returns a human-friendly due date label for survey summaries.
  #
  # @param due_date [Time, Date, nil]
  # @return [String]
  def survey_due_note(due_date)
    return "No due date" if due_date.blank?

    date = due_date.to_date
    today = Time.zone.today

    if date < today
      "Overdue · #{l(date, format: :long)}"
    elsif date == today
      "Due today"
    else
      "Due #{l(date, format: :long)}"
    end
  end

  # Generates a concise summary string from survey audit metadata.
  #
  # @param metadata [Hash]
  # @return [String]
  def summarize_survey_audit_metadata(metadata)
    data = metadata.with_indifferent_access
    fragments = []

    fragments << data[:note].to_s if data[:note].present?

    if data[:attributes].is_a?(Hash)
      data[:attributes].each do |attribute, change|
        change = change.with_indifferent_access
        before = humanize_audit_value(change[:before])
        after = humanize_audit_value(change[:after])
        next if before == after

        fragments << "#{attribute.to_s.titleize}: #{before} -> #{after}"
      end
    end

    if data[:associations].is_a?(Hash)
      data[:associations].each do |name, change|
        change = change.with_indifferent_access
        before = humanize_audit_list(change[:before])
        after = humanize_audit_list(change[:after])
        next if before == after

        fragments << "#{name.to_s.titleize}: #{before} -> #{after}"
      end
    end

    fragments = fragments.compact
    fragments = [ "No recorded changes" ] if fragments.empty?
    fragments.first(3).join(" | ")
  end

  # Renders a sortable column header link, preserving existing filters.
  #
  # @param label [String]
  # @param column [String]
  # @return [String]
  def sortable_header(label, column)
    active = @sort_column == column
    next_direction = active && @sort_direction == "asc" ? "desc" : "asc"

    preserved_query = request.query_parameters.slice(*SURVEY_SORTABLE_KEYS)
    target_params = preserved_query.merge("sort" => column, "direction" => next_direction)

    classes = [
      "inline-flex items-center gap-1 text-xs font-semibold uppercase tracking-wide text-slate-500 transition hover:text-slate-700"
    ]
    classes << "text-indigo-600" if active

    indicator = if active
      content_tag(:span, "(#{@sort_direction})", class: "text-[0.65rem] font-medium text-indigo-600")
    end
    label_content = indicator ? safe_join([ label, indicator ], " ") : label

    link_to label_content, admin_surveys_path(target_params), class: classes.join(" ")
  end

  # Supplies an accessible label for avatar placeholders and profile images.
  #
  # @param user [Object, nil]
  # @return [String]
  def avatar_aria_label(user)
    return "User avatar" if user.blank?

    name = user.respond_to?(:full_name) ? user.full_name.to_s.strip : ""
    name.present? ? "Profile picture for #{name}" : "User avatar"
  end

  # Returns the configured labels for a scale question, falling back to a
  # standard 1-5 list when no custom labels were provided.
  #
  # @param question [Question]
  # @return [Array<String>]
  def scale_labels_for(question)
    Array(question&.answer_options_list).presence || DEFAULT_SCALE_LABELS
  end

  # Resolves the display label for a stored scale value. When the value is a
  # numeric index, the matching configured label is returned; otherwise the raw
  # value is shown.
  #
  # @param question [Question]
  # @param raw_value [String, Integer]
  # @return [String]
  def scale_label_for_value(question, raw_value)
    return "" if raw_value.blank?

    labels = scale_labels_for(question)
    index = Integer(raw_value) rescue nil
    if index
      labels.fetch(index - 1, raw_value.to_s.presence || "")
    else
      raw_value.to_s
    end
  end

  private

  # Humanizes single audit attribute values for display.
  #
  # @param value [Object]
  # @return [String]
  def humanize_audit_value(value)
    return "none" if value.nil?
    return humanize_audit_list(value) if value.is_a?(Array)

    string = value.to_s.strip
    string.present? ? string : "none"
  end

  # Humanizes audit value arrays into comma-separated strings.
  #
  # @param values [Array]
  # @return [String]
  def humanize_audit_list(values)
    items = Array(values).map { |item| item.to_s.strip }.reject(&:blank?)
    return "none" if items.empty?

    items.join(", ")
  end
end
