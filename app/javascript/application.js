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

  // Keep all toggles in sync (supports both legacy buttons and new switches)
  const controls = document.querySelectorAll("[data-high-contrast-toggle]")
  controls.forEach((el) => {
    if (el instanceof HTMLInputElement && el.type === "checkbox") {
      el.checked = enabled
      el.setAttribute("aria-checked", enabled ? "true" : "false")
      if (el.dataset.toggleInitialized === "true") {
        el.dataset.togglePrev = enabled ? "true" : "false"
      }
    } else {
      el.setAttribute("aria-pressed", enabled ? "true" : "false")
      el.textContent = enabled ? "High Contrast: On" : "High Contrast: Off"
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
    // Avoid adding duplicate listeners on Turbo navigations
    if (el.dataset.hcInitialized === "true") return
    el.dataset.hcInitialized = "true"

    const handler = (e) => {
      if (!(el instanceof HTMLInputElement && el.type === "checkbox")) {
        e.preventDefault()
      }
      const isEnabled = document.body.classList.contains("high-contrast")
      const next = !isEnabled
      applyHighContrast(next)
      window.localStorage.setItem(HIGH_CONTRAST_KEY, String(next))
    }

    if (el instanceof HTMLInputElement && el.type === "checkbox") {
      el.addEventListener("change", handler)
    } else {
      el.addEventListener("click", handler)
    }
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
    if (el instanceof HTMLInputElement && el.type === "checkbox") {
      el.checked = false
      el.setAttribute("aria-checked", "false")
      if (el.dataset.toggleInitialized === "true") {
        el.dataset.togglePrev = "false"
      }
    } else {
      el.setAttribute("aria-pressed", "false")
      el.textContent = "Read Page Aloud"
    }
  })
}

function startReading() {
  if (!("speechSynthesis" in window)) {
    alert("Text-to-speech is not supported in this browser.")
    return
  }

  const main = document.querySelector("main")
  const text = (main || document.body).innerText || (main || document.body).textContent

  if (!text || !text.trim()) {
    alert("There is no readable content on this page.")
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
      if (el instanceof HTMLInputElement && el.type === "checkbox") {
        el.checked = true
        el.setAttribute("aria-checked", "true")
        if (el.dataset.toggleInitialized === "true") {
          el.dataset.togglePrev = "true"
        }
      } else {
        el.setAttribute("aria-pressed", "true")
        el.textContent = "Stop Reading"
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
      el.disabled = true
      if (!(el instanceof HTMLInputElement && el.type === "checkbox")) {
        el.textContent = "Read Aloud (not supported)"
      }
    })
    return
  }

  controls.forEach((el) => {
    if (el.dataset.ttsInitialized === "true") return
    el.dataset.ttsInitialized = "true"

    const handler = (e) => {
      if (!(el instanceof HTMLInputElement && el.type === "checkbox")) {
        e.preventDefault()
      }

      const isSpeaking = window.speechSynthesis.speaking
      if (isSpeaking) {
        stopReading()
      } else {
        startReading()
      }
    }

    if (el instanceof HTMLInputElement && el.type === "checkbox") {
      el.addEventListener("change", handler)
    } else {
      el.addEventListener("click", handler)
    }
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
      const inputName = `answers[${questionId}]`
      const selected = form.querySelector(`input[name="${inputName}"]:checked`)

      const wrapper = form.querySelector(`[data-other-input-wrapper][data-other-for-question-id="${questionId}"]`)
      if (!wrapper) return

      const otherChoiceValue = (wrapper.dataset.otherChoiceValue || "Other").trim()
      const isOther = selected && selected.value === otherChoiceValue

      wrapper.classList.toggle("hidden", !isOther)
      wrapper.setAttribute("aria-hidden", isOther ? "false" : "true")

      const input = wrapper.querySelector("input")
      if (input) input.disabled = !isOther
    }

    wrappers.forEach((wrapper) => {
      const qid = wrapper.dataset.otherForQuestionId
      if (!qid) return

      const inputName = `answers[${qid}]`
      const radios = form.querySelectorAll(`input[name="${inputName}"]`)
      radios.forEach((radio) => {
        radio.addEventListener("change", () => sync(qid))
      })

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
}

document.addEventListener("turbo:load", initAccessibilityFeatures)
document.addEventListener("DOMContentLoaded", initAccessibilityFeatures)

console.debug("[Application] JS bootstrap loaded (once)")
