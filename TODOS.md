# TODOS

## Design

### Establish a design system (DESIGN.md)
- **What:** Run `/design-consultation` to define a shared design system — typeface, color tokens (CSS variables), spacing scale, and the core components (table, button, form field, empty state) — captured in `DESIGN.md`.
- **Why:** There is no DESIGN.md today. Every screen built this cycle (roles/user management, invitations, device pairing) is ad-hoc Tailwind with its own choices. Without shared tokens, each new screen reinvents type/color/spacing and the inconsistency compounds.
- **Pros:** New UI aligns to one system; design reviews calibrate against stated tokens instead of universal principles; faster to build consistent screens.
- **Cons:** Up-front effort; some rework of existing screens to adopt the tokens.
- **Context:** Surfaced during `/plan-design-review` of the device-pairing feature (2026-06-19). The account/devices page, the invitations form, and the manage_users table would all benefit from aligning to a single system.
- **Depends on / blocked by:** Nothing. Best done before significantly more UI lands.
