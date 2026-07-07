import { Controller } from "@hotwired/stimulus"

// Draws photo annotations (from the shared photo_annotations doc) over the
// lightbox image. The SVG uses a natural-pixel viewBox with
// preserveAspectRatio="xMidYMid meet", so it letterboxes EXACTLY like the
// image's `object-contain` — normalized (0..1) coordinates line up at any size
// with no resize math. Coordinate/shape semantics mirror the mobile editor
// (od_flutter photos_screen.dart): box = (x,y)-(x2,y2) per-axis, circle radius
// is normalized against the average of width & height, freehand = path[{x,y}].
export default class extends Controller {
  static targets = ["image", "svg"]
  static values = { annotations: Array }

  connect() {
    this._redraw = () => this.render()
    if (this.hasImageTarget) this.imageTarget.addEventListener("load", this._redraw)
    window.addEventListener("resize", this._redraw)
    this.render()
  }

  disconnect() {
    if (this.hasImageTarget) this.imageTarget.removeEventListener("load", this._redraw)
    window.removeEventListener("resize", this._redraw)
  }

  annotationsValueChanged() {
    this.render()
  }

  render() {
    if (!this.hasImageTarget || !this.hasSvgTarget) return
    const img = this.imageTarget
    const nw = img.naturalWidth
    const nh = img.naturalHeight
    const svg = this.svgTarget
    if (!nw || !nh) {
      svg.innerHTML = ""
      return
    }

    svg.setAttribute("viewBox", `0 0 ${nw} ${nh}`)
    svg.setAttribute("preserveAspectRatio", "xMidYMid meet")
    const avg = (nw + nh) / 2

    const esc = (s) =>
      String(s).replace(/[<&>"]/g, (c) => ({ "<": "&lt;", "&": "&amp;", ">": "&gt;", '"': "&quot;" }[c]))
    const sw = 'stroke-width="3" vector-effect="non-scaling-stroke"'
    const parts = []

    for (const a of this.annotationsValue || []) {
      const color = a.color || "#ff3b30"
      const x = (a.x || 0) * nw
      const y = (a.y || 0) * nh

      if (a.type === "box") {
        const x2 = (a.x2 == null ? a.x : a.x2) * nw
        const y2 = (a.y2 == null ? a.y : a.y2) * nh
        parts.push(
          `<rect x="${Math.min(x, x2)}" y="${Math.min(y, y2)}" width="${Math.abs(x2 - x)}" height="${Math.abs(y2 - y)}" fill="none" stroke="${color}" ${sw}/>`
        )
      } else if (a.type === "circle") {
        const r = (a.radius == null ? 0.05 : a.radius) * avg
        parts.push(`<circle cx="${x}" cy="${y}" r="${r}" fill="none" stroke="${color}" ${sw}/>`)
      } else if (a.type === "freehand" && Array.isArray(a.path)) {
        const pts = a.path.map((p) => `${(p.x || 0) * nw},${(p.y || 0) * nh}`).join(" ")
        parts.push(
          `<polyline points="${pts}" fill="none" stroke="${color}" ${sw} stroke-linejoin="round" stroke-linecap="round"/>`
        )
      } else {
        parts.push(
          `<circle cx="${x}" cy="${y}" r="${avg * 0.012}" fill="${color}" stroke="#fff" ${sw}/>`
        )
      }

      if (a.label) {
        parts.push(
          `<text x="${x + avg * 0.015}" y="${y - avg * 0.012}" font-size="${avg * 0.032}" fill="${color}" stroke="#000" stroke-width="0.6" paint-order="stroke" style="font-weight:600">${esc(a.label)}</text>`
        )
      }
    }

    svg.innerHTML = parts.join("")
  }
}
