import { Controller } from "@hotwired/stimulus"

// Inline add/delete for a plain <select> pick list (e.g. Decoration). Builds a
// small "add / manage" panel under the select and POSTs changes to
// /lookup_values, which persists them to the project list. Adds/removes options
// in place so the registrar's other unsaved edits are preserved (no reload).
export default class extends Controller {
  static targets = ["select"]
  static values = { lookup: String }

  connect() {
    this.injectStylesOnce()
    this.build()
  }

  build() {
    this.wrap = document.createElement("div")
    this.wrap.className = "lookup-manager__tools"

    this.toggleBtn = document.createElement("button")
    this.toggleBtn.type = "button"
    this.toggleBtn.className = "lookup-manager__toggle"
    this.toggleBtn.textContent = `+ Add / manage ${this.lookupLabel()}`
    this.toggleBtn.addEventListener("click", () => this.togglePanel())

    this.panel = document.createElement("div")
    this.panel.className = "lookup-manager__panel"
    this.panel.hidden = true

    const addRow = document.createElement("div")
    addRow.className = "lookup-manager__add"
    this.input = document.createElement("input")
    this.input.type = "text"
    this.input.className = "form-control"
    this.input.placeholder = `New ${this.lookupLabel()}…`
    this.input.addEventListener("keydown", (e) => {
      if (e.key === "Enter") { e.preventDefault(); this.add() }
    })
    const addBtn = document.createElement("button")
    addBtn.type = "button"
    addBtn.className = "btn btn-sm lookup-manager__addbtn"
    addBtn.textContent = "Add"
    addBtn.addEventListener("click", () => this.add())
    addRow.appendChild(this.input)
    addRow.appendChild(addBtn)

    this.list = document.createElement("div")
    this.list.className = "lookup-manager__list"

    this.panel.appendChild(addRow)
    this.panel.appendChild(this.list)
    this.wrap.appendChild(this.toggleBtn)
    this.wrap.appendChild(this.panel)
    this.element.appendChild(this.wrap)

    this.renderList()
  }

  togglePanel() {
    this.panel.hidden = !this.panel.hidden
    if (!this.panel.hidden) this.input.focus()
  }

  // Current, deletable values = the select's non-blank options.
  values() {
    return Array.from(this.selectTarget.options)
      .map((o) => o.value)
      .filter((v) => v && v.trim() !== "")
  }

  renderList() {
    this.list.innerHTML = ""
    this.values().forEach((v) => {
      const row = document.createElement("div")
      row.className = "lookup-manager__row"
      const label = document.createElement("span")
      label.textContent = v
      const del = document.createElement("button")
      del.type = "button"
      del.className = "lookup-manager__del"
      del.setAttribute("aria-label", `Delete ${v}`)
      del.textContent = "×"
      del.addEventListener("click", () => this.remove(v))
      row.appendChild(label)
      row.appendChild(del)
      this.list.appendChild(row)
    })
  }

  async add() {
    const value = this.input.value.trim()
    if (!value) return
    const ok = await this.send("POST", value)
    if (!ok) return
    if (!this.values().includes(value)) {
      const opt = new Option(value, value, false, true) // selected
      this.selectTarget.add(opt)
    } else {
      this.selectTarget.value = value
    }
    this.input.value = ""
    this.renderList()
  }

  async remove(value) {
    const ok = await this.send("DELETE", value)
    if (!ok) return
    const opt = Array.from(this.selectTarget.options).find((o) => o.value === value)
    if (opt) {
      const wasSelected = opt.selected
      opt.remove()
      if (wasSelected) this.selectTarget.value = ""
    }
    this.renderList()
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

  lookupLabel() {
    return this.lookupValue.replace(/_/g, " ")
  }

  injectStylesOnce() {
    if (document.getElementById("lookup-manager-styles")) return
    const style = document.createElement("style")
    style.id = "lookup-manager-styles"
    style.textContent = `
      .lookup-manager__tools { margin-top: 6px; }
      .lookup-manager__toggle { border:0; background:transparent; color:#9c6b3f;
        font-size:.8rem; cursor:pointer; padding:2px 0; }
      .lookup-manager__toggle:hover { text-decoration: underline; }
      .lookup-manager__panel { margin-top:6px; padding:8px; border:1px solid #e7dcc4;
        border-radius:8px; background:#fff; }
      .lookup-manager__add { display:flex; gap:6px; margin-bottom:8px; }
      .lookup-manager__addbtn { flex:0 0 auto; background:#b1542b; color:#fff; border:0;
        border-radius:9999px; padding:0 0.9rem; cursor:pointer; }
      .lookup-manager__list { display:flex; flex-wrap:wrap; gap:6px; }
      .lookup-manager__row { display:inline-flex; align-items:center; gap:6px;
        border:1px solid #ddcfb4; border-radius:9999px; padding:2px 6px 2px 10px; font-size:.8rem; }
      .lookup-manager__del { border:0; background:transparent; color:#9c2a1c; cursor:pointer;
        font-size:1rem; line-height:1; padding:0 2px; }
    `
    document.head.appendChild(style)
  }
}
