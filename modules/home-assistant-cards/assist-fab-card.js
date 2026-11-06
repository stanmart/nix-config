// custom:assist-fab-card: a round floating button in the bottom right corner that opens
// Assist, the same dialog as the header's Assist icon. Takes no room in the view.
//
// Config:
//   pipeline_id?: Assist pipeline to open (default: the preferred one)
//   start_listening?: start listening right away on devices with a microphone (default false)
//   icon?: default mdi:comment-processing-outline
//   navbar_offset?: extra distance from the bottom in the companion app, where the navbar
//     card is shown (default 60px)

class AssistFabCard extends HTMLElement {
  setConfig(config) {
    this._config = config;
    if (!this.shadowRoot) this._build();
    this._icon.icon = config.icon || "mdi:comment-processing-outline";
    this._button.style.setProperty("--navbar-offset", config.navbar_offset || "60px");
  }

  set hass(hass) {
    this._hass = hass;
    // The navbar card is only shown in the companion app, so only lift the button there.
    this._button.classList.toggle("above-navbar", !!hass.auth?.external);
  }

  getCardSize() {
    return 0;
  }

  getGridOptions() {
    return { columns: "full", rows: "auto" };
  }

  _build() {
    const root = this.attachShadow({ mode: "open" });
    root.innerHTML = `
      <style>
        :host {
          display: block;
          height: 0;
        }
        button {
          position: fixed;
          right: calc(16px + env(safe-area-inset-right));
          bottom: calc(16px + env(safe-area-inset-bottom));
          z-index: 4;
          width: 56px;
          height: 56px;
          border: none;
          border-radius: 50%;
          display: flex;
          align-items: center;
          justify-content: center;
          background: var(--primary-color);
          color: var(--text-primary-color, #fff);
          box-shadow: var(--ha-box-shadow-m, 0 3px 5px -1px rgba(0, 0, 0, 0.2), 0 6px 10px 0 rgba(0, 0, 0, 0.14));
          cursor: pointer;
          -webkit-tap-highlight-color: transparent;
        }
        button.above-navbar {
          bottom: calc(16px + var(--navbar-offset) + env(safe-area-inset-bottom));
        }
        button:active {
          filter: brightness(0.9);
        }
      </style>
      <button aria-label="Assist"><ha-icon></ha-icon></button>
    `;
    this._button = root.querySelector("button");
    this._icon = root.querySelector("ha-icon");
    this._button.addEventListener("click", () => this._openAssist());
  }

  _openAssist() {
    const { pipeline_id, start_listening = false } = this._config;
    // The stock "assist" action, fired the way built-in cards fire their tap actions.
    this.dispatchEvent(
      new CustomEvent("hass-action", {
        bubbles: true,
        composed: true,
        detail: {
          config: { tap_action: { action: "assist", pipeline_id, start_listening } },
          action: "tap",
        },
      }),
    );
  }
}

customElements.define("assist-fab-card", AssistFabCard);
window.customCards = window.customCards || [];
window.customCards.push({
  type: "assist-fab-card",
  name: "Floating Assist button",
  description: "A floating button in the bottom right corner that opens Assist",
});
