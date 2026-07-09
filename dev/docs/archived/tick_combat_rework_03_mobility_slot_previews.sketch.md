# Tick Combat Rework 03: Mobility Slot And Previews

Skeleton sketch written ahead of the phase; revise against the codebase at phase start. The codebase wins every disagreement.

## Goal

Formalize the dash verb, the preview-is-truth targeting layer with resolved outcomes, and the ability-override seam that lets a Major replace the mobility slot's payload without touching the input grammar. This phase also separates neutral attack preview from held mobility aiming, so dash targeting has its own focused preview state instead of competing with every other verb at once.

## Requirements

1. Dash: straight line in 4 directions, cursor picks the landing cell clamped to range (5), wall and non-walkable cells stop the scan and hide every later tile, enemies can be passed through and hit but cannot be the landing cell, and cooldown counts in ticks. This is the slot's default payload.
2. Hit prediction and hit application share `TickHitResolver` as the pure tick/grid outcome authority, so the preview layer structurally cannot disagree with the commit — the prototype's predict/apply split becomes the production shape while the existing enemy hit resolver becomes a compatibility adapter instead of a competing rules source.
3. Previews show resolved outcomes, not just geometry: a landing ghost plus per-victim angle/result badges (chip, break, kill tiers), because the prototype showed geometry-only previews read as no preview at all.
4. Player-side preview visuals use a palette strictly separated from the enemy telegraph palette (hard rule from the design document).
5. The mobility slot reads its payload from the run build's narrow ability-override API at verb time; this phase ships dash as the default payload plus a debug-only synthetic stub payload to prove the read path before phase 4 adds the first real replacement payload.
6. The angle resolver quantizes to grid: attacker origin cell (for dash, the cell before entering the target's cell) relative to target facing; diagonal or ambiguous origins resolve to side.
7. Dash commits drive the existing hit feedback and audio semantics through the shared resolver result — blocked, damaged, guard break, stagger burst, kill, and whiff should read like the legacy combat events even though no physics dash hitbox owns the truth.
8. Neutral aiming shows the normal attack preview only; holding the mobility input enters mobility aim, highlights legal landing cells for the active payload, shows a player ghost and path outcome badges for the hovered legal landing, and commits on release only when the current landing is legal. Releasing over an illegal location or pressing Escape cancels back to neutral without consuming a tick; after Escape, the matching mobility-input release is suppressed so it cannot accidentally commit.

## Design

Outcome badge tiers (from the prototype): tier 0 chip = angle label only, tier 1 = break/burst, tier 2 = kill; higher tiers draw brighter and thicker. Badge density remains parked in the design document's deferred list, but mobility hold-to-aim is promoted into this phase because dash targeting needs a focused preview state.

Dash path rule: the scan proceeds from the player cell in the aimed cardinal direction until range 5 or the first wall/non-walkable cell. Enemy-occupied cells stay in the travel path and become victims, but they are skipped as landing candidates; a dash into an adjacent enemy can still land behind it when a later scanned cell is open. If no open landing cell exists before the blocker, the dash is illegal and consumes no tick.

Input preview states: neutral, mobility aim, and cancel-suppressed release. Neutral preview is lightweight and attack-focused. Mobility aim starts on right mouse press only when the active payload can currently be aimed; dash cooldown soft-denies the press and stays neutral. Escape exits mobility aim and marks the current right-button release as ignored, so canceling never turns into a late dash. A very short press still works as a quick dash attempt because press enters mobility aim immediately and release commits against the current hovered landing if legal.

## Sketch (non-normative)

- New resolver authority: add `tick_hit_resolver.gd` / `TickHitResolver` as the production tick/grid hit truth. It accepts attacker origin cell, target snapshot, base damage, and hit kind, then resolves angle, guard damage, hp damage, break, burst, kill, and feedback flags without reading or mutating live nodes.
- Legacy adapter path: keep the existing enemy hit resolver public surface only as a compatibility bridge for legacy physics/enemy-component call sites during the conversion. Where possible, it should build the same target snapshot shape from live `Guard` / `Health` / facing state and delegate outcome math to `TickHitResolver`, so there is still only one production rules source.
- Unified outcome shape: one dictionary or small value object carries at least `angle`, `was_guarded`, `guard_broken`, `stagger_burst`, `killed`, `hp_damage`, `guard_damage`, `feedback_kind`, and later hook metadata. Preview badges, commit feedback, and phase 4 trigger hooks consume or modify this same shape instead of inventing per-call labels.
- Ability-override read: `RunBuild` gains a narrow mobility payload override API with `StringName` constants such as `PAYLOAD_DASH` and a debug-only synthetic payload for this phase. The input layer asks the run build at verb time, but the store does not become an arbitrary payload or trigger registry; the reward-store architecture itself remains untouched.
- Preview state flows controller → view as plain dictionaries, as in the prototype; the view stays a dumb renderer. The controller owns the neutral/mobility/cancel-suppressed state machine so the view only renders the active preview mode.
- Target snapshots for prediction: cell, facing, guard current/max, staggered, hp — read-only copies so prediction can never mutate.
- Commit results emit presentation events from the resolver result rather than from collision callbacks, so existing VFX/SFX helpers can be reused without letting physics hitboxes become the authority again.

## Non-Goals

1. No real Smash, no windup grammar, no triggered effects (phase 4). A debug-only synthetic mobility payload may exist only to prove that the slot reads the run build seam.
2. No speed stats (phase 5); dash cooldown is a constant here.
3. No modal targeting UI beyond the held mobility aim state — no click-to-enter targeting mode, no persistent cursor mode, and no separate confirm button.

## Acceptance Criteria

1. Every commit executes exactly what its preview displayed at press time, including clamped landings; preview and commit provably share `TickHitResolver` for hit math.
2. Swapping the ability-override value swaps the slot's behavior with zero input-layer changes, demonstrated with a debug-only stub payload ahead of phase 4's real Major.
3. Outcome badges match the resolved results across angle, break, and kill cases.
4. Dash hit, blocked, break, kill, and whiff feedback remains event-driven from the tick commit result and does not regress to silent grey-box hits.
5. Neutral hover shows only the normal attack preview, held mobility aim shows legal landing cells plus the hovered landing ghost/path/outcomes, legal release commits the displayed dash, illegal release cancels for free, and Escape cancel suppresses the pending release.
