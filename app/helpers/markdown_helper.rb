# frozen_string_literal: true

# Shared Markdown rendering helpers.
module MarkdownHelper
  MARKDOWN_ALLOWED_TAGS = %w[
    p br h1 h2 h3 h4 h5 h6
    ul ol li
    strong em b i u del
    blockquote code pre hr
    a
  ].freeze

  MARKDOWN_ALLOWED_ATTRIBUTES = %w[href title rel target].freeze
  INLINE_MARKDOWN_ALLOWED_TAGS = %w[strong em b i u del code a br].freeze

  # Renders markdown into sanitized HTML.
  #
  # @param text [String]
  # @param wrapper_class [String, nil]
  # @param min_heading_level [Integer] Minimum heading level (1–6). Markdown `#` headings will be
  #   offset so the first/smallest heading level maps to this value.
  # @return [ActiveSupport::SafeBuffer]
  def render_markdown(text, wrapper_class: nil, min_heading_level: 1)
    raw = text.to_s
    return "".html_safe if raw.strip.blank?

    html = markdown_to_html(raw)
    html = offset_heading_levels(html, min_heading_level) if min_heading_level > 1
    sanitized = sanitize(
      html,
      tags: MARKDOWN_ALLOWED_TAGS,
      attributes: MARKDOWN_ALLOWED_ATTRIBUTES
    )

    return sanitized if wrapper_class.blank?

    content_tag(:div, sanitized, class: wrapper_class)
  end

  # Renders markdown for inline-only contexts (for example inside label text).
  #
  # @param text [String]
  # @return [ActiveSupport::SafeBuffer]
  def render_markdown_inline(text)
    raw = text.to_s
    return "".html_safe if raw.strip.blank?

    html = markdown_to_html(raw)
    sanitized = sanitize(
      html,
      tags: INLINE_MARKDOWN_ALLOWED_TAGS,
      attributes: MARKDOWN_ALLOWED_ATTRIBUTES
    )

    flattened = sanitized.to_s
      .gsub(%r{</p>\s*<p>}i, "<br>")
      .gsub(%r{</?p>}i, "")

    flattened.html_safe
  end

  private

  def normalize_href(href)
    raw = href.to_s.strip
    return nil if raw.blank?

    return "https://#{raw}" if raw.match?(/\Awww\./i)
    return raw if raw.match?(/\Ahttps?:\/\//i)
    return raw if raw.match?(/\Amailto:/i)
    return raw if raw.match?(/\Atel:/i)
    return raw if raw.start_with?("/", "#")

    nil
  end

  def inline_markdown_fallback(text)
    escaped = ERB::Util.html_escape(text.to_s)

    with_code = escaped.gsub(/`([^`]+)`/, "<code>\\1</code>")
    with_strong = with_code.gsub(/\*\*([^*\n][\s\S]*?[^*\n]|[^*\n])\*\*/, "<strong>\\1</strong>")
    with_em = with_strong.gsub(/(^|[^*])\*([^*\n][\s\S]*?[^*\n]|[^*\n])\*(?!\*)/, "\\1<em>\\2</em>")
    with_em = with_em.gsub(/(^|[^_])_([^_\n][\s\S]*?[^_\n]|[^_\n])_(?!_)/, "\\1<em>\\2</em>")
    with_underline = with_em.gsub(/\+\+([^+\n][\s\S]*?[^+\n]|[^+\n])\+\+/, "<u>\\1</u>")
    with_underline = with_underline.gsub(/&lt;u&gt;([\s\S]*?)&lt;\/u&gt;/i, "<u>\\1</u>")

    linked = with_underline.gsub(/\[([^\]]+)\]\(([^\s)]+)(?:\s+"[^"]*")?\)/) do
      label = Regexp.last_match(1)
      href = normalize_href(Regexp.last_match(2))
      href.present? ? %(<a href="#{ERB::Util.html_escape(href)}">#{label}</a>) : label
    end

    auto_linked = linked.gsub(/(^|[\s(>])(https?:\/\/[^\s<]+|www\.[^\s<]+)/i) do
      lead = Regexp.last_match(1)
      href = Regexp.last_match(2)
      safe_href = normalize_href(href)
      if safe_href.present?
        %(#{lead}<a href="#{ERB::Util.html_escape(safe_href)}">#{ERB::Util.html_escape(href)}</a>)
      else
        "#{lead}#{ERB::Util.html_escape(href)}"
      end
    end

    auto_linked
      .gsub(/&lt;br\s*\/?&gt;/i, "<br>")
      .gsub(/\r?\n/, "<br>")
  end

  def basic_markdown_to_html(text)
    blocks = text.to_s.strip.split(/\r?\n\r?\n+/)
    return "" if blocks.empty?

    blocks.map do |block|
      lines = block.split(/\r?\n/).reject(&:blank?)
      next "" if lines.empty?

      setext = lines.length >= 2 ? lines[1].match(/\A([=-])\1{2,}\z/) : nil
      if setext
        level = setext[1] == "=" ? 1 : 2
        heading_html = "<h#{level}>#{inline_markdown_fallback(lines.first)}</h#{level}>"
        remainder = lines.drop(2)
        next heading_html if remainder.empty?

        if remainder.all? { |line| line.match?(/\A\s*[-*+]\s+/) }
          items = remainder.map { |line| "<li>#{inline_markdown_fallback(line.sub(/\A\s*[-*+]\s+/, ""))}</li>" }.join
          next "#{heading_html}<ul>#{items}</ul>"
        elsif remainder.all? { |line| line.match?(/\A\s*\d+\.\s+/) }
          items = remainder.map { |line| "<li>#{inline_markdown_fallback(line.sub(/\A\s*\d+\.\s+/, ""))}</li>" }.join
          next "#{heading_html}<ol>#{items}</ol>"
        else
          next "#{heading_html}<p>#{inline_markdown_fallback(remainder.join("\n"))}</p>"
        end
      end

      atx = lines.first.match(/\A(\#{1,6})\s+(.+)\z/)
      if atx
        level = atx[1].length
        heading_html = "<h#{level}>#{inline_markdown_fallback(atx[2])}</h#{level}>"
        remainder = lines.drop(1)
        next heading_html if remainder.empty?

        if remainder.all? { |line| line.match?(/\A\s*[-*+]\s+/) }
          items = remainder.map { |line| "<li>#{inline_markdown_fallback(line.sub(/\A\s*[-*+]\s+/, ""))}</li>" }.join
          next "#{heading_html}<ul>#{items}</ul>"
        elsif remainder.all? { |line| line.match?(/\A\s*\d+\.\s+/) }
          items = remainder.map { |line| "<li>#{inline_markdown_fallback(line.sub(/\A\s*\d+\.\s+/, ""))}</li>" }.join
          next "#{heading_html}<ol>#{items}</ol>"
        else
          next "#{heading_html}<p>#{inline_markdown_fallback(remainder.join("\n"))}</p>"
        end
      end

      if lines.all? { |line| line.match?(/\A\s*[-*+]\s+/) }
        items = lines.map { |line| "<li>#{inline_markdown_fallback(line.sub(/\A\s*[-*+]\s+/, ""))}</li>" }.join
        "<ul>#{items}</ul>"
      elsif lines.all? { |line| line.match?(/\A\s*\d+\.\s+/) }
        items = lines.map { |line| "<li>#{inline_markdown_fallback(line.sub(/\A\s*\d+\.\s+/, ""))}</li>" }.join
        "<ol>#{items}</ol>"
      elsif lines.length == 1 && (match = lines.first.match(/\A(\#{1,6})\s+(.+)\z/))
        level = match[1].length
        "<h#{level}>#{inline_markdown_fallback(match[2])}</h#{level}>"
      elsif lines.length == 1 && lines.first.match?(/\A---+\z/)
        "<hr>"
      else
        "<p>#{inline_markdown_fallback(lines.join("\n"))}</p>"
      end
    end.join
  end

  def markdown_to_html(text)
    if defined?(Commonmarker)
      Commonmarker.to_html(
        text,
        options: {
          parse: { smart: true },
          render: { hardbreaks: true }
        },
        extensions: %i[autolink strikethrough table tasklist tagfilter]
      )
    else
      basic_markdown_to_html(text)
    end
  rescue StandardError => e
    Rails.logger.warn("Markdown rendering failed: #{e.message}")
    basic_markdown_to_html(text)
  end

  # Shifts all HTML heading tags so that the minimum level present maps to +min_level+.
  # For example, with min_level: 3, a `<h1>` becomes `<h3>`, `<h2>` becomes `<h4>`, etc.
  # Headings are capped at <h6>.
  def offset_heading_levels(html, min_level)
    return html unless html.match?(/<h[1-6]/i)

    used_levels = html.scan(/<h([1-6])/i).map { |m| m[0].to_i }
    return html if used_levels.empty?

    offset = min_level - used_levels.min
    return html if offset <= 0

    # Match both opening tags (which may carry attributes) and closing tags.
    html.gsub(/<(\/?)h([1-6])((?:\s[^>]*)?)>/i) do
      slash = Regexp.last_match(1)
      new_level = [ Regexp.last_match(2).to_i + offset, 6 ].min
      attrs = Regexp.last_match(3)
      "<#{slash}h#{new_level}#{attrs}>"
    end
  end
end
