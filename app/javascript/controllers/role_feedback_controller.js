import { Controller } from "@hotwired/stimulus"

console.log("[stimulus] role_feedback_controller loaded")

export default class extends Controller {
  static values = { change: String }

  connect() {
    const state = (this.changeValue || "").toLowerCase()
    console.log("role-feedback", state)
    if (!["success", "failure"].includes(state)) return

    this.setBorderColor(state === "success" ? "border-green-500" : "border-red-500")
    requestAnimationFrame(() => {
      this.setBorderColor("border-gray-300")
    })
  }

  setBorderColor(color) {
    this.element.classList.remove("border-gray-500", "border-green-500", "border-red-500")
    this.element.classList.add(color)
  }
}