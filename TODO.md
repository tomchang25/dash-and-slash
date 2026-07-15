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

- [project_structure] Consolidate arena-owned entities, grid, combat, and presentation while keeping only portable infrastructure in common — [ref plans/runtime_structure_reorganization.md]

- [action_points] Replace Speed-meter free actions with player-round AP, overflow-aware Chain Dash, and round-relative timing — [ref plans/tick_arena_action_points_and_relative_timing.md]
- [enemy_commitment] Remove the FaceOnce action tax, add immediate hit-facing and multi-step MoveActions, and replan conflicts within one enemy-phase action — [ref plans/enemy_action_commitment_and_replanning.md]
- [enemy_mobility] Rework ChargeEnemy as a facing-free collision charge, add DashEnemy backline ambush, and establish shared forced displacement — [ref plans/tick_arena_enemy_mobility_and_forced_displacement.md]
- [execution_resistance] Convert Execution instant kills into triple Mobility damage against bosses and other resistant enemies — [ref plans/combat_execution_resistance.md]
- [meta_progression] Add save-backed Coin, Ninja-clear Viking unlock, Main Menu character selection, and purchasable Artifact pool unlocks — [ref plans/meta_progression.md]

---

## Chore

One-line, no reasoning, no backing doc.

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

### 0.1.0 Player Baseline Balance Pass

Current enemies feel too punishing, but exact player buffs should land only after enemy commitment, timing, and forced-displacement behavior stop changing so balance is not tuned around avoidable action-tax or occupancy bugs.

- Playtest both Ninja and Viking across the authored ten-wave demo after the combat-rule plans land.
- Compare authored player maximum health, normal and Mobility damage, base Mobility cooldowns, and reward magnitudes before changing enemy role identities or encounter grammar.
- Keep the final adjustments in authored balance data and avoid hidden difficulty compensation or unconditional enemy-stat pressure.

### Smash Occupied Landing Resolution

An armed Smash must not be cancelled, rejected indefinitely, or reduced to leaving the player at the origin merely because an enemy occupied the locked landing during Windup. The non-cancelling collision result remains undecided and stays outside the enemy mobility plan until that rule is locked.

- Instantly killing the blocking center enemy so Smash lands normally is one candidate.
- Reuse the shared forced-displacement seam when the center enemy can move, but do not treat failed displacement as action cancellation.
- Define the resistant Boss or priority-target result together with the final blocked-displacement rule before promoting this Draft.

### Forced Trade-Off Curses And Nemesis

The data-driven wave and level cutover removed the current pressure curses. A later plan should replace the forced single random curse with a forced three-choice offer whose mutators change how the run is played rather than adding hidden enemy stat pressure.

- Explore a wave-start mutator that begins each wave at half HP.
- Explore doubled Mobility cooldown paired with doubled normal and Mobility attack damage.
- Explore losing 1 HP per action tick while healing for 10% of actual normal and Mobility attack damage dealt.
- Explore normal attacks dealing no Guard damage while Mobility Guard damage doubles.
- Explore a persistent Nemesis-style invincible hunter that relentlessly pressures the player without belonging to normal wave groups or blocking wave completion.

### 增加額外障礙物 Grid 替代

凍結每輪隨機增減或搬動地形；太隨機或太碎的地形有可能導致死局或卡手，不適合目前偏半益智型的 tick combat。後續地圖壓力改研究在穩定 10x10 基底上增加額外障礙物 grid，取代每輪碎地形的 run cadence。

- Corrupt Land（已自 tick rework 流程退役）是此方向的第一個候選危險格機制——spec 保留在 `archived/tick_combat_rework_06a_corrupt_land.implementation_spec.md`，撿起時先對照 codebase 修訂。

### Defensive Terrain And Tower Reward Cards

Later reward cards that add player-owned board pressure, re-anchored to the stable-base obstacle-grid direction (see 增加額外障礙物 Grid 替代) now that per-wave terrain mutation is frozen.

- Add Fortified Land as a reward card that blocks tile attacks from spawning on that cell.
- Add Tower as a reward card that regularly attacks nearby tiles.
- Add Archer Tower as a reward card that behaves like Tower but launches one-hit arrows.
- Keep these behind the obstacle-grid work and basic enemy spawn weighting.

## Future Draft

Preliminary concepts — bigger than a one-liner, but a single `###` sub-section says enough. Not necessarily actionable yet. One `###` heading per idea (nested under this `## Draft` so the section stays intact). When an idea outgrows its sub-section / becomes actionable / needs a stable link → move it into its own `dev/docs/plans/<x>.md` and delete it here. Stale and never grew → just delete it.

### Spawn Telegraph Forced Displacement Follow-up

Keep the group-based spawning refactor on its current safe replacement behavior when the player occupies a warned spawn cell at resolution. After the shared forced-displacement and occupancy-refresh contract in `tick_arena_enemy_mobility_and_forced_displacement.md` is implemented and proven, revisit whether the enemy should instead spawn on its warned cell and displace the player.

- Reuse the shared forced-displacement seam rather than adding spawn-owned knockback logic or coupling spawning directly to `ChargeEnemy`.
- Define displacement direction, legal destination selection, pinned-player handling, damage, simultaneous spawn order, and warning-to-resolution agreement before this becomes actionable.
- Keep this future behavior outside the group-based spawning refactor; spawning telegraphs may block enemy path planning first while player-cell resolution continues to use nearby legal replacement placement.

### Normal Attack Variants

Normal attack shape variants are frozen while the first character classes establish identity through fixed Mobility and Mobility-specific Majors. Every initial class keeps the current one-cell cardinal normal attack.

- Revisit line, arc, wide, or other footprints only after Ninja and Viking have been playtested as distinct Mobility identities.
- Any future variant pass must resolve one shared footprint for preview, committed hits, and auto-attack-on-move so the displayed cells cannot disagree with the executed attack.
- Define penetration, obstacle blocking, multi-target order, and any windup or recovery trade-off before allowing a larger footprint to ship.

### Samurai Character Class

Samurai is deferred until Ninja and Viking prove the fixed-Mobility class model. Because different classes do not share Mobility in the current direction, Samurai needs its own Mobility identity rather than reusing Dash.

- Decide whether guard and counter timing deserve a new player combat verb/state or whether Samurai should use a different mobility-centered fantasy.
- Keep Samurai out of the initial class data, selection surface, sprite work, and Major eligibility pools.

### Wave Reward Deferred Ideas

Later reward-economy work, kept behind the core loop stabilizing. The former terrain-targeting and terrain-shaping ideas were dropped — per-wave terrain mutation is frozen and the obstacle-grid direction replaces that pressure channel.

- Card rarity, weighted rolls, deck-building economy, and final card art.
