import { Controller } from "@hotwired/stimulus"

// Repeatable field: an "Add" button clones a blank entry from a <template>, and
// each entry's delete button removes it. Cloned entries that contain their own
// controllers (e.g. the Munsell colour picker) are connected by Stimulus
// automatically when inserted. No reload, so other unsaved edits survive.
export default class extends Controller {
  static targets = ["entries", "template"]

  add(event) {
    event.preventDefault()
    const frag = this.templateTarget.content.cloneNode(true)
    this.entriesTarget.appendChild(frag)
  }

  remove(event) {
    event.preventDefault()
    const entry = event.currentTarget.closest(".repeatable__entry")
    if (entry) entry.remove()
  }
}
