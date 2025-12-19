# frozen_string_literal: true

module GuidanceTextHelper
  def render_guidance_text(text, heading_tag: :h4)
    sections = GuidanceTextParser.new(text).sections
    return "".html_safe if sections.blank?

    rendered_sections = sections.map do |section|
      inner = []

      if section.title.present?
        inner << content_tag(heading_tag, section.title, class: "guidance-section-title")
      end

      section.paragraphs.each do |paragraph|
        inner << content_tag(:p, paragraph, class: "guidance-paragraph")
      end

      if section.bullets.present?
        items = section.bullets.map { |bullet| content_tag(:li, bullet) }
        inner << content_tag(:ul, safe_join(items), class: "guidance-list")
      end

      content_tag(:div, safe_join(inner), class: "guidance-section")
    end

    content_tag(:div, safe_join(rendered_sections), class: "guidance-text")
  end
end
