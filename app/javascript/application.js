import "@hotwired/turbo-rails"
import "controllers"

// Accessibility helpers for high contrast mode and text-to-speech support.

// -----------------------------
// High-contrast mode
// -----------------------------

const HIGH_CONTRAST_KEY = "mha_high_contrast"

function applyHighContrast(enabled) {
  const body = document.body
  if (!body) return

  if (enabled) {
    body.classList.add("high-contrast")
  } else {
    body.classList.remove("high-contrast")
  }

  // Keep all toggle switches in sync.
  const controls = document.querySelectorAll("[data-high-contrast-toggle]")
  controls.forEach((el) => {
    if (!(el instanceof HTMLInputElement) || el.type !== "checkbox") return

    el.checked = enabled
    el.setAttribute("aria-checked", enabled ? "true" : "false")
    if (el.dataset.toggleInitialized === "true") {
      el.dataset.togglePrev = enabled ? "true" : "false"
    }
  })
}

function initHighContrastToggle() {
  const controls = document.querySelectorAll("[data-high-contrast-toggle]")
  if (!controls.length) return

  // Restore previous preference (if any)
  const stored = window.localStorage.getItem(HIGH_CONTRAST_KEY)
  const initialEnabled = stored === "true"
  applyHighContrast(initialEnabled)

  controls.forEach((el) => {
    if (!(el instanceof HTMLInputElement) || el.type !== "checkbox") return

    // Avoid adding duplicate listeners on Turbo navigations
    if (el.dataset.hcInitialized === "true") return
    el.dataset.hcInitialized = "true"

    const handler = () => {
      const next = el.checked
      applyHighContrast(next)
      window.localStorage.setItem(HIGH_CONTRAST_KEY, String(next))
    }

    el.addEventListener("change", handler)
  })
}

// -----------------------------
// Text-to-speech: Read Page Aloud
// -----------------------------

let currentUtterance = null

function stopReading() {
  if (window.speechSynthesis && window.speechSynthesis.speaking) {
    window.speechSynthesis.cancel()
  }
  currentUtterance = null

  const controls = document.querySelectorAll("[data-tts-toggle]")
  controls.forEach((el) => {
    if (!(el instanceof HTMLInputElement) || el.type !== "checkbox") return

    el.checked = false
    el.setAttribute("aria-checked", "false")
    if (el.dataset.toggleInitialized === "true") {
      el.dataset.togglePrev = "false"
    }
  })
}

function startReading() {
  if (!("speechSynthesis" in window)) {
    alert("Text-to-speech is not supported in this browser.")
    stopReading()
    return
  }

  const main = document.querySelector("main")
  const text = (main || document.body).innerText || (main || document.body).textContent

  if (!text || !text.trim()) {
    alert("There is no readable content on this page.")
    stopReading()
    return
  }

  stopReading() // cancel any previous utterance just in case

  const utterance = new SpeechSynthesisUtterance(text)
  utterance.lang = "en-US"
  utterance.rate = 1.0
  utterance.pitch = 1.0

  utterance.onstart = () => {
    const controls = document.querySelectorAll("[data-tts-toggle]")
    controls.forEach((el) => {
      if (!(el instanceof HTMLInputElement) || el.type !== "checkbox") return

      el.checked = true
      el.setAttribute("aria-checked", "true")
      if (el.dataset.toggleInitialized === "true") {
        el.dataset.togglePrev = "true"
      }
    })
  }

  utterance.onend = stopReading
  utterance.onerror = stopReading

  currentUtterance = utterance
  window.speechSynthesis.speak(utterance)
}

function initTTSToggle() {
  const controls = document.querySelectorAll("[data-tts-toggle]")
  if (!controls.length) return

  // If API is missing, disable the control
  if (!("speechSynthesis" in window)) {
    controls.forEach((el) => {
      if (!(el instanceof HTMLInputElement) || el.type !== "checkbox") return
      el.disabled = true
    })
    return
  }

  controls.forEach((el) => {
    if (!(el instanceof HTMLInputElement) || el.type !== "checkbox") return

    if (el.dataset.ttsInitialized === "true") return
    el.dataset.ttsInitialized = "true"

    const handler = () => {
      if (el.checked) {
        startReading()
      } else {
        stopReading()
      }
    }

    el.addEventListener("change", handler)
  })
}

// -----------------------------
// Survey branching: Yes/No parents
// -----------------------------

function initSurveyBranching() {
  const forms = document.querySelectorAll(".survey-form")
  if (!forms.length) return

  forms.forEach((form) => {
    if (form.dataset.branchInitialized === "true") return
    form.dataset.branchInitialized = "true"

    const parents = form.querySelectorAll('[data-branch-parent="true"]')
    if (!parents.length) return

    const setChildVisibility = (parentId, shouldShow) => {
      const children = form.querySelectorAll(`[data-branch-child-of="${parentId}"]`)
      children.forEach((child) => {
        child.classList.toggle("hidden", !shouldShow)
        child.setAttribute("aria-hidden", shouldShow ? "false" : "true")

        const inputs = child.querySelectorAll("input, select, textarea, button")
        inputs.forEach((el) => {
          if (el.getAttribute("type") === "hidden") return
          el.disabled = !shouldShow
        })
      })
    }

    parents.forEach((parent) => {
      const parentId = parent.dataset.branchParentId
      const targetValue = (parent.dataset.branchTargetValue || "").trim()
      if (!parentId || !targetValue) return

      const inputName = `answers[${parentId}]`
      const inputs = form.querySelectorAll(`input[name="${inputName}"]`)
      if (!inputs.length) return

      const update = () => {
        const checked = form.querySelector(`input[name="${inputName}"]:checked`)
        const currentValue = (checked ? checked.value : "").trim()
        setChildVisibility(parentId, currentValue === targetValue)
      }

      inputs.forEach((input) => {
        input.addEventListener("change", update)
      })

      update()
    })
  })
}

function initOtherChoiceInputs() {
  const forms = document.querySelectorAll(".survey-form")
  if (!forms.length) return

  forms.forEach((form) => {
    if (form.dataset.otherChoiceInitialized === "true") return
    form.dataset.otherChoiceInitialized = "true"

    const wrappers = form.querySelectorAll("[data-other-input-wrapper]")
    if (!wrappers.length) return

    const sync = (questionId) => {
      // Support both editable survey forms (answers[ID]) and read-only displays
      // (readonly_answers[ID]) by matching on the trailing [ID].
      const selectedRadio = form.querySelector(`input[type="radio"][name$="[${questionId}]"]:checked`)
      const select = form.querySelector(`select[name$="[${questionId}]"]`)
      const currentValue = (selectedRadio ? selectedRadio.value : (select ? select.value : "")).trim()

      const matchingWrappers = form.querySelectorAll(`[data-other-input-wrapper][data-other-for-question-id="${questionId}"]`)
      if (!matchingWrappers.length) return

      matchingWrappers.forEach((wrapper) => {
        const otherChoiceValue = (wrapper.dataset.otherChoiceValue || "Other").trim()
        const isOther = currentValue && currentValue === otherChoiceValue

        wrapper.classList.toggle("hidden", !isOther)
        wrapper.setAttribute("aria-hidden", isOther ? "false" : "true")

        const input = wrapper.querySelector("input")
        // Only manage disabled state for editable inputs (other_answers[ID]).
        // Read-only pages intentionally keep inputs disabled.
        if (input && (input.name || "").startsWith("other_answers[")) {
          input.disabled = !isOther
        }
      })
    }

    wrappers.forEach((wrapper) => {
      const qid = wrapper.dataset.otherForQuestionId
      if (!qid) return

      const radios = form.querySelectorAll(`input[type="radio"][name$="[${qid}]"]`)
      radios.forEach((radio) => {
        radio.addEventListener("change", () => sync(qid))
      })

      const select = form.querySelector(`select[name$="[${qid}]"]`)
      if (select) {
        select.addEventListener("change", () => sync(qid))
      }

      sync(qid)
    })
  })
}

// -----------------------------
// Reusable toggle switch (confirm + submit)
// -----------------------------

function initToggleSwitches() {
  const inputs = document.querySelectorAll('input[type="checkbox"][data-toggle-switch="true"]')
  if (!inputs.length) return

  inputs.forEach((input) => {
    if (input.dataset.toggleInitialized === "true") return
    input.dataset.toggleInitialized = "true"

    // Track last confirmed state so cancel can revert cleanly.
    input.dataset.togglePrev = input.checked ? "true" : "false"
    input.setAttribute("aria-checked", input.checked ? "true" : "false")

    input.addEventListener("change", (e) => {
      const nextChecked = input.checked
      const prevChecked = input.dataset.togglePrev === "true"

      const confirmOn = input.getAttribute("data-confirm-on")
      const confirmOff = input.getAttribute("data-confirm-off")
      const message = nextChecked ? confirmOn : confirmOff

      if (message && !window.confirm(message)) {
        // Revert to previous value and do not submit.
        input.checked = prevChecked
        input.setAttribute("aria-checked", prevChecked ? "true" : "false")
        return
      }

      input.dataset.togglePrev = nextChecked ? "true" : "false"
      input.setAttribute("aria-checked", nextChecked ? "true" : "false")

      const form = input.closest("form")
      if (form) form.requestSubmit()
    })
  })
}

// -----------------------------
// Combobox (searchable dropdown)
// -----------------------------

function initComboboxes() {
  const widgets = document.querySelectorAll('[data-combobox="true"]')
  if (!widgets.length) return

  widgets.forEach((widget) => {
    if (widget.dataset.comboboxInitialized === "true") return
    widget.dataset.comboboxInitialized = "true"

    const input = widget.querySelector('[data-combobox-input="true"]')
    const hidden = widget.querySelector('[data-combobox-value="true"]')
    const menu = widget.querySelector('[data-combobox-menu="true"]')
    const empty = widget.querySelector('[data-combobox-empty="true"]')
    if (!input || !hidden || !menu) return

    const options = Array.from(widget.querySelectorAll('[data-combobox-option="true"]'))

    const setOpen = (open) => {
      menu.classList.toggle("hidden", !open)
      input.setAttribute("aria-expanded", open ? "true" : "false")
    }

    const filter = () => {
      const q = (input.value || "").trim().toLowerCase()
      let visible = 0

      options.forEach((btn) => {
        const haystack = (btn.dataset.comboboxOptionSearch || "").toLowerCase()
        const match = q === "" || haystack.includes(q)
        btn.hidden = !match
        if (match) visible += 1
      })

      if (empty) empty.hidden = !(q !== "" && visible === 0)
    }

    const selectOption = (btn) => {
      const value = btn.dataset.comboboxOptionValue || ""
      const label = btn.dataset.comboboxOptionLabel || ""
      hidden.value = value
      input.value = label
      setOpen(false)
    }

    input.addEventListener("focus", () => {
      filter()
      setOpen(true)
    })

    input.addEventListener("input", () => {
      hidden.value = "" // user is typing; clear selection until chosen
      filter()
      setOpen(true)
    })

    input.addEventListener("keydown", (e) => {
      if (e.key === "Escape") {
        setOpen(false)
        return
      }
    })

    options.forEach((btn) => {
      btn.addEventListener("click", () => selectOption(btn))
    })

    document.addEventListener("click", (e) => {
      if (!widget.contains(e.target)) setOpen(false)
    })
  })
}

// -----------------------------
// Impersonation: lock write forms (UI)
// -----------------------------

function initImpersonationReadOnlyUI() {
  const body = document.body
  if (!body) return
  if (body.dataset.impersonating !== "true") return

  const forms = document.querySelectorAll("form")
  forms.forEach((form) => {
    if (form.dataset.impersonationLocked === "true") return

    const rawMethod = (form.getAttribute("method") || "get").toLowerCase()
    if (rawMethod === "get") return

    const action = (form.getAttribute("action") || "").toLowerCase()
    const override = form.querySelector('input[name="_method"]')
    const intendedMethod = (override ? override.value : rawMethod).toLowerCase()

    const isExitOrSignOut =
      intendedMethod === "delete" &&
      (action.endsWith("/impersonation") ||
        action.endsWith("/advisor_impersonation") ||
        action.endsWith("/users/sign_out") ||
        action.endsWith("/sign_out"))

    if (isExitOrSignOut) return

    form.dataset.impersonationLocked = "true"
    form.setAttribute("aria-disabled", "true")

    const controls = form.querySelectorAll("input, select, textarea, button")
    controls.forEach((el) => {
      if (el instanceof HTMLInputElement && el.type === "hidden") return
      el.disabled = true
    })
  })
}


// -----------------------------
// Disable submit if unchanged (survey response edit)
// -----------------------------

function initDisableSubmitIfUnchanged() {
  const forms = document.querySelectorAll('form[data-disable-submit-if-unchanged="true"]')
  if (!forms.length) return

  const serialize = (form) => {
    const entries = []

    const elements = Array.from(form.elements || [])
    elements.forEach((el) => {
      if (!(el instanceof HTMLInputElement || el instanceof HTMLSelectElement || el instanceof HTMLTextAreaElement)) return

      if (el.disabled) return
      if (!el.name) return

      if (el instanceof HTMLInputElement) {
        const type = (el.type || "").toLowerCase()

        // Ignore Rails plumbing + buttons.
        if (type === "hidden" || type === "submit" || type === "button" || type === "reset") return

        if (type === "radio") {
          if (!el.checked) return
          entries.push([ el.name, el.value ])
          return
        }

        if (type === "checkbox") {
          entries.push([ el.name, el.checked ? (el.value || "on") : "" ])
          return
        }

        entries.push([ el.name, el.value || "" ])
        return
      }

      if (el instanceof HTMLSelectElement) {
        if (el.multiple) {
          const values = Array.from(el.selectedOptions || []).map((opt) => opt.value)
          entries.push([ el.name, values.sort().join("\u0000") ])
        } else {
          entries.push([ el.name, el.value || "" ])
        }
        return
      }

      // textarea
      entries.push([ el.name, el.value || "" ])
    })

    entries.sort((a, b) => {
      if (a[0] === b[0]) return a[1] < b[1] ? -1 : a[1] > b[1] ? 1 : 0
      return a[0] < b[0] ? -1 : 1
    })

    return JSON.stringify(entries)
  }

  const setDisabled = (form, disabled) => {
    const buttons = form.querySelectorAll('[data-save-button="true"]')
    buttons.forEach((btn) => {
      btn.disabled = !!disabled
      if (disabled) {
        btn.setAttribute("aria-disabled", "true")
      } else {
        btn.removeAttribute("aria-disabled")
      }
    })
  }

  forms.forEach((form) => {
    if (form.dataset.disableSubmitInitialized === "true") return
    form.dataset.disableSubmitInitialized = "true"

    const baseline = serialize(form)
    form.dataset.disableSubmitBaseline = baseline

    const refresh = () => {
      const current = serialize(form)
      const unchanged = current === form.dataset.disableSubmitBaseline
      setDisabled(form, unchanged)
    }

    // Disable on first load unless already dirty.
    refresh()

    let scheduled = false
    const scheduleRefresh = () => {
      if (scheduled) return
      scheduled = true
      window.requestAnimationFrame(() => {
        scheduled = false
        refresh()
      })
    }

    form.addEventListener("input", scheduleRefresh)
    form.addEventListener("change", scheduleRefresh)
  })
}


// -----------------------------
// Hover dropdown support for <details>
// -----------------------------

function initHoverDropdownDetails() {
  // Some browsers effectively keep <details> content non-rendered unless [open] is set.
  // For hover-based dropdowns implemented with <details>/<summary>, keep [open]
  // in sync with hover/focus so menus behave like the profile dropdown.
  document.querySelectorAll("details.u-hover-dropdown").forEach((details) => {
    if (details.dataset.hoverDropdownInitialized === "true") return
    details.dataset.hoverDropdownInitialized = "true"

    let closeTimer = null

    const openNow = () => {
      if (closeTimer) {
        window.clearTimeout(closeTimer)
        closeTimer = null
      }
      details.open = true
    }

    const closeSoon = () => {
      if (closeTimer) window.clearTimeout(closeTimer)
      closeTimer = window.setTimeout(() => {
        if (details.matches(":focus-within")) return
        details.open = false
      }, 75)
    }

    details.addEventListener("mouseenter", openNow)
    details.addEventListener("mouseleave", closeSoon)
    details.addEventListener("focusin", openNow)
    details.addEventListener("focusout", closeSoon)

    // If a click toggles [open] off while still hovered/focused, immediately restore it.
    details.addEventListener("toggle", () => {
      if (details.open) return
      if (details.matches(":hover") || details.matches(":focus-within")) {
        details.open = true
      }
    })
  })
}


// -----------------------------
// Hook into Turbo / DOM load
// -----------------------------

function initAccessibilityFeatures() {
  initHighContrastToggle()
  initTTSToggle()
  initSurveyBranching()
  initOtherChoiceInputs()
  initToggleSwitches()
  initComboboxes()
  initImpersonationReadOnlyUI()
  initDisableSubmitIfUnchanged()
  initHoverDropdownDetails()
}

document.addEventListener("turbo:load", initAccessibilityFeatures)
document.addEventListener("DOMContentLoaded", initAccessibilityFeatures)

console.debug("[Application] JS bootstrap loaded (once)")
