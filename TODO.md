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

Nothing currently in progress.

---

## Plan

Queued work, big enough to have a pre-plan file in `dev/docs/plans/`. Promote a line to `## Active` when building starts; if it goes stale here, retire it back to `## Draft`.

[wave_rewards-main] Main roguelite wave reward loop design with wave 5 boss and first-pass card boundaries — [ref plans/roguelite_wave_reward_loop.md]
[wave_rewards] Add the wave reward choice controller with random three-card offers and immediate application — [ref plans/wave_reward_choice_controller.sketch.md]
[wave_rewards] Reposition the player to a safe central land cell when each wave starts — [ref plans/wave_start_player_reposition.sketch.md]
[wave_rewards] Replace the fixed wave sequence with data-driven waves and future enemy modifiers — [ref plans/data_driven_wave_controller.sketch.md]
[wave_rewards] Add a run-scoped data-driven player stat path for reward buffs — [ref plans/data_driven_player_stats.sketch.md]
[wave_rewards] Add first-pass Minor reward cards for numeric player stat buffs — [ref plans/minor_wave_reward_cards.sketch.md]
[wave_rewards] Add the Major reward card skeleton with a class-change placeholder — [ref plans/major_wave_reward_card_skeleton.sketch.md]

---

## Chore

One-line, no reasoning, no backing doc.

[toast-manager]

---

## Bug

_(no known bugs)_

---

## Draft

Preliminary concepts — bigger than a one-liner, but a single `###` sub-section says enough. Not necessarily actionable yet. One `###` heading per idea (nested under this `## Draft` so the section stays intact). When an idea outgrows its sub-section / becomes actionable / needs a stable link → move it into its own `dev/docs/plans/<x>.md` and delete it here. Stale and never grew → just delete it.

### Weapon Class Attack Variants

Player sprite addon and player attack hitbox rework for weapon/class readability.

- Kunai / Ninja: thrust attack, fast but weak, dash damage creates a long line attack.
- Katana / Samurai: 45-degree slash, average damage and speed, dash damage stays direct.
- Heavy axe / undecided class: 180-degree slash, high damage and slow speed, dash damage creates a landing circle area hitbox.

### Wave Reward Deferred Ideas

Later work that should not ride on the first wave reward loop PR.

- Real Major class changes that swap class identity, action behavior, or weapon rules.
- Manual terrain targeting with tile preview, validity highlight, confirmation, and cancellation.
- Card rarity, weighted rolls, deck-building economy, permanent progression, and final card art.
- Advanced terrain shaping beyond random connected add and random safe connected remove.

### Enemy Character Sprite Readability

Replace prototype enemy bodies with real character sprites and readable animation.

- Full version: each enemy gets four-direction movement sprites and four-direction attack sprites.
- Simpler version: use left/right sprites with flipping, then tween squash and tilt to imitate movement and attack.
- Needs a clear visual rule for enemies with contact attacks versus enemies without contact attacks.

### Player Weapon

Prototype a rounder player body with a weapon/facing marker that communicates aim direction now and can become the class identity read later.

- Add or adjust player prototype weapon/facing marker nodes so the marker points toward the current aim direction.
- Keep the player body visually round enough that facing is read from the weapon/facing marker rather than the character silhouette.
- Treat the marker as the future class representation instead of requiring a full player character sprite immediately.

### Enemy Grid Attack Planning Optimization

Reduce wasted enemy planning work and make blocked-line charge behavior degrade into normal pursuit.

- Optimize `GridEnemy.plan_cell_attack_action()` by deriving candidate attack origins from the target cell instead of scanning every grid cell and facing.
- Gate ChargeEnemy telegraph/attack entry on whether the stored charge line can actually travel through walkable cells.
- When ChargeEnemy has no viable charge origin on the target row or column, fall back to ordinary approach movement toward the player.

### ToastManager

Restore or rebuild the template ToastManager so runtime warnings can surface in-game without hiding the underlying issue.

- Add a `ToastManager.warn` path for recoverable gameplay anomalies such as ChargeEnemy entering charge attack without stored charge cells.
- Keep engine/developer diagnostics visible through `push_warning` while also showing player-facing or debug-facing toast feedback.
- Check why the template clone did not bring over ToastManager and align the replacement with current autoload and UI overlay conventions.

### Charge Enemy Ratio Tweak + Enemy Spawn Ratio Data Drive Refactor

Later balance and data work after ChargeEnemy blocked-line behavior is stable.

- Consider lowering ChargeEnemy spawn share to 20% after the AI fallback fix has been tested in real waves.
- Replace the hard-coded equal `ENEMY_POOL` selection with data-driven enemy spawn weights.
- Allow spawn weights to vary by wave, stage, or run configuration instead of being fixed in the stage script.
