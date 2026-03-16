# frozen_string_literal: true

module GuidanceTextHelper
  include MarkdownHelper

  def render_guidance_text(text, heading_tag: :h4)
    _heading_tag = heading_tag
    # Keep signature stable for existing call sites while rendering real markdown.
    render_markdown(text, wrapper_class: "guidance-text")
  end
end
