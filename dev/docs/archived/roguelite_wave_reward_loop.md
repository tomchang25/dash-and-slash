# Roguelite Wave Reward Loop

## Goal

Turn the current short arena sequence into an early roguelite run loop where clearing normal waves offers reward profiles that can change player power, move arena terrain, or raise future wave pressure before the wave 5 boss gate.

## Requirements

1. The run has four normal waves followed by a wave 5 boss, because the first boss gate should arrive quickly enough to validate the reward loop without requiring a long run.
2. Clearing each normal wave presents three random reward choices before the next wave starts so the player gets a deliberate build or map decision between combat beats.
3. Choosing a reward applies it immediately and starts the next wave after the choice closes, because the first pass favors low-friction pacing over targeting previews or delayed resolution.
4. Terrain rewards move one land tile by adding one connected land tile and then removing one safe connected land tile while preserving gameplay validity, because terrain changes should create tactical variety without isolating actors or breaking pathing.
5. Pressure rewards can increase future support enemy counts, including boss-wave support enemies, so the player can trade power or space against higher later-wave pressure without multiplying the boss itself.
6. Reward offers use the current Conservative, Balanced, and Aggressive profiles as the player-facing choice shape; effect families such as terrain movement, pressure, numeric player buffs, and the first-pass major placeholder are ingredients inside those profiles rather than separate card categories.

## Design

Wave structure:

| Wave | Role   | Enemy plan                                 |
| ---- | ------ | ------------------------------------------ |
| 1    | Normal | 5 normal enemies                           |
| 2    | Normal | 6 normal enemies                           |
| 3    | Normal | 7 normal enemies                           |
| 4    | Normal | 8 normal enemies                           |
| 5    | Boss   | 1 boss plus support enemies from wave data |

Normal wave enemy counts are base count plus accumulated future-enemy modifiers. The boss wave stays a boss gate with exactly one boss, but it may also spawn normal support enemies. Pressure modifiers increase future normal/support enemy counts and do not duplicate the boss.

The boss wave ends when the boss dies. Any remaining support enemies are force-cleared during boss wave resolution before the run completes, because support enemies should raise boss pressure without turning post-boss victory into cleanup.

Reward timing:

1. A wave spawns all enemies for that wave.
2. When all enemies are cleared, spawning pauses and the reward phase corrects the player to a safe land cell if needed.
3. Three reward choices appear.
4. The selected reward applies immediately.
5. The next wave starts.
6. Killing the boss force-clears any remaining boss-wave support enemies and completes the run.

Reward profiles:

| Profile      | Meaning                           | First-pass shape                                    |
| ------------ | --------------------------------- | --------------------------------------------------- |
| Conservative | Lower-risk offer profile          | Small terrain movement, pressure, or numeric upside |
| Balanced     | Mixed upside and downside profile | Combined terrain, pressure, and numeric effects     |
| Aggressive   | Higher-swing offer profile        | Larger stacks and the major placeholder can appear  |

Move Land chooses a random sea cell adjacent to the existing landmass and turns it into land immediately, then chooses a random removable land cell, rejects cells occupied by active actors or reservations, and rejects removals that would split the remaining landmass. Terrain choices do not open a tile-selection mode in this phase.

The major placeholder is an Aggressive-profile effect ingredient, not a separate rarity or complete class-change system. The first implementation only needs enough plumbing to show, select, and apply a placeholder effect without implementing real class behavior.

Controller ownership rule: runtime controllers coordinate flow and may hold ephemeral state such as the current reward offer, but durable run state belongs to the system that owns that state. Enemy count modifiers belong to the run/wave state, player stat buffs belong to player stat state, and terrain changes belong to the arena terrain authority.

## Non-Goals

1. Do not implement card rarity, deck-building economy, permanent progression, or reward art.
2. Do not implement real class changes, weapon attack variants, or player action-model swaps in this phase.
3. Do not add manual tile preview, tile targeting, placement confirmation, or cancellation for terrain rewards.
4. Do not add advanced procedural island shaping beyond one connected add and one safe connected remove in a Move Land effect.
5. Do not add mid-wave normal enemy spawning.

## Acceptance Criteria

1. Waves 1 through 4 are normal enemy waves and wave 5 is the boss gate.
2. Clearing each normal wave presents exactly three reward choices before the next wave begins.
3. Selecting a reward applies exactly one option immediately and then advances the run.
4. Move Land rewards never create isolated land.
5. Move Land rewards never remove occupied, reserved, or player cells and never split the remaining landmass.
6. Future enemy count increases affect later normal/support enemy spawns after the reward is selected without increasing the boss count.
7. Numeric player stat rewards apply through player stat state.
8. Conservative, Balanced, and Aggressive reward profiles can be generated, displayed, and selected, including an Aggressive-profile major placeholder without implementing real class behavior.
9. Boss death force-clears remaining support enemies before the run enters the completed state.
