// app/javascript/high_contrast.js

function setupHighContrastToggle() {
  const body   = document.body;
  const toggle = document.getElementById("high-contrast-toggle");

  if (!body || !toggle) return;

  // Helper to apply state to DOM + button
  const applyState = (on) => {
    if (on) {
      body.classList.add("high-contrast");
      toggle.setAttribute("aria-pressed", "true");
      toggle.textContent = "High Contrast: On";
    } else {
      body.classList.remove("high-contrast");
      toggle.setAttribute("aria-pressed", "false");
      toggle.textContent = "High Contrast: Off";
    }
  };

  // Initial state from localStorage
  const stored = localStorage.getItem("highContrast");
  const initialOn = stored === "true";

  applyState(initialOn);

  // Toggle on every click (on → off → on → off…)
  toggle.addEventListener("click", () => {
    const nowOn = !body.classList.contains("high-contrast");
    applyState(nowOn);
    localStorage.setItem("highContrast", nowOn ? "true" : "false");
  });
}

// Run on Turbo navigation
document.addEventListener("turbo:load",  setupHighContrastToggle);
document.addEventListener("turbo:render", setupHighContrastToggle);
