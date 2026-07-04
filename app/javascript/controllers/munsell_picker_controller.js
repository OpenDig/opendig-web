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
  static values = { colors: Array, lookup: String }

  // Cap rendered rows so a bare/short query can't paint all 1498 at once.
  MAX_ROWS = 400

  connect() {
    // Work on a local copy so add/delete don't re-serialize the (large) colors
    // attribute. Custom (project) colours carry no hex; base Munsell chips do.
    this.colors = Array.isArray(this.colorsValue) ? this.colorsValue.slice() : []
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

    // "Add colour" footer — only when this picker is backed by a managed lookup.
    if (this.lookupValue) {
      const foot = document.createElement("div")
      foot.className = "munsell-picker__addcolor"
      this.addInput = document.createElement("input")
      this.addInput.type = "text"
      this.addInput.className = "form-control"
      this.addInput.placeholder = "Add a custom colour…"
      this.addInput.addEventListener("keydown", (e) => {
        if (e.key === "Enter") { e.preventDefault(); this.addColor() }
      })
      const btn = document.createElement("button")
      btn.type = "button"
      btn.className = "btn btn-sm munsell-picker__addbtn"
      btn.textContent = "Add"
      btn.addEventListener("click", () => this.addColor())
      foot.appendChild(this.addInput)
      foot.appendChild(btn)
      this.panel.appendChild(foot)
    }

    this.element.appendChild(this.panel)
  }

  render(query) {
    const norm = (s) => s.toLowerCase().replace(/\s+/g, "")
    const q = norm(query)
    const matches = q
      ? this.colors.filter((c) => norm(c.n).includes(q))
      : this.colors
    const shown = matches.slice(0, this.MAX_ROWS)

    const rows = shown
      .map((c) => {
        const n = this.esc(c.n)
        const swatch = c.hex
          ? `<span class="munsell-picker__swatch" style="background-color:${this.esc(c.hex)}"></span>`
          : `<span class="munsell-picker__swatch munsell-picker__swatch--custom"></span>`
        const choose =
          `<button type="button" class="munsell-picker__row" data-value="${n}" data-hex="${this.esc(c.hex || "")}" data-action="click->munsell-picker#choose">` +
          `${swatch}<span>${n}</span></button>`
        // Only custom (project) colours — those without a hex — can be deleted.
        const del = c.hex
          ? ""
          : `<button type="button" class="munsell-picker__rowdel" data-del="${n}" aria-label="Delete ${n}" data-action="click->munsell-picker#deleteColor">×</button>`
        return `<div class="munsell-picker__rowwrap">${choose}${del}</div>`
      })
      .join("")

    const more =
      matches.length > shown.length
        ? `<div class="munsell-picker__more">${matches.length - shown.length} more — keep typing to narrow…</div>`
        : ""
    const empty = matches.length === 0 ? `<div class="munsell-picker__more">No match</div>` : ""

    this.list.innerHTML = rows + more + empty
  }

  async addColor() {
    const value = this.addInput.value.trim()
    if (!value) return
    const ok = await this.send("POST", value)
    if (!ok) return
    if (!this.colors.some((c) => c.n === value)) {
      this.colors.unshift({ n: value, hex: null, custom: true })
    }
    this.addInput.value = ""
    this.render(this.search.value)
  }

  deleteColor(event) {
    event.stopPropagation()
    const value = event.currentTarget.dataset.del
    this.send("DELETE", value).then((ok) => {
      if (!ok) return
      this.colors = this.colors.filter((c) => c.n !== value)
      // If the deleted colour was the selected one, clear the field (without
      // closing the panel, so the user can keep managing the list).
      if (this.inputTarget.value === value) {
        this.inputTarget.value = ""
        this.labelTarget.textContent = "Select a colour…"
        this.swatchTarget.classList.add("is-empty")
      }
      this.render(this.search.value)
    })
  }

  async send(method, value) {
    try {
      const res = await fetch("/lookup_values", {
        method,
        headers: {
          "Content-Type": "application/json",
          Accept: "application/json",
          "X-CSRF-Token": this.csrf()
        },
        body: JSON.stringify({ lookup: this.lookupValue, value })
      })
      return res.ok
    } catch (_e) {
      return false
    }
  }

  csrf() {
    return document.querySelector('meta[name="csrf-token"]')?.content || ""
  }

  esc(s) {
    return String(s).replace(/[&<>"']/g, (c) =>
      ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c])
    )
  }

  choose(event) {
    const el = event.currentTarget
    this.pick(el.dataset.value, el.dataset.hex)
  }

  pick(value, hex) {
    this.inputTarget.value = value
    this.labelTarget.textContent = value || "Select a colour…"
    if (hex) {
      this.swatchTarget.classList.remove("is-empty")
      this.swatchTarget.style.backgroundColor = hex
    } else {
      // Custom colours (and the empty reset) show no swatch.
      this.swatchTarget.classList.add("is-empty")
    }
    this.close()
    this.triggerTarget.focus()
  }

  injectStylesOnce() {
    if (document.getElementById("munsell-picker-styles")) return
    const style = document.createElement("style")
    style.id = "munsell-picker-styles"
    style.textContent = `
      .munsell-picker { position: relative; }
      .munsell-picker__trigger { display:flex; align-items:center; gap:0.55rem; text-align:left; }
      .munsell-picker__value { min-width:0; overflow:hidden; text-overflow:ellipsis; white-space:nowrap; }
      .munsell-picker__swatch { display:inline-block; width:1.1rem; height:1.1rem;
        border:1px solid rgba(0,0,0,.35); border-radius:3px; flex:0 0 auto; }
      .munsell-picker__swatch.is-empty { display:none; }
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
      .munsell-picker__swatch--custom { border-style:dashed; background:transparent; }
      .munsell-picker__rowwrap { display:flex; align-items:center; }
      .munsell-picker__rowwrap .munsell-picker__row { flex:1 1 auto; }
      .munsell-picker__rowdel { flex:0 0 auto; border:0; background:transparent; color:#9c2a1c;
        cursor:pointer; font-size:1.1rem; line-height:1; padding:0 8px; border-radius:6px; }
      .munsell-picker__rowdel:hover { background:#fdecea; }
      .munsell-picker__addcolor { display:flex; gap:6px; margin-top:6px; padding-top:8px;
        border-top:1px solid #eadfc9; }
      .munsell-picker__addbtn { flex:0 0 auto; background:#b1542b; color:#fff; border:0;
        border-radius:9999px; padding:0 0.9rem; cursor:pointer; }
      .munsell-picker__more { padding:6px 8px; color:#6a5d4c; font-size:.8rem; }
    `
    document.head.appendChild(style)
  }
}
