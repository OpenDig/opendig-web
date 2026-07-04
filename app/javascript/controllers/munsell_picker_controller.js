import { Controller } from "@hotwired/stimulus"

// Searchable Munsell colour picker with live swatches.
//
// The full Munsell Book of Color (1498 chips) is passed in as a Stimulus value
// (`data-munsell-picker-colors-value`, an array of {n, hex}). A hidden input
// carries the stored notation so form submission is identical to the old plain
// <select>. The dropdown panel, search box, and swatch rows are built here so
// the server-rendered markup stays tiny.
export default class extends Controller {
  static targets = ["input", "trigger", "swatch", "label"]
  static values = { colors: Array }

  // Cap rendered rows so a bare/short query can't paint all 1498 at once.
  MAX_ROWS = 400

  connect() {
    this.injectStylesOnce()
    this.buildPanel()
    this.open = false
    this._onDocClick = (e) => {
      if (!this.element.contains(e.target)) this.close()
    }
    document.addEventListener("click", this._onDocClick)
  }

  disconnect() {
    document.removeEventListener("click", this._onDocClick)
  }

  toggle(event) {
    event.preventDefault()
    this.open ? this.close() : this.show()
  }

  show() {
    this.open = true
    this.panel.hidden = false
    this.search.value = ""
    this.render("")
    this.search.focus()
  }

  close() {
    this.open = false
    if (this.panel) this.panel.hidden = true
  }

  filter() {
    this.render(this.search.value)
  }

  keydown(event) {
    if (event.key === "Escape") {
      this.close()
      this.triggerTarget.focus()
    } else if (event.key === "Enter") {
      event.preventDefault()
      const first = this.list.querySelector("[data-value]")
      if (first) this.pick(first.dataset.value, first.dataset.hex)
    }
  }

  // --- internals -----------------------------------------------------------

  buildPanel() {
    this.panel = document.createElement("div")
    this.panel.className = "munsell-picker__panel"
    this.panel.hidden = true

    this.search = document.createElement("input")
    this.search.type = "text"
    this.search.className = "munsell-picker__search form-control"
    this.search.placeholder = "Filter, e.g. 10YR 5/3 or Y 5"
    this.search.setAttribute("autocomplete", "off")
    this.search.addEventListener("input", () => this.filter())
    this.search.addEventListener("keydown", (e) => this.keydown(e))

    this.list = document.createElement("div")
    this.list.className = "munsell-picker__list"

    this.panel.appendChild(this.search)
    this.panel.appendChild(this.list)
    this.element.appendChild(this.panel)
  }

  render(query) {
    const norm = (s) => s.toLowerCase().replace(/\s+/g, "")
    const q = norm(query)
    const matches = q
      ? this.colorsValue.filter((c) => norm(c.n).includes(q))
      : this.colorsValue
    const shown = matches.slice(0, this.MAX_ROWS)

    const rows = shown
      .map(
        (c) =>
          `<button type="button" class="munsell-picker__row" data-value="${c.n}" data-hex="${c.hex}" data-action="click->munsell-picker#choose">` +
          `<span class="munsell-picker__swatch" style="background-color:${c.hex}"></span>` +
          `<span>${c.n}</span></button>`
      )
      .join("")

    const more =
      matches.length > shown.length
        ? `<div class="munsell-picker__more">${matches.length - shown.length} more — keep typing to narrow…</div>`
        : ""
    const empty = matches.length === 0 ? `<div class="munsell-picker__more">No match</div>` : ""

    this.list.innerHTML = rows + more + empty
  }

  choose(event) {
    const el = event.currentTarget
    this.pick(el.dataset.value, el.dataset.hex)
  }

  pick(value, hex) {
    this.inputTarget.value = value
    this.labelTarget.textContent = value
    this.swatchTarget.style.backgroundColor = hex || "transparent"
    this.close()
    this.triggerTarget.focus()
  }

  injectStylesOnce() {
    if (document.getElementById("munsell-picker-styles")) return
    const style = document.createElement("style")
    style.id = "munsell-picker-styles"
    style.textContent = `
      .munsell-picker { position: relative; }
      .munsell-picker__swatch { display:inline-block; width:1.1rem; height:1.1rem;
        border:1px solid rgba(0,0,0,.35); border-radius:3px; flex:0 0 auto; }
      .munsell-picker__panel { position:absolute; z-index:50; left:0; right:0; margin-top:4px;
        background:#fff; border:1px solid #c9ba9c; border-radius:8px;
        box-shadow:0 8px 24px rgba(0,0,0,.18); padding:8px; }
      .munsell-picker__search { margin-bottom:6px; }
      .munsell-picker__list { max-height:min(50vh,340px); overflow-y:auto; }
      .munsell-picker__row { display:flex; align-items:center; gap:8px; width:100%;
        border:0; background:transparent; padding:5px 8px; text-align:left; cursor:pointer;
        border-radius:6px; font-size:.9rem; }
      .munsell-picker__row:hover, .munsell-picker__row:focus {
        background:#f2e9d6; outline:none; }
      .munsell-picker__more { padding:6px 8px; color:#6a5d4c; font-size:.8rem; }
    `
    document.head.appendChild(style)
  }
}
