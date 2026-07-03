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

---

## Chore

One-line, no reasoning, no backing doc.

- [wave-balance] Playtest and retune WaveScaling's per-tier hp/damage/defense growth constants against the target curve (runs ending ~wave 20, wave 30 as practical ceiling).
- [terrain-balance] Cap Break Land at 2 tiles removed per wave now that waves are infinite.

---

## Bug

One-line, no reasoning, no backing doc.

---

## Draft

Preliminary concepts — bigger than a one-liner, but a single `###` sub-section says enough. Not necessarily actionable yet. One `###` heading per idea (nested under this `## Draft` so the section stays intact). When an idea outgrows its sub-section / becomes actionable / needs a stable link → move it into its own `dev/docs/plans/<x>.md` and delete it here. Stale and never grew → just delete it.

### Major And Minor Run Build Effects

Move reward effects toward persistent run build state instead of only immediate stat mutation.

- Major effects are capped at 4 and change ability behavior.
- Minor effects stack without a hard cap and mostly modify stats or small rules.
- Dash type, Smash replacement, Chain Dash, execution, cooldown, range, and triggered effects should survive later ability swaps.
- Existing direct stat rewards can remain as first-pass Minor effects.
- Guard Shredder major: back dash hit instantly zeroes target guard and enters stagger, bypassing the max(half_guard, 32) baseline calc.
- Execution major: dash hit on an already-staggered enemy instantly kills instead of applying the 2.0x stagger burst multiplier.

- Chain Dash and Smash are mutually exclusive, so It will need an exclusive logic to handle it

### Guard Damage, HP Bypass, And Stagger Burst Rework

Baseline hit resolution values are finalized (GDD v0.4 §6); this replaces the earlier front/side/back numbers and moves the instant-break and instant-kill behaviors out of baseline entirely.

- Normal attack and dash share one guard damage table: front 8, side max(quarter_guard, 16), back max(half_guard, 32).
- Guard-active hits also bypass a fraction of base damage straight to HP by angle: front 0, side 0.1, back 0.25.
- Once an enemy is staggered (guard already broken), hits deal HP damage at a multiplier: normal attack 1.0x, dash 2.0x.
- Guard broken on hit plays a new broken SFX; guard-active hits play blocked SFX; staggered hits play damaged SFX scaled to the multiplier.
- Enemy max_guard does not scale with the 5-wave milestone system — only def/hp/damage scale, so the quarter/half guard floors stay meaningful for the whole run.
- Instant guard break on a back dash hit, and instant kill on a staggered dash hit, are no longer baseline — see the Guard Shredder and Execution major effects under Major And Minor Run Build Effects.

### Enemy Sprite Readability Scaffold

Replace pure prototype enemy bodies with low-cost readable state sprites before expanding enemy pattern count.

- Use one four-direction sprite each for Idle, Move, Prepare Attack, and Attack.
- Do not require full frame animation for the first pass.
- Use offset, squash/stretch, rotation, flash, windup VFX, and attack VFX to sell motion and impact.
- Apply the scaffold to SmallEnemy first so later pattern colors and telegraphs remain readable.
- Keep enemy visual identity focused on state, facing, and attack intent before investing in polished art.

### Small Enemy Pattern Director

Make SmallEnemy the main spawn body and use color/pattern identity for most wave pressure.

- Add 6-8 SmallEnemy attack patterns through `EnemyAttackData`.
- Bind pattern identity to readable body color.
- Keep SmallEnemy at roughly 60% or more of base spawns.
- Use SmallEnemy pattern variety as the main content multiplier before adding many new enemy scenes.

### Enemy Spawn Ratio Data Drive

Replace uniform enemy scene selection with weighted spawn pools that can scale by wave and run pressure.

- Replace hard-coded uniform support enemy selection with data-driven enemy spawn weights.
- Allow spawn weights to vary by wave, milestone, stage, or run configuration.
- Keep reward downside pressure as fixed future enemy additions or weighted pool modifiers instead of hidden randomness.
- Consider lowering ChargeEnemy spawn share after the idle-corner fallback fix has been tested in real waves.

### Terrain Chaos Rewards

Keep terrain mutation random but readable enough for fast chaotic play.

- Keep connected-land safety as the main terrain rule.
- Keep Break Land and Move Land as random pressure effects; cap Break Land at 2 tiles removed per wave.
- Add Expand Land as the fixed every-5-wave recovery valve, at 10 tiles per milestone.
- Add Corrupt Land as a visible tick-damage zone; dash i-frames already prevent tick damage while dashing through it, so no extra dash-vs-corrupt rule is needed.
- Reward downside copy is not fully consistent yet (Aggressive-tier offers read more clearly than the others) — accepted gap for now, not blocking this work.

### Wave Reward Deferred Ideas

Later reward work that should wait until Major/Minor run build state exists.

- Manual terrain targeting with tile preview, validity highlight, confirmation, and cancellation.
- Card rarity, weighted rolls, deck-building economy, permanent progression, and final card art.
- Advanced terrain shaping beyond random connected add and random safe connected remove.

### Weapon Class Attack Variants

Player sprite addon and player attack hitbox rework for weapon/class readability.

- Kunai / Ninja: thrust attack, fast but weak, dash damage creates a long line attack.
- Katana / Samurai: 45-degree slash, average damage and speed, dash damage stays direct.
- Heavy axe / undecided class: 180-degree slash, high damage and slow speed, dash damage creates a landing circle area hitbox.

### Wave Reward Effect Stats Table

A player-facing HUD table that groups applied reward effects by tier and displays `definition.display_name` as a human-readable label per group. The overlay currently only shows effect descriptions inline during choice — the title field exists in `WaveRewardEffectDefinition` but has no UI consumer. Once the table is added, the overlay can drop the extra title line and keep its current concise per-effect description format.

### Defensive Terrain And Tower Reward Cards

Later terrain-control reward cards that add player-owned board pressure after the core chaos loop is stable.

- Add Fortified Land as a reward card that blocks tile attacks from spawning on that cell.
- Add Tower as a reward card that regularly attacks nearby tiles.
- Add Archer Tower as a reward card that behaves like Tower but launches one-hit arrows.
- Keep these behind core terrain chaos, Major/Minor build state, and basic enemy spawn weighting work.

### Player Weapon

Prototype a rounder player body with a weapon/facing marker that communicates aim direction now and can become the class identity read later.

- Add or adjust player prototype weapon/facing marker nodes so the marker points toward the current aim direction.
- Keep the player body visually round enough that facing is read from the weapon/facing marker rather than the character silhouette.
- Treat the marker as the future class representation instead of requiring a full player character sprite immediately.
