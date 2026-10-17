import { Controller } from "@hotwired/stimulus"

// Select-all checkbox plus a submit button that shows how many rows are selected.
export default class extends Controller {
  static targets = ["all", "item", "submit"]

  connect() { this.update() }

  toggleAll() {
    this.itemTargets.forEach((box) => { box.checked = this.allTarget.checked })
    this.update()
  }

  update() {
    const count = this.itemTargets.filter((box) => box.checked).length
    this.submitTarget.disabled = count === 0
    this.submitTarget.value = count === 0 ? "Delete selected" : `Delete ${count} selected`
    if (this.hasAllTarget) this.allTarget.checked = count > 0 && count === this.itemTargets.length
  }
}
