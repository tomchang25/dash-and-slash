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

- [rewards] Tick artifact rewards: replace point-balanced generator with Risk-of-Rain artifacts, milestone curses, unified Minor/Major, build inspection panel — [ref plans/tick_artifact_rewards.md]
- [ui] Tick arena HUD refactor: single combat-info layer plus run-build summary — gated on tick artifact rewards shipping — [ref plans/tick_arena_hud_refactor.sketch.md]

---

## Chore

One-line, no reasoning, no backing doc.

- [wave-balance] Playtest and retune WaveScaling's per-tier hp/damage/defense growth constants against the target curve (runs ending ~wave 20, wave 30 as practical ceiling).
- [audio] Add a dedicated guard-broken SFX event — guard break currently plays only VFX plus the generic damaged/blocked audio (forgotten bullet from the shipped guard rework).
- [docs] Sync the GDD to v0.5 shipped reality (drop the draft banner, close resolved deferred-list items) — remaining tail from the archived tick combat rework cutover.

---

## Bug

One-line, no reasoning, no backing doc.

---

## Draft

Preliminary concepts — bigger than a one-liner, but a single `###` sub-section says enough. Not necessarily actionable yet. One `###` heading per idea (nested under this `## Draft` so the section stays intact). When an idea outgrows its sub-section / becomes actionable / needs a stable link → move it into its own `dev/docs/plans/<x>.md` and delete it here. Stale and never grew → just delete it.

### Future Major Effects

Later Major content. The override and triggered-effect seams these need are shipped (Smash proves the payload override; Guard Shredder, Execution, and Mobility Free Action prove the trigger seam), so these are ready to build whenever content volume is wanted.

- Chain Dash should share `SmashMajorEffect.EXCLUSIVITY_GROUP` and use `RunBuild.set_mobility_payload_override()` the same way Smash does (see `game/tick_arena/reward/effects/smash_major_effect.gd`).
- Shockwave Dash and other mobility-slot-triggered Majors should reuse `RunBuild.set_mobility_trigger()` / `has_mobility_trigger()` (the seam Guard Shredder and Execution use, payload-agnostic across Dash and Smash) instead of forking either payload's resolution.

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

### Enemy Idle And Path Reservation Follow-up

Enemy Idle is currently a tick decision state, not a long-lived waiting state. When a GridEnemy in Reposition loses ownership of the first reserved path step, `tick_step_along_path()` clears the path and returns false; `EnemyRepositionState` then transitions back to Idle instead of replanning, turning, or committing inside the same funded actor action. That makes path conflicts consume the enemy's action and produces visible idle churn. Newly spawned enemies can show a related symptom because the first Idle decision may only transition into Reposition, with the actual step delayed until the next `advance_tick()`.

- Decide whether one funded enemy action should resolve decision plus movement/turn/commit in the same tick, instead of paying a separate FSM-transition tick.
- Add an immediate replan path for reservation-lost or blocked-first-step cases so the enemy still simulates useful behavior when its planned path is stolen.
- Recheck newly spawned enemy behavior after spawn warning resolution so first-round actors do not appear parked in Idle for the next round.

### Wave Reward Deferred Ideas

Later reward-economy work, kept behind the core loop stabilizing. The former terrain-targeting and terrain-shaping ideas were dropped — per-wave terrain mutation is frozen and the obstacle-grid direction replaces that pressure channel.

- Card rarity, weighted rolls, deck-building economy, permanent progression, and final card art.

### 增加額外障礙物 Grid 替代

凍結每輪隨機增減或搬動地形；太隨機或太碎的地形有可能導致死局或卡手，不適合目前偏半益智型的 tick combat。後續地圖壓力改研究在穩定 10x10 基底上增加額外障礙物 grid，取代每輪碎地形的 run cadence。

- Corrupt Land（已自 tick rework 流程退役）是此方向的第一個候選危險格機制——spec 保留在 `archived/tick_combat_rework_06a_corrupt_land.implementation_spec.md`，撿起時先對照 codebase 修訂。

### Character Classes

Rewrite of the old weapon-class idea against tick verbs: a class is a bundled starting identity, not a hitbox variant.

- Each class bundles a distinct base Speed profile (meter fill rate), normal attack cell shape, default mobility payload (Dash vs Smash), and one unique class-locked perk.
- Class visual identity is a weapon sprite/marker on the round player body pointing at the current mouse aim (folded in from the retired Player Weapon draft) — the tick player has no combat facing, so the marker reads as aim, not facing.
- Example directions to explore: kunai/ninja (fast Speed fill, line-thrust attack shape, Dash default), katana/samurai (balanced, arc slash shape, Dash default), heavy axe (slow, wide shape, Smash default).

### Defensive Terrain And Tower Reward Cards

Later reward cards that add player-owned board pressure, re-anchored to the stable-base obstacle-grid direction (see 增加額外障礙物 Grid 替代) now that per-wave terrain mutation is frozen.

- Add Fortified Land as a reward card that blocks tile attacks from spawning on that cell.
- Add Tower as a reward card that regularly attacks nearby tiles.
- Add Archer Tower as a reward card that behaves like Tower but launches one-hit arrows.
- Keep these behind the obstacle-grid work and basic enemy spawn weighting.
