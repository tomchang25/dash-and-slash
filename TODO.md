# TODO

The single forward surface — open this and you see everything: open work _and_ brewing ideas. Every forward item lives in **exactly one** section here (or, once it earns a file, in `dev/docs/plans/`). There is deliberately **no "Done" tier** — done = delete the line; its record lives in `CHANGELOG.md`.

> **The one rule (now about sections, not files):** the actionable tiers (`Plan` / `Chore` / `Bug`) are **one line each** — no paragraphs, no tables, no _why_. The moment an item needs real reasoning, it belongs in `## Draft` as its own `###` sub-section. When a Draft entry grows sub-structure, becomes actionable, or needs to be linked from elsewhere, it graduates to its own file in `dev/docs/plans/`.
>
> Within `## Draft`, no `####` headings or `**label:**` bold-label patterns — use plain-text labels (em-dash, colon) and lists for sub-structure.
>
> **Tag format:** the `[Scope]` tag in actionable lines is **snake_case** — short lowercase identifier, no spaces, no parens, no mixed case (e.g. `[feature]`, `[bugfix]`).

Actionable line format: `[Scope] one sentence — [ref plans/<x>.md if any]`

In-flight and ready-to-implement work lives in `## Active` — promoted from `## Plan` when building starts or the plan is ready to build; more than one entry is fine.

---

## Active

> Do not delete this reminder text
> Flows currently being built or ready to implement — may hold more than one entry. One-line pointer each — same format as `## Plan`, promoted here when building starts or the plan is ready to build.
> Phase detail and progress live in the linked `dev/docs/plans/` file;
> Ship a phase → cut it from that file + append `CHANGELOG.md`, leaving this line untouched.
> All phases shipped → archive the plan file + delete this line.

- [enemy] Data-backed enemy structure — see `dev/docs/plans/enemy_data_backed_structure.md`
- [enemy] Phase 1 enemy data resources — see `dev/docs/plans/enemy_data_resources.sketch.md`
- [enemy] Phase 2 cell attack controller — see `dev/docs/plans/enemy_cell_attack_controller.sketch.md`
- [enemy] Phase 3 special attack data integration — see `dev/docs/plans/enemy_special_attack_data.sketch.md`
- [enemy] Phase 4 state consolidation — see `dev/docs/plans/enemy_state_consolidation.sketch.md`

---

## Plan

Queued work, big enough to have a pre-plan file in `dev/docs/plans/`. Promote a line to `## Active` when building starts; if it goes stale here, retire it back to `## Draft`.

- [grid] Dynamic 16x16 land/sea gameplay grid — see `dev/docs/plans/dynamic_grid_land_sea.sketch.md`

---

## Chore

One-line, no reasoning, no backing doc.

_(no chores)_

---

## Bug

_(no known bugs)_

---

## Draft

Preliminary concepts — bigger than a one-liner, but a single `###` sub-section says enough. Not necessarily actionable yet. One `###` heading per idea (nested under this `## Draft` so the section stays intact). When an idea outgrows its sub-section / becomes actionable / needs a stable link → move it into its own `dev/docs/plans/<x>.md` and delete it here. Stale and never grew → just delete it.

_(no draft ideas yet)_
