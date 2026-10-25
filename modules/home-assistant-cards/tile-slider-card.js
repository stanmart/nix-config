// custom:tile-slider-card: the stock tile card with a thin brightness slider and a round knob
// underneath, in place of the tile's thick light-brightness feature.
//
// Config: any tile option (entity, name, icon, color, tap_action, ...), plus
// slider_color?: CSS color of the knob while the light is on.

const SETTLE_MS = 1500; // ignore state echoes this long after a local change
const DRAG_THRESHOLD_PX = 8; // sideways travel before a touch counts as a drag
const THUMB_PX = 24; // keep in sync with the thumb size in the CSS

class TileSliderCard extends HTMLElement {
  setConfig(config) {
    if (!config.entity || !config.entity.startsWith("light.")) {
      throw new Error("entity must be a light");
    }
    this._config = config;
    const { type, features, features_position, slider_color, ...tileConfig } = config;
    this._tileConfig = { ...tileConfig, type: "tile" };
    if (!this.shadowRoot) this._build();
    this._makeTile();
  }

  set hass(hass) {
    this._hass = hass;
    if (this._tile) this._tile.hass = hass;
    this._update();
  }

  getCardSize() {
    return 2;
  }

  getGridOptions() {
    return { columns: 6, min_columns: 4 };
  }

  _build() {
    const root = this.attachShadow({ mode: "open" });
    root.innerHTML = `
      <style>
        ha-card {
          overflow: hidden;
        }
        .tile {
          --ha-card-border-width: 0;
          --ha-card-border-radius: 0;
          --ha-card-box-shadow: none;
          --ha-card-background: transparent;
          --card-background-color: transparent;
        }
        .row {
          display: flex;
          padding: 0 12px 4px;
          margin-top: -8px;
          --knob: var(--secondary-text-color);
        }
        .row.unavailable {
          opacity: 0.4;
          pointer-events: none;
        }
        .slider {
          flex: 1;
          min-width: 0;
          display: flex;
          cursor: pointer;
          touch-action: pan-y;
          -webkit-tap-highlight-color: transparent;
        }
        input {
          flex: 1;
          min-width: 0;
          height: 44px;
          margin: 0;
          background: transparent;
          -webkit-appearance: none;
          appearance: none;
          pointer-events: none;
        }
        input:focus {
          outline: none;
        }
        input::-webkit-slider-runnable-track {
          height: 3px;
          border-radius: 2px;
          background: var(--divider-color);
        }
        input::-moz-range-track {
          height: 3px;
          border-radius: 2px;
          background: var(--divider-color);
        }
        input::-webkit-slider-thumb {
          -webkit-appearance: none;
          width: 24px;
          height: 24px;
          margin-top: -10.5px;
          border: none;
          border-radius: 50%;
          background: var(--disabled-color);
        }
        input::-moz-range-thumb {
          width: 24px;
          height: 24px;
          border: none;
          border-radius: 50%;
          background: var(--disabled-color);
        }
        input.on::-webkit-slider-thumb {
          background: var(--knob);
        }
        input.on::-moz-range-thumb {
          background: var(--knob);
        }
      </style>
      <ha-card>
        <div class="tile"></div>
        <div class="row">
          <div class="slider">
            <input type="range" min="0" max="100" step="1" tabindex="-1" aria-label="Brightness" />
          </div>
        </div>
      </ha-card>
    `;
    this._tileHost = root.querySelector(".tile");
    this._row = root.querySelector(".row");
    this._slider = root.querySelector("input");
    this._lastLocal = 0;
    this._bindGestures(root.querySelector(".slider"));
  }

  // The native range input grabs the knob on touch-down, so scrolling the page with a
  // finger on the slider moved it. Like the stock slider, a touch only becomes a drag
  // once it moves sideways; a vertical move is left to the browser, which scrolls and
  // cancels the pointer. A tap without movement sets the value. Applies on release;
  // 0 turns the light off.
  _bindGestures(area) {
    let start = null; // { id, x, y, dragging }
    const valueAt = (clientX) => {
      const rect = this._slider.getBoundingClientRect();
      const t = THUMB_PX;
      const frac = (clientX - rect.left - t / 2) / (rect.width - t);
      return Math.round(Math.min(1, Math.max(0, frac)) * 100);
    };
    const show = (pct) => {
      this._lastLocal = Date.now();
      this._slider.value = pct;
      this._slider.classList.toggle("on", pct > 0);
    };
    const capture = (id) => {
      try {
        area.setPointerCapture(id);
      } catch {
        // not an active pointer (synthetic events); dragging still works without it
      }
    };
    area.addEventListener("pointerdown", (e) => {
      if (e.button !== 0) return;
      start = { id: e.pointerId, x: e.clientX, y: e.clientY, dragging: e.pointerType === "mouse" };
      if (start.dragging) {
        capture(e.pointerId);
        show(valueAt(e.clientX));
      }
    });
    area.addEventListener("pointermove", (e) => {
      if (!start || e.pointerId !== start.id) return;
      if (!start.dragging) {
        const dx = Math.abs(e.clientX - start.x);
        const dy = Math.abs(e.clientY - start.y);
        if (dy > DRAG_THRESHOLD_PX && dy >= dx) {
          start = null; // a scroll; the browser takes it from here
          return;
        }
        if (dx <= DRAG_THRESHOLD_PX) return;
        start.dragging = true;
        capture(e.pointerId);
      }
      show(valueAt(e.clientX));
    });
    area.addEventListener("pointerup", (e) => {
      if (!start || e.pointerId !== start.id) return;
      start = null;
      const pct = valueAt(e.clientX);
      show(pct);
      this._apply(pct);
    });
    area.addEventListener("pointercancel", () => {
      if (!start) return;
      start = null;
      this._lastLocal = 0; // snap back to the light's real state
      this._update();
    });
  }

  _apply(pct) {
    const entity_id = this._config.entity;
    if (pct === 0) {
      this._hass.callService("light", "turn_off", { entity_id });
    } else {
      this._hass.callService("light", "turn_on", { entity_id, brightness_pct: pct });
    }
  }

  async _makeTile() {
    const config = this._tileConfig;
    const helpers = await window.loadCardHelpers();
    if (config !== this._tileConfig) return; // config changed while loading
    const tile = helpers.createCardElement(config);
    if (this._hass) tile.hass = this._hass;
    this._tileHost.replaceChildren(tile);
    this._tile = tile;
  }

  _update() {
    if (!this._hass || !this._config || !this.shadowRoot) return;
    const stateObj = this._hass.states[this._config.entity];
    if (!stateObj) return;
    if (this._config.slider_color) this._row.style.setProperty("--knob", this._config.slider_color);
    this._row.classList.toggle("unavailable", stateObj.state === "unavailable");
    const on = stateObj.state === "on";
    if (Date.now() - this._lastLocal > SETTLE_MS) {
      const b = stateObj.attributes.brightness;
      this._slider.value = on && b ? Math.max(1, Math.round(b / 2.55)) : 0;
      this._slider.classList.toggle("on", on);
    }
  }
}

customElements.define("tile-slider-card", TileSliderCard);
window.customCards = window.customCards || [];
window.customCards.push({
  type: "tile-slider-card",
  name: "Tile with thin slider",
  description: "The stock tile card with a thin brightness slider underneath",
});
