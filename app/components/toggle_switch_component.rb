# frozen_string_literal: true

# Reusable iOS-style toggle switch.
#
# Renders an accessible checkbox styled as a switch using the existing `.c-toggle*` CSS.
#
# Notes:
# - When rendered inside a form, `initToggleSwitches()` will auto-submit on change.
# - For client-only toggles, omit `name:` and attach custom data attributes.
class ToggleSwitchComponent < ViewComponent::Base
  def initialize(id:, checked: false, name: nil, label: nil, disabled: false, confirm_on: nil, confirm_off: nil, data: {})
    @id = id
    @checked = !!checked
    @name = name
    @label = label
    @disabled = !!disabled
    @confirm_on = confirm_on
    @confirm_off = confirm_off
    @data = data || {}
  end

  private

  attr_reader :id, :checked, :name, :label, :disabled, :confirm_on, :confirm_off, :data

  def input_attributes
    data_attributes = { toggle_switch: true }
    data_attributes[:confirm_on] = confirm_on if confirm_on.present?
    data_attributes[:confirm_off] = confirm_off if confirm_off.present?
    data_attributes.merge!(data)

    attrs = {
      id: id,
      class: "c-toggle__input",
      type: "checkbox",
      role: "switch",
      aria: { checked: checked ? "true" : "false" },
      data: data_attributes
    }

    if name.present?
      attrs[:name] = name
      attrs[:value] = "1"
    end

    attrs[:checked] = true if checked
    attrs[:disabled] = true if disabled

    attrs
  end
end
