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

- [enemy_mobility] Rework committed enemy mobility around ChargeEnemy collision displacement and a new DashEnemy backline ambush — [ref plans/tick_arena_enemy_mobility_and_forced_displacement.md]
- [enemy_roles] Establish predictable Guard resilience, reactive facing, distinct combat roles, and role-aware spawn formations — [ref plans/tick_arena_enemy_combat_roles_and_counterpressure.md]
- [meta_progression] Add save-backed Coin, Ninja-clear Viking unlock, Main Menu character selection, and purchasable Artifact pool unlocks — [ref plans/meta_progression.md]
- [wave_progression] Build data-driven ordered wave groups and enemy-level scaling for a ten-wave demo plus optional lethal endless continuation — [ref plans/data_driven_wave_progression_and_enemy_levels.md]

---

## Chore

One-line, no reasoning, no backing doc.

- [docs] Sync the GDD to v0.5 shipped reality (drop the draft banner, close resolved deferred-list items) — remaining tail from the archived tick combat rework cutover.

---

## Bug

One-line, no reasoning, no backing doc.

---

## Draft

Preliminary concepts — bigger than a one-liner, but a single `###` sub-section says enough. Not necessarily actionable yet. One `###` heading per idea (nested under this `## Draft` so the section stays intact). When an idea outgrows its sub-section / becomes actionable / needs a stable link → move it into its own `dev/docs/plans/<x>.md` and delete it here. Stale and never grew → just delete it.

### Future Mobility-Specific Major Effects

Character classes use fixed, non-shared Mobility identities, so future Majors extend the active Mobility instead of replacing it. Major eligibility should be filtered by required Mobility: Dash effects belong to the Ninja pool, Smash effects belong to the Viking pool, and a class never rolls another Mobility's exclusive effects.

- Expand Dash and Smash with additional Mobility-specific effects after the initial class slice proves the eligibility and runtime seams.
- Keep Mobility execution behavior owned by the active payload while artifacts contribute named modifiers or triggers; do not restore payload-replacement artifacts.
- If future classes ever share a Mobility, revisit whether required-Mobility filtering also needs an explicit class restriction instead of making those classes share every Major automatically.

### Normal Attack Variants

Normal attack shape variants are frozen while the first character classes establish identity through fixed Mobility and Mobility-specific Majors. Every initial class keeps the current one-cell cardinal normal attack.

- Revisit line, arc, wide, or other footprints only after Ninja and Viking have been playtested as distinct Mobility identities.
- Any future variant pass must resolve one shared footprint for preview, committed hits, and auto-attack-on-move so the displayed cells cannot disagree with the executed attack.
- Define penetration, obstacle blocking, multi-target order, and any windup or recovery trade-off before allowing a larger footprint to ship.

### Samurai Character Class

Samurai is deferred until Ninja and Viking prove the fixed-Mobility class model. Because different classes do not share Mobility in the current direction, Samurai needs its own Mobility identity rather than reusing Dash.

- Decide whether guard and counter timing deserve a new player combat verb/state or whether Samurai should use a different mobility-centered fantasy.
- Keep Samurai out of the initial class data, selection surface, sprite work, and Major eligibility pools.

### Enemy Idle And Path Reservation Follow-up

Enemy Idle is currently a tick decision state, not a long-lived waiting state. When a GridEnemy in Reposition loses ownership of the first reserved path step, `tick_step_along_path()` clears the path and returns false; `EnemyRepositionState` then transitions back to Idle instead of replanning, turning, or committing inside the same funded actor action. That makes path conflicts consume the enemy's action and produces visible idle churn. Newly spawned enemies can show a related symptom because the first Idle decision may only transition into Reposition, with the actual step delayed until the next `advance_tick()`.

- Decide whether one funded enemy action should resolve decision plus movement/turn/commit in the same tick, instead of paying a separate FSM-transition tick.
- Add an immediate replan path for reservation-lost or blocked-first-step cases so the enemy still simulates useful behavior when its planned path is stolen.
- Recheck newly spawned enemy behavior after spawn warning resolution so first-round actors do not appear parked in Idle for the next round.

### Spawn Telegraph Forced Displacement Follow-up

Keep the group-based spawning refactor on its current safe replacement behavior when the player occupies a warned spawn cell at resolution. After the shared forced-displacement and occupancy-refresh contract in `tick_arena_enemy_mobility_and_forced_displacement.md` is implemented and proven, revisit whether the enemy should instead spawn on its warned cell and displace the player.

- Reuse the shared forced-displacement seam rather than adding spawn-owned knockback logic or coupling spawning directly to `ChargeEnemy`.
- Define displacement direction, legal destination selection, pinned-player handling, damage, simultaneous spawn order, and warning-to-resolution agreement before this becomes actionable.
- Keep this future behavior outside the group-based spawning refactor; spawning telegraphs may block enemy path planning first while player-cell resolution continues to use nearby legal replacement placement.

### Wave Reward Deferred Ideas

Later reward-economy work, kept behind the core loop stabilizing. The former terrain-targeting and terrain-shaping ideas were dropped — per-wave terrain mutation is frozen and the obstacle-grid direction replaces that pressure channel.

- Card rarity, weighted rolls, deck-building economy, and final card art.

### Forced Trade-Off Curses And Nemesis

Freeze replacement curse work until the data-driven wave and level cutover removes the current pressure curses. A later plan should replace the forced single random curse with a forced three-choice offer whose mutators change how the run is played rather than adding hidden enemy stat pressure.

- Explore a wave-start mutator that begins each wave at half HP.
- Explore doubled Mobility cooldown paired with doubled normal and Mobility attack damage.
- Explore losing 1 HP per action tick while healing for 10% of actual normal and Mobility attack damage dealt.
- Explore normal attacks dealing no Guard damage while Mobility Guard damage doubles.
- Explore a persistent Nemesis-style invincible hunter that relentlessly pressures the player without belonging to normal wave groups or blocking wave completion.

### 增加額外障礙物 Grid 替代

凍結每輪隨機增減或搬動地形；太隨機或太碎的地形有可能導致死局或卡手，不適合目前偏半益智型的 tick combat。後續地圖壓力改研究在穩定 10x10 基底上增加額外障礙物 grid，取代每輪碎地形的 run cadence。

- Corrupt Land（已自 tick rework 流程退役）是此方向的第一個候選危險格機制——spec 保留在 `archived/tick_combat_rework_06a_corrupt_land.implementation_spec.md`，撿起時先對照 codebase 修訂。

### Player Action State Ownership

Player movement, Smash windup ("prepare attack"), and normal attack are all resolved inline inside `TickActionController.handle_verb()`'s verb match/dispatch, not through the project's `StateMachine`/`State` delegation pattern. Smash's two-phase prepare/release is tracked with a single `_smash_armed` bool on `TickPlayer` (`arm_smash`/`disarm_smash`/`is_smash_armed`) rather than a real state object, and normal attack has no windup phase at all.

- Revisit whether this should move onto the shared `StateMachine`/`State` framework once more multi-phase player actions exist (e.g. a future Samurai guard/counter verb, see Samurai Character Class above).
- Until then, treat `TickActionController` verb dispatch plus the `_smash_armed` flag as the intentional lightweight shape — do not add more ad hoc bools for new multi-phase actions without reconsidering this.

### Defensive Terrain And Tower Reward Cards

Later reward cards that add player-owned board pressure, re-anchored to the stable-base obstacle-grid direction (see 增加額外障礙物 Grid 替代) now that per-wave terrain mutation is frozen.

- Add Fortified Land as a reward card that blocks tile attacks from spawning on that cell.
- Add Tower as a reward card that regularly attacks nearby tiles.
- Add Archer Tower as a reward card that behaves like Tower but launches one-hit arrows.
- Keep these behind the obstacle-grid work and basic enemy spawn weighting.
