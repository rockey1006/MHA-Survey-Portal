import "@hotwired/turbo-rails"
import "controllers"

// -----------------------------
// High-contrast mode
// -----------------------------

const HIGH_CONTRAST_KEY = "mha_high_contrast";

function applyHighContrast(enabled) {
  const body = document.body;
  if (!body) return;

  if (enabled) {
    body.classList.add("high-contrast");
  } else {
    body.classList.remove("high-contrast");
  }

  // Keep all toggles in sync
  const buttons = document.querySelectorAll("[data-high-contrast-toggle]");
  buttons.forEach((btn) => {
    btn.setAttribute("aria-pressed", enabled ? "true" : "false");
    btn.textContent = enabled ? "High Contrast: On" : "High Contrast: Off";
  });
}

function initHighContrastToggle() {
  const buttons = document.querySelectorAll("[data-high-contrast-toggle]");
  if (!buttons.length) return;

  // Restore previous preference (if any)
  const stored = window.localStorage.getItem(HIGH_CONTRAST_KEY);
  const initialEnabled = stored === "true";
  applyHighContrast(initialEnabled);

  buttons.forEach((btn) => {
    // Avoid adding duplicate listeners on Turbo navigations
    if (btn.dataset.hcInitialized === "true") return;
    btn.dataset.hcInitialized = "true";

    btn.addEventListener("click", (e) => {
      e.preventDefault();
      const isEnabled = document.body.classList.contains("high-contrast");
      const next = !isEnabled;
      applyHighContrast(next);
      window.localStorage.setItem(HIGH_CONTRAST_KEY, String(next));
    });
  });
}

// -----------------------------
// Text-to-speech: Read Page Aloud
// -----------------------------

let currentUtterance = null;

function stopReading() {
  if (window.speechSynthesis && window.speechSynthesis.speaking) {
    window.speechSynthesis.cancel();
  }
  currentUtterance = null;

  const buttons = document.querySelectorAll("[data-tts-toggle]");
  buttons.forEach((btn) => {
    btn.setAttribute("aria-pressed", "false");
    btn.textContent = "Read Page Aloud";
  });
}

function startReading() {
  if (!("speechSynthesis" in window)) {
    alert("Text-to-speech is not supported in this browser.");
    return;
  }

  const main = document.querySelector("main");
  const text = (main || document.body).innerText || (main || document.body).textContent;

  if (!text || !text.trim()) {
    alert("There is no readable content on this page.");
    return;
  }

  stopReading(); // cancel any previous utterance just in case

  const utterance = new SpeechSynthesisUtterance(text);
  utterance.lang = "en-US";
  utterance.rate = 1.0;
  utterance.pitch = 1.0;

  utterance.onstart = () => {
    const buttons = document.querySelectorAll("[data-tts-toggle]");
    buttons.forEach((btn) => {
      btn.setAttribute("aria-pressed", "true");
      btn.textContent = "Stop Reading";
    });
  };

  utterance.onend = stopReading;
  utterance.onerror = stopReading;

  currentUtterance = utterance;
  window.speechSynthesis.speak(utterance);
}

function initTTSToggle() {
  const buttons = document.querySelectorAll("[data-tts-toggle]");
  if (!buttons.length) return;

  // If API is missing, disable the control
  if (!("speechSynthesis" in window)) {
    buttons.forEach((btn) => {
      btn.disabled = true;
      btn.textContent = "Read Aloud (not supported)";
    });
    return;
  }

  buttons.forEach((btn) => {
    if (btn.dataset.ttsInitialized === "true") return;
    btn.dataset.ttsInitialized = "true";

    btn.addEventListener("click", (e) => {
      e.preventDefault();

      const isSpeaking = window.speechSynthesis.speaking;
      if (isSpeaking) {
        stopReading();
      } else {
        startReading();
      }
    });
  });
}

// -----------------------------
// Hook into Turbo / DOM load
// -----------------------------

function initAccessibilityFeatures() {
  initHighContrastToggle();
  initTTSToggle();
}

document.addEventListener("turbo:load", initAccessibilityFeatures);
document.addEventListener("DOMContentLoaded", initAccessibilityFeatures);
