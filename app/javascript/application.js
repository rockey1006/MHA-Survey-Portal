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

  // Keep all toggles in sync
  const buttons = document.querySelectorAll("[data-high-contrast-toggle]")
  buttons.forEach((btn) => {
    btn.setAttribute("aria-pressed", enabled ? "true" : "false")
    btn.textContent = enabled ? "High Contrast: On" : "High Contrast: Off"
  })
}

function initHighContrastToggle() {
  const buttons = document.querySelectorAll("[data-high-contrast-toggle]")
  if (!buttons.length) return

  // Restore previous preference (if any)
  const stored = window.localStorage.getItem(HIGH_CONTRAST_KEY)
  const initialEnabled = stored === "true"
  applyHighContrast(initialEnabled)

  buttons.forEach((btn) => {
    // Avoid adding duplicate listeners on Turbo navigations
    if (btn.dataset.hcInitialized === "true") return
    btn.dataset.hcInitialized = "true"

    btn.addEventListener("click", (e) => {
      e.preventDefault()
      const isEnabled = document.body.classList.contains("high-contrast")
      const next = !isEnabled
      applyHighContrast(next)
      window.localStorage.setItem(HIGH_CONTRAST_KEY, String(next))
    })
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

  const buttons = document.querySelectorAll("[data-tts-toggle]")
  buttons.forEach((btn) => {
    btn.setAttribute("aria-pressed", "false")
    btn.textContent = "Read Page Aloud"
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
    const buttons = document.querySelectorAll("[data-tts-toggle]")
    buttons.forEach((btn) => {
      btn.setAttribute("aria-pressed", "true")
      btn.textContent = "Stop Reading"
    })
  }

  utterance.onend = stopReading
  utterance.onerror = stopReading

  currentUtterance = utterance
  window.speechSynthesis.speak(utterance)
}

function initTTSToggle() {
  const buttons = document.querySelectorAll("[data-tts-toggle]")
  if (!buttons.length) return

  // If API is missing, disable the control
  if (!("speechSynthesis" in window)) {
    buttons.forEach((btn) => {
      btn.disabled = true
      btn.textContent = "Read Aloud (not supported)"
    })
    return
  }

  buttons.forEach((btn) => {
    if (btn.dataset.ttsInitialized === "true") return
    btn.dataset.ttsInitialized = "true"

    btn.addEventListener("click", (e) => {
      e.preventDefault()

      const isSpeaking = window.speechSynthesis.speaking
      if (isSpeaking) {
        stopReading()
      } else {
        startReading()
      }
    })
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
// Hook into Turbo / DOM load
// -----------------------------

function initAccessibilityFeatures() {
  initHighContrastToggle()
  initTTSToggle()
  initSurveyBranching()
  initOtherChoiceInputs()
}

document.addEventListener("turbo:load", initAccessibilityFeatures)
document.addEventListener("DOMContentLoaded", initAccessibilityFeatures)

console.debug("[Application] JS bootstrap loaded (once)")
