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
// Hook into Turbo / DOM load
// -----------------------------

function initAccessibilityFeatures() {
  initHighContrastToggle()
  initTTSToggle()
  initSurveyBranching()
  initOtherChoiceInputs()
  initToggleSwitches()
}

document.addEventListener("turbo:load", initAccessibilityFeatures)
document.addEventListener("DOMContentLoaded", initAccessibilityFeatures)

console.debug("[Application] JS bootstrap loaded (once)")
