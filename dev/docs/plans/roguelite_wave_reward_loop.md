# Roguelite Wave Reward Loop

## Goal

Turn the current short arena sequence into an early roguelite run loop where clearing normal waves offers reward cards that can change player power, arena terrain, or future wave pressure before the wave 5 boss gate.

## Requirements

1. The run has four normal waves followed by a wave 5 boss, because the first boss gate should arrive quickly enough to validate the reward loop without requiring a long run.
2. Clearing each normal wave presents three random reward choices before the next wave starts so the player gets a deliberate build or map decision between combat beats.
3. Choosing a reward applies it immediately and starts the next wave after the choice closes, because the first pass favors low-friction pacing over targeting previews or delayed resolution.
4. Terrain rewards can add one connected land tile or remove one safe land tile while preserving gameplay validity, because terrain changes should create tactical variety without isolating actors or breaking pathing.
5. Pressure rewards can increase future enemy counts so the player can trade power or space against higher later-wave pressure.
6. Minor cards are numeric player stat changes, while Major cards are structural gameplay changes with only a placeholder class-change family in this phase.

## Design

Wave structure:

| Wave | Role   | Base enemies |
| ---- | ------ | ------------ |
| 1    | Normal | 5            |
| 2    | Normal | 6            |
| 3    | Normal | 7            |
| 4    | Normal | 8            |
| 5    | Boss   | 1 boss       |

Normal wave enemy counts are base count plus accumulated future-enemy modifiers. The boss wave stays a boss gate and does not need to multiply the boss count from pressure rewards in the first pass.

Reward timing:

1. A normal wave starts by moving the player to a safe central land cell.
2. The wave spawns all enemies for that wave.
3. When all enemies are cleared, spawning pauses and three reward choices appear.
4. The selected reward applies immediately.
5. The next wave starts.
6. Clearing the boss completes the run.

Card categories:

| Category | Meaning                     | First-pass examples                                              |
| -------- | --------------------------- | ---------------------------------------------------------------- |
| Terrain  | Changes playable land shape | Add one connected land tile, remove one safe connected land tile |
| Pressure | Makes later waves harder    | Add one enemy to each future normal wave                         |
| Minor    | Numeric player stat buff    | Damage up, dash cooldown down, max health up                     |
| Major    | Structural gameplay change  | Class-change placeholder                                         |

Terrain add chooses a random sea cell adjacent to the existing landmass and turns it into land immediately. Terrain removal chooses a random removable land cell, rejects cells occupied by active actors or reservations, and rejects removals that would split the remaining landmass. Terrain choices do not open a tile-selection mode in this phase.

Major and Minor are card categories, not rarity. Minor means pure numeric stat change. Major means a change that can alter the player's action model, class, weapon, or other structural rules. The first implementation only needs enough Major-card plumbing to show, select, and apply a placeholder effect without implementing real class behavior.

Controller ownership rule: runtime controllers coordinate flow and may hold ephemeral state such as the current reward offer, but durable run state belongs to the system that owns that state. Enemy count modifiers belong to the run/wave state, player stat buffs belong to player stat state, and terrain changes belong to the arena terrain authority.

## Non-Goals

1. Do not implement card rarity, deck-building economy, permanent progression, or reward art.
2. Do not implement real class changes, weapon attack variants, or player action-model swaps in this phase.
3. Do not add manual tile preview, tile targeting, placement confirmation, or cancellation for terrain rewards.
4. Do not add advanced procedural island shaping beyond connected add and safe connected remove.
5. Do not add mid-wave normal enemy spawning.

## Acceptance Criteria

1. Waves 1 through 4 are normal enemy waves and wave 5 is the boss gate.
2. Clearing each normal wave presents exactly three reward choices before the next wave begins.
3. Selecting a reward applies exactly one option immediately and then advances the run.
4. Add-land rewards never create isolated land.
5. Remove-land rewards never remove occupied, reserved, or player cells and never split the remaining landmass.
6. Future enemy count increases affect later normal waves after the card is selected.
7. Minor cards apply numeric player stat changes through player stat state.
8. Major cards can be identified, offered, and selected without implementing real class behavior.
