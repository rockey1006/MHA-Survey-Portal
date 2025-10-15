module ApplicationHelper
  FLASH_BASE_CLASSES = "mb-4 flex items-start gap-3 rounded-lg border-l-4 px-4 py-3 shadow-sm".freeze

  def flash_classes(key)
    tone = key.to_sym

    case tone
    when :notice, :info
      "#{FLASH_BASE_CLASSES} border-blue-500 bg-blue-50 text-blue-900"
    when :success
      "#{FLASH_BASE_CLASSES} border-emerald-500 bg-emerald-50 text-emerald-900"
    when :alert, :error
      "#{FLASH_BASE_CLASSES} border-red-500 bg-red-50 text-red-900"
    when :warning
      "#{FLASH_BASE_CLASSES} border-amber-500 bg-amber-50 text-amber-900"
    else
      "#{FLASH_BASE_CLASSES} border-slate-400 bg-white text-slate-700"
    end
  end

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

  def tailwind_button_classes(variant = :primary, extra_classes: "")
    base = "inline-flex items-center justify-center gap-2 rounded-lg px-4 py-2 text-sm font-semibold transition-colors focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 disabled:cursor-not-allowed disabled:opacity-50"

    variant_classes = case variant.to_sym
    when :primary
      "bg-[#500000] text-white hover:bg-[#330000] focus-visible:outline-[#500000]"
    when :secondary
      "border border-[#500000] text-[#500000] hover:bg-[#f9f2f2] focus-visible:outline-[#500000]"
    when :subtle
      "bg-slate-100 text-slate-700 hover:bg-slate-200 focus-visible:outline-slate-400"
    else
      "bg-slate-700 text-white hover:bg-slate-800 focus-visible:outline-slate-700"
    end

    [ base, variant_classes, extra_classes.presence ].compact.join(" ")
  end

  def survey_status_badge_classes(status)
    base = "inline-flex items-center rounded-full border px-3 py-1 text-xs font-semibold uppercase tracking-wide"

    variant = case status.to_s
    when SurveyResponse.statuses[:submitted]
      "border-[#500000] bg-[#f9f2f2] text-[#500000]"
    when SurveyResponse.statuses[:approved]
      "border-emerald-200 bg-emerald-50 text-emerald-700"
    when SurveyResponse.statuses[:in_progress]
      "border-amber-200 bg-amber-50 text-amber-700"
    when SurveyResponse.statuses[:under_review]
      "border-blue-200 bg-blue-50 text-blue-700"
    else
      "border-slate-200 bg-slate-100 text-slate-600"
    end

    "#{base} #{variant}"
  end
end
